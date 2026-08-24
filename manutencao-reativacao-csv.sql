-- ============================================================================
-- Contatos TR — de-para e reativação, com banco SOMENTE LEITURA
-- ============================================================================
-- NÃO PRECISA DO EXPORT DO DIA 10, e não precisa criar tabela de staging.
--
-- Por quê: um contato que foi inativado indevidamente deixa rastro na própria
-- base. Se ele veio no arquivo do S3, a carga o recriou como registro NOVO em
-- 13, 14 ou 20/08 — mesma pessoa, mesma conta. Quem NÃO tem registro novo é
-- porque realmente não veio no arquivo, e para esse a inativação está correta.
--
-- Medido em 24/08: dos 10.495 registros antigos inativos, 98,6% têm registro
-- novo correspondente. A inativação não foi por ausência no arquivo — foi
-- falha de match do upsert.
--
--   9.566  pessoas-conta na origem Integração Sistema
--   2.052  têm contato ativo hoje
--   7.398  vieram no arquivo e estão SEM nenhum ativo  ← o alvo da reativação
--     116  não vieram no arquivo → inativação correta, não mexer
--
-- Depois da carga: 9.450 das 9.566 pessoas-conta com contato ativo.
--
-- PRÉ-REQUISITO: pausar `Pré-processing_Inativa_Contatos` (2012) e
-- `Contatos_S3_V4` (2036) antes de subir o arquivo. A carga rodou em
-- 13, 14, 20, 21 e 24/08 — se rodar depois, desfaz a reativação.
-- ============================================================================


-- ============================================================================
-- 0. BASE NORMALIZADA — cole no topo de cada consulta
-- ============================================================================

