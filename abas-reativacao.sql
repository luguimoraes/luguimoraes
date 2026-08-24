-- Contatos TR — quem entra no arquivo e por quê.
--
-- Não reconstrói as 41 colunas: elas já vêm preenchidas no export de contatos
-- do SenseData. Esta query só devolve a chave e o veredito, e serve à aba de
-- conferência — quem ficou inativo, quem é afetado, quem entra e por quê.
--
--     python3 montar-excel.py export.csv selecao.csv contatos-reativacao.xlsx
--
--     export.csv    export de contatos do SenseData, com as 41 colunas
--     selecao.csv   a saída desta query
--
-- Sai o xlsx de duas abas e o manutencao.csv de duas colunas, que é o que
-- sobe. Para só reativar, sem a conferência, o `reativar-csv.sql` dá o mesmo
-- arquivo direto do banco, sem passar pelo script.

WITH b AS (
  SELECT id, id_customer, btrim(email) AS email, is_active, created_at,
         coalesce(custom_fields->'produto_contact'->>'value','') AS produto,
         btrim(email) ~ '^[^@[:space:],;<>]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
           AND btrim(email) !~ '\.\.'
           AND btrim(email) !~* '\.(con|ne|cm|bra)$'
           AND id NOT IN (209338, 210078, 211563, 218790)        AS email_ok,
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
         count(*)                                 OVER par AS no_par,
         row_number() OVER (PARTITION BY lower(email), id_customer
                            ORDER BY (benchmarking IS NOT NULL) DESC,
                                     (produto <> '') DESC, created_at DESC) AS rn
  FROM b WINDOW par AS (PARTITION BY lower(email), id_customer)
)
SELECT g.id        AS "ID Contato",
       c.id_legacy AS "ID Original",
       g.email     AS "Email",
       CASE WHEN g.tem_ativo THEN 'OK — pessoa tem ativo'
            WHEN NOT g.veio  THEN 'inativo correto — nao veio no arquivo'
            ELSE 'AFETADO — veio no arquivo e esta sem ativo' END AS "_Veredito",
       g.no_par                                                   AS "_Registros no par",
       CASE WHEN NOT g.email_ok THEN 'e-mail quebrado — corrigir na mao no SenseData'
            WHEN g.rn > 1       THEN 'outro registro da mesma pessoa foi escolhido'
       END                                                        AS "_Fora do arquivo por",
       g.veio AND NOT g.tem_ativo AND g.rn = 1 AND g.email_ok     AS "_Entra no arquivo"
FROM g JOIN public.customer c ON c.id = g.id_customer
WHERE NOT g.is_active
ORDER BY 2, 3;
