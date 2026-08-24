-- ============================================================================
-- Contatos TR — reativação via manutenção CSV, com banco SOMENTE LEITURA
-- ============================================================================
-- Premissa: não há permissão para CREATE TABLE / COPY / \copy no banco.
-- Só `SELECT`. Então o cruzamento entre o export do dia 10 e a base atual
-- acontece FORA do banco, e o banco serve para consultar e conferir.
--
-- FLUXO
--   1. puxar o estado atual da base (query 1) e salvar como CSV
--   2. cruzar com o export do dia 10 fora do banco (Excel ou script — seção 4)
--   3. subir o CSV resultante na manutenção do SenseData
--   4. conferir o resultado no banco (seção 5)
--
-- A reativação é feita pela manutenção do produto, que não depende de escrita
-- direta no banco. O que está bloqueado é só o import de staging.
--
-- PRÉ-REQUISITO: pausar `Pré-processing_Inativa_Contatos` (2012) e
-- `Contatos_S3_V4` (2036) antes de subir o arquivo. A carga rodou em
-- 13, 14, 20, 21 e 24/08 — se rodar depois da manutenção, desfaz tudo.
-- ============================================================================


-- ============================================================================
-- 1. ESTADO ATUAL — a única consulta que você precisa exportar
-- ============================================================================
-- Salve o resultado como CSV. É o lado "hoje" do cruzamento.
-- `id_contato` é a chave de cruzamento com o export do dia 10.

