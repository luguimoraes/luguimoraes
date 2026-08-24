-- ============================================================================
-- Contatos TR — as duas abas do Excel da Jaqueline
-- ============================================================================
--   seção 1  ABA "Inativos (de-para)"  — todo contato inativo do escopo, com
--            veredito e a marca de quem entra no arquivo. É aqui que sai a
--            quantidade de desativados.
--   seção 2  ABA "Manutenção CSV"      — o que vai ser importado.
--
-- Depois: exporte as duas como CSV e rode
--     python3 montar-excel.py inativos.csv manutencao.csv contatos-reativacao.xlsx
--
-- ############################################################################
-- ESTE ARQUIVO AINDA NÃO ESTÁ PRONTO PARA SUBIR.
-- Todo campo marcado '<<TROCAR>>' é coluna que eu não sei de onde vem no banco.
-- Deixei o literal '<<TROCAR>>' de propósito, no lugar de vazio: se alguém subir
-- sem terminar, a manutenção erra alto em vez de APAGAR o campo em 7 mil
-- contatos. Rode `descobrir-colunas.sql`, me mande a saída, e eu preencho.
-- ############################################################################
--
-- POR QUE ISSO IMPORTA: com 41 colunas, a manutenção grava as 41. Coluna que
-- for vazia apaga o que está hoje no SenseData. Por isso a seção 2 devolve o
-- valor ATUAL de cada campo — só `Ativo` muda de False para True.
--
-- CONFIRMAR ANTES DE SUBIR:
--   a) o formato de data que a manutenção espera (hoje sai ISO, do banco);
--   b) se os campos de NPS são graváveis — se forem calculados, tire as oito
--      colunas de NPS do arquivo em vez de devolvê-las;
--   c) 'Brand ' e 'Produto ' estão com espaço no fim, como na sua lista. Se a
--      manutenção não aceitar, tire o espaço nos dois aliases.
--
-- A chave da importação aqui é (ID Original, Email) — esta lista não tem
-- coluna de ID Sensedata. Rode a consulta 4 de `descobrir-colunas.sql` antes.
-- ============================================================================


