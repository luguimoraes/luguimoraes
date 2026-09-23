# Padrões de tabela de detalhamento (composição de KPI)

Quando o pedido é "quero a tabela de detalhamento/composição desse KPI", o objetivo é: mostrar o
histórico mensal por trás do número, de um jeito que a **primeira linha bata exatamente com o valor que o
KPI está mostrando agora**, e que explique por que ele está naquele patamar.

## Esqueleto de query que funciona bem

```sql
WITH base AS (
    SELECT
        ref_date,
        CAST(data ->> 'campo_do_kpi' AS NUMERIC) AS valor
        -- outros campos relacionados que ajudam a contextualizar
    FROM custom_data
    WHERE type_ = 'kpis'
      AND id_customer = %(id_customer)s
      AND data ? 'campo_do_kpi'
),
calc AS (
    SELECT
        ref_date,
        valor,
        LAG(valor) OVER (ORDER BY ref_date) AS valor_anterior,
        ROUND(AVG(valor) OVER (), 1) AS media_historica
    FROM base
)
SELECT
    TO_CHAR(ref_date, 'MM/YYYY') AS periodo,
    valor,
    (valor - valor_anterior) AS diff,
    media_historica,
    CASE
        WHEN valor IS NULL THEN 'sem_dado'
        WHEN valor_anterior IS NULL THEN 'novo'
        WHEN valor > valor_anterior THEN 'subiu'
        WHEN valor < valor_anterior THEN 'caiu'
        ELSE 'estavel'
    END AS direcao,
    CASE WHEN media_historica IS NULL OR media_historica = 0 THEN NULL
         ELSE ROUND(((valor - media_historica) / media_historica) * 100, 1) END AS delta_vs_historico
FROM calc
ORDER BY ref_date DESC
LIMIT 12
```

Por que cada peça está aí:

