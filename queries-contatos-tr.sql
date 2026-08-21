-- ============================================================================
-- Contatos TR — apuração da recriação da base e dimensionamento da recuperação
-- Tabela: public.customer_contact   ·   Benchmarking fica em custom_fields (jsonb)
-- ============================================================================
-- ATENÇÃO ao formato do campo. Confirmado no export de 21/08:
--
--     custom_fields -> 'benchmarking' -> 'value'   é um ARRAY jsonb
--     exemplos:  ["N/A"]   ["Legal One"]   ["OSGT -  Import", "Onesource Global Trade"]
--     e às vezes  {"value": null}  (chave existe, valor nulo)
--
-- Por isso `custom_fields->'benchmarking'->>'value'` devolve a string '["N/A"]',
-- e não 'N/A'. Comparar com NOT IN ('', 'N/A') deixa passar TODA a base.
-- Todas as queries abaixo usam a CTE `cc`, que normaliza isso.
-- ============================================================================


-- ============================================================================
-- 0. BASE NORMALIZADA — copie este bloco no topo de cada consulta
-- ============================================================================
-- `benchmarking` sai como texto ('Legal One' ou 'OSGT - Import; Onesource Global Trade')
-- e é NULL quando não há marcação real.

WITH cc AS (
  SELECT c.*,
         c.custom_fields->'origem'->>'value'          AS origem,
         c.custom_fields->'produto_contact'->>'value' AS produto,
         nullif(c.custom_fields->'data_benchmark'->>'value', '') AS data_benchmark,
         (SELECT string_agg(v.val, '; ')
            FROM jsonb_array_elements_text(
                   CASE jsonb_typeof(c.custom_fields #> '{benchmarking,value}')
                     WHEN 'array'  THEN c.custom_fields #> '{benchmarking,value}'
                     WHEN 'string' THEN jsonb_build_array(c.custom_fields #> '{benchmarking,value}')
                     ELSE '[]'::jsonb
                   END
                 ) AS v(val)
           WHERE v.val <> '' AND v.val <> 'N/A')      AS benchmarking
  FROM public.customer_contact c
)
SELECT count(*) FILTER (WHERE benchmarking IS NOT NULL)                   AS com_benchmarking,
       count(*) FILTER (WHERE benchmarking IS NOT NULL AND is_active)     AS benchmarking_ativos,
       count(*) FILTER (WHERE benchmarking IS NOT NULL AND NOT is_active) AS benchmarking_inativos,
       count(*)                                                          AS total
FROM cc;
-- Apuração de 21/08 sobre o recorte exportado: 452 com marcação · 4 ativos · 448 inativos.


-- ============================================================================
-- 1. A CHAVE DE UPSERT — o achado que fecha o diagnóstico
-- ============================================================================
-- `id_legacy` guarda a chave calculada na carga que gravou o registro.
-- No export de 21/08 há TRÊS formatos convivendo na mesma coluna. Cada troca de
-- formato zera o match do upsert: a base inteira vira "registro novo".

-- 1.1 · Inventário de formatos de chave por geração
SELECT CASE
         WHEN id_legacy ~ '^[0-9]+$'                     THEN 'A · numerica (carga 2025-07)'
         WHEN id_legacy ~ '^[0-9]+-[A-Z]+$'              THEN 'C · conta (carga 2026-08-20)'
         WHEN id_legacy LIKE '%:%:%'                     THEN 'B · email:cnpj:produto (carga 2026-08-13/14)'
         WHEN id_legacy LIKE '%:%'                       THEN 'B- · email:cnpj (carga anterior a 13/08 20:48)'
         WHEN id_legacy IS NULL OR id_legacy = ''        THEN 'sem chave'
         ELSE 'outro'
       END                                    AS formato_chave,
       date_trunc('month', created_at)::date  AS geracao,
       count(*)                               AS registros,
       count(*) FILTER (WHERE is_active)      AS ativos
FROM public.customer_contact
WHERE custom_fields->'origem'->>'value' = 'Integração Sistema'
GROUP BY 1, 2
ORDER BY 1, 2;
-- >>> Se aparecer mais de um formato, está provado que a chave muda entre execuções.
-- >>> Apuração de 21/08: 7.079 numéricas · 17 email:cnpj:produto · 4 conta.

-- 1.2 · Chaves duplicadas (o upsert não sabe em qual registro gravar)
SELECT id_legacy, count(*) AS registros
FROM public.customer_contact
WHERE custom_fields->'origem'->>'value' = 'Integração Sistema'
GROUP BY 1
HAVING count(*) > 1
ORDER BY 2 DESC
LIMIT 50;

-- 1.3 · Registros que a carga atual NUNCA mais vai casar
--       (chave gravada em formato antigo → só podem ser desativados, nunca reativados)
SELECT count(*) AS orfaos_permanentes
FROM public.customer_contact
WHERE custom_fields->'origem'->>'value' = 'Integração Sistema'
  AND id_legacy ~ '^[0-9]+$';


-- ============================================================================
-- 2. AS ONDAS — quando cada execução desativou a base
-- ============================================================================

-- 2.1 · Ondas de desativação por hora
SELECT date_trunc('hour', updated_at) AS hora,
       count(*)                       AS registros_tocados,
       count(*) FILTER (WHERE NOT is_active) AS ficaram_inativos,
       count(*) FILTER (WHERE is_active)     AS ficaram_ativos
FROM public.customer_contact
WHERE custom_fields->'origem'->>'value' = 'Integração Sistema'
  AND updated_at >= now() - interval '30 days'
GROUP BY 1
HAVING count(*) > 50
ORDER BY 1;
-- Ondas conhecidas: 13/08 22h43 · 14/08 · 20/08 22h · 21/08 18h12.

-- 2.2 · O recorte de hoje foi a base inteira ou só uma parte?
--       (esta query resolve a única dúvida em aberto sobre o export de 21/08)
SELECT count(*) FILTER (WHERE updated_at >= date_trunc('day', now())) AS tocados_hoje,
       count(*) FILTER (WHERE updated_at <  date_trunc('day', now())) AS nao_tocados_hoje,
       count(*)                                                       AS total_integracao
FROM public.customer_contact
WHERE custom_fields->'origem'->>'value' = 'Integração Sistema';
-- Se tocados_hoje ≈ 7.100 e não_tocados_hoje for grande, o pré-processing leu
-- apenas um subconjunto — e aí o filtro do step 2132 também precisa ser revisto.

-- 2.3 · Ondas de criação (cada pico = uma execução que recriou a base)
SELECT date_trunc('day', created_at)::date AS dia,
       count(*)                            AS criados,
       count(DISTINCT lower(email))        AS pessoas,
       count(DISTINCT id_customer)         AS contas
FROM public.customer_contact
WHERE custom_fields->'origem'->>'value' = 'Integração Sistema'
GROUP BY 1
HAVING count(*) > 50
ORDER BY 1;


-- ============================================================================
-- 3. BENCHMARKING — o dado que não pode ser perdido
-- ============================================================================

-- 3.1 · Quebra por produto de referência
WITH cc AS (
  SELECT c.*,
         (SELECT string_agg(v.val, '; ')
            FROM jsonb_array_elements_text(
                   CASE jsonb_typeof(c.custom_fields #> '{benchmarking,value}')
                     WHEN 'array'  THEN c.custom_fields #> '{benchmarking,value}'
                     WHEN 'string' THEN jsonb_build_array(c.custom_fields #> '{benchmarking,value}')
                     ELSE '[]'::jsonb END) AS v(val)
           WHERE v.val <> '' AND v.val <> 'N/A') AS benchmarking
  FROM public.customer_contact c
)
SELECT benchmarking                          AS produto_referencia,
       count(*) FILTER (WHERE is_active)     AS ativos,
       count(*) FILTER (WHERE NOT is_active) AS inativos
FROM cc
WHERE benchmarking IS NOT NULL
GROUP BY 1
ORDER BY 3 DESC;

-- 3.2 · Dos inativos com Benchmarking, quantos têm contato ATIVO correspondente
WITH cc AS (
  SELECT c.*,
         (SELECT string_agg(v.val, '; ')
            FROM jsonb_array_elements_text(
                   CASE jsonb_typeof(c.custom_fields #> '{benchmarking,value}')
                     WHEN 'array'  THEN c.custom_fields #> '{benchmarking,value}'
                     WHEN 'string' THEN jsonb_build_array(c.custom_fields #> '{benchmarking,value}')
                     ELSE '[]'::jsonb END) AS v(val)
           WHERE v.val <> '' AND v.val <> 'N/A') AS benchmarking
  FROM public.customer_contact c
),
bm AS (
  SELECT id, lower(email) AS email, id_customer, benchmarking
  FROM cc
  WHERE NOT is_active AND benchmarking IS NOT NULL
),
ativos AS (
  SELECT lower(email) AS email, id_customer, count(*) AS qtd, min(id) AS id_destino
  FROM public.customer_contact
  WHERE is_active
  GROUP BY 1, 2
)
SELECT CASE
         WHEN a.qtd = 1 THEN 'match direto (1 ativo na mesma conta)'
         WHEN a.qtd > 1 THEN 'ambiguo (varios ativos)'
         ELSE 'sem contato ativo'
       END      AS situacao,
       count(*) AS contatos
FROM bm
LEFT JOIN ativos a ON a.email = bm.email AND a.id_customer = bm.id_customer
GROUP BY 1
ORDER BY 2 DESC;
-- Apuração sobre o export de 20/08: 120 direto · 16 ambíguo · 277 sem ativo.
-- Rodar de novo APÓS cada carga: o número de "match direto" só cai.

-- 3.3 · Lista dos que voltam direto (conferir antes de gravar)
WITH cc AS (
  SELECT c.*,
         (SELECT string_agg(v.val, '; ')
            FROM jsonb_array_elements_text(
                   CASE jsonb_typeof(c.custom_fields #> '{benchmarking,value}')
                     WHEN 'array'  THEN c.custom_fields #> '{benchmarking,value}'
                     WHEN 'string' THEN jsonb_build_array(c.custom_fields #> '{benchmarking,value}')
                     ELSE '[]'::jsonb END) AS v(val)
           WHERE v.val <> '' AND v.val <> 'N/A') AS benchmarking
  FROM public.customer_contact c
),
bm AS (
  SELECT id AS id_origem, email, id_customer, benchmarking,
         custom_fields->'data_benchmark'->>'value' AS data_benchmark
  FROM cc
  WHERE NOT is_active AND benchmarking IS NOT NULL
)
SELECT a.id        AS id_contato_destino,
       bm.benchmarking,
       bm.data_benchmark,
       a.name      AS nome,
       a.email,
       c.id_legacy AS conta,
       bm.id_origem
FROM bm
JOIN public.customer_contact a
  ON lower(a.email) = lower(bm.email)
 AND a.id_customer  = bm.id_customer
 AND a.is_active
JOIN public.customer c ON c.id = a.id_customer
ORDER BY c.id_legacy, a.name;


-- ============================================================================
-- 4. DUPLICAÇÃO — dimensionar a limpeza
-- ============================================================================

-- 4.1 · Registros redundantes por pessoa-conta
WITH g AS (
  SELECT lower(email) AS email, id_customer, count(*) AS registros
  FROM public.customer_contact
  WHERE custom_fields->'origem'->>'value' = 'Integração Sistema'
  GROUP BY 1, 2
)
SELECT registros,
       count(*)           AS pessoas_conta,
       sum(registros - 1) AS redundantes
FROM g
GROUP BY 1
ORDER BY 1;
-- Apuração de 20/08: 9.110 pessoas-conta com 2+ registros · 20.159 redundantes.

-- 4.2 · Redundantes que carregam dado exclusivo (NÃO podem ser excluídos)
WITH cc AS (
  SELECT c.*,
         (SELECT string_agg(v.val, '; ')
            FROM jsonb_array_elements_text(
                   CASE jsonb_typeof(c.custom_fields #> '{benchmarking,value}')
                     WHEN 'array'  THEN c.custom_fields #> '{benchmarking,value}'
                     WHEN 'string' THEN jsonb_build_array(c.custom_fields #> '{benchmarking,value}')
                     ELSE '[]'::jsonb END) AS v(val)
           WHERE v.val <> '' AND v.val <> 'N/A') AS benchmarking
  FROM public.customer_contact c
)
SELECT count(*) FILTER (WHERE benchmarking IS NOT NULL) AS com_benchmarking,
       count(*) FILTER (WHERE email_unsubscribe)        AS com_optout,
       count(*)                                         AS total_inativos
FROM cc
WHERE NOT is_active
  AND custom_fields->'origem'->>'value' = 'Integração Sistema';


-- ============================================================================
-- 5. VALIDAÇÃO DEPOIS DA CORREÇÃO / DA RECUPERAÇÃO
-- ============================================================================

-- 5.1 · Rodar a query 0 de novo: benchmarking_ativos deve subir de 4 para ~120+.

-- 5.2 · Um único formato de chave por origem (rodar 1.1: deve sobrar uma linha).

-- 5.3 · Nenhum contato ativo pode ter perdido o opt-out
SELECT count(*) AS ativos_sem_optout_mas_com_historico
FROM public.customer_contact a
WHERE a.is_active
  AND NOT a.email_unsubscribe
  AND EXISTS (
    SELECT 1 FROM public.customer_contact i
    WHERE i.email_unsubscribe
      AND lower(i.email) = lower(a.email)
      AND i.id_customer  = a.id_customer
      AND NOT i.is_active
  );
-- Deve retornar 0. Na apuração de 20/08 retornava 0 — manter assim.

-- 5.4 · Contagem de ativos por conta (comparar entre execuções da carga)
SELECT c.id_legacy AS conta, count(*) AS contatos_ativos
FROM public.customer_contact cc
JOIN public.customer c ON c.id = cc.id_customer
WHERE cc.is_active
  AND cc.custom_fields->'origem'->>'value' = 'Integração Sistema'
GROUP BY 1
ORDER BY 2 DESC;
