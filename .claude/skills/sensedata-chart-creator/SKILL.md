---
name: sensedata-chart-creator
description: Cria, corrige e valida os JSONs de "gráfico customizado" do SenseData — o schema chart_type/columns/fields/query/slots/type usado nas tabelas de detalhamento e KPIs. Use esta skill sempre que o usuário pedir para montar uma tabela de detalhamento, um gráfico ou um KPI no SenseData, colar uma query SQL de KPI pedindo "a tabela de composição/detalhamento" correspondente, ou pedir ajuda pra arrumar um JSON de gráfico que não está renderizando, mostrando número errado, com # ou % quebrando a query, ou com coluna/template bugado. Também dispara quando o usuário menciona "criador de gráficos", "detalhamento do KPI", "composição do cálculo", ou pede pra revisar/validar um JSON desses antes de subir pra produção.
---

# SenseData — Criador de Gráficos (JSON de tabela/KPI)

## O que é isso

O "criador de gráficos" do SenseData é um construtor de tabelas e KPIs customizados: você escreve uma
query SQL (Postgres) e um JSON de configuração, e a plataforma roda a query por cliente (`id_customer`)
e renderiza o resultado como tabela (grid Kendo UI) ou como valor de KPI. A maior parte dos pedidos deste
tipo se encaixam em duas categorias:

1. **KPI** — uma query curta que devolve `id_customer, score` para TODOS os clientes de uma vez
   (executada com bind `:ref_date`, estilo SQLAlchemy). Normalmente já vem pronta quando o usuário pede
   ajuda — seu trabalho costuma ser explicar o que ela calcula ou montar a tabela de detalhamento dela.
2. **Tabela de detalhamento/composição** — uma tabela por cliente (`chart_type: "table"`) que justifica o
   valor de um KPI, mostrando o histórico e como o número foi composto. É aqui que mora a maior parte do
   trabalho desta skill.

Isso é diferente da skill `sense-data` (Regras, Playbooks, Jornada) — aquela é sobre configurar automações
de CS na tela de Regras; esta é sobre escrever o JSON/SQL por trás de um gráfico ou KPI.

## Fluxo recomendado

1. **Nunca adivinhe o nome ou o formato de uma chave de `custom_data`.** Peça pro usuário rodar (ou rode
   você mesmo, se tiver acesso) `SELECT DISTINCT jsonb_object_keys(data) FROM custom_data WHERE type_ = '<tipo>'`
   antes de escrever a query — nomes têm pegadinhas reais já vistas (`brand_`, `bechmarking_`, chave que é
   contagem vs. chave que é percentual com nome parecido). Se o usuário mandar um export/CSV real, cruze os
   dados ao invés de confiar só no nome do campo — veja `references/design-patterns.md`.
2. **Escreva a query primeiro, como string Python separada**, depois o JSON. Sempre gere o arquivo final
   com um script Python que faça `json.dump(..., ensure_ascii=False, indent=2)` — nunca digite o JSON à
   mão quando a query tem aspas, emoji, `%` ou `#`. Use `scripts/build_chart_json.py` como esqueleto.
3. **Depois de gerar, rode `scripts/validate_chart_json.py <arquivo>`** antes de mostrar o resultado pro
   usuário. Ele checa tudo que já causou bug real nesta conta (ver landmines abaixo).
4. Se a tabela é uma "composição/detalhamento" de um KPI, siga os padrões de
   `references/design-patterns.md` (tendência, média histórica, proteção contra NULL, cor invertida
   quando "menor é melhor").
5. Para os detalhes de sintaxe do Kendo (`#: #` vs `#= #`, tooltip, mailto, span colorido), veja
   `references/kendo-templates.md`.

## Anatomia mínima do JSON

Todo gráfico tem esses campos obrigatórios — sem eles a plataforma rejeita ou renderiza em branco:

