# Conta Matriz / Grupos Econômicos — SenseData

**Cliente:** Grupo Hiper Saúde – RM Farma · **Ticket:** 477940 (Movidesk)
**Integração:** `Grupos_Economicos` (id 20) · **Conexão:** `SENSEDATA_HOM` (id 6)

Análise técnica da integração atual, correções necessárias e plano de implantação.

---

## 1. O que o cliente pediu (resumo dos documentos)

| Requisito | Origem | Atendido pela integração atual? |
|---|---|---|
| Registrar CS Feeling e anotações **uma única vez** na Conta Matriz | Ticket 477940, ação 1 | Sim |
| Propagar automaticamente para todos os CNPJs do grupo | Ticket, ação 5 (resposta 1) | Sim |
| Registros permanecerem **editáveis**, alteração reflete para o grupo | Ticket, ação 5 (resposta 3) | Sim (`overwrite`) |
| Atualização **em tempo real** | Ticket, ação 5 (resposta 4) | **Não** — é batch agendado |
| Conta Matriz **sem CNPJ** para não poluir volumetria de lojas | Ticket, ação 1 | Parcial — a conta continua contando nos painéis |
| Propagar **resumo de atividades** e visões estratégicas | Ticket, ação 5 (resposta 2) | Não — fora do escopo atual |
| Filtrar **apenas lojas ativas** | Ata de 30/07/2026 | **Não** — é o gap principal |
| Detalhamento por CNPJ preservado | Ata de 25/06/2026 | **Não na v1** — sobrescreve o campo da loja |

---

## 2. Achados da análise

### 2.1 🔴 BLOQUEANTE — o Base64 do documento de estruturação está quebrado

O Base64 publicado no item *3.2 – Passos para Implantação* **não é o mesmo SQL** mostrado no
item 3.1. Ao decodificar, aparece uma vírgula a mais:

```sql
WHERE "group",  IS NOT NULL
--            ^ vírgula indevida
```

Validado com o parser oficial do PostgreSQL (libpg_query):

```
syntax error at or near ",", at index 244
```

Se essa string for colada no step 122, **a integração quebra na primeira execução**. Foi um
encode manual — por isso este repositório inclui `tools/gerar_integracao.py`, que gera o Base64
a partir do `.sql` revisado e faz round-trip obrigatório. Encode manual não deve mais acontecer.

### 2.2 🔴 Duplicação silenciosa quando o grupo tem mais de uma matriz

A CTE `matriz` não garante unicidade por `(company, group)`. Basta existir uma segunda conta sem
CNPJ no mesmo grupo — prospect importado, cadastro duplicado, matriz antiga não removida — para o
`INNER JOIN` multiplicar as linhas. Cada loja aparece 2x com valores diferentes e **o valor gravado
vira loteria**, sem erro nenhum no log. Corrigido com `DISTINCT ON` + desempate determinístico
(`updated_at DESC, id DESC`). Diagnóstico: `sql/01_qualidade_dados.sql` item 1.1.

### 2.3 🟠 Reescrita total a cada execução (`load_type: total`, sem delta)

A query devolve **todas** as lojas de **todos** os grupos, mudou ou não. Consequências:

- histórico/timeline da conta poluído com atualizações que não mudaram nada;
- risco real de disparar as **regras de ciclo e alerta de CS Feeling** definidas na ata de 23/07 —
  uma loja pode aparecer como "CS Feeling em dia" só porque o robô reescreveu o mesmo valor;
- carga de escrita desnecessária a cada execução.

Corrigido com filtro `IS DISTINCT FROM` comparando o valor da matriz com o que já está na loja.
Só trafega o que mudou de verdade.

### 2.4 🟠 Informação órfã nunca é limpa

A carga é `update` por chave: **linha que não aparece no resultado não é tocada**. Então:

- loja que sai do grupo → mantém o CS Feeling do grupo antigo, para sempre;
- loja que é cancelada → congela a última anotação;
- matriz apagada → todas as filhas ficam com o dado fantasma.

