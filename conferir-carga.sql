-- Conferência da carga — reativação e Benchmarking na mesma consulta.
--
-- Rode ANTES de subir, para ter a foto inicial, e DEPOIS de cada carga.
-- Somente leitura.
--
--                       antes da carga    depois das duas cargas
--   ativos                     1.668                     9.066
--   ativos_com_bm                  4                       452
--   inativos_com_bm              448                       169
--
-- ativos_com_bm indo de 4 para 452 é a prova de que o Benchmarking chegou no
-- contato ativo — que é o que a cliente pediu. Os 169 que sobram inativos com
-- marcação são os registros antigos, com o histórico preservado.

WITH b AS (
  SELECT is_active,
         (SELECT string_agg(v,'; ') FROM jsonb_array_elements_text(
            CASE jsonb_typeof(custom_fields#>'{benchmarking,value}')
              WHEN 'array'  THEN custom_fields#>'{benchmarking,value}'
              WHEN 'string' THEN jsonb_build_array(custom_fields#>'{benchmarking,value}')
              ELSE '[]'::jsonb END) v
           WHERE v NOT IN ('','N/A'))                            AS bm
  FROM public.customer_contact
  WHERE custom_fields->'origem'->>'value' = 'Integração Sistema'
)
SELECT count(*) FILTER (WHERE is_active)                        AS ativos,
       count(*) FILTER (WHERE NOT is_active)                    AS inativos,
       count(*) FILTER (WHERE is_active AND bm IS NOT NULL)     AS ativos_com_bm,
       count(*) FILTER (WHERE NOT is_active AND bm IS NOT NULL) AS inativos_com_bm
FROM b;
