# SQL na base espelho do SenseData (campo)

Padrões para quem escreve a query de uma fonte PostgreSQL que lê a própria base do SenseData, ou audita uma carga. O modelo abaixo foi **observado** em tenants reais; confirme no seu com as queries de descoberta (seção 2) antes de publicar qualquer coisa.

> Todas as queries deste arquivo são **somente leitura**. Rode primeiro em homologação.

## 1. Modelo de dados observado

### 1.1 `public.customer` (clientes)
| Coluna | Tipo observado | Observação |
|---|---|---|
| `id` | inteiro | ID Sensedata |
| `id_legacy` | `character varying` | ID Original / chave usada pelas cargas. Pode ter nulos e duplicados: confira antes de usar como chave |
| `name` | texto | Nome do cliente |
| `cnpj` | texto | Pode vir vazio (`''`), não só `NULL` |
| `"group"` | texto | Grupo econômico. **`group` é palavra reservada**: use sempre entre aspas |
| `company` | — | Separação por empresa/tenant dentro da base; inclua nas junções |
| `status` | **inteiro** numa base observada | Não assuma `'active'`/`'Ativo'`: descubra os códigos (bloco G da seção 2.2) |
| `dt_cancel` | data | Preenchida quando o cliente foi cancelado; bom critério de "ativo" enquanto o código de status não é confirmado |
| `cancel_tag` | texto | Motivo/etiqueta de cancelamento |
| `stage` | texto | Fase |
| `custom_fields` | `jsonb` | Campos customizados (seção 3) |
| `updated_at` | `timestamp without time zone` | Provavelmente em UTC; confirme (seção 5) |

### 1.2 `public.customer_contact` (contatos)
| Coluna | Observação |
|---|---|
| `id` | ID do contato |
| `id_customer` | FK para `customer.id` |
| `email`, `name` | Normalize (`lower(btrim(email))`) antes de agrupar ou casar |
| `is_active` | Ativo/inativo |
| `id_legacy` | Chave gravada pela carga que criou/atualizou o registro. **Mostra o formato da chave de cada geração de carga** |
| `email_unsubscribe` | Opt-out |
| `created_at`, `updated_at` | Picos de `created_at` = execuções que criaram registros; picos de `updated_at` = execuções que tocaram registros |
| `custom_fields` | `jsonb`; ex.: `origem`, `produto_contact`, listas de marcação |

### 1.3 Modelos de DW/export
Extrações para DW ou exports da tela podem usar outros nomes (`customers`, `contacts`, `users`, `id_original`, colunas por rótulo de exibição). Ajuste as queries ao modelo que você tem. No export da tela, duas colunas podem ter nomes quase iguais (ex.: `Comercial` e `Comercial ` com espaço no fim): uma é o campo nativo, a outra o custom field.

## 2. Descoberta antes de escrever a query

### 2.1 Queries soltas
```sql
-- Estrutura da tabela
SELECT ordinal_position, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'customer'
ORDER BY ordinal_position;

-- Colunas candidatas a "ativo"
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'customer'
  AND column_name ILIKE ANY (ARRAY['%status%','%activ%','%situa%','%churn%','%cancel%','%delet%']);

-- Quais custom fields existem (nomes internos) e quantos clientes têm cada um
SELECT k AS custom_field, count(*) AS clientes
FROM public.customer c
CROSS JOIN LATERAL jsonb_object_keys(c.custom_fields::jsonb) AS k
WHERE c.custom_fields IS NOT NULL
GROUP BY k ORDER BY clientes DESC;

-- Estrutura interna de um custom field (sem expor conteúdo)
SELECT DISTINCT k
FROM public.customer c
CROSS JOIN LATERAL jsonb_object_keys(c.custom_fields::jsonb -> 'cs_feeling') AS k
WHERE jsonb_typeof(c.custom_fields::jsonb -> 'cs_feeling') = 'object';

-- A chave de carga é segura?
SELECT count(*) AS total,
       count(*) FILTER (WHERE NULLIF(btrim(id_legacy::text), '') IS NULL) AS sem_id_legacy,
       count(DISTINCT id_legacy) AS distintos
FROM public.customer;

SELECT id_legacy, count(*) AS qtd
FROM public.customer
WHERE NULLIF(btrim(id_legacy::text), '') IS NOT NULL
GROUP BY id_legacy HAVING count(*) > 1
ORDER BY qtd DESC;
```

