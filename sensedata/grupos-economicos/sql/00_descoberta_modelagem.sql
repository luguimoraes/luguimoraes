-- =====================================================================
-- 00 - DESCOBERTA DE MODELAGEM  (rodar ANTES de qualquer alteracao)
-- Ambiente: SENSEDATA_HOM (connection_id = 6)
-- Objetivo: descobrir os nomes reais das colunas/campos usados na
--           integracao "Grupos_Economicos" antes de publicar a query.
-- Todas as queries abaixo sao SOMENTE LEITURA.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0.1 Estrutura completa da tabela customer
-- ---------------------------------------------------------------------
SELECT ordinal_position,
       column_name,
       data_type,
       is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'customer'
ORDER BY ordinal_position;


-- ---------------------------------------------------------------------
-- 0.2 Candidatas ao "filtro de lojas ativas"
--     O documento assume  filho.status = 'active'.  ISSO PRECISA SER
--     CONFIRMADO: pode ser is_active boolean, situation, active_flag,
--     churn_date, canceled_at etc.
-- ---------------------------------------------------------------------
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'customer'
  AND (column_name ILIKE '%status%'
    OR column_name ILIKE '%activ%'
    OR column_name ILIKE '%situa%'
    OR column_name ILIKE '%churn%'
    OR column_name ILIKE '%cancel%'
    OR column_name ILIKE '%deleted%')
ORDER BY column_name;


-- ---------------------------------------------------------------------
-- 0.3 Dominio real dos valores de status (descobre se e 'active',
--     'Ativo', 'ATIVO', 1, true ...)
--     >> Se a coluna nao se chamar "status", troque o nome abaixo.
-- ---------------------------------------------------------------------
SELECT status,
       count(*) AS qtd_contas,
       count(*) FILTER (WHERE NULLIF(btrim(cnpj), '') IS NOT NULL) AS qtd_com_cnpj,
       count(*) FILTER (WHERE NULLIF(btrim(cnpj), '') IS NULL)     AS qtd_sem_cnpj
FROM public.customer
GROUP BY status
ORDER BY qtd_contas DESC;


-- ---------------------------------------------------------------------
-- 0.4 Quais chaves existem de fato dentro de custom_fields
--     (confirma se e 'cs_feeling' / 'anotacoes_grupo' mesmo, e revela
--      os nomes internos disponiveis para os campos novos da v2)
-- ---------------------------------------------------------------------
SELECT k AS custom_field_key,
       count(*) AS contas_que_possuem
FROM public.customer c
CROSS JOIN LATERAL jsonb_object_keys(c.custom_fields::jsonb) AS k
WHERE c.custom_fields IS NOT NULL
GROUP BY k
ORDER BY contas_que_possuem DESC;


-- ---------------------------------------------------------------------
-- 0.5 Estrutura interna de um custom field
--     Confirma se o valor esta mesmo em ->>'value' e se e texto simples,
--     lista, ou par id/label (muda o SQL de leitura).
-- ---------------------------------------------------------------------
SELECT id,
       name,
       jsonb_pretty(custom_fields::jsonb -> 'cs_feeling')      AS cs_feeling_raw,
       jsonb_pretty(custom_fields::jsonb -> 'anotacoes_grupo') AS anotacoes_raw
FROM public.customer
WHERE custom_fields::jsonb ? 'cs_feeling'
LIMIT 5;


-- ---------------------------------------------------------------------
-- 0.6 A coluna id_legacy serve mesmo como chave de carga?
--     O step 123 usa keys = ["customer_id_legacy"]. Se houver id_legacy
--     nulo ou duplicado, a carga falha ou atualiza a conta errada.
-- ---------------------------------------------------------------------
SELECT count(*)                                                          AS total_contas,
       count(*) FILTER (WHERE NULLIF(btrim(id_legacy::text), '') IS NULL) AS sem_id_legacy,
       count(DISTINCT id_legacy)                                          AS id_legacy_distintos
FROM public.customer;

-- id_legacy duplicado (se retornar linhas, a chave de carga e insegura)
SELECT id_legacy, count(*) AS qtd, string_agg(name, ' | ') AS contas
FROM public.customer
WHERE NULLIF(btrim(id_legacy::text), '') IS NOT NULL
GROUP BY id_legacy
HAVING count(*) > 1
ORDER BY qtd DESC;


-- ---------------------------------------------------------------------
-- 0.7 Existe coluna de atualizacao para desempate/delta?
-- ---------------------------------------------------------------------
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'customer'
  AND column_name IN ('updated_at', 'created_at', 'modified_at', 'date_update');
