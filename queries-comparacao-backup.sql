-- ============================================================================
-- Contatos TR — comparação backup (dia 10) x base atual
-- Complementa `queries-contatos-tr.sql`. Staging: stg_contatos_bkp_10 / stg_contatos_atual
-- ============================================================================
-- TRÊS ARMADILHAS confirmadas no export de 21/08 (7.100 linhas):
--
-- 1. NÃO existe a chave 'Produto' no custom_fields. A chave é 'produto_contact'
--    e o valor é aninhado:  custom_fields -> 'produto_contact' ->> 'value'
--    `custom_fields->>'Produto'` devolve NULL em 100% das linhas — com COALESCE
--    a coluna inteira vira 'N/A' e parece que ninguém tem produto.
--
-- 2. JOIN por (email, id_customer) INFLA o resultado. A base tem 9.110 pessoas-conta
--    com 2+ registros; um join backup x atual por esse par multiplica linha por linha
--    (3 x 3 = 9). Sobre a distribuição atual a inflação é ~3,3x.
--    Os dois snapshots são da MESMA tabela → case por `id`, que é estável.
--
-- 3. `is_active` importado de CSV costuma vir como TEXTO ('TRUE'/'FALSE'), não boolean.
--    `WHERE is_active = true` então falha ou dá erro de tipo. Os blocos abaixo normalizam.
--
-- E uma armadilha de interpretação, que é a mais cara — ver seção 2.
-- ============================================================================


-- ============================================================================
-- 0. NORMALIZAÇÃO — cole este bloco no topo das consultas 1 e 2
-- ============================================================================
-- Serve tanto se o staging veio de dump do banco (jsonb, boolean) quanto de CSV
-- (texto). Se o CSV foi gerado pela tela do SenseData, o custom_fields sai em
-- formato Python ('chave': {'value': ...}) e NÃO converte para jsonb — nesse caso
-- use a coluna `produto` que o próprio export já traz pronta.

WITH bkp AS (
  SELECT b.id,
         b.id_customer,
         lower(trim(b.email))                          AS email,
         b.name                                        AS nome,
         b.id_legacy                                   AS chave_no_dia_10,
         (lower(nullif(b.is_active::text, '')) IN ('true','t','1','sim'))  AS ativo,
         b.custom_fields->'produto_contact'->>'value'  AS produto
  FROM stg_contatos_bkp_10 b
),
atu AS (
  SELECT a.id,
         a.id_customer,
         lower(trim(a.email))                          AS email,
         a.id_legacy                                   AS chave_hoje,
         a.updated_at,
         (lower(nullif(a.is_active::text, '')) IN ('true','t','1','sim'))  AS ativo
  FROM stg_contatos_atual a
)


-- ============================================================================
-- 1. REGISTRO A REGISTRO — o que foi desligado (sua query, corrigida)
-- ============================================================================
-- Case por `id`: mesma tabela em dois momentos, então o id é a identidade real.
-- LEFT JOIN em vez de INNER: pega também quem SUMIU da base (expurgo), que o
-- INNER JOIN esconderia justamente no cenário irreversível.

SELECT c.id_legacy                          AS id_conta,
       bkp.nome                             AS nome_contato,
       bkp.email,
       coalesce(bkp.produto, '—')           AS produto_dia_10,
       CASE WHEN atu.id IS NULL THEN 'SUMIU DA BASE (expurgo?)'
            ELSE 'desativado' END           AS o_que_aconteceu,
       bkp.chave_no_dia_10,
       atu.chave_hoje,
       (bkp.chave_no_dia_10 IS DISTINCT FROM atu.chave_hoje) AS chave_reescrita,
       atu.updated_at                       AS ultima_alteracao,
       CASE date_trunc('day', atu.updated_at)
         WHEN '2026-08-13'::timestamp THEN '1a onda'
         WHEN '2026-08-14'::timestamp THEN '2a onda'
         WHEN '2026-08-20'::timestamp THEN '3a onda'
         WHEN '2026-08-21'::timestamp THEN '4a onda'
         ELSE 'fora das ondas conhecidas'
       END                                  AS onda
FROM bkp
LEFT JOIN atu           ON atu.id = bkp.id
JOIN public.customer c  ON c.id  = bkp.id_customer
WHERE c.id_legacy = '132626-TAX'
  AND bkp.ativo                              -- estava ativo no dia 10
  AND (atu.id IS NULL OR NOT atu.ativo)      -- hoje está inativo, ou não existe mais
ORDER BY atu.updated_at DESC NULLS FIRST;

-- Sobre `updated_at`: é a última alteração de QUALQUER tipo, não a data da
-- inativação. Um registro desligado em 13/08 e recarimbado em 21/08 mostra 21/08.
-- Por isso a coluna `onda` — e por isso ela não prova quando o registro caiu,
-- só quando foi tocado pela última vez.