E, ironicamente, **adicionar o filtro de lojas ativas piora isso**: a loja inativa some do resultado
justamente com o dado velho gravado. A v2 resolve emitindo valor vazio para quem deixou de ser
elegível.

### 2.5 🟠 O JOIN por texto exato é frágil

`filho."group" = matriz."group"` é comparação literal. `"RM Farma"`, `"RM FARMA "` e `"rm farma"`
são três grupos distintos para o Postgres — a loja simplesmente não recebe nada e ninguém percebe.
Normalizado com `upper(btrim(...))` nos dois lados. Diagnóstico: item 1.4.

### 2.6 🟠 Matriz vazia apaga o conteúdo das filhas

Se a matriz está com CS Feeling em branco, a query propaga `NULL` com `overwrite` — **apagando** o
que a loja tinha. Na v1 a matriz em branco é ignorada; na v2 a limpeza passa a ser intencional e
controlada pela regra de elegibilidade.

### 2.7 🟡 Identificar matriz por "não tem CNPJ" é uma heurística, não uma regra

Ausência de CNPJ é *consequência* de ser matriz, não a *definição*. Qualquer conta cadastrada sem
CNPJ (prospect, importação incompleta) vira matriz por acidente. Proposta: custom field
`tipo_conta = 'matriz'`, com o critério antigo mantido como fallback — a query aceita os dois, então
a migração pode ser feita sem janela de indisponibilidade.

### 2.8 🟡 Chave de carga (`customer_id_legacy`) não foi verificada

O step 123 usa `keys: ["customer_id_legacy"]`. Se houver `id_legacy` nulo ou duplicado, a carga
falha ou atualiza a conta errada. As queries já filtram nulos; a checagem está em
`sql/00_descoberta_modelagem.sql` item 0.6.

### 2.9 🟡 "Tempo real" não é o que a integração entrega

O cliente respondeu, textualmente, que a necessidade é **atualização em tempo real**. Uma integração
agendada não faz isso. Isso precisa ser alinhado explicitamente — ver seção 5.

### 2.10 🟡 A conta fantasma continua poluindo os indicadores

Foi o motivo declarado para a matriz não ter CNPJ, mas ela permanece na base e é contada em
volumetria, health score médio, listas e segmentações. Não tem solução via SQL da integração: exige
excluir `tipo_conta = 'matriz'` dos painéis e segmentações.

### 2.11 ⚪ Ponto de atenção de produto — o bug histórico das atividades

O cliente relata que o projeto foi abandonado no passado porque **a atividade não podia ser editada
depois de criada**. Replicar atividades para N CNPJs recria exatamente esse problema, multiplicado.
Recomendação: **não replicar atividades**. Manter o registro único na matriz e dar à loja um campo
com o nome da matriz (`conta_matriz_nome`) — e, se possível, um deep-link — para o consultor chegar
ao histórico central em um clique.

---

## 3. O que está neste repositório

```
sensedata/grupos-economicos/
├─ sql/
│  ├─ 00_descoberta_modelagem.sql   Descobre o nome real da coluna de status,
│  │                                 chaves de custom_fields, integridade do id_legacy
│  ├─ 01_qualidade_dados.sql        Prova com número: matriz duplicada, grupo órfão,
│  │                                 grafia divergente, matriz vazia
│  ├─ 02_preview_impacto.sql        Dry-run: quantas contas cada versão toca, antes/depois
│  ├─ 10_query_v1_correcao_minima.sql   Drop-in, mesmo mapeamento de hoje
│  ├─ 20_query_v2_recomendada.sql       Campos dedicados + limpeza + rastreabilidade
│  └─ 90_indices_sugeridos.sql      Opcional, só se o EXPLAIN justificar
├─ tools/
│  └─ gerar_integracao.py           Gera o JSON e o Base64 a partir do .sql (com round-trip)
└─ integracao/
   ├─ Grupos_Economicos.json                        original recebido
   ├─ Grupos_Economicos_v1_correcao_minima.json     pronto para importar
   └─ Grupos_Economicos_v2_recomendada.json         pronto para importar
```

