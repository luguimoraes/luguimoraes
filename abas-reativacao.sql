-- Contatos TR — as 41 colunas do arquivo da Jaqueline, UMA query só.
--
-- Exporte o resultado como `inativos.csv` e rode:
--     python3 montar-excel.py inativos.csv contatos-reativacao.xlsx
-- O script gera as duas abas e o `manutencao.csv` que sobe: a aba da
-- manutenção é o filtro `_Entra no arquivo = t`, sem as colunas `_`, com
-- Ativo = True. Por isso não existe uma segunda query — a seleção é a mesma,
-- e duas queries iguais só dariam chance de divergirem.
--
-- ##########################################################################
-- Todo '<<TROCAR>>' é coluna cuja origem no banco eu ainda não sei. Rode
-- `descobrir-colunas.sql` e me mande a saída. Deixei o literal no lugar de
-- vazio de propósito: com 41 colunas a manutenção grava as 41, e coluna
-- vazia APAGA o campo. Assim, subir sem terminar erra alto em vez de zerar
-- Cargo e Telefone de 7 mil contatos.
-- ##########################################################################
--
-- A chave é (ID Original, E-mail): esta lista não tem ID Sensedata.

WITH b AS (
  SELECT id, id_customer, name AS nome, btrim(email) AS email,
         is_active, email_unsubscribe AS optout, created_at, updated_at,
         coalesce(custom_fields->'produto_contact'->>'value','') AS produto,
         custom_fields->'data_benchmark'->>'value'               AS data_benchmark,
         custom_fields->'origem'->>'value'                       AS origem,
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
SELECT c.name        AS "Cliente",
       g.nome        AS "Nome",
       '<<TROCAR>>'  AS "Grupo Econômico",
       c.id_legacy   AS "ID Original",
       g.id          AS "ID Contato",
       '<<TROCAR>>'  AS "Apelido",
       g.email       AS "Email",
       '<<TROCAR>>'  AS "Cargo",
       CASE WHEN g.is_active THEN 'True' ELSE 'False' END AS "Ativo",
       '<<TROCAR>>'  AS "Tel",
       '<<TROCAR>>'  AS "Tel 2",
       '<<TROCAR>>'  AS "Sponsor",
       '<<TROCAR>>'  AS "Skype",
       '<<TROCAR>>'  AS "Endereço",
       CASE WHEN g.optout THEN 'True' ELSE 'False' END    AS "Email Unsubscribe",
       '<<TROCAR>>'  AS "Motivo Unsubscribe",
       '<<TROCAR>>'  AS "SMS Unsubscribe",
       '<<TROCAR>>'  AS "SMS Unsubscribe_2",
       g.updated_at  AS "Última atualização",
       g.created_at  AS "Data de Inserção SD",
       '<<TROCAR>>'  AS "Tipo Contato",
       '<<TROCAR>>'  AS "País",
       '<<TROCAR>>'  AS "Favorito",
       '<<TROCAR>>'  AS "Status do cliente",
       coalesce(g.benchmarking,'')   AS "Benchmarking",
       '<<TROCAR>>'  AS "Blacklist",
       '<<TROCAR>>'  AS "País_1",
       '<<TROCAR>>'  AS "Brand ",
       g.produto     AS "Produto ",
       coalesce(g.data_benchmark,'') AS "Data Benchmark",
       '<<TROCAR>>'  AS "Data Resposta NPS",
       '<<TROCAR>>'  AS "Nota último NPS",
       '<<TROCAR>>'  AS "Sentimento NPS",
       '<<TROCAR>>'  AS "Request for contact NPS",
       '<<TROCAR>>'  AS "Pesquisas",
       '<<TROCAR>>'  AS "Avaliação NPS",
       '<<TROCAR>>'  AS "Solicitar Contato NPS Digital",
       g.origem      AS "Origem",
       '<<TROCAR>>'  AS "Nível do Cargo",
       '<<TROCAR>>'  AS "Nota último NPS Digital",
       '<<TROCAR>>'  AS "Data Resp NPS Digital",
       -- colunas de controle: o script usa e descarta na aba da manutenção
       CASE WHEN g.tem_ativo THEN 'OK — pessoa tem ativo'
            WHEN NOT g.veio  THEN 'inativo correto — nao veio no arquivo'
            ELSE 'AFETADO — veio no arquivo e esta sem ativo' END AS "_Veredito",
       g.no_par      AS "_Registros no par",
       CASE WHEN g.email !~ '^[^@[:space:],;<>]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
                 OR g.email ~ '\.\.'                THEN 'e-mail invalido — corrigir na mao'
            WHEN g.email ~* '\.(con|ne|cm|bra)$'
                 OR g.id IN (209338,210078,211563,218790) THEN 'terminacao truncada — corrigir na mao'
       END           AS "_Problema no e-mail",
       g.veio AND NOT g.tem_ativo AND g.rn = 1
         AND g.email ~ '^[^@[:space:],;<>]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
         AND g.email !~ '\.\.' AND g.email !~* '\.(con|ne|cm|bra)$'
         AND g.id NOT IN (209338,210078,211563,218790) AS "_Entra no arquivo"
FROM g JOIN public.customer c ON c.id = g.id_customer
WHERE NOT g.is_active
ORDER BY 4, 2, 7;