### 2.2 Checklist numa query só (bloco / chave / valor)
Útil para pedir a alguém do cliente que rode e devolva o resultado sem expor dados: só devolve nomes de coluna, nomes de campo e contagens.
```sql
WITH cols AS (
  SELECT column_name, data_type FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'customer'
),
status_cand AS (
  SELECT column_name FROM cols
  WHERE column_name ILIKE ANY (ARRAY['%status%','%activ%','%situa%','%churn%','%cancel%','%delet%'])
),
a AS (SELECT 'A. colunas' AS bloco, column_name AS chave, data_type AS valor FROM cols),
-- to_jsonb(linha) ->> 'coluna' devolve NULL (e não erro) se a coluna não existir
b AS (
  SELECT 'B. valores por coluna de status', sc.column_name,
         COALESCE(to_jsonb(c) ->> sc.column_name, '(null)') || ' -> ' || count(*) || ' contas'
  FROM public.customer c CROSS JOIN status_cand sc
  GROUP BY sc.column_name, COALESCE(to_jsonb(c) ->> sc.column_name, '(null)')
),
c AS (
  SELECT 'C. custom fields', k, count(*) || ' contas'
  FROM public.customer c CROSS JOIN LATERAL jsonb_object_keys(c.custom_fields::jsonb) k
  WHERE c.custom_fields IS NOT NULL GROUP BY k
),
e AS (
  SELECT 'E. id_legacy', 'duplicados',
         (SELECT count(*) FROM (SELECT id_legacy FROM public.customer
            WHERE NULLIF(btrim(id_legacy::text),'') IS NOT NULL
            GROUP BY id_legacy HAVING count(*) > 1) d)::text
),
g AS ( -- decodificar status inteiro cruzando com sinais de cancelamento
  SELECT 'G. status', 'status = ' || COALESCE(status::text,'(null)'),
         count(*) || ' contas | com dt_cancel: ' || count(*) FILTER (WHERE dt_cancel IS NOT NULL)
         || ' | stages: ' || COALESCE(string_agg(DISTINCT stage, ','), '(nenhum)')
  FROM public.customer GROUP BY status
),
h AS (
  SELECT 'H. relogio', 'now()', to_char(now(), 'DD/MM/YYYY HH24:MI:SS TZ')
  UNION ALL SELECT 'H. relogio', 'TimeZone', current_setting('TimeZone')
  UNION ALL SELECT 'H. relogio', 'max(updated_at)', to_char(max(updated_at), 'DD/MM/YYYY HH24:MI:SS') FROM public.customer
)
SELECT * FROM a UNION ALL SELECT * FROM b UNION ALL SELECT * FROM c
UNION ALL SELECT * FROM e UNION ALL SELECT * FROM g UNION ALL SELECT * FROM h
ORDER BY 1, 2, 3;
```
Remova o bloco G se `dt_cancel`/`stage` não existirem no seu tenant.

## 3. Lendo `custom_fields`

### 3.1 Valor simples
```sql
c.custom_fields::jsonb -> 'cs_feeling' ->> 'value'
```
- O valor fica em `->'<nome_interno>'->>'value'`. Confirme com a query de estrutura interna (2.1): alguns tipos podem guardar `id`/`label`.
- Use o **nome interno**, não o rótulo.
- O cast `::jsonb` é inofensivo quando a coluna já é `jsonb`; deixe por segurança.