Todos os arquivos `.sql` foram validados sintaticamente com o parser oficial do PostgreSQL
(libpg_query/pglast). **Nenhum foi executado contra a base.**

> ⚠️ **Credencial redigida.** O JSON exportado do SenseData traz o campo `connection_params` com a
> credencial da conexão (criptografada, mas ainda material sensível). Nos arquivos deste repositório
> ele foi substituído por `REDACTED__preencher_no_ambiente_SenseData`. **Ao importar, o SenseData
> deve reaproveitar a conexão já existente (id 6) — não versione o blob original.** Vale registrar
> como prática do time: export de integração é artefato com segredo dentro.

---

## 4. As duas versões propostas

### v1 — Correção mínima (drop-in)

Mesmo mapeamento de campos de hoje, nenhum campo novo no SenseData. Entrega o filtro de lojas
ativas pedido em 30/07 e fecha os bugs de duplicação, grafia, churn e matriz vazia.
Use se o objetivo for destravar o prazo com risco mínimo.

**Trade-off:** continua sobrescrevendo o `cs_feeling` da própria loja. O consultor perde a
capacidade de ter um feeling individual por CNPJ — e, se editar na loja, o robô reverte na próxima
execução. Isso precisa ser dito ao cliente, porque contradiz o "permitindo detalhar por CNPJ" da
ata de 25/06.

### v2 — Recomendada

O dado do grupo passa a viver em campos próprios:

| Campo na loja | Conteúdo |
|---|---|
| `cs_feeling_grupo` | CS Feeling registrado na matriz |
| `anotacoes_grupo` | anotações estratégicas da matriz |
| `conta_matriz_nome` | qual matriz originou o dado |
| `grupo_atualizado_em` | quando a matriz foi atualizada |

Ganhos: o feeling individual da loja é preservado; acaba a ambiguidade de "quem escreveu isso";
a passagem de bastão fica resolvida de verdade (o consultor vê a origem e a data); e a limpeza de
dado órfão passa a acontecer automaticamente.

**Custo:** criar 4 custom fields e ajustar os painéis/visão 360 para exibi-los. É meio dia de
configuração.

---

## 5. Sobre o "tempo real" — alinhamento necessário

A integração é **batch agendado**. Não existe propagação instantânea por esse caminho. Caminhos
possíveis, em ordem de custo:

1. **Agora:** agendar a cada 30–60 min + orientar o time a usar "executar agora" depois de uma
   reunião estratégica. Cobre a operação real de CS (ninguém registra CS Feeling e consulta o
   resultado em outro CNPJ no minuto seguinte).
2. **Curto prazo:** reduzir para 15 min, se o volume permitir — com o filtro de delta da v1/v2 o
   custo por execução cai bastante, então aumentar a frequência fica barato.
3. **Estrutural:** hierarquia nativa de contas no SenseData (matriz/filial como relação de produto,
   não como integração). É demanda de roadmap, não de configuração.