-- ============================================================================
-- 2. A PERGUNTA QUE A JAQUE REALMENTE FAZ — quem sumiu da tela 360
-- ============================================================================
-- ARMADILHA DE INTERPRETAÇÃO: a seção 1 conta REGISTROS desligados. Mas a
-- recriação desliga o registro antigo E cria um novo ativo para a mesma pessoa.
-- Contar registros desligados superestima a perda — vai devolver milhares de
-- linhas de gente que continua aparecendo na tela, só que em outro registro.
--
-- O que dói para o cliente é a PESSOA sem nenhum contato ativo na conta.
-- Agregar ANTES de cruzar também elimina o fan-out do join.

WITH bkp AS (  /* ... cole a CTE da seção 0 ... */
  SELECT b.id_customer, lower(trim(b.email)) AS email, b.name AS nome,
         (lower(nullif(b.is_active::text,'')) IN ('true','t','1','sim')) AS ativo,
         b.custom_fields->'produto_contact'->>'value' AS produto
  FROM stg_contatos_bkp_10 b
),
atu AS (
  SELECT a.id_customer, lower(trim(a.email)) AS email,
         (lower(nullif(a.is_active::text,'')) IN ('true','t','1','sim')) AS ativo
  FROM stg_contatos_atual a
),
antes AS (
  SELECT email, id_customer,
         min(nome)                       AS nome,
         min(produto)                    AS produto_dia_10,
         count(*)                        AS registros_dia_10,
         count(*) FILTER (WHERE ativo)   AS ativos_dia_10
  FROM bkp GROUP BY 1, 2
),
depois AS (
  SELECT email, id_customer,
         count(*)                        AS registros_hoje,
         count(*) FILTER (WHERE ativo)   AS ativos_hoje
  FROM atu GROUP BY 1, 2
)
SELECT c.id_legacy        AS id_conta,
       antes.nome,
       antes.email,
       coalesce(antes.produto_dia_10, '—') AS produto_dia_10,
       antes.ativos_dia_10,
       coalesce(depois.ativos_hoje, 0)     AS ativos_hoje,
       coalesce(depois.registros_hoje, 0)  AS registros_hoje
FROM antes
LEFT JOIN depois ON depois.email = antes.email
                AND depois.id_customer = antes.id_customer
JOIN public.customer c ON c.id = antes.id_customer
WHERE c.id_legacy = '132626-TAX'
  AND antes.ativos_dia_10 > 0
  AND coalesce(depois.ativos_hoje, 0) = 0   -- perdeu TODA presença ativa na conta
ORDER BY antes.nome;

-- `registros_hoje > 0` com `ativos_hoje = 0` → a pessoa existe, só está desligada.
-- `registros_hoje = 0` → não existe mais nenhum registro dela nesta conta.
-- Tire o filtro de conta para ter o número da base inteira. Esse é o número
-- honesto de perda; o da seção 1 é o volume de estrago, não de perda.


-- ============================================================================
-- 3. RESUMO DA CONTA — uma linha para levar à conversa
-- ============================================================================

SELECT c.id_legacy AS id_conta,
       count(*) FILTER (WHERE lower(nullif(b.is_active::text,'')) IN ('true','t','1','sim'))
                                                              AS ativos_dia_10,
       (SELECT count(*) FROM stg_contatos_atual a
         WHERE a.id_customer = c.id
           AND lower(nullif(a.is_active::text,'')) IN ('true','t','1','sim'))
                                                              AS ativos_hoje
FROM stg_contatos_bkp_10 b
JOIN public.customer c ON c.id = b.id_customer
WHERE c.id_legacy = '132626-TAX'
GROUP BY c.id, c.id_legacy;
-- Esperado para 132626-TAX, conferido registro a registro na auditoria: 7 contatos.


-- ============================================================================
-- 4. SANIDADE DO BACKUP — rode ANTES de confiar nas seções acima
-- ============================================================================
-- A primeira onda foi 13/08 22h43. Se o snapshot for posterior, ele já está
-- contaminado e a comparação mede só a diferença entre duas ondas.

SELECT count(*)                                                       AS linhas,
       count(*) FILTER (WHERE lower(nullif(is_active::text,'')) IN ('true','t','1','sim'))
                                                                      AS ativos,
       min(created_at)                                                AS criado_mais_antigo,
       max(created_at)                                                AS criado_mais_recente,
       max(updated_at)                                                AS ultima_alteracao
FROM stg_contatos_bkp_10;
-- `max(updated_at)` precisa ser ANTERIOR a 2026-08-13 22:43.
-- `ativos` de origem Integração Sistema deve bater com ~6.257 (patamar de 13/08).
-- Se vier ~2.053, o backup é pós-20/08 e não serve como linha de base.

-- 4.1 · Os dois snapshots cobrem o mesmo universo?
SELECT (SELECT count(*) FROM stg_contatos_bkp_10)   AS linhas_backup,
       (SELECT count(*) FROM stg_contatos_atual)    AS linhas_hoje,
       (SELECT count(*) FROM stg_contatos_bkp_10 b
         WHERE NOT EXISTS (SELECT 1 FROM stg_contatos_atual a WHERE a.id = b.id))
                                                    AS sumiram_da_base;
-- `sumiram_da_base` > 0 é o alerta de expurgo — cenário irreversível do runbook (C.1).
