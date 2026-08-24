-- Contatos TR — CSV da manutenção (somente leitura)
-- Devolve APENAS as duas colunas da manutenção. Exporte o resultado como CSV e
-- suba: não precisa editar nada depois.
--
-- Esperado: 7.398 linhas.
-- Para conferir antes (conta, cliente, nome, e-mail, produto, benchmarking),
-- use `reativar-completa.sql` — mesma seleção, com as colunas de apoio.
--
-- ANTES DE SUBIR: pausar `Pré-processing_Inativa_Contatos` (2012) e
-- `Contatos_S3_V4` (2036). Se a carga rodar depois, desfaz a reativação.
--
-- CONFIRME o cabeçalho que a manutenção do SenseData espera. Se ela pedir
-- outro nome de coluna, troque só os aliases do SELECT final.

WITH cc AS (
  SELECT c.id,
         c.id_customer,
         lower(trim(c.email))                                       AS email,
         c.is_active,
         c.created_at,
         coalesce(c.custom_fields->'produto_contact'->>'value', '')  AS produto,
         (SELECT string_agg(v.val, '; ')
            FROM jsonb_array_elements_text(
                   CASE jsonb_typeof(c.custom_fields #> '{benchmarking,value}')
                     WHEN 'array'  THEN c.custom_fields #> '{benchmarking,value}'
                     WHEN 'string' THEN jsonb_build_array(c.custom_fields #> '{benchmarking,value}')
                     ELSE '[]'::jsonb
                   END) AS v(val)
           WHERE v.val <> '' AND v.val <> 'N/A')                    AS benchmarking
  FROM public.customer_contact c
  WHERE c.custom_fields->'origem'->>'value' = 'Integração Sistema'
),
grupo AS (
  SELECT email,
         id_customer,
         bool_or(is_active)                        AS tem_ativo,
         bool_or(created_at >= DATE '2026-08-13')  AS veio_no_arquivo
  FROM cc
  GROUP BY email, id_customer
),
escolhido AS (
  SELECT DISTINCT ON (cc.email, cc.id_customer) cc.id
  FROM cc
  JOIN grupo g
    ON g.email = cc.email
   AND g.id_customer = cc.id_customer
  WHERE g.veio_no_arquivo
    AND NOT g.tem_ativo
  ORDER BY cc.email,
           cc.id_customer,
           (cc.benchmarking IS NOT NULL) DESC,   -- 1o: preserva o dado manual
           (cc.produto <> '') DESC,              -- 2o: registro com produto preenchido
           cc.created_at DESC                    -- 3o: o mais recente
)
SELECT id      AS "ID Contato",
       'True'  AS "Ativo"
FROM escolhido
ORDER BY id;
