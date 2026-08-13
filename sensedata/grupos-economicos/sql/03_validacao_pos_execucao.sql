-- =====================================================================
-- 03 - ESCOLHA DO PILOTO E VALIDACAO PoS-EXECUCAO
-- Ambiente: SENSEDATA_HOM (connection_id = 6)
-- Somente leitura.
--
-- Query A: rodar ANTES, para escolher o grupo de teste.
-- Query B: rodar DEPOIS de executar a integracao, para conferir o
--          resultado matriz x filhas em uma tela so.
-- =====================================================================


-- ---------------------------------------------------------------------
-- A. Qual grupo usar como piloto
--
-- O melhor piloto e um grupo que tenha matriz, loja ativa E loja
-- cancelada ao mesmo tempo: so assim da para provar, na mesma execucao,
-- que a propagacao funciona e que o filtro de loja ativa segura o que
-- tem que segurar.
--
-- Se nao voltar nenhuma linha, remova a linha do HAVING: significa que
-- nenhum grupo tem loja cancelada, e ai qualquer grupo serve para testar
-- a propagacao (mas o filtro de ativas fica sem prova).
-- ---------------------------------------------------------------------
SELECT m.company,
       btrim(m."group")                                       AS grupo,
       m.name                                                 AS conta_matriz,
       m.id                                                   AS matriz_id,
       count(f.id)                                            AS lojas_no_grupo,
       count(f.id) FILTER (WHERE f.dt_cancel IS NULL)         AS lojas_ativas,
       count(f.id) FILTER (WHERE f.dt_cancel IS NOT NULL)     AS lojas_canceladas,
       CASE WHEN NULLIF(btrim(m.custom_fields::jsonb -> 'cs_feeling' ->> 'value'), '') IS NULL
            THEN 'matriz SEM cs_feeling preenchido'
            ELSE 'matriz preenchida' END                      AS estado_da_matriz
FROM public.customer m
JOIN public.customer f
      ON f.company = m.company
     AND upper(btrim(f."group")) = upper(btrim(m."group"))
     AND NULLIF(btrim(f.cnpj), '') IS NOT NULL
WHERE NULLIF(btrim(m.cnpj), '') IS NULL
  AND NULLIF(btrim(m."group"), '') IS NOT NULL
GROUP BY m.company, btrim(m."group"), m.name, m.id, m.custom_fields
HAVING count(f.id) FILTER (WHERE f.dt_cancel IS NOT NULL) > 0
ORDER BY lojas_canceladas DESC, lojas_no_grupo DESC;


-- ---------------------------------------------------------------------
-- B. Conferencia do grupo piloto, matriz e filhas lado a lado
--
-- >>> TROCAR os dois valores abaixo pelo company e pelo grupo que a
--     query A devolveu.
--
-- Como ler o resultado:
--   - a linha  >> MATRIZ  e a fonte da verdade
--   - toda loja ATIVA deve ter cs_feeling_grupo igual ao da matriz
--   - toda loja CANCELADA deve ter cs_feeling_grupo vazio
--   - veio_da_matriz mostra a rastreabilidade que resolve a passagem
--     de bastao
--   - cs_feeling_proprio e o campo individual da loja: na v2 ele
--     NAO pode ter sido tocado pela integracao
-- ---------------------------------------------------------------------
SELECT CASE WHEN NULLIF(btrim(c.cnpj), '') IS NULL THEN '>> MATRIZ' ELSE '   loja' END AS papel,
       c.name                                                       AS conta,
       c.cnpj,
       CASE WHEN c.dt_cancel IS NULL
            THEN 'ativa'
            ELSE 'CANCELADA em ' || c.dt_cancel::text END           AS situacao,
       c.custom_fields::jsonb -> 'cs_feeling'          ->> 'value'   AS cs_feeling_proprio,
       c.custom_fields::jsonb -> 'cs_feeling_grupo'    ->> 'value'   AS cs_feeling_grupo,
       c.custom_fields::jsonb -> 'conta_matriz_nome'   ->> 'value'   AS veio_da_matriz,
       c.custom_fields::jsonb -> 'grupo_atualizado_em' ->> 'value'   AS atualizado_em,
       left(COALESCE(c.custom_fields::jsonb -> 'anotacoes_grupo' ->> 'value', ''), 80) AS anotacoes_grupo,
       c.updated_at
FROM public.customer c
WHERE c.company = 1                                    -- <<< TROCAR
  AND upper(btrim(c."group")) = upper(btrim('RM FARMA'))  -- <<< TROCAR
ORDER BY papel, c.name;