### 3.2 Lista (seleção múltipla) — armadilha
Em listas, `value` é um **array jsonb**, às vezes uma string solta, às vezes `null`:
```
["Produto X"]    ["Produto A", "Produto B"]    ["N/A"]    {"value": null}
```
`custom_fields->'campo'->>'value'` devolve o texto `'["N/A"]'`, não `'N/A'`. Um filtro `NOT IN ('', 'N/A')` deixa passar a base inteira. Normalize:
```sql
(SELECT string_agg(v, '; ')
   FROM jsonb_array_elements_text(
          CASE jsonb_typeof(c.custom_fields #> '{campo,value}')
            WHEN 'array'  THEN c.custom_fields #> '{campo,value}'
            WHEN 'string' THEN jsonb_build_array(c.custom_fields #> '{campo,value}')
            ELSE '[]'::jsonb END) AS v
  WHERE v NOT IN ('', 'N/A')) AS campo_texto   -- NULL quando não há marcação real
```

### 3.3 Merge ou replace?
Antes de uma carga que grava um único custom field, confirme se a plataforma faz **merge** no jsonb (mantém os outros campos) ou **replace** (apaga os outros). Teste com 10 registros comparando o `custom_fields` inteiro antes e depois.

## 4. Padrões de query para uma fonte de integração

### 4.1 Uma linha por chave, com desempate determinístico
```sql
SELECT DISTINCT ON (m.company, upper(btrim(m."group")))
       m.company, upper(btrim(m."group")) AS group_key, m.id, m.name
FROM public.customer m
WHERE ...
ORDER BY m.company, upper(btrim(m."group")), m.updated_at DESC NULLS LAST, m.id DESC;
```
Sem isso, duas linhas com a mesma chave chegam ao carregamento e o valor gravado depende da ordem ("loteria"), sem erro no log.

### 4.2 Junção por texto normalizado
```sql
ON m.company = f.company
AND m.group_key = upper(btrim(f."group"))
```
`'Rede Alfa'`, `'REDE ALFA '` e `'rede alfa'` são três valores diferentes para o Postgres.

### 4.3 Vazio é vazio
```sql
NULLIF(btrim(cnpj), '') IS NULL       -- trata NULL e '' como ausentes
NULLIF(btrim(id_legacy::text), '') IS NOT NULL
```

### 4.4 Delta (só o que mudou)
```sql
WHERE valor_atual IS DISTINCT FROM valor_novo
```
`IS DISTINCT FROM` trata `NULL` corretamente (`NULL <> 'x'` é nulo, não verdadeiro). Compare com `COALESCE(..., '')` dos dois lados se `''` e `NULL` devem ser equivalentes.

### 4.5 Limpeza explícita de quem saiu do escopo
Com `integ_type = update`, linha ausente do resultado não é tocada. Para limpar, **inclua** a linha com valor vazio:
```sql
CASE WHEN elegivel THEN COALESCE(valor, '') ELSE '' END AS campo_destino
```
E mantenha o filtro de delta para não reenviar `''` todo dia.

### 4.6 Aliases = nomes das colunas da fonte
O `SELECT` final define as colunas do `output_schema`. Use aliases explícitos e estáveis (`AS customer_id_legacy`). Colunas extras de conferência (nome, CNPJ, grupo) ajudam no preview; mapeie-as como Ignorar.

## 5. Datas e fuso
- `updated_at` é `timestamp without time zone`. Se o banco grava em UTC (padrão), converta para exibição:
  ```sql
  to_char((ts AT TIME ZONE 'UTC') AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI')
  ```
- Confirme antes com `now()`, `current_setting('TimeZone')` e `max(updated_at)` (bloco H da seção 2.2). Se o relógio já estiver em horário de Brasília, remova o primeiro `AT TIME ZONE 'UTC'`, senão a data sai 3 horas errada.