```
chart_type   "table" (ou outro tipo de gráfico)
type         mesmo valor de chart_type na prática observada ("table")
slots        sempre 2
columns      lista de {field, title, width, template?}
fields       {"fields": {<field>: {"field": <field>, "type": "string"|"number"}, ...}}
query        a query SQL, numa linha só, com bind %(id_customer)s
```

Todo `field` usado em `columns` **precisa** ter uma entrada correspondente em `fields.fields`. Campos que
só existem para alimentar um `template` (não aparecem como coluna própria) também devem entrar em
`fields.fields` — não custa nada e evita erro silencioso.

O restante dos campos (`advanced_mode`, `aggregation_type`, `custom_data_type`, `data_fields`,
`data_source`, `dimension`, `filter`, `interval_range`, `interval_type`, `legend`, `name`, `title`,
`tooltip_template`, `transpose`, `x`, `x_template`, `x_title`, `x_type`, `y`, `y_labels`, `y_title`) é
boilerplate — veja `references/schema.md` pros valores default de cada um. Vale usar `tooltip_template`
pra documentar em uma frase a lógica da tabela (cores, o que cada coluna representa) — isso já ajudou o
usuário a entender rápido tabelas mais carregadas.

## Os dois landmines que já quebraram gráfico de verdade

**1. `#` só pode aparecer em pares `#: campo #` ou `#= expressão #`.** Qualquer `#` solto quebra a
renderização do Kendo. Depois de escrever qualquer `template`, conte quantos `#` tem — tem que ser par.
O validador faz isso automaticamente.

**2. `%` literal fora de um bind `%(nome)s` precisa virar `%%`.** O SenseData aplica formatação de string
estilo Python na query antes de rodar — isso vale pra `LIKE`/`ILIKE` também (`ILIKE '%%palavra%%'`, não
`'%palavra%'`), não só pra `LIKE` "antigo". Um `%` sozinho no meio da query quebra o bind.

Os dois itens acima, mais paridade de aspas simples/duplas e parênteses, e a checagem
`columns` ↔ `fields.fields`, são exatamente o que `scripts/validate_chart_json.py` roda. Use sempre —
já foi assim que se pegou bug antes de chegar no usuário mais de uma vez nesta conta.

## Query de KPI vs. query de tabela de detalhamento

Não são o mesmo motor/contexto — não misture o estilo de bind:

- **KPI** (roda pra todos os clientes): usa CTEs nomeadas (`"A"`, `"B"`), bind `:ref_date`
  (estilo SQLAlchemy), e faz `LEFT OUTER JOIN` com `customer`. Você recebe essas prontas na maioria das
  vezes — leia com atenção pra saber exatamente qual chave do `custom_data` ela usa antes de montar
  qualquer coisa em cima dela (veja o caso do campo `veiculos` vs `veiculos_utilizados` em
  `references/design-patterns.md` — o nome do KPI não garante qual chave o SQL realmente lê).
- **Tabela de detalhamento** (roda por cliente): filtra `WHERE id_customer = %(id_customer)s`
  (bind estilo psycopg2), normalmente com `ORDER BY ref_date DESC LIMIT N` pra trazer o histórico mais
  recente primeiro — a primeira linha deve bater exatamente com o valor que o KPI está mostrando.

## Antes de entregar

- [ ] Rodei `scripts/validate_chart_json.py` no arquivo final e todos os checks passaram
- [ ] Toda chave de `custom_data` usada foi confirmada (nome exato, e se é contagem ou percentual)
- [ ] Se é tabela de detalhamento: a linha mais recente bate com o valor do KPI
- [ ] Se a métrica pode ter "menor é melhor" (devoluções, cancelamentos, chamados) — confirmei que a cor
      e a classificação estão na direção certa, não copiei a lógica de uma tabela "maior é melhor" sem
      inverter
- [ ] Testei mentalmente (ou simulei em Python) pelo menos 2 cenários reais: um "normal" e um "borda"
      (cliente com só 1 período, ou com o período mais recente sem dado) — veja
      `references/design-patterns.md` pra a lista completa de cenários de borda que valem a pena simular