- **`AVG(valor) OVER ()` sem `PARTITION BY`** funciona como "média histórica do cliente" só porque o
  `WHERE id_customer = %(id_customer)s` já filtrou pra um cliente só antes da janela ser calculada. Não é
  uma média de todos os clientes — é a própria base de comparação do cliente contra ele mesmo. Isso é
  proposital: nunca invente uma meta/benchmark externo que o usuário não confirmou (tipo "abaixo de X é
  ruim"). Comparar o cliente com o próprio histórico é uma linha de base defensável sem precisar de
  confirmação de negócio.
- **`ORDER BY ref_date DESC LIMIT 12`** só limita a EXIBIÇÃO. A média histórica (`AVG(...) OVER()` na CTE
  `calc`) já foi calculada em cima de TODO o histórico disponível na CTE `base`, antes do `LIMIT` — não
  mexa na ordem disso, senão a média fica só dos últimos 12 meses mostrados.
- **Tolerância de ±5%** na classificação (`delta_vs_historico >= 5` / `<= -5`) evita que arredondamento
  vire ruído: sem isso, qualquer diferença mínima já pinta de verde ou vermelho.

## O bug de NULL que já aconteceu de verdade (proteja sempre)

`NULL > x` e `NULL < x` em SQL nunca são verdadeiros — então um `CASE` sem o `WHEN valor IS NULL THEN`
explícito cai no `ELSE` e mostra "Estável" pra um mês que na verdade **não tem dado nenhum lançado**. Isso
já enganou a leitura de uma tabela real (mostrava "➡️ Estável" quando devia mostrar "sem dado"). Sempre
coloque o `WHEN valor IS NULL THEN 'sem_dado'` como **primeira** condição do CASE, antes de comparar com
o período anterior.

O mesmo problema existe do lado do JavaScript nos templates: `5 > null` vira `5 > 0` → `true`. Por isso
todo template que compara um valor com uma referência (`media_historica`, etc.) precisa checar
`== null` nos dois primeiro, na ordem: valor da própria célula → depois a referência → só então comparar.

## "Maior é melhor" vs. "menor é melhor" — não copie a cor sem pensar

Antes de colorir/classificar, pergunte: **pra essa métrica, subir é bom ou ruim?**

- Romaneios por veículo, % de utilização de frota, NPS → maior é melhor → acima da média = 🟢, abaixo = 🔴.
- Devoluções, cancelamentos, reentregas, chamados em aberto, dias em atraso → menor é melhor → **inverta**:
  acima da média = 🔴, abaixo da média = 🟢.

É fácil copiar uma tabela pronta pra economizar tempo e esquecer de inverter esse sinal — isso já
aconteceu (o padrão "maior é melhor" foi reaproveitado certo, mas exigiu atenção explícita na hora de
montar a tabela de devoluções pra não sair igual à de romaneios).

## Percentual disfarçado de contagem (e vice-versa)

Antes de confiar no *nome* de uma chave do `custom_data`, confira o que ela **realmente** contém: já
apareceu uma chave chamada de um jeito que sugeria contagem (`veiculos`) mas que na real guardava um
**percentual** (veículos utilizados / veículos contratados × 100), enquanto a contagem de verdade estava
em outra chave (`veiculos_utilizados`). Isso só foi descoberto cruzando exemplos reais de dados
(`veiculos_utilizados / veiculos_contratados * 100` batendo exatamente com o valor de `veiculos` em
várias linhas). Um card de KPI que mostra só o número cru, sem `%`, faz o percentual parecer contagem —
gera confusão real do tipo "esse cliente tem 3 veículos?" quando na verdade é "3% de utilização".

Regra prática: se o *nome* do campo é ambíguo (`veiculos`, `realizadas`, `total_entregas_70`...), pegue
2-3 linhas reais de dado e tente recalcular a partir de campos relacionados antes de assumir o
significado. Se o resultado não bater, ou se você não tiver como confirmar, é melhor:

1. Separar em dois campos/KPIs com nome explícito (`Veículos Utilizados` = contagem,
   `% Utilização da Frota` = percentual) do que forçar os dois significados num nome só, e
2. Perguntar ao usuário em vez de adivinhar o que uma chave ambígua representa.

## Cenários de borda que valem a pena simular antes de entregar

Ao montar (ou testar) uma tabela de detalhamento, tenta cobrir mentalmente ou com dado real:

- **Só 1 período de histórico** — `media_historica`/`valor_anterior` ficam `NULL`; confira que o template
  não quebra nem colore errado (ver seção de NULL acima).
- **Denominador zero** (ex.: `veiculos_utilizados = 0` numa razão) — confirme que o `NULLIF(x, 0)` está lá
  e que a célula mostra `-`, não erro.
- **Mês mais recente sem dado, mas com histórico anterior** — é diferente de "só 1 período": aqui
  `valor IS NULL` mas `valor_anterior` existe. Precisa cair em `'sem_dado'`, não em `'novo'`.
  Isso é *comum* na prática quando a chave existe no JSON com valor `null` em vez de a chave estar
  ausente — o filtro `data ? 'chave'` não pega esse caso (a chave existe, só o valor é nulo).
- **Tendência de alta / de queda clara** — confirma a seta e a cor certas.
- **Valor exatamente igual à média histórica** (dentro da tolerância) — cai em "🟡 Na média", não em
  🟢 nem 🔴.
- **Vários `id_customer` com o mesmo valor exato** — pode ser normal (grupo econômico/matriz replicando
  valor pros clientes-filho), não assuma que é erro de query.

## Achando clientes reais pra testar (em vez de inventar dado)

Se o usuário puder mandar um export/CSV real de `custom_data` (ou de qualquer tabela relevante), **use
os dados de verdade** pra achar clientes que cobrem os cenários de borda acima, em vez de simular
mentalmente:

```python
import csv, json
# CSV costuma vir pipe-delimited, com uma coluna `data` em JSON (aspas duplicadas: "" vira ")
with open(path, newline="", encoding="utf-8") as f:
    reader = csv.reader(f, delimiter="|")
    header = next(reader)
    for row in reader:
        if row[2] != "kpis":  # coluna type_
            continue
        data = json.loads(row[3])
        # cruze data.get('campo_a'), data.get('campo_b') pra achar os casos de borda
```

Um ponto que já rendeu recomendação errada: ao procurar "um cliente detrator" ou "um cliente que bate a
condição X" pra testar uma Regra, **filtre primeiro pelo registro mais recente por cliente**, e só depois
aplique a condição — porque Regras e KPIs avaliam o estado ATUAL do cliente, não qualquer ponto do
histórico. Um cliente que teve uma resposta de NPS detratora há 1 ano mas cuja resposta mais recente é
promotora **não** é um bom teste pra uma regra de detrator.

## Descoberta de chaves do `custom_data`

Nunca adivinhe o nome exato de uma chave — já apareceram chaves com sublinhado sobrando ou erro de
digitação (`brand_`, `bechmarking_`). Antes de escrever a query:

```sql
SELECT DISTINCT jsonb_object_keys(data) AS chave
FROM custom_data
WHERE type_ = 'kpis'  -- ou o type_ relevante
ORDER BY 1;
```

Repare também que o mesmo cliente pode ter mais de um `type_` em `custom_data`, com granularidades
diferentes — por exemplo `'kpis'` (uma linha por cliente/mês, métricas agregadas) e outro `type_` mais
granular (uma linha por cliente/mês/veículo, ou por cliente/mês/contato). Confirme qual `type_` realmente
tem o campo que você precisa antes de montar a query.

## Extração defensiva de JSON com formato incerto

Quando você não confirmou se um campo customizado vem como valor direto (`{"chave": "valor"}`) ou
aninhado (`{"chave": {"value": "valor"}}`), use um CASE que aceita os dois formatos em vez de escolher um
e quebrar se estiver errado:

```sql
case when custom_fields -> 'chave' is null then null
     when jsonb_typeof(custom_fields -> 'chave') = 'object' then (custom_fields -> 'chave') ->> 'value'
     else custom_fields ->> 'chave' end
```

## JOIN por nome quando a chave estrangeira não está populada

Se uma coluna de FK existir no schema mas estiver vazia na prática (confirme com
`SELECT count(*), count(coluna_fk) FROM tabela`), um fallback razoável é casar por nome normalizado,
sempre escopado pelo mesmo cliente e com dedup pra não multiplicar linha:

```sql
SELECT DISTINCT ON (id_customer, lower(trim(name))) *
FROM tabela_b
ORDER BY id_customer, lower(trim(name)), atualizado_em DESC NULLS LAST
```

## Cast numérico seguro em coluna de texto

Pra reaproveitar uma coluna de texto (tipo um ID legado) como campo numérico sem quebrar em linhas que
não são puramente numéricas:

```sql
CASE WHEN coluna_texto ~ '^[0-9]+$' THEN coluna_texto::bigint ELSE outra_coisa END
```

## Sintaxe de variável em template de e-mail / anotação de tarefa

Confirmado a partir de uma URL real gerada pela própria plataforma: o SenseData usa `$campo` (cifrão,
sem chaves) como marcador de mesclagem em textos de e-mail/anotação — não `{{campo}}`. Ainda assim, peça
pro usuário confirmar o nome exato de cada campo pelo botão "VAR" da tela dele antes de finalizar um
texto que os usa, porque só o formato (`$campo`) está confirmado, não necessariamente todo nome de campo
que você propuser.