WITH cc AS (
  SELECT c.id,
         c.id_customer,
         lower(trim(c.email))                          AS email,
         c.name                                        AS nome,
         c.is_active,
         c.created_at,
         c.updated_at,
         c.id_legacy                                   AS chave_gravada,
         c.email_unsubscribe                           AS optout,
         coalesce(c.custom_fields->'produto_contact'->>'value', '') AS produto,
         nullif(c.custom_fields->'data_benchmark'->>'value','')     AS data_benchmark,
         (SELECT string_agg(v.val, '; ')
            FROM jsonb_array_elements_text(
                   CASE jsonb_typeof(c.custom_fields #> '{benchmarking,value}')
                     WHEN 'array'  THEN c.custom_fields #> '{benchmarking,value}'
                     WHEN 'string' THEN jsonb_build_array(c.custom_fields #> '{benchmarking,value}')
                     ELSE '[]'::jsonb END) AS v(val)
           WHERE v.val <> '' AND v.val <> 'N/A')       AS benchmarking
  FROM public.customer_contact c
  WHERE c.custom_fields->'origem'->>'value' = 'Integração Sistema'
)


-- ============================================================================
-- 1. O DE-PARA — o que mudou, e quem foi afetado indevidamente
-- ============================================================================
-- Agrupa por (pessoa, conta) — um contato ativo por pessoa em cada conta, que é
-- o modelo alvo do CR-1(a). NÃO agrupe por produto: a geração de 13/08 nasceu
-- sem produto, então (pessoa, conta, '') viraria grupo separado de
-- (pessoa, conta, 'ONESOURCE TAX ONE') e a mesma pessoa seria reativada duas
-- vezes — 15.080 registros em vez de 7.398, piorando a duplicação.

WITH cc AS ( /* cole a CTE da seção 0 */
  SELECT c.id, c.id_customer, lower(trim(c.email)) AS email, c.name AS nome,
         c.is_active, c.created_at, c.id_legacy AS chave_gravada,
         c.email_unsubscribe AS optout,
         coalesce(c.custom_fields->'produto_contact'->>'value','') AS produto,
         (SELECT string_agg(v.val,'; ') FROM jsonb_array_elements_text(
            CASE jsonb_typeof(c.custom_fields #> '{benchmarking,value}')
              WHEN 'array' THEN c.custom_fields #> '{benchmarking,value}'
              ELSE '[]'::jsonb END) AS v(val)
           WHERE v.val <> '' AND v.val <> 'N/A') AS benchmarking
  FROM public.customer_contact c
  WHERE c.custom_fields->'origem'->>'value' = 'Integração Sistema'
),
grupo AS (
  SELECT email, id_customer,
         bool_or(is_active)                                AS tem_ativo,
         bool_or(created_at >= DATE '2026-08-13')          AS veio_no_arquivo,
         count(*)                                          AS registros
  FROM cc
  GROUP BY 1, 2
)
SELECT CASE
         WHEN tem_ativo                     THEN 'OK — tem contato ativo'
         WHEN NOT veio_no_arquivo           THEN 'inativo correto — nao veio no arquivo'
         ELSE 'AFETADO — veio no arquivo e esta sem ativo'
       END                                  AS veredito,
       count(*)                             AS pessoas_conta,
       count(DISTINCT id_customer)          AS contas,
       sum(registros)                       AS registros_envolvidos
FROM grupo
GROUP BY 1
ORDER BY 2 DESC;

-- 'AFETADO' é o número que vai para o cliente. 'inativo correto' é o que a
-- regra de negócio acordada manda inativar — não entra na reativação.


-- ============================================================================
-- 2. A LISTA NOMINAL — um registro escolhido por contato
-- ============================================================================
-- Um registro por pessoa-conta. Regra de escolha, nesta ordem:
--   1º  registro que carrega Benchmarking (preserva o dado manual)
--   2º  registro com produto preenchido (a geração de 13/08 nasceu sem produto)
--   3º  o mais recente
-- Assim a reativação devolve o contato E o campo preenchido, quando existir.
--
-- Resultado esperado: 7.398 registros · 1.577 contas · 279 com Benchmarking ·
-- 1.209 com opt-out preservado · todos com produto preenchido.
-- A geração escolhida é majoritariamente a de 14/08 (7.056), que é a última
-- recriação fiel do arquivo — por contato e com produto.

WITH cc AS ( /* cole a CTE da seção 0 */
  SELECT c.id, c.id_customer, lower(trim(c.email)) AS email, c.name AS nome,
         c.is_active, c.created_at, c.id_legacy AS chave_gravada,
         c.email_unsubscribe AS optout,
         coalesce(c.custom_fields->'produto_contact'->>'value','') AS produto,
         nullif(c.custom_fields->'data_benchmark'->>'value','') AS data_benchmark,
         (SELECT string_agg(v.val,'; ') FROM jsonb_array_elements_text(
            CASE jsonb_typeof(c.custom_fields #> '{benchmarking,value}')
              WHEN 'array' THEN c.custom_fields #> '{benchmarking,value}'
              ELSE '[]'::jsonb END) AS v(val)
           WHERE v.val <> '' AND v.val <> 'N/A') AS benchmarking
  FROM public.customer_contact c
  WHERE c.custom_fields->'origem'->>'value' = 'Integração Sistema'
),
grupo AS (
  SELECT email, id_customer,
         bool_or(is_active)                       AS tem_ativo,
         bool_or(created_at >= DATE '2026-08-13') AS veio_no_arquivo
  FROM cc GROUP BY 1, 2
),
escolhido AS (
  SELECT DISTINCT ON (cc.email, cc.id_customer)
         cc.*
  FROM cc
  JOIN grupo g
    ON g.email = cc.email AND g.id_customer = cc.id_customer
  WHERE g.veio_no_arquivo
    AND NOT g.tem_ativo
  ORDER BY cc.email, cc.id_customer,
           (cc.benchmarking IS NOT NULL) DESC,   -- 1o: preserva o dado manual
           (cc.produto <> '') DESC,              -- 2o: registro com produto preenchido
           cc.created_at DESC                    -- 3o: o mais recente
)
SELECT e.id                AS "ID Contato",
       'True'              AS "Ativo",
       cli.id_legacy       AS conta,
       cli.name            AS cliente,
       e.nome,
       e.email,
       e.produto,
       e.benchmarking,
       e.data_benchmark,
       e.optout,
       e.chave_gravada,
       e.created_at::date  AS criado_em
FROM escolhido e
JOIN public.customer cli ON cli.id = e.id_customer
ORDER BY cli.id_legacy, e.nome, e.produto;

-- Exporte o resultado. Para a manutenção, mantenha apenas as duas primeiras
-- colunas ("ID Contato" e "Ativo") — as demais são para conferência.
-- CONFIRME o cabeçalho que a manutenção do SenseData espera antes de subir.


-- ============================================================================
-- 3. CONFERÊNCIAS ANTES DE SUBIR
-- ============================================================================

-- 3.1 · Quanto cada conta recupera (leve esta lista para o cliente)
WITH cc AS ( SELECT c.id, c.id_customer, lower(trim(c.email)) AS email, c.is_active,
                    c.created_at, coalesce(c.custom_fields->'produto_contact'->>'value','') AS produto
             FROM public.customer_contact c
             WHERE c.custom_fields->'origem'->>'value' = 'Integração Sistema' ),
grupo AS ( SELECT email, id_customer, bool_or(is_active) AS tem_ativo,
                  bool_or(created_at >= DATE '2026-08-13') AS veio_no_arquivo
           FROM cc GROUP BY 1,2 )
SELECT cli.id_legacy                                        AS conta,
       cli.name                                             AS cliente,
       count(*) FILTER (WHERE tem_ativo)                    AS ativos_hoje,
       count(*) FILTER (WHERE NOT tem_ativo AND veio_no_arquivo) AS a_reativar,
       count(*) FILTER (WHERE NOT tem_ativo AND NOT veio_no_arquivo) AS inativo_correto
FROM grupo
JOIN public.customer cli ON cli.id = grupo.id_customer
GROUP BY 1, 2
HAVING count(*) FILTER (WHERE NOT tem_ativo AND veio_no_arquivo) > 0
ORDER BY a_reativar DESC;

-- 3.2 · A carga rodou de novo? Rode ANTES e DEPOIS da manutenção.
SELECT date_trunc('hour', updated_at) AS hora,
       count(*)                                AS tocados,
       count(*) FILTER (WHERE NOT is_active)   AS terminaram_inativos
FROM public.customer_contact
WHERE custom_fields->'origem'->>'value' = 'Integração Sistema'
  AND updated_at >= now() - interval '20 days'
GROUP BY 1 HAVING count(*) > 50 ORDER BY 1;
-- Hora nova depois da manutenção = a carga não foi pausada e desfez tudo.


-- ============================================================================
-- 4. DEPOIS DE SUBIR
-- ============================================================================

-- 4.1 · Sobrou pessoa-conta sem ativo? (rode a seção 1 de novo)
--       'AFETADO' deve ir a zero.

-- 4.2 · Nenhum opt-out perdido
SELECT count(*) AS ativos_sem_optout_mas_com_historico
FROM public.customer_contact a
WHERE a.is_active AND NOT a.email_unsubscribe
  AND EXISTS (SELECT 1 FROM public.customer_contact i
               WHERE i.email_unsubscribe
                 AND lower(i.email) = lower(a.email)
                 AND i.id_customer  = a.id_customer);
-- Deve retornar 0. Retornava 0 em 24/08 — manter assim.

-- 4.3 · Benchmarking: quanto voltou junto
SELECT count(*) FILTER (WHERE is_active)     AS marcacoes_ativas,
       count(*) FILTER (WHERE NOT is_active) AS marcacoes_inativas
FROM public.customer_contact
WHERE (SELECT count(*) FROM jsonb_array_elements_text(
         CASE jsonb_typeof(custom_fields #> '{benchmarking,value}')
           WHEN 'array' THEN custom_fields #> '{benchmarking,value}'
           ELSE '[]'::jsonb END) AS v(val)
        WHERE v.val <> '' AND v.val <> 'N/A') > 0;
-- Em 24/08: 7 ativas · 448 inativas. A reativação sobe as ativas em ~279
-- (as pessoas-conta afetadas que têm marcação em algum registro).
-- O resto continua sendo frente separada — ver seção C de
-- `queries-depara-contatos.sql`.
