-- ============================================================================
-- Contatos TR — conferir a alegação do cliente e montar o de-para da recarga
-- Tabela: public.customer_contact  ·  roda direto no banco, sem importar backup
-- ============================================================================
-- PERGUNTAS QUE ESTE ARQUIVO RESPONDE
--   A. No dia 10 esses contatos estavam mesmo ativos? A data é essa mesmo?
--   B. Bate o número de contatos entre o dia 10 e hoje?
--   C. Qual registro antigo alimenta qual registro novo (de-para da recarga)?
--
-- LIMITE HONESTO: o Postgres não guarda histórico de estado. O que dá para fazer
-- é INFERIR o estado do dia 10 a partir de `created_at` e `updated_at`. A inferência
-- só é válida porque a auditoria já mapeou as ondas de desativação em massa —
-- 13/08, 14/08, 20/08 e 21/08 — e nenhuma antes disso. Ver seção A.3, que testa
-- exatamente essa premissa antes de você confiar no resto.
--
-- CUIDADO COM OS NOMES: `customer_contact.id_legacy` é a chave de upsert do contato.
-- `customer.id_legacy` é o código da conta ('132626-TAX'). Nomes iguais, coisas
-- diferentes — abaixo estão sempre com alias.
--
-- FORMATO DOS CAMPOS (confirmado no export de 21/08, 7.100 linhas):
--   custom_fields -> 'produto_contact' ->> 'value'   texto  (NÃO existe 'Produto')
--   custom_fields -> 'benchmarking'    -> 'value'    ARRAY jsonb — ver CTE `cc`
--   custom_fields -> 'data_benchmark'  ->> 'value'   texto 'AAAA-MM-DD'
-- ============================================================================


-- ============================================================================
-- 0. BASE NORMALIZADA — cole este bloco no topo de cada consulta
-- ============================================================================

