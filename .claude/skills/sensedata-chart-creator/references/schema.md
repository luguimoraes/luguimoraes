# Schema completo do JSON de gráfico

Referência campo a campo. A maioria é boilerplate que você só copia; os que importam de verdade estão
marcados como **importante**.

```json
{
  "_comment": "",
  "advanced_mode": true,
  "aggregation_type": null,
  "chart_type": "table",
  "columns": [ /* importante — ver abaixo */ ],
  "custom_data_type": null,
  "data_fields": [],
  "data_source": "support_ticket",
  "dimension": null,
  "fields": { "fields": { /* importante — ver abaixo */ } },
  "filter": [],
  "interval_range": null,
  "interval_type": null,
  "legend": true,
  "name": "nome_interno_sem_espaco",
  "query": "SELECT ... %(id_customer)s ...",
  "slots": 2,
  "title": "Título visível pro usuário",
  "tooltip_template": null,
  "transpose": null,
  "type": "table",
  "x": "",
  "x_template": "",
  "x_title": "",
  "x_type": null,
  "y": [],
  "y_labels": {},
  "y_title": []
}
```

## `columns` (importante)

Lista ordenada — a ordem aqui é a ordem visual das colunas na tabela.

```json
{ "field": "ticket", "title": "Ticket", "width": "100px" }
```

Com template (ver `kendo-templates.md` pra sintaxe):

```json
{ "field": "dias_aberto", "title": "Dias em aberto", "width": "95px", "template": "#= dias_html #" }
```

- `field`: precisa bater com uma coluna do `SELECT` da query E ter entrada em `fields.fields`.
- `title`: o texto do cabeçalho, livre.
- `width`: string com `px`. Sem isso o Kendo distribui de forma imprevisível quando a tabela é larga.
- `template` (opcional): sobrescreve o que é renderizado na célula. Sem `template`, a coluna renderiza o
  valor cru (bom pra números que precisam ordenar certo, como `ticket` ou `nps`).

## `fields.fields` (importante)

Dicionário `{nome_do_campo: {"field": nome_do_campo, "type": "string"|"number"}}`. Regras:

- Todo `field` que aparece em `columns` tem que estar aqui.
- Todo campo que só é usado **dentro de um `template`** (mas não é ele mesmo uma coluna) também precisa
  estar aqui — por exemplo, `media_historica` sendo lido dentro do template de outra coluna pra decidir
  a cor.
- `type: "number"` é o que garante que a coluna ordena numericamente em vez de como texto — use sempre
  que o valor cru é numérico, mesmo que o `template` da coluna vá formatar como HTML/emoji por cima.

## `data_source`

Nome informativo da tabela/entidade principal da query (`support_ticket`, `custom_data`, `customer`...).
Não muda o comportamento da query em si (a query já é SQL puro), mas mantenha coerente com o que a query
realmente lê — ajuda quem for reabrir esse JSON depois.

## `title` vs `name`

- `title`: o que o usuário final vê como cabeçalho do gráfico.
- `name`: identificador interno, sem espaço, em snake_case (ex.: `detalhamento_devolucoes_totais`).

## `tooltip_template`

Texto livre (não é um template Kendo, é só uma string) mostrado como tooltip/legenda do gráfico. Vale
muito a pena preencher em tabelas de detalhamento carregadas — documentar em 1-2 frases o que cada cor/
emoji significa e qual linha corresponde ao valor do KPI evita que o usuário tenha que perguntar depois.

## Campos que praticamente sempre ficam com o default

`advanced_mode: true`, `aggregation_type: null`, `custom_data_type: null`, `data_fields: []`,
`dimension: null`, `filter: []`, `interval_range: null`, `interval_type: null`, `legend: true`,
`transpose: null`, `x/x_template/x_title: ""`, `x_type: null`, `y: []`, `y_labels: {}`, `y_title: []`.
Esses só mudam de valor em tipos de gráfico diferentes de tabela (linha, barra etc.), que esta skill não
cobre em detalhe ainda — se o usuário pedir um gráfico de linha/barra, os campos `x`/`y`/`x_type` passam
a importar; pergunte ou peça um exemplo já configurado desse tipo antes de inventar a estrutura.
