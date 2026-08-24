-- Contatos TR — CSV da manutenção. Exporte e suba.
--
-- A manutenção casa por (Cliente, E-mail), não por ID do contato. Como cada
-- pessoa-conta do alvo tem mais de um registro com o mesmo e-mail, suba UMA
-- conta primeiro e confira se cada pessoa terminou com 1 ativo, não 2.
--
-- O e-mail sai como está no banco (só btrim): a coluna-chave também é gravada.
-- O WHERE derruba os e-mails quebrados, que não casariam com nada — esses
-- ficam para correção manual na tela do SenseData.

WITH b AS (
  SELECT id, id_customer, btrim(email) AS email, is_active, created_at,
         coalesce(custom_fields->'produto_contact'->>'value','') AS produto,
         (SELECT string_agg(v,'; ') FROM jsonb_array_elements_text(
            CASE jsonb_typeof(custom_fields#>'{benchmarking,value}')
              WHEN 'array'  THEN custom_fields#>'{benchmarking,value}'
              WHEN 'string' THEN jsonb_build_array(custom_fields#>'{benchmarking,value}')
              ELSE '[]'::jsonb END) v
           WHERE v NOT IN ('','N/A'))                            AS benchmarking
  FROM public.customer_contact
  WHERE custom_fields->'origem'->>'value' = 'Integração Sistema'
),
g AS (
  SELECT *,
         bool_or(is_active)                       OVER par AS tem_ativo,
         bool_or(created_at >= DATE '2026-08-13') OVER par AS veio,
         row_number() OVER (PARTITION BY lower(email), id_customer
                            ORDER BY (benchmarking IS NOT NULL) DESC,  -- preserva o dado manual
                                     (produto <> '') DESC,             -- registro com produto
                                     created_at DESC) AS rn            -- o mais recente
  FROM b WINDOW par AS (PARTITION BY lower(email), id_customer)
)
SELECT c.id_legacy AS "Cliente (ID Original)",
       g.email     AS "E-mail",
       'True'      AS "Ativo"
FROM g JOIN public.customer c ON c.id = g.id_customer
WHERE g.veio AND NOT g.tem_ativo AND g.rn = 1
  AND g.email ~ '^[^@[:space:],;<>]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
  AND g.email !~ '\.\.'
  AND g.email !~* '\.(con|ne|cm|bra)$'
  AND g.id NOT IN (209338, 210078, 211563, 218790)  -- .co que era .com
ORDER BY 1, 2;

-- Piloto: acrescente `AND c.id_legacy = '132626-TAX'` ao WHERE.
-- Conferência depois de subir — cada pessoa-conta tem que ter 1 ativo, não 2:
--   troque o SELECT final por
--   SELECT count(*) FILTER (WHERE is_active) AS ativos_no_par, count(*)
--   FROM g WHERE g.veio GROUP BY lower(email), id_customer ORDER BY 1;