Sugestão de encaminhamento: entregar o item 1 agora e registrar o item 3 como pedido de produto no
mesmo ticket — inclusive porque é a solução definitiva que o cliente pediu ("solução viável e
definitiva").

---

## 6. Passo a passo de implantação

**Etapa 0 — Descoberta (30 min, homologação)**
1. Rodar `sql/00_descoberta_modelagem.sql` inteiro.
2. Anotar: nome e valores reais da coluna de status; confirmar que os custom fields se chamam
   mesmo `cs_feeling` e `anotacoes_grupo`; confirmar que o valor está em `->>'value'`;
   confirmar integridade do `id_legacy`; verificar se existe `updated_at`.
3. Substituir todas as linhas marcadas `[AJUSTAR]` nos arquivos `10_` e `20_`.

**Etapa 1 — Diagnóstico (30 min, homologação)**
4. Rodar `sql/01_qualidade_dados.sql`. Se o item 1.1 retornar linhas, **resolver os grupos com
   matriz duplicada antes de subir** — é a origem de resultado imprevisível.
5. Rodar `sql/02_preview_impacto.sql` e guardar os números. Eles viram a evidência da entrega.

**Etapa 2 — Decisão com o cliente (reunião curta)**
6. Apresentar v1 vs v2 (seção 4) e decidir. Ponto obrigatório da pauta: na v1, o CS Feeling
   individual por loja deixa de existir.
7. Confirmar a expectativa de frequência (seção 5).

**Etapa 3 — Publicação em homologação**
8. Se v2: criar os 4 custom fields.
9. Gerar o JSON:
   ```bash
   cd sensedata/grupos-economicos/tools
   python3 gerar_integracao.py build \
       --base ../integracao/Grupos_Economicos.json \
       --sql  ../sql/20_query_v2_recomendada.sql \
       --out  ../integracao/Grupos_Economicos_v2_recomendada.json \
       --campos cs_feeling_grupo,anotacoes_grupo,conta_matriz_nome,grupo_atualizado_em
   ```
10. Importar o JSON na integração 20, ou colar apenas o Base64 no step 122 e ajustar o
    mapeamento do step 123. **Não montar Base64 à mão** (ver 2.1).
11. Conferir no step 123: `keys = ["customer_id_legacy"]` e `options = overwrite` nos campos de
    destino — o `overwrite` é o que garante a característica editável pedida pelo cliente.

**Etapa 4 — Teste em homologação (o roteiro que valida o pedido do cliente)**
12. Escolher um grupo piloto que tenha loja ativa **e** loja inativa (item 2.2 do preview).
13. Editar CS Feeling e anotações na matriz → executar → conferir:
    - todas as lojas **ativas** receberam o valor;
    - nenhuma loja **inativa** foi tocada; ← *este é o ajuste de 30/07*
    - nenhuma conta duplicou registro;
    - o valor continua editável na matriz e a segunda edição também propaga. ← *bug histórico*
14. Executar a integração **duas vezes seguidas sem mudar nada** e confirmar que a segunda
    execução processa **0 linhas**. É a prova de que o anti-churn funciona.
15. Se v2: tirar uma loja do grupo, executar, confirmar que os campos de grupo foram limpos.

**Etapa 5 — Produção**
16. Criar/apontar a conexão de **produção** (hoje o JSON usa `SENSEDATA_HOM`, id 6) — este é o erro
    clássico de virada, o de subir a integração ainda apontando para homologação.
17. Definir o agendamento acordado na Etapa 2.
18. Excluir `tipo_conta = 'matriz'` dos painéis de volumetria e segmentações (item 2.10).
19. Monitoramento: acompanhar a contagem de linhas processadas. Zero por vários dias seguidos
    significa "nada mudou" **ou** "quebrou" — vale um alerta para distinguir.

**Etapa 6 — Governança**
20. Documentar para o time de CS: a matriz é a fonte da verdade do dado de grupo; editar na loja
    (v1) será revertido.
21. Migrar as matrizes para `tipo_conta = 'matriz'` e, depois, remover o fallback por CNPJ nulo.
22. Rodar `01_qualidade_dados.sql` mensalmente — grupo órfão e grafia divergente reaparecem
    sozinhos conforme a base cresce.

---

## 7. Resumo executivo

O ajuste pedido na ata de 30/07 (filtro de lojas ativas) é **uma linha**. O que a análise mostrou é
que subir só essa linha entrega um filtro correto sobre uma integração que ainda pode duplicar dado,
apagar informação com matriz vazia, reescrever tudo a cada execução e — se o Base64 do documento
for usado — nem sequer roda. As correções estão prontas e validadas; falta a decisão de v1 vs v2 e a
confirmação da modelagem em homologação.