WITH cc AS (
  SELECT c.*,
         c.custom_fields->'origem'->>'value'          AS origem,
         c.custom_fields->'produto_contact'->>'value' AS produto,
         c.custom_fields->'brand_'->>'value'          AS brand,
         nullif(c.custom_fields->'data_benchmark'->>'value', '') AS data_benchmark,
         (SELECT string_agg(v.val, '; ')
            FROM jsonb_array_elements_text(
                   CASE jsonb_typeof(c.custom_fields #> '{benchmarking,value}')
                     WHEN 'array'  THEN c.custom_fields #> '{benchmarking,value}'
                     WHEN 'string' THEN jsonb_build_array(c.custom_fields #> '{benchmarking,value}')
                     ELSE '[]'::jsonb
                   END
                 ) AS v(val)
           WHERE v.val <> '' AND v.val <> 'N/A')      AS benchmarking
  FROM public.customer_contact c
)


-- ============================================================================
-- A. A ALEGAÇÃO DO CLIENTE: "no dia 10 estavam ativos"
-- ============================================================================

-- ----------------------------------------------------------------------------
-- A.1 · Linha do tempo da conta que a Jaque citou  ← COMECE POR AQUI
-- ----------------------------------------------------------------------------
-- Uma linha por registro, com quando nasceu, quando foi tocado e qual chave
-- carrega. É a evidência que se mostra ao cliente.

WITH cc AS ( /* cole a CTE da seção 0 */
  SELECT c.*,
         c.custom_fields->'produto_contact'->>'value' AS produto,
         nullif(c.custom_fields->'data_benchmark'->>'value','') AS data_benchmark,
         (SELECT string_agg(v.val, '; ')
            FROM jsonb_array_elements_text(
                   CASE jsonb_typeof(c.custom_fields #> '{benchmarking,value}')
                     WHEN 'array'  THEN c.custom_fields #> '{benchmarking,value}'
                     WHEN 'string' THEN jsonb_build_array(c.custom_fields #> '{benchmarking,value}')
                     ELSE '[]'::jsonb END) AS v(val)
           WHERE v.val <> '' AND v.val <> 'N/A') AS benchmarking
  FROM public.customer_contact c
)
SELECT cli.id_legacy                     AS conta,
       cc.id                             AS id_contato,
       cc.name                           AS nome,
       cc.email,
       cc.produto,
       cc.benchmarking,
       cc.is_active                      AS ativo_hoje,
       cc.id_legacy                      AS chave_upsert_gravada,
       cc.created_at,
       cc.updated_at,
       CASE
         WHEN cc.created_at > TIMESTAMP '2026-08-10 23:59:59' THEN 'nao existia em 10/08'
         WHEN cc.is_active                                    THEN 'ativo hoje'
         WHEN cc.updated_at > TIMESTAMP '2026-08-10 23:59:59' THEN 'ATIVO EM 10/08 -> desligado depois'
         ELSE 'ja estava inativo em 10/08'
       END                               AS estado_em_10_08
FROM cc
JOIN public.customer cli ON cli.id = cc.id_customer
WHERE cli.id_legacy = '132626-TAX'
ORDER BY cc.created_at, cc.id;

-- Como ler: se aparecerem registros 'ATIVO EM 10/08 -> desligado depois' com
-- `created_at` de 2025-07 e `updated_at` em 13, 14, 20 ou 21/08, a cliente está
-- certa — estavam ativos no dia 10 e foram desligados pelas cargas.
-- Troque '132626-TAX' pela conta que ela mandar. Sem o WHERE, roda na base toda.


-- ----------------------------------------------------------------------------
-- A.2 · Reconstrução do dia 10 na base inteira
-- ----------------------------------------------------------------------------

WITH cc AS ( /* cole a CTE da seção 0 */ SELECT c.*, c.custom_fields->'origem'->>'value' AS origem FROM public.customer_contact c )
SELECT CASE
         WHEN created_at > TIMESTAMP '2026-08-10 23:59:59' THEN 'nao existia em 10/08'
         WHEN is_active                                    THEN 'ativo hoje'
         WHEN updated_at > TIMESTAMP '2026-08-10 23:59:59' THEN 'ATIVO EM 10/08 -> desligado depois'
         ELSE 'ja estava inativo em 10/08'
       END                    AS estado_em_10_08,
       count(*)               AS contatos,
       count(DISTINCT id_customer) AS contas
FROM cc
WHERE origem = 'Integração Sistema'
GROUP BY 1
ORDER BY 2 DESC;

-- 'ATIVO EM 10/08 -> desligado depois' é o tamanho do estrago que a cliente vê.


-- ----------------------------------------------------------------------------
-- A.3 · A data foi mesmo o dia 10?  ← TESTA A PREMISSA DE A.1 E A.2
-- ----------------------------------------------------------------------------
-- Desativações por dia. Se houver pico em 10/08, a inferência acima está errada
-- e precisa de backup de verdade. Se os picos forem só 13, 14, 20 e 21/08,
-- o dia 10 é a data da LISTAGEM do cliente, não a data da inativação.

WITH cc AS ( SELECT c.*, c.custom_fields->'origem'->>'value' AS origem FROM public.customer_contact c )
SELECT date_trunc('day', updated_at)::date AS dia,
       count(*)                            AS registros_tocados,
       count(*) FILTER (WHERE NOT is_active) AS terminaram_inativos,
       count(*) FILTER (WHERE is_active)     AS terminaram_ativos
FROM cc
WHERE origem = 'Integração Sistema'
  AND updated_at >= DATE '2026-08-01'
GROUP BY 1
ORDER BY 1;

-- Apuração até 21/08: ondas em 13/08 (22h43), 14/08, 20/08 (22h00) e 21/08 (18h12).
-- Nenhuma em 10/08. Rode de novo — pode ter havido uma quinta onda entre 22 e 24/08.


-- ============================================================================
-- B. BATE O NÚMERO DE CONTATOS? — por conta, dia 10 x hoje
-- ============================================================================
-- É o quadro que responde "são os mesmos números de contatos".

WITH cc AS ( SELECT c.*, c.custom_fields->'origem'->>'value' AS origem FROM public.customer_contact c ),
est AS (
  SELECT cc.id_customer,
         count(*) FILTER (WHERE cc.is_active)                          AS ativos_hoje,
         count(*) FILTER (WHERE cc.created_at <= TIMESTAMP '2026-08-10 23:59:59'
                            AND (cc.is_active OR cc.updated_at > TIMESTAMP '2026-08-10 23:59:59'))
                                                                       AS ativos_em_10_08
  FROM cc
  WHERE cc.origem = 'Integração Sistema'
  GROUP BY 1
)
SELECT cli.id_legacy        AS conta,
       cli.name             AS cliente,
       est.ativos_em_10_08,
       est.ativos_hoje,
       est.ativos_hoje - est.ativos_em_10_08 AS diferenca
FROM est
JOIN public.customer cli ON cli.id = est.id_customer
WHERE est.ativos_em_10_08 <> est.ativos_hoje
ORDER BY diferenca ASC, conta;      -- as contas que mais perderam primeiro

-- Tire o WHERE e some as colunas para ter o total da base.


-- ============================================================================
-- C. O DE-PARA — qual registro antigo alimenta qual registro novo
-- ============================================================================
-- Este é o insumo da recarga. O par é (mesma pessoa, mesma conta): o registro
-- inativo carrega o campo preenchido à mão, o ativo é o destino.
--
-- AGREGA ANTES DE CRUZAR. Cruzar por (email, id_customer) sem agregar multiplica
-- linha por linha — há 9.110 pessoas-conta com 2+ registros, inflação de ~3,3x.

WITH cc AS ( /* cole a CTE da seção 0 — precisa de benchmarking e data_benchmark */
  SELECT c.*,
         c.custom_fields->'produto_contact'->>'value' AS produto,
         nullif(c.custom_fields->'data_benchmark'->>'value','') AS data_benchmark,
         (SELECT string_agg(v.val, '; ')
            FROM jsonb_array_elements_text(
                   CASE jsonb_typeof(c.custom_fields #> '{benchmarking,value}')
                     WHEN 'array'  THEN c.custom_fields #> '{benchmarking,value}'
                     WHEN 'string' THEN jsonb_build_array(c.custom_fields #> '{benchmarking,value}')
                     ELSE '[]'::jsonb END) AS v(val)
           WHERE v.val <> '' AND v.val <> 'N/A') AS benchmarking
  FROM public.customer_contact c
),
origem AS (   -- registros inativos que carregam dado manual
  SELECT lower(trim(email)) AS email_norm, id_customer,
         count(*)                                   AS registros_origem,
         min(id)                                    AS id_origem,
         string_agg(DISTINCT benchmarking, ' | ')   AS benchmarking,
         max(data_benchmark)                        AS data_benchmark,
         bool_or(email_unsubscribe)                 AS tinha_optout
  FROM cc
  WHERE NOT is_active
    AND benchmarking IS NOT NULL
  GROUP BY 1, 2
),
destino AS (  -- registros ativos que devem receber
  SELECT lower(trim(email)) AS email_norm, id_customer,
         count(*)      AS registros_destino,
         min(id)       AS id_destino,
         min(name)     AS nome,
         min(produto)  AS produto
  FROM cc
  WHERE is_active
  GROUP BY 1, 2
)
SELECT cli.id_legacy                AS conta,
       d.nome,
       o.email_norm                 AS email,
       d.produto,
       o.benchmarking,
       o.data_benchmark,
       o.tinha_optout,
       o.id_origem,
       d.id_destino,
       o.registros_origem,
       d.registros_destino,
       CASE
         WHEN d.id_destino IS NULL      THEN 'SEM DESTINO — decisao do cliente (reativar?)'
         WHEN d.registros_destino > 1   THEN 'AMBIGUO — conferencia manual'
         WHEN o.registros_origem  > 1   THEN 'AMBIGUO — varias origens com marcacao'
         ELSE 'AUTOMATICO'
       END                          AS tratamento
FROM origem o
LEFT JOIN destino d ON d.email_norm  = o.email_norm
                   AND d.id_customer = o.id_customer
JOIN public.customer cli ON cli.id = o.id_customer
ORDER BY tratamento, cli.id_legacy, d.nome;

-- Apuração de 21/08: 452 marcações em 416 pessoas-conta. Sobre o mapeamento de
-- 20/08: 120 automáticos · 16 ambíguos · 277 sem destino ativo.
-- Filtre `tratamento = 'AUTOMATICO'` para gerar o arquivo da carga.


-- ----------------------------------------------------------------------------
-- C.1 · Antes de gravar: a carga faz merge ou replace no jsonb?
-- ----------------------------------------------------------------------------
-- Se for replace, gravar Benchmarking APAGA os demais custom fields do registro.
-- Rode em 10 registros, guarde o resultado, faça a carga, rode de novo e compare.

SELECT id, jsonb_object_keys(custom_fields) AS chave
FROM public.customer_contact
WHERE id IN ( /* os 10 ids de destino do teste */ )
ORDER BY id, chave;

-- A carga de recuperação usa `integ_type = update` (NUNCA upsert), chaveada pelo
-- identificador do próprio registro de destino, gravando só os dois campos.
-- Upsert aqui recria a base de novo — é exatamente o bug em apuração.


-- ============================================================================
-- D. O DE-PARA 10/08 x HOJE — cruzar a listagem do cliente com a base
-- ============================================================================
-- POR QUE ESTA SEÇÃO EXISTE, E NÃO DÁ PARA FAZER SÓ COM A SEÇÃO A:
--
-- A onda de 24/08 13h13 sobrescreveu `updated_at` em TODOS os registros de
-- `Integração Sistema`. A inferência da seção A depende de `updated_at` para
-- separar "estava ativo e foi desligado" de "já estava inativo antes" — e essa
-- separação deixou de existir. Hoje a seção A devolve TODO registro criado antes
-- de 10/08 como se estivesse ativo naquele dia, o que superestima a perda.
--
-- Medido em 24/08: a seção A devolve 10.495; o snapshot real de 13/08 mostra
-- 6.257 ativos. A diferença são registros que JÁ estavam inativos e foram
-- recarimbados. Portanto: para dar número ao cliente, cruze com uma listagem
-- de verdade. Só a listagem prova o estado.
--
-- Cada nova execução da carga piora isso. Pausar preserva a evidência.
-- ============================================================================

-- Importe a listagem do dia 10 como `stg_contatos_10ago`, com no mínimo:
--   id_contato (se houver) · email · conta · ativo
-- Se a listagem for do próprio cliente e não tiver o ID do SenseData, use D.3.


-- ----------------------------------------------------------------------------
-- D.1 · Conferir o import antes de tirar conclusão
-- ----------------------------------------------------------------------------
SELECT count(*)                                                          AS linhas,
       count(*) FILTER (WHERE lower(nullif(ativo::text,'')) IN ('true','t','1','sim'))
                                                                         AS ativos,
       count(DISTINCT conta)                                             AS contas,
       count(*) FILTER (WHERE id_contato IS NULL OR id_contato::text = '') AS sem_id
FROM stg_contatos_10ago;
-- Se `ativos` vier perto de 6.257, a listagem é POSTERIOR à primeira onda
-- (13/08 22h43) e já mede uma base contaminada — ela subestima a perda.
-- Se vier acima disso, é anterior à onda e serve como linha de base real.


-- ----------------------------------------------------------------------------
-- D.2 · DE-PARA por ID Contato  ← use este se a listagem tiver o ID
-- ----------------------------------------------------------------------------
WITH dez AS (
  SELECT (id_contato)::bigint AS id,
         lower(trim(email))   AS email,
         conta,
         (lower(nullif(ativo::text,'')) IN ('true','t','1','sim')) AS ativo_em_10
  FROM stg_contatos_10ago
  WHERE id_contato IS NOT NULL AND id_contato::text <> ''
),
cc AS (
  SELECT c.id, c.name, c.email, c.id_customer, c.is_active, c.id_legacy, c.updated_at,
         c.custom_fields->'produto_contact'->>'value' AS produto,
         (SELECT string_agg(v.val, '; ')
            FROM jsonb_array_elements_text(
                   CASE jsonb_typeof(c.custom_fields #> '{benchmarking,value}')
                     WHEN 'array'  THEN c.custom_fields #> '{benchmarking,value}'
                     WHEN 'string' THEN jsonb_build_array(c.custom_fields #> '{benchmarking,value}')
                     ELSE '[]'::jsonb END) AS v(val)
           WHERE v.val <> '' AND v.val <> 'N/A') AS benchmarking
  FROM public.customer_contact c
)
SELECT CASE
         WHEN cc.id IS NULL      THEN 'SUMIU DA BASE'
         WHEN cc.is_active       THEN 'continua ativo'
         ELSE 'DESATIVADO desde 10/08'
       END                       AS resultado,
       count(*)                  AS contatos,
       count(*) FILTER (WHERE cc.benchmarking IS NOT NULL) AS com_benchmarking
FROM dez
LEFT JOIN cc ON cc.id = dez.id
WHERE dez.ativo_em_10
GROUP BY 1
ORDER BY 2 DESC;

-- Troque o GROUP BY pela lista nominal quando precisar do arquivo:
--   SELECT cli.id_legacy AS conta, cc.name, cc.email, cc.produto, cc.benchmarking,
--          cc.id AS id_contato, cc.id_legacy AS chave_gravada
--   FROM dez JOIN cc ON cc.id = dez.id
--   JOIN public.customer cli ON cli.id = cc.id_customer
--   WHERE dez.ativo_em_10 AND NOT cc.is_active
--   ORDER BY cli.id_legacy, cc.name;
-- Essa lista, com `Ativo = True`, É o arquivo da carga de reativação.

-- 'SUMIU DA BASE' > 0 é o alerta de expurgo. Medido no cruzamento 13/08 x 24/08:
-- 200 registros sumiram, 54 deles ativos, concentrados em 24 contas. Investigar
-- antes de reativar — pode haver exclusão de conta envolvida.


-- ----------------------------------------------------------------------------
-- D.3 · DE-PARA por (email, conta) — se a listagem não tiver o ID do SenseData
-- ----------------------------------------------------------------------------
-- AGREGA ANTES DE CRUZAR. Sem isso o join multiplica: há 9.110 pessoas-conta
-- com 2+ registros, inflação de ~3,3x.

WITH dez AS (
  SELECT lower(trim(email)) AS email, conta,
         bool_or(lower(nullif(ativo::text,'')) IN ('true','t','1','sim')) AS tinha_ativo
  FROM stg_contatos_10ago
  GROUP BY 1, 2
),
hoje AS (
  SELECT lower(trim(cc.email)) AS email,
         cli.id_legacy         AS conta,
         count(*)                                  AS registros_hoje,
         count(*) FILTER (WHERE cc.is_active)      AS ativos_hoje,
         max(cc.id) FILTER (WHERE cc.is_active)    AS id_ativo
  FROM public.customer_contact cc
  JOIN public.customer cli ON cli.id = cc.id_customer
  GROUP BY 1, 2
)
SELECT CASE
         WHEN hoje.email IS NULL           THEN 'SUMIU DA BASE'
         WHEN hoje.ativos_hoje = 0         THEN 'PERDEU TODA PRESENCA ATIVA'
         ELSE 'tem contato ativo'
       END                                 AS resultado,
       count(*)                            AS pessoas_conta,
       count(DISTINCT dez.conta)           AS contas
FROM dez
LEFT JOIN hoje ON hoje.email = dez.email AND hoje.conta = dez.conta
WHERE dez.tinha_ativo
GROUP BY 1
ORDER BY 2 DESC;

-- 'PERDEU TODA PRESENCA ATIVA' é o número honesto do impacto: a pessoa sumiu da
-- tela da conta. É diferente de contar registros desligados, que superestima
-- porque a recriação desliga o antigo e cria um novo ativo para a mesma pessoa.


-- ----------------------------------------------------------------------------
-- D.4 · Resumo por conta — a "lista de contatos inativos" pedida pelo cliente
-- ----------------------------------------------------------------------------
WITH dez AS (
  SELECT conta, count(*) FILTER (WHERE lower(nullif(ativo::text,'')) IN ('true','t','1','sim'))
                                                  AS ativos_em_10
  FROM stg_contatos_10ago GROUP BY 1
),
hoje AS (
  SELECT cli.id_legacy AS conta, cli.name AS cliente,
         count(*) FILTER (WHERE cc.is_active AND cc.custom_fields->'origem'->>'value' = 'Integração Sistema')
                                                  AS ativos_hoje
  FROM public.customer_contact cc
  JOIN public.customer cli ON cli.id = cc.id_customer
  GROUP BY 1, 2
)
SELECT hoje.conta, hoje.cliente,
       coalesce(dez.ativos_em_10, 0) AS ativos_em_10,
       hoje.ativos_hoje,
       hoje.ativos_hoje - coalesce(dez.ativos_em_10, 0) AS diferenca
FROM hoje
LEFT JOIN dez ON dez.conta = hoje.conta
WHERE hoje.ativos_hoje <> coalesce(dez.ativos_em_10, 0)
ORDER BY diferenca ASC, hoje.conta;
