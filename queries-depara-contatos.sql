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
-- D. SE VOCÊ IMPORTAR OS ARQUIVOS GERADOS (stg_contatos_bkp_10 / stg_contatos_atual)
-- ============================================================================
-- Só vale a pena se o arquivo do dia 10 for anterior a 13/08 22h43. Se for
-- posterior, ele já está contaminado e a seção A dá resposta melhor.
--
-- Ao importar, três coisas quebram em silêncio:
--   · `is_active` vem como TEXTO ('TRUE'/'FALSE') — `= true` não funciona;
--   · se o CSV veio da tela do SenseData, `custom_fields` sai em formato Python
--     ('chave': {'value': ...}, aspas simples) e NÃO converte para jsonb — use a
--     coluna `produto` que o próprio export já traz pronta;
--   · cruzar por (email, id_customer) infla; os dois snapshots são da mesma
--     tabela, então case por `id`, que é estável.

-- D.1 · Sanidade: o arquivo do dia 10 é mesmo anterior à primeira onda?
SELECT count(*)                                                        AS linhas,
       count(*) FILTER (WHERE lower(nullif(is_active::text,'')) IN ('true','t','1','sim'))
                                                                       AS ativos,
       min(created_at) AS criado_mais_antigo,
       max(updated_at) AS ultima_alteracao
FROM stg_contatos_bkp_10;
-- `ultima_alteracao` precisa ser ANTERIOR a 2026-08-13 22:43.
-- `ativos` perto de 6.257 = patamar pré-primeira-onda. Perto de 2.053 = pós-20/08,
-- não serve como linha de base.

-- D.2 · Comparação antes x depois, por registro
SELECT cli.id_legacy AS conta,
       b.name        AS nome_contato,
       b.email,
       coalesce(b.custom_fields->'produto_contact'->>'value', '—') AS produto_dia_10,
       CASE WHEN a.id IS NULL THEN 'SUMIU DA BASE (expurgo?)' ELSE 'desativado' END
                     AS o_que_aconteceu,
       b.id_legacy   AS chave_no_dia_10,
       a.id_legacy   AS chave_hoje,
       (b.id_legacy IS DISTINCT FROM a.id_legacy) AS chave_reescrita,
       a.updated_at  AS ultima_alteracao
FROM stg_contatos_bkp_10 b
LEFT JOIN stg_contatos_atual a ON a.id = b.id          -- pelo id, não pelo email
JOIN public.customer cli       ON cli.id = b.id_customer
WHERE cli.id_legacy = '132626-TAX'
  AND      lower(nullif(b.is_active::text,'')) IN ('true','t','1','sim')
  AND (a.id IS NULL OR NOT lower(nullif(a.is_active::text,'')) IN ('true','t','1','sim'))
ORDER BY a.updated_at DESC NULLS FIRST;

-- `updated_at` é a última alteração de QUALQUER tipo, não a data da inativação:
-- registro desligado em 13/08 e recarimbado em 21/08 aparece como 21/08.