## 6. Exemplo completo — propagar o dado da conta matriz para as lojas do grupo
Campos de destino (custom fields a criar antes): `cs_feeling_grupo`, `anotacoes_grupo`, `conta_matriz_nome`, `grupo_atualizado_em`. Carregamento: `customer`, `update`, `keys = ["customer_id_legacy"]`.
```sql
WITH matriz AS (
    SELECT DISTINCT ON (m.company, upper(btrim(m."group")))
           m.company,
           upper(btrim(m."group"))                                 AS group_key,
           m.id                                                    AS matriz_id,
           m.name                                                  AS matriz_name,
           m.custom_fields::jsonb -> 'cs_feeling'      ->> 'value' AS cs_feeling_matriz,
           m.custom_fields::jsonb -> 'anotacoes_grupo' ->> 'value' AS anotacoes_matriz,
           m.updated_at                                            AS matriz_updated_at
    FROM public.customer m
    WHERE NULLIF(btrim(m."group"), '') IS NOT NULL
      -- matriz: flag explícita; "sem CNPJ" só como fallback durante a migração
      AND (lower(m.custom_fields::jsonb -> 'tipo_conta' ->> 'value') IN ('matriz', 'conta matriz')
           OR NULLIF(btrim(m.cnpj), '') IS NULL)
    ORDER BY m.company, upper(btrim(m."group")), m.updated_at DESC NULLS LAST, m.id DESC
),
base AS (
    SELECT f.id AS customer_id, f.id_legacy AS customer_id_legacy, f.name AS customer_name,
           f.cnpj AS customer_cnpj, f."group" AS customer_group, f.custom_fields AS filho_cf,
           m.matriz_name, m.cs_feeling_matriz, m.anotacoes_matriz, m.matriz_updated_at,
           -- [AJUSTAR] critério de loja ativa: confirme a coluna e os códigos reais
           (m.matriz_id IS NOT NULL AND f.dt_cancel IS NULL) AS elegivel
    FROM public.customer f
    LEFT JOIN matriz m
           ON m.company = f.company AND m.group_key = upper(btrim(f."group"))
    WHERE NULLIF(btrim(f.cnpj), '') IS NOT NULL
      AND NULLIF(btrim(f.id_legacy::text), '') IS NOT NULL
),
alvo AS (
    SELECT customer_id, customer_id_legacy, customer_name, customer_cnpj, customer_group,
           CASE WHEN elegivel THEN COALESCE(cs_feeling_matriz, '') ELSE '' END AS cs_feeling_grupo,
           CASE WHEN elegivel THEN COALESCE(anotacoes_matriz,  '') ELSE '' END AS anotacoes_grupo,
           CASE WHEN elegivel THEN COALESCE(matriz_name,       '') ELSE '' END AS conta_matriz_nome,
           CASE WHEN elegivel
                THEN COALESCE(to_char((matriz_updated_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Sao_Paulo',
                                      'DD/MM/YYYY HH24:MI'), '')
                ELSE '' END                                                    AS grupo_atualizado_em,
           COALESCE(filho_cf::jsonb -> 'cs_feeling_grupo'  ->> 'value', '') AS cs_feeling_grupo_atual,
           COALESCE(filho_cf::jsonb -> 'anotacoes_grupo'   ->> 'value', '') AS anotacoes_grupo_atual,
           COALESCE(filho_cf::jsonb -> 'conta_matriz_nome' ->> 'value', '') AS conta_matriz_nome_atual
    FROM base
)
SELECT customer_id, customer_id_legacy, customer_name, customer_cnpj, customer_group,
       cs_feeling_grupo, anotacoes_grupo, conta_matriz_nome, grupo_atualizado_em
FROM alvo
WHERE cs_feeling_grupo_atual  IS DISTINCT FROM cs_feeling_grupo
   OR anotacoes_grupo_atual   IS DISTINCT FROM anotacoes_grupo
   OR conta_matriz_nome_atual IS DISTINCT FROM conta_matriz_nome;
```
Notas:
- A versão "mínima" (sobrescrever o próprio `cs_feeling` da loja) é mais simples, mas acaba com o feeling individual por loja e reverte edições feitas na loja. Diga isso ao cliente.
- A conta matriz continua existindo como cliente: exclua-a de painéis de volumetria e segmentações (ex.: `tipo_conta <> 'matriz'`).
- Não replique **atividades** para as lojas: multiplica registros não editáveis. Mantenha o histórico na matriz e dê à loja o nome da matriz para chegar lá.