-- ============================================================================
-- 1. ABA "Inativos (de-para)"
-- ============================================================================
WITH cc AS (
  SELECT c.id,
         c.id_customer,
         c.name                                                     AS nome,
         btrim(c.email)                                             AS email_gravado,
         lower(trim(c.email))                                       AS email_chave,
         c.is_active,
         c.email_unsubscribe                                        AS optout,
         c.created_at,
         c.updated_at,
         coalesce(c.custom_fields->'produto_contact'->>'value', '')  AS produto,
         nullif(c.custom_fields->'data_benchmark'->>'value', '')     AS data_benchmark,
         coalesce(c.custom_fields->'origem'->>'value', '')           AS origem,
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
  SELECT email_chave, id_customer,
         bool_or(is_active)                       AS tem_ativo,
         bool_or(created_at >= DATE '2026-08-13') AS veio_no_arquivo,
         count(*)                                 AS registros_no_par
  FROM cc GROUP BY 1, 2
),
escolhido AS (
  SELECT DISTINCT ON (cc.email_chave, cc.id_customer) cc.id
  FROM cc
  JOIN grupo g ON g.email_chave = cc.email_chave AND g.id_customer = cc.id_customer
  WHERE g.veio_no_arquivo AND NOT g.tem_ativo
  ORDER BY cc.email_chave, cc.id_customer,
           (cc.benchmarking IS NOT NULL) DESC, (cc.produto <> '') DESC, cc.created_at DESC
)
SELECT cli.name                                   AS "Cliente",
       e.nome                                     AS "Nome",
       '<<TROCAR>>'                               AS "Grupo Econômico",
       cli.id_legacy                              AS "ID Original",
       e.id                                       AS "ID Contato",
       '<<TROCAR>>'                               AS "Apelido",
       e.email_gravado                            AS "Email",
       '<<TROCAR>>'                               AS "Cargo",
       CASE WHEN e.is_active THEN 'True' ELSE 'False' END AS "Ativo",
       '<<TROCAR>>'                               AS "Tel",
       '<<TROCAR>>'                               AS "Tel 2",
       '<<TROCAR>>'                               AS "Sponsor",
       '<<TROCAR>>'                               AS "Skype",
       '<<TROCAR>>'                               AS "Endereço",
       CASE WHEN e.optout THEN 'True' ELSE 'False' END AS "Email Unsubscribe",
       '<<TROCAR>>'                               AS "Motivo Unsubscribe",
       '<<TROCAR>>'                               AS "SMS Unsubscribe",
       '<<TROCAR>>'                               AS "SMS Unsubscribe_2",
       e.updated_at                               AS "Última atualização",
       e.created_at                               AS "Data de Inserção SD",
       '<<TROCAR>>'                               AS "Tipo Contato",
       '<<TROCAR>>'                               AS "País",
       '<<TROCAR>>'                               AS "Favorito",
       '<<TROCAR>>'                               AS "Status do cliente",
       coalesce(e.benchmarking, '')               AS "Benchmarking",
       '<<TROCAR>>'                               AS "Blacklist",
       '<<TROCAR>>'                               AS "País_1",
       '<<TROCAR>>'                               AS "Brand ",
       e.produto                                  AS "Produto ",
       coalesce(e.data_benchmark, '')             AS "Data Benchmark",
       '<<TROCAR>>'                               AS "Data Resposta NPS",
       '<<TROCAR>>'                               AS "Nota último NPS",
       '<<TROCAR>>'                               AS "Sentimento NPS",
       '<<TROCAR>>'                               AS "Request for contact NPS",
       '<<TROCAR>>'                               AS "Pesquisas",
       '<<TROCAR>>'                               AS "Avaliação NPS",
       '<<TROCAR>>'                               AS "Solicitar Contato NPS Digital",
       e.origem                                   AS "Origem",
       '<<TROCAR>>'                               AS "Nível do Cargo",
       '<<TROCAR>>'                               AS "Nota último NPS Digital",
       '<<TROCAR>>'                               AS "Data Resp NPS Digital",
       -- colunas de controle: só nesta aba, não vão para a manutenção
       CASE WHEN g.tem_ativo            THEN 'OK — pessoa tem contato ativo'
            WHEN NOT g.veio_no_arquivo  THEN 'inativo correto — nao veio no arquivo'
            ELSE 'AFETADO — veio no arquivo e esta sem ativo' END AS "_Veredito",
       CASE WHEN e.id IN (SELECT id FROM escolhido) THEN 'Sim' ELSE 'Nao' END AS "_Entra no arquivo",
       g.registros_no_par                         AS "_Registros no par",
       CASE
         WHEN e.email_gravado !~ '^[^@[:space:],;<>]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
              THEN 'e-mail invalido — corrigir na mao'
         WHEN e.email_gravado ~ '\.\.' THEN 'e-mail com ponto duplo — corrigir na mao'
         WHEN e.email_gravado ~* '\.(con|ne|cm|bra)$' THEN 'terminacao suspeita — conferir'
       END                                        AS "_Problema no e-mail"
FROM cc e
JOIN grupo g ON g.email_chave = e.email_chave AND g.id_customer = e.id_customer
JOIN public.customer cli ON cli.id = e.id_customer
WHERE NOT e.is_active
ORDER BY cli.id_legacy, e.nome, e.email_gravado;


