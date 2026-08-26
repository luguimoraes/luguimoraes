-- Validação dos números — o que a base diz contra o que a Jaqueline disse.
--
-- Uma consulta, uma linha por número, com a referência do lado. Somente
-- leitura. Rode em homologação depois das cargas.
--
-- IMPORTANTE: esta consulta NÃO filtra por origem nas linhas de controle.
-- Os registros que a manutenção criou hoje vêm sem origem preenchida, então
-- uma consulta filtrada por 'Integração Sistema' não os enxerga e os números
-- saem limpos mesmo com lixo na base. As duas últimas linhas expõem isso.

WITH cc AS (
  SELECT c.id, c.is_active, c.created_at,
         coalesce(c.custom_fields->'origem'->>'value','')          AS origem,
         nullif(btrim(coalesce(
           c.custom_fields->'data_benchmark'->>'value','')), '')   AS data_benchmark,
         (SELECT string_agg(v,'; ') FROM jsonb_array_elements_text(
            CASE jsonb_typeof(c.custom_fields#>'{benchmarking,value}')
              WHEN 'array'  THEN c.custom_fields#>'{benchmarking,value}'
              WHEN 'string' THEN jsonb_build_array(c.custom_fields#>'{benchmarking,value}')
              ELSE '[]'::jsonb END) v
           WHERE v NOT IN ('','N/A'))                              AS benchmarking
  FROM public.customer_contact c
),
n AS (
  SELECT
    count(*) FILTER (WHERE origem = 'Integração Sistema' AND is_active)          AS ativos,
    count(*) FILTER (WHERE origem = 'Integração Sistema' AND is_active
                       AND benchmarking IS NOT NULL)                             AS ativos_bm,
    count(*) FILTER (WHERE origem = 'Integração Sistema' AND NOT is_active
                       AND benchmarking IS NOT NULL)                             AS inativos_bm,
    count(*) FILTER (WHERE origem = 'Integração Sistema' AND is_active
                       AND data_benchmark IS NOT NULL)                           AS ativos_data,
    count(*) FILTER (WHERE benchmarking IS NOT NULL)                             AS total_bm,
    count(*) FILTER (WHERE created_at::date = CURRENT_DATE)                      AS criados_hoje,
    count(*) FILTER (WHERE created_at::date = CURRENT_DATE AND origem = '')      AS criados_em_branco
  FROM cc
)
SELECT item, valor, referencia FROM (VALUES
  (1, 'Contatos ATIVOS (origem Integração Sistema)',
      (SELECT ativos      FROM n), 'eram 1.668 antes da carga'),
  (2, 'ATIVOS com Benchmarking',
      (SELECT ativos_bm   FROM n), 'Jaqueline viu 4. Meta: 452'),
  (3, 'INATIVOS com Benchmarking',
      (SELECT inativos_bm FROM n), 'Jaqueline viu 448. Esperado agora: 169'),
  (4, 'ATIVOS com Data Benchmark preenchida',
      (SELECT ativos_data FROM n), 'tem que acompanhar a linha 2'),
  (5, 'Total com Benchmarking na base inteira',
      (SELECT total_bm    FROM n), 'tem que continuar 452 — se caiu, a carga APAGOU marcação'),
  (6, 'Registros criados HOJE (qualquer origem)',
      (SELECT criados_hoje FROM n), 'a carga devia ATUALIZAR, não inserir. Ideal: 0'),
  (7, 'Destes, criados sem origem (registro em branco)',
      (SELECT criados_em_branco FROM n), 'lixo das tentativas — limpar antes da validação dela')
) t(ord, item, valor, referencia)
ORDER BY ord;


-- --------------------------------------------------------------------------
-- Para ver as linhas em vez dos totais — os contatos ativos com a marcação:
--
--   SELECT c.id_legacy AS "Cliente (ID Original)", cc.id AS "ID Contato",
--          cc.name AS "Nome", cc.email AS "Email",
--          cc.custom_fields#>>'{benchmarking,value}'    AS "Benchmarking",
--          cc.custom_fields->'data_benchmark'->>'value' AS "Data Benchmark"
--   FROM public.customer_contact cc
--   JOIN public.customer c ON c.id = cc.id_customer
--   WHERE cc.is_active
--     AND cc.custom_fields->'origem'->>'value' = 'Integração Sistema'
--     AND coalesce(cc.custom_fields#>>'{benchmarking,value}','') NOT IN ('','[]','["N/A"]')
--   ORDER BY 1, 4;
--
-- Essa lista é o anexo que vai para a Jaqueline: ela confere linha a linha
-- que a marcação está no contato ATIVO, que é o que ela pediu.
-- --------------------------------------------------------------------------