SELECT cc.id                                          AS id_contato,
       cli.id_legacy                                  AS conta,
       cli.name                                       AS cliente,
       cc.name                                        AS nome,
       lower(trim(cc.email))                          AS email,
       cc.is_active                                   AS ativo_hoje,
       cc.id_legacy                                   AS chave_gravada,
       cc.created_at,
       cc.updated_at,
       cc.email_unsubscribe                           AS optout,
       cc.custom_fields->'origem'->>'value'           AS origem,
       cc.custom_fields->'produto_contact'->>'value'  AS produto,
       nullif(cc.custom_fields->'data_benchmark'->>'value','') AS data_benchmark,
       (SELECT string_agg(v.val, '; ')
          FROM jsonb_array_elements_text(
                 CASE jsonb_typeof(cc.custom_fields #> '{benchmarking,value}')
                   WHEN 'array'  THEN cc.custom_fields #> '{benchmarking,value}'
                   WHEN 'string' THEN jsonb_build_array(cc.custom_fields #> '{benchmarking,value}')
                   ELSE '[]'::jsonb END) AS v(val)
         WHERE v.val <> '' AND v.val <> 'N/A')        AS benchmarking
FROM public.customer_contact cc
JOIN public.customer cli ON cli.id = cc.id_customer
ORDER BY cli.id_legacy, cc.name, cc.id;

-- Se o cliente SQL travar com ~35 mil linhas, filtre por origem:
--   WHERE cc.custom_fields->'origem'->>'value' = 'Integração Sistema'
-- Só essa origem foi atingida — Zendesk e GSI têm zero inativos.


-- ============================================================================
-- 2. CRUZAMENTO DENTRO DO BANCO, SEM CRIAR TABELA
-- ============================================================================
-- Dá para cruzar sem staging colando os IDs do dia 10 num VALUES.
-- Funciona bem até uns poucos milhares de linhas; acima disso o SQL fica
-- gigante e a seção 4 (fora do banco) é mais prática.
--
-- Monte a lista a partir da coluna `ID Contato` do export do dia 10, filtrando
-- só os que estavam ATIVOS. No Excel, numa coluna auxiliar:
--     ="("&A2&"),"
-- e cole o resultado no lugar dos exemplos abaixo.

WITH dez (id) AS (
  VALUES (188555), (188556), (201963), (201964)   -- ← cole aqui os IDs ativos em 10/08
)
SELECT CASE
         WHEN cc.id IS NULL THEN 'SUMIU DA BASE'
         WHEN cc.is_active  THEN 'continua ativo'
         ELSE 'DESATIVADO depois do dia 10'
       END      AS resultado,
       count(*) AS contatos
FROM dez
LEFT JOIN public.customer_contact cc ON cc.id = dez.id
GROUP BY 1
ORDER BY 2 DESC;

-- 2.1 · A lista nominal — é esta que vira o arquivo da manutenção
WITH dez (id) AS (
  VALUES (188555), (188556), (201963), (201964)   -- ← mesma lista
)
SELECT cc.id     AS "ID Contato",
       'True'    AS "Ativo",
       cli.id_legacy AS conta,
       cc.name   AS nome,
       cc.email,
       cc.email_unsubscribe AS optout
FROM dez
JOIN public.customer_contact cc ON cc.id = dez.id
JOIN public.customer cli        ON cli.id = cc.id_customer
WHERE NOT cc.is_active
ORDER BY cli.id_legacy, cc.name;
-- Exporte, apague as colunas de conferência e suba só "ID Contato" e "Ativo".


-- ============================================================================
-- 3. O QUE DÁ PARA RESPONDER SÓ COM O BANCO, SEM O EXPORT DO DIA 10
-- ============================================================================

-- 3.1 · Quem está inativo hoje, por conta (a lista que o cliente pediu)
SELECT cli.id_legacy                                  AS conta,
       cli.name                                       AS cliente,
       count(*) FILTER (WHERE cc.is_active)           AS ativos,
       count(*) FILTER (WHERE NOT cc.is_active)       AS inativos
FROM public.customer_contact cc
JOIN public.customer cli ON cli.id = cc.id_customer
WHERE cc.custom_fields->'origem'->>'value' = 'Integração Sistema'
GROUP BY 1, 2
HAVING count(*) FILTER (WHERE NOT cc.is_active) > 0
ORDER BY inativos DESC;

-- 3.2 · As marcações de Benchmarking e onde elas estão
SELECT cc.is_active AS ativo,
       count(*)     AS marcacoes
FROM public.customer_contact cc
WHERE (SELECT count(*) FROM jsonb_array_elements_text(
         CASE jsonb_typeof(cc.custom_fields #> '{benchmarking,value}')
           WHEN 'array' THEN cc.custom_fields #> '{benchmarking,value}'
           ELSE '[]'::jsonb END) AS v(val)
        WHERE v.val <> '' AND v.val <> 'N/A') > 0
GROUP BY 1;
-- Em 24/08: 7 ativas · 448 inativas.

-- 3.3 · Ondas de alteração (mostra se a carga rodou de novo)
SELECT date_trunc('hour', cc.updated_at) AS hora,
       count(*)                                   AS tocados,
       count(*) FILTER (WHERE NOT cc.is_active)   AS terminaram_inativos
FROM public.customer_contact cc
WHERE cc.custom_fields->'origem'->>'value' = 'Integração Sistema'
  AND cc.updated_at >= now() - interval '20 days'
GROUP BY 1
HAVING count(*) > 50
ORDER BY 1;
-- Rode antes e depois da manutenção. Se aparecer hora nova, a carga não foi
-- pausada e a reativação vai ser desfeita.


-- ============================================================================
-- 4. O CRUZAMENTO FORA DO BANCO — caminho recomendado
-- ============================================================================
-- Dois arquivos: o export do dia 10 e o resultado da query 1.
-- Chave de cruzamento: `ID Contato` (é o mesmo id nos dois).
--
-- NO EXCEL
--   1. abra os dois em abas da mesma planilha: `dia10` e `hoje`
--   2. na aba `dia10`, filtre Ativo = True
--   3. numa coluna nova, procure o status atual:
--        =PROCX([@[ID Contato]]; hoje!A:A; hoje!F:F; "SUMIU DA BASE")
--      (ajuste as colunas: A = ID Contato, F = ativo_hoje na query 1)
--   4. filtre essa coluna por FALSE → são os contatos a reativar
--   5. copie `ID Contato` para uma planilha nova, acrescente a coluna `Ativo`
--      preenchida com True, e salve como CSV
--
-- Versões antigas do Excel não têm PROCX; use
--   =PROCV([@[ID Contato]]; hoje!A:F; 6; FALSO)
--
-- CONFERÊNCIAS QUE NÃO PODEM SER PULADAS
--   · "SUMIU DA BASE" > 0 → registro não existe mais; reativação não recupera.
--     No cruzamento 13/08 x 24/08 foram 200 casos em 24 contas.
--   · opt-out: se o contato tinha descadastro, ele precisa continuar com
--     descadastro depois de reativado. Confira na coluna `optout`.
--   · Benchmarking: as 431 marcações estão em registros que já constavam
--     inativos em 13/08 — população diferente da que as ondas desativaram.
--     Filtre o `dia10` por Benchmarking preenchido e veja se estavam ativos:
--     é isso que decide se entram nesta carga ou viram frente separada.


-- ============================================================================
-- 5. DEPOIS DE SUBIR O ARQUIVO
-- ============================================================================

-- 5.1 · Sobrou alguém? Cole a mesma lista de IDs.
WITH dez (id) AS ( VALUES (188555), (188556) )
SELECT count(*) AS ainda_inativos
FROM dez JOIN public.customer_contact cc ON cc.id = dez.id
WHERE NOT cc.is_active;
-- Deve retornar 0.

-- 5.2 · Nenhum opt-out foi perdido
SELECT count(*) AS ativos_sem_optout_mas_com_historico
FROM public.customer_contact a
WHERE a.is_active AND NOT a.email_unsubscribe
  AND EXISTS (SELECT 1 FROM public.customer_contact i
               WHERE i.email_unsubscribe
                 AND lower(i.email) = lower(a.email)
                 AND i.id_customer  = a.id_customer);
-- Deve retornar 0. Retornava 0 em 24/08 — manter assim.

-- 5.3 · A contagem por conta subiu?  (rode 3.1 de novo e compare)

-- 5.4 · A carga não rodou por cima?  (rode 3.3 e confira se surgiu hora nova)