-- ============================================================================
-- 2. ABA "Manutenção CSV" — o arquivo que sobe
-- ============================================================================
-- Mesma seleção de `reativar-csv.sql`, com as 41 colunas. Sai um registro por
-- pessoa-conta, já sem os 47 e-mails quebrados.
WITH cc AS (
  SELECT c.id,
         c.id_customer,
         c.name                                                     AS nome,
         btrim(c.email)                                             AS email_gravado,
         lower(trim(c.email))                                       AS email_chave,
         c.is_active,
         c.email_unsubscribe                                        AS optout,
         c.created_at,
         c.updated_at,
         coalesce(c.custom_fields->'produto_contact'->>'value', '')  AS produto,
         nullif(c.custom_fields->'data_benchmark'->>'value', '')     AS data_benchmark,
         coalesce(c.custom_fields->'origem'->>'value', '')           AS origem,
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
  SELECT email_chave, id_customer,
         bool_or(is_active)                       AS tem_ativo,
         bool_or(created_at >= DATE '2026-08-13') AS veio_no_arquivo
  FROM cc GROUP BY 1, 2
),
escolhido AS (
  SELECT DISTINCT ON (cc.email_chave, cc.id_customer) cc.*
  FROM cc
  JOIN grupo g ON g.email_chave = cc.email_chave AND g.id_customer = cc.id_customer
  WHERE g.veio_no_arquivo AND NOT g.tem_ativo
  ORDER BY cc.email_chave, cc.id_customer,
           (cc.benchmarking IS NOT NULL) DESC, (cc.produto <> '') DESC, cc.created_at DESC
)
SELECT cli.name                                   AS "Cliente",
       e.nome                                     AS "Nome",
       '<<TROCAR>>'                               AS "Grupo Econômico",
       cli.id_legacy                              AS "ID Original",
       e.id                                       AS "ID Contato",
       '<<TROCAR>>'                               AS "Apelido",
       e.email_gravado                            AS "Email",
       '<<TROCAR>>'                               AS "Cargo",
       'True'                                     AS "Ativo",
       '<<TROCAR>>'                               AS "Tel",
       '<<TROCAR>>'                               AS "Tel 2",
       '<<TROCAR>>'                               AS "Sponsor",
       '<<TROCAR>>'                               AS "Skype",
       '<<TROCAR>>'                               AS "Endereço",
       CASE WHEN e.optout THEN 'True' ELSE 'False' END AS "Email Unsubscribe",
       '<<TROCAR>>'                               AS "Motivo Unsubscribe",
       '<<TROCAR>>'                               AS "SMS Unsubscribe",
       '<<TROCAR>>'                               AS "SMS Unsubscribe_2",
       e.updated_at                               AS "Última atualização",
       e.created_at                               AS "Data de Inserção SD",
       '<<TROCAR>>'                               AS "Tipo Contato",
       '<<TROCAR>>'                               AS "País",
       '<<TROCAR>>'                               AS "Favorito",
       '<<TROCAR>>'                               AS "Status do cliente",
       coalesce(e.benchmarking, '')               AS "Benchmarking",
       '<<TROCAR>>'                               AS "Blacklist",
       '<<TROCAR>>'                               AS "País_1",
       '<<TROCAR>>'                               AS "Brand ",
       e.produto                                  AS "Produto ",
       coalesce(e.data_benchmark, '')             AS "Data Benchmark",
       '<<TROCAR>>'                               AS "Data Resposta NPS",
       '<<TROCAR>>'                               AS "Nota último NPS",
       '<<TROCAR>>'                               AS "Sentimento NPS",
       '<<TROCAR>>'                               AS "Request for contact NPS",
       '<<TROCAR>>'                               AS "Pesquisas",
       '<<TROCAR>>'                               AS "Avaliação NPS",
       '<<TROCAR>>'                               AS "Solicitar Contato NPS Digital",
       e.origem                                   AS "Origem",
       '<<TROCAR>>'                               AS "Nível do Cargo",
       '<<TROCAR>>'                               AS "Nota último NPS Digital",
       '<<TROCAR>>'                               AS "Data Resp NPS Digital"
FROM escolhido e
JOIN public.customer cli ON cli.id = e.id_customer
WHERE e.id NOT IN (
  218697,209082,211439,217581,211232,211099,219211,215616,218671,219193,
  219196,215256,216133,216597,213579,219090,208688,210850,212229,216802,
  218453,210518,208551,217285,213104,217503,208620,211723,211734,216824,
  216825,216827,216831,216832,217443,217447,212475,212476,218113,215610,
  217440,211010,209338,216638,210078,211563,218790)
ORDER BY cli.id_legacy, e.email_gravado;
-- Os 47 IDs acima são os e-mails quebrados: não casam com a chave, então não
-- adianta mandar. Eles aparecem na aba 1 com o motivo em "_Problema no e-mail",
-- para correção manual na tela do SenseData.
