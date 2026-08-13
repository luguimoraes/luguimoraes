-- =====================================================================
-- 04 - EXPORT PARA VALIDACAO
-- Ambiente: SENSEDATA_HOM (connection_id = 6)
-- Substitui o "Exportar tabela" da interface. Rode no cliente SQL e
-- exporte o resultado em CSV por la.
-- Somente leitura.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 4.1 Foto das contas que participam de grupo economico
--
-- Bem menor que a lista completa (2.396 contas) e traz o que a tela nao
-- mostra: os campos customizados. E este o arquivo util para validar a
-- integracao antes e depois de executar.
--
-- A matriz aparece primeiro dentro de cada grupo.
-- ---------------------------------------------------------------------
SELECT c.id,
       c.id_legacy                                            AS id_original,
       c.name                                                 AS cliente,
       c.cnpj,
       c."group"                                              AS grupo,
       CASE WHEN NULLIF(btrim(c.cnpj), '') IS NULL
            THEN 'MATRIZ' ELSE 'loja' END                     AS papel,
       c.status,
       c.dt_cancel,
       c.custom_fields -> 'cs_feeling'          ->> 'value'    AS cs_feeling,
       c.custom_fields -> 'anotacoes_grupo'     ->> 'value'    AS anotacoes_grupo,
       -- as duas grafias possiveis do campo de rastreio
       COALESCE(c.custom_fields -> 'conta_matriz_nome'   ->> 'value',
                c.custom_fields -> 'conta_matriz'        ->> 'value')  AS conta_matriz_nome,
       COALESCE(c.custom_fields -> 'grupo_atualizado_em' ->> 'value',
                c.custom_fields -> 'grupo_atualizado'    ->> 'value')  AS grupo_atualizado_em,
       c.updated_at
FROM public.customer c
WHERE NULLIF(btrim(c."group"), '') IS NOT NULL
ORDER BY upper(btrim(c."group")),
         (NULLIF(btrim(c.cnpj), '') IS NOT NULL),   -- matriz primeiro
         c.name;


-- ---------------------------------------------------------------------
-- 4.2 Decodificar o status (aproveitando o que a tela ja mostra)
--
-- A interface exibe ATIVO / INATIVO, mas a coluna no banco e INTEGER.
-- Rode isto e compare a coluna exemplo_de_conta com o que a tela mostra
-- para aquela conta: e o suficiente para descobrir qual numero e ativo.
-- ---------------------------------------------------------------------
SELECT status,
       count(*)                                                AS contas,
       count(*) FILTER (WHERE dt_cancel IS NOT NULL)           AS com_dt_cancel,
       count(*) FILTER (WHERE NULLIF(btrim(cnpj), '') IS NULL) AS sem_cnpj,
       min(name)                                               AS exemplo_de_conta
FROM public.customer
GROUP BY status
ORDER BY contas DESC;


-- ---------------------------------------------------------------------
-- 4.3 Atalho: decodificar pelo par de contas visiveis na tela
--
-- Na listagem, DROGARIA POPULAR (001605050001) aparece como ATIVO e
-- DROGARIA SAO JOSE (002681760001) como INATIVO. Comparar as duas
-- resolve o mapeamento de uma vez.
-- Se os IDs nao baterem, troque pelos que estiverem na sua tela.
-- ---------------------------------------------------------------------
SELECT id_legacy   AS id_original,
       name        AS cliente,
       status,
       dt_cancel,
       cancel_tag
FROM public.customer
WHERE id_legacy IN ('001605050001', '002681760001')
ORDER BY id_legacy;