## 7. Qualidade de dados (rodar antes da virada e mensalmente)
```sql
-- Grupo com mais de uma "matriz"
SELECT company, btrim("group") AS grupo, count(*) AS qtd
FROM public.customer
WHERE NULLIF(btrim("group"), '') IS NOT NULL AND NULLIF(btrim(cnpj), '') IS NULL
GROUP BY company, btrim("group") HAVING count(*) > 1;

-- Lojas com grupo e sem matriz (nunca recebem nada, em silêncio)
SELECT f.company, btrim(f."group") AS grupo, count(*) AS lojas
FROM public.customer f
WHERE NULLIF(btrim(f.cnpj), '') IS NOT NULL AND NULLIF(btrim(f."group"), '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.customer m
                  WHERE m.company = f.company
                    AND upper(btrim(m."group")) = upper(btrim(f."group"))
                    AND NULLIF(btrim(m.cnpj), '') IS NULL)
GROUP BY 1, 2 ORDER BY lojas DESC;

-- Grafia divergente do mesmo grupo
SELECT company, upper(btrim("group")) AS grupo, count(DISTINCT "group") AS variacoes,
       string_agg(DISTINCT '"' || "group" || '"', ' | ') AS grafias
FROM public.customer
WHERE NULLIF(btrim("group"), '') IS NOT NULL
GROUP BY 1, 2 HAVING count(DISTINCT "group") > 1;
```

## 8. Auditoria de uma carga de contatos
```sql
-- Formatos de chave por geração (mais de um formato = a chave mudou entre execuções)
SELECT CASE
         WHEN id_legacy ~ '^[0-9]+$'                 THEN 'numérica'
         WHEN id_legacy ~ '^[^:]+@[^:]+:[^:]+:[^:]+$' THEN 'email:doc:produto'
         WHEN id_legacy ~ '^[^:]+@[^:]+:[^:]+$'       THEN 'email:doc'
         WHEN id_legacy ~ '^[0-9]+-[A-Z]+$'           THEN 'código da conta'
         ELSE 'outro' END                             AS formato,
       count(*), min(created_at), max(created_at)
FROM public.customer_contact
WHERE custom_fields->'origem'->>'value' = '<origem da integração>'
GROUP BY 1 ORDER BY 2 DESC;

-- Ondas: quantos registros cada execução tocou (updated_at) e criou (created_at)
SELECT date_trunc('hour', updated_at) AS hora, count(*) AS tocados,
       count(*) FILTER (WHERE NOT is_active) AS terminaram_inativos
FROM public.customer_contact
GROUP BY 1 HAVING count(*) > 100 ORDER BY 1 DESC;

SELECT date_trunc('hour', created_at) AS hora, count(*) AS criados
FROM public.customer_contact
GROUP BY 1 HAVING count(*) > 100 ORDER BY 1 DESC;

-- Registros por pessoa-conta (1 é o correto)
SELECT n AS registros_por_pessoa_conta, count(*) AS qtd
FROM (SELECT id_customer, lower(btrim(email)) AS e, count(*) AS n
      FROM public.customer_contact GROUP BY 1, 2) t
GROUP BY n ORDER BY n;

-- Inativos que têm um registro novo da mesma pessoa na mesma conta
-- (vieram no arquivo e a carga não casou = defeito de chave, não ausência na origem)
SELECT count(*) FILTER (WHERE EXISTS (
         SELECT 1 FROM public.customer_contact n
         WHERE n.id_customer = o.id_customer
           AND lower(btrim(n.email)) = lower(btrim(o.email))
           AND n.created_at > o.created_at)) AS reapareceram_como_novo,
       count(*) AS inativos
FROM public.customer_contact o
WHERE NOT o.is_active;
```
Ajuste os padrões de regex ao formato de chave do seu tenant.
