-- Contatos TR — lista de reativação (roda como está, somente leitura)
-- Mesma seleção de `reativar-csv.sql`, com as colunas de apoio para conferir.
-- `email_gravado` é o e-mail como está no banco — é ele que vai no arquivo da
-- manutenção, porque a chave é (cliente, e-mail). `email` é só a versão
-- normalizada usada para agrupar.
WITH cc AS (
  SELECT c.id,
         c.id_customer,
         btrim(c.email)                                             AS email_gravado,
         lower(trim(c.email))                                       AS email,
         c.name                                                     AS nome,
         c.is_active,
         c.created_at,
         c.id_legacy                                                AS chave_gravada,
         c.email_unsubscribe                                        AS optout,
         coalesce(c.custom_fields->'produto_contact'->>'value', '')  AS produto,
         nullif(c.custom_fields->'data_benchmark'->>'value', '')     AS data_benchmark,
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
  SELECT DISTINCT ON (cc.email, cc.id_customer) cc.*
  FROM cc
  JOIN grupo g
    ON g.email = cc.email
   AND g.id_customer = cc.id_customer
  WHERE g.veio_no_arquivo
    AND NOT g.tem_ativo
  ORDER BY cc.email,
           cc.id_customer,
           (cc.benchmarking IS NOT NULL) DESC,
           (cc.produto <> '') DESC,
           cc.created_at DESC
)
SELECT e.id_customer      AS "Cliente (ID Sensedata)",
       e.email_gravado    AS "E-mail",
       'True'             AS "Ativo",
       e.id               AS id_contato,
       cli.id_legacy      AS conta,
       cli.name           AS cliente,
       e.nome,
       e.produto,
       e.benchmarking,
       e.data_benchmark,
       e.optout,
       e.chave_gravada,
       e.created_at::date AS criado_em
FROM escolhido e
JOIN public.customer cli ON cli.id = e.id_customer
ORDER BY cli.id_legacy, e.nome;
