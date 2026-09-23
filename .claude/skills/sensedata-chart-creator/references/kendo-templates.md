# Templates Kendo — receitas

O grid é renderizado pelo Kendo UI. Uma coluna sem `template` mostra o valor cru do `field`. Com
`template`, você controla o HTML da célula — mas o campo **continua existindo** por baixo pra fins de
ordenação (por isso ele precisa estar em `fields.fields` com o `type` certo mesmo tendo um template).

Existem dois estilos de template. Não misture os dois dentro da mesma expressão.

## Estilo 1 — `#: campo #` (interpolação simples)

Só imprime o valor do campo (com HTML-escape). Use quando a **própria query SQL** já montou o HTML/texto
final e você só precisa jogar na célula:

```json
"template": "<span title='#: motivo_full #'>#: motivo #</span>"
```

Aqui `motivo_full` e `motivo` são colunas normais do `SELECT` — o SQL já decidiu o texto, o template só
posiciona.

## Estilo 2 — `#= expressão #` (JavaScript nativo)

Roda JavaScript de verdade no navegador, com acesso a qualquer campo da linha (`dataItem`, mas dentro do
`#= #` os campos ficam disponíveis direto pelo nome). Use quando a decisão (cor, emoji, texto condicional)
depende de comparar valores ou montar string dinamicamente:

```json
"template": "#= nps == null ? '-' : (nps >= 9 ? '🟢 ' : nps >= 7 ? '🟡 ' : '🔴 ') + nps #"
```

```json
"template": "#= media_atual == null ? '-' : '<span style=\"color:' + (media_atual >= media_historica ? 'seagreen; font-weight:700' : 'crimson; font-weight:700') + '\">' + media_atual + '</span>' #"
```

Repare: aspas duplas dentro do HTML (`style=\"color:...\"`) precisam ser escapadas com `\"` porque tudo
isso é uma string dentro do JSON. É exatamente o tipo de coisa que quebra se você escrever o JSON à mão —
gere sempre via `json.dump` (ver `scripts/build_chart_json.py`).

**Sempre cheque `null` primeiro**, antes de qualquer comparação (`>`, `>=`, `<`). Em JavaScript,
`5 > null` vira `5 > 0` (null vira zero) e dá `true` — isso já causou uma coluna colorindo "verde" um
cliente que não tinha histórico nenhum ainda, só porque `media_historica` era `null`. Padrão seguro:

```
#= valor == null ? '-' : (referencia == null ? valor : /* comparação normal aqui */) #
```

## Receitas prontas

**Mailto clicável:**
```json
"template": "#= email == '-' ? '-' : '<a href=\"mailto:' + email + '\" style=\"color:rgb(0,90,200); text-decoration:none;\">✉️ ' + email + '</a>' #"
```

**Variação com seta (novo / subiu / caiu / estável), a partir de um campo de direção calculado em SQL:**
```json
"template": "#= direcao == 'sem_dado' ? '⚠️ Sem dado no período' : (direcao == 'novo' ? '🆕 Novo período' : (direcao == 'subiu' ? '⬆️ +' + variacao + '%' : (direcao == 'caiu' ? '⬇️ ' + variacao + '%' : '➡️ Estável'))) #"
```

**Diferença com seta neutra (sem julgar se subir é bom ou ruim):**
```json
"template": "#= diff == null ? '🆕 Novo' : (diff > 0 ? '🔼 +' + diff : diff < 0 ? '🔽 ' + diff : '➖ 0') #"
```

**Badge de classificação vs. média histórica (maior é melhor):**
```json
"template": "#= valor == null ? '⚠️ Sem dado' : (delta == null ? '🟡 Sem histórico' : (delta >= 5 ? '🟢 Acima da média' : (delta <= -5 ? '🔴 Abaixo da média' : '🟡 Na média'))) #"
```

**A mesma badge, mas invertida (menor é melhor — devoluções, cancelamentos, chamados):** troque os dois
sinais de comparação (`<=` fica `🟢`, `>=` fica `🔴`) — veja `design-patterns.md` sobre esse ponto, é
fácil esquecer de inverter quando se copia de outra tabela.

## Checklist rápido de sintaxe

- Todo `#` abre e fecha em par (`#:` ou `#=`, sempre terminando em ` #`).
- Toda aspas dupla dentro do HTML gerado por um `#= #` está escapada como `\"`.
- Nunca misture `#:` com `#=` na mesma célula — escolha um estilo por template.
- Se o template ficar com mais de 2-3 ternários aninhados, considere mover parte da decisão pra uma
  coluna calculada em SQL (um campo `direcao`/`categoria` em texto) e deixar o template só traduzir esse
  texto pro emoji/cor — fica mais fácil de debugar do que um ternário gigante.
