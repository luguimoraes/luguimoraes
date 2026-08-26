-- Validação da carga — linha a linha, com os campos da lista de contatos.
--
-- Rode DEPOIS de subir. Devolve os contatos que a carga tinha de tocar, com
-- Ativo, Benchmarking e Data Benchmark, e uma coluna "_Conferir" que diz se
-- cada linha ficou certa. Somente leitura.
--
-- Os problemas vêm primeiro: se a primeira linha for "OK", subiu certo.
--
--   FALTOU ATIVAR                  a pessoa continua sem contato ativo nenhum
--   MARCACAO NAO CHEGOU NO ATIVO   o Benchmarking está preso no registro
--                                  inativo e o contato ativo está em branco
--   OK - ativo com marcacao        ativo e com Benchmarking preenchido
--   OK - ativo                     ativo; essa pessoa não tem marcação
--   registro antigo (historico)    inativo de propósito — é a duplicata que
--                                  guarda o histórico, e a pessoa já tem ativo
--
-- A checagem de "tem ativo" olha a base INTEIRA, não só os contatos da
-- integração: quem tem um ativo criado à mão não pode aparecer como faltando.
--
-- Para contar em vez de listar, troque o SELECT final por:
--   SELECT "_Conferir", count(*) ... GROUP BY 1 ORDER BY 2 DESC;

WITH todos AS (
  SELECT cc.id, cc.id_customer, cc.name AS nome, btrim(cc.email) AS email,
         cc.is_active, cc.created_at,
         cc.custom_fields->'origem'->>'value'         AS origem,
         cc.custom_fields->'data_benchmark'->>'value' AS data_benchmark,
         (SELECT string_agg(v,'; ') FROM jsonb_array_elements_text(
            CASE jsonb_typeof(cc.custom_fields#>'{benchmarking,value}')
              WHEN 'array'  THEN cc.custom_fields#>'{benchmarking,value}'
              WHEN 'string' THEN jsonb_build_array(cc.custom_fields#>'{benchmarking,value}')
              ELSE '[]'::jsonb END) v
           WHERE v NOT IN ('','N/A'))                 AS benchmarking
  FROM public.customer_contact cc
),
g AS (
  SELECT *,
         bool_or(is_active)                    OVER par AS tem_ativo,
         bool_or(benchmarking IS NOT NULL)     OVER par AS bm_no_par,
         bool_or(is_active AND benchmarking IS NOT NULL)
                                               OVER par AS bm_no_ativo,
         bool_or(created_at >= DATE '2026-08-13'
                 AND origem = 'Integração Sistema')
                                               OVER par AS veio
  FROM todos WINDOW par AS (PARTITION BY id_customer, lower(email))
)
SELECT c.id_legacy      AS "Cliente (ID Original)",
       g.id             AS "ID Contato",
       g.nome           AS "Nome",
       g.email          AS "Email",
       CASE WHEN g.is_active THEN 'Sim' ELSE 'Nao' END AS "Ativo",
       g.benchmarking   AS "Benchmarking",
       g.data_benchmark AS "Data Benchmark",
       CASE
         WHEN NOT g.tem_ativo                   THEN 'FALTOU ATIVAR'
         WHEN g.bm_no_par AND NOT g.bm_no_ativo THEN 'MARCACAO NAO CHEGOU NO ATIVO'
         WHEN g.is_active AND g.benchmarking IS NOT NULL
                                                THEN 'OK - ativo com marcacao'
         WHEN g.is_active                       THEN 'OK - ativo'
         ELSE 'registro antigo (historico)'
       END              AS "_Conferir"
FROM g
JOIN public.customer c ON c.id = g.id_customer
WHERE g.origem = 'Integração Sistema'
  AND (g.veio OR g.bm_no_par)        -- o universo que a carga tinha de tocar
ORDER BY CASE
           WHEN NOT g.tem_ativo                   THEN 1
           WHEN g.bm_no_par AND NOT g.bm_no_ativo THEN 2
           WHEN g.benchmarking IS NOT NULL        THEN 3
           ELSE 4
         END,
         c.id_legacy, lower(g.email), g.created_at;
