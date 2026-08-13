-- =====================================================================
-- 02 - PREVIEW DE IMPACTO (dry-run)
-- Rodar em SENSEDATA_HOM antes de publicar a query no step 122.
-- Mostra QUANTAS e QUAIS contas a integracao vai tocar, e compara o
-- comportamento da query ATUAL contra a query CORRIGIDA.
-- Somente leitura.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 2.1 Quantas linhas cada versao devolve
--     Espera-se: v1_corrigida <<< atual (por causa do filtro de ativas
--     e do anti-churn). Se v1 devolver MAIS que a atual, tem duplicacao
--     em algum lugar -> investigar com 01_qualidade_dados.sql (1.1).
-- ---------------------------------------------------------------------
WITH matriz_atual AS (
    SELECT company, "group",
           custom_fields::jsonb -> 'cs_feeling'      ->> 'value' AS cs_feeling_matriz,
           custom_fields::jsonb -> 'anotacoes_grupo' ->> 'value' AS anotacoes_matriz
    FROM public.customer
    WHERE "group" IS NOT NULL
      AND "group" <> ''
      AND (cnpj IS NULL OR cnpj = '')
),
resultado_atual AS (
    SELECT filho.id
    FROM public.customer filho
    INNER JOIN matriz_atual m
            ON filho."group"  = m."group"
           AND filho.company  = m.company
    WHERE filho.cnpj IS NOT NULL
      AND filho.cnpj <> ''
),
matriz_nova AS (
    SELECT DISTINCT ON (m.company, upper(btrim(m."group")))
           m.company,
           upper(btrim(m."group"))                                 AS group_key,
           m.custom_fields::jsonb -> 'cs_feeling'      ->> 'value' AS cs_feeling_matriz,
           m.custom_fields::jsonb -> 'anotacoes_grupo' ->> 'value' AS anotacoes_matriz
    FROM public.customer m
    WHERE m."group" IS NOT NULL
      AND btrim(m."group") <> ''
      AND NULLIF(btrim(m.cnpj), '') IS NULL
    ORDER BY m.company, upper(btrim(m."group")), m.updated_at DESC NULLS LAST, m.id DESC
),
resultado_novo AS (
    SELECT filho.id
    FROM public.customer filho
    INNER JOIN matriz_nova m
            ON m.company   = filho.company
           AND m.group_key = upper(btrim(filho."group"))
    WHERE NULLIF(btrim(filho.cnpj), '') IS NOT NULL
      AND filho.status = 'active'                                  -- [AJUSTAR]
      AND (
            filho.custom_fields::jsonb -> 'cs_feeling'      ->> 'value' IS DISTINCT FROM m.cs_feeling_matriz
         OR filho.custom_fields::jsonb -> 'anotacoes_grupo' ->> 'value' IS DISTINCT FROM m.anotacoes_matriz
      )
)
SELECT
    (SELECT count(*)          FROM resultado_atual) AS linhas_query_atual,
    (SELECT count(DISTINCT id) FROM resultado_atual) AS contas_query_atual,
    (SELECT count(*)          FROM resultado_novo)  AS linhas_query_corrigida,
    (SELECT count(DISTINCT id) FROM resultado_novo)  AS contas_query_corrigida;


-- ---------------------------------------------------------------------
-- 2.2 Lojas que a query ATUAL atualiza indevidamente (inativas)
--     Esta e a evidencia objetiva do ajuste pedido em 30/07.
-- ---------------------------------------------------------------------
SELECT filho.company,
       btrim(filho."group") AS grupo,
       filho.id,
       filho.name,
       filho.cnpj,
       filho.status
FROM public.customer filho
WHERE NULLIF(btrim(filho.cnpj), '') IS NOT NULL
  AND filho."group" IS NOT NULL
  AND btrim(filho."group") <> ''
  AND filho.status <> 'active'                                     -- [AJUSTAR]
  AND EXISTS (
        SELECT 1
        FROM public.customer m
        WHERE m.company = filho.company
          AND upper(btrim(m."group")) = upper(btrim(filho."group"))
          AND NULLIF(btrim(m.cnpj), '') IS NULL
  )
ORDER BY grupo, filho.name;


-- ---------------------------------------------------------------------
-- 2.3 Foto do antes/depois por conta (amostra para validacao manual)
--     Use para escolher o grupo piloto do teste em homologacao.
-- ---------------------------------------------------------------------
WITH matriz AS (
    SELECT DISTINCT ON (m.company, upper(btrim(m."group")))
           m.company,
           upper(btrim(m."group"))                                 AS group_key,
           m.name                                                  AS matriz_nome,
           m.custom_fields::jsonb -> 'cs_feeling'      ->> 'value' AS cs_feeling_matriz,
           m.custom_fields::jsonb -> 'anotacoes_grupo' ->> 'value' AS anotacoes_matriz
    FROM public.customer m
    WHERE m."group" IS NOT NULL
      AND btrim(m."group") <> ''
      AND NULLIF(btrim(m.cnpj), '') IS NULL
    ORDER BY m.company, upper(btrim(m."group")), m.updated_at DESC NULLS LAST, m.id DESC
)
SELECT btrim(f."group")                                              AS grupo,
       m.matriz_nome,
       f.name                                                        AS loja,
       f.cnpj,
       f.status,
       f.custom_fields::jsonb -> 'cs_feeling' ->> 'value'            AS cs_feeling_antes,
       m.cs_feeling_matriz                                           AS cs_feeling_depois,
       left(COALESCE(f.custom_fields::jsonb -> 'anotacoes_grupo' ->> 'value', ''), 60) AS anotacoes_antes,
       left(COALESCE(m.anotacoes_matriz, ''), 60)                    AS anotacoes_depois
FROM public.customer f
JOIN matriz m
      ON m.company   = f.company
     AND m.group_key = upper(btrim(f."group"))
WHERE NULLIF(btrim(f.cnpj), '') IS NOT NULL
ORDER BY grupo, f.name;


-- ---------------------------------------------------------------------
-- 2.4 Volumetria: matrizes na base (impacto nos indicadores de lojas)
--     O cliente pediu explicitamente que a conta fantasma nao polua a
--     volumetria. Este numero e o que precisa ser excluido dos paineis.
-- ---------------------------------------------------------------------
SELECT count(*) AS contas_matriz_na_base
FROM public.customer
WHERE NULLIF(btrim(cnpj), '') IS NULL
  AND "group" IS NOT NULL
  AND btrim("group") <> '';
