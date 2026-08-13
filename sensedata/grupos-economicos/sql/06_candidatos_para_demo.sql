-- =====================================================================
-- 06 - CANDIDATOS REAIS PARA DEMONSTRACAO
-- Ambiente: SENSEDATA_HOM (connection_id = 6)
-- Somente leitura.
--
-- Objetivo: sair do grupo de teste e mostrar o problema com a base real.
--   6.1  ranking dos grupos economicos e o estado de cada um
--   6.2  o numero do ganho operacional (para o slide de abertura)
--   6.3  detalhe loja a loja do grupo escolhido (a tela do "antes")
--   6.4  a evidencia da fragmentacao: mesmo grupo, CS Feeling diferente
-- =====================================================================


-- ---------------------------------------------------------------------
-- 6.1 Ranking de grupos candidatos
--
-- Colunas que importam na hora de escolher:
--   situacao              -> se ja da para propagar ou falta criar a matriz
--   bom_para_demo_filtro  -> tem loja ativa E cancelada, entao serve para
--                            provar o filtro pedido na ata de 30/07
--   cs_feelings_diferentes-> quantas avaliacoes distintas convivem hoje
--                            dentro do MESMO grupo. E a fragmentacao que
--                            a Giovanna descreveu no ticket
-- ---------------------------------------------------------------------
WITH filhas AS (
    SELECT c.company,
           upper(btrim(c."group"))                                             AS group_key,
           btrim(c."group")                                                    AS grupo,
           c.id,
           c.dt_cancel,
           NULLIF(btrim(c.custom_fields -> 'cs_feeling'      ->> 'value'), '') AS cs_feeling,
           NULLIF(btrim(c.custom_fields -> 'anotacoes_grupo' ->> 'value'), '') AS anotacoes
    FROM public.customer c
    WHERE NULLIF(btrim(c."group"), '') IS NOT NULL
      AND NULLIF(btrim(c.cnpj), '')    IS NOT NULL
      AND c."group" NOT ILIKE '%TESTE%'          -- fora as contas de teste
      AND c.cnpj    NOT LIKE '00.000.000%'       -- fora os CNPJs ficticios
),
matrizes AS (
    SELECT company,
           upper(btrim("group")) AS group_key,
           count(*)              AS qtd_matriz,
           min(name)             AS matriz_nome
    FROM public.customer
    WHERE NULLIF(btrim("group"), '') IS NOT NULL
      AND NULLIF(btrim(cnpj), '')    IS NULL
      AND "group" NOT ILIKE '%TESTE%'
    GROUP BY company, upper(btrim("group"))
)
SELECT min(f.grupo)                                             AS grupo,
       count(*)                                                 AS lojas,
       count(*) FILTER (WHERE f.dt_cancel IS NULL)              AS ativas,
       count(*) FILTER (WHERE f.dt_cancel IS NOT NULL)          AS canceladas,
       COALESCE(m.matriz_nome, '(sem matriz)')                  AS conta_matriz,
       count(f.cs_feeling)                                      AS lojas_com_cs_feeling,
       count(DISTINCT f.cs_feeling)                             AS cs_feelings_diferentes,
       count(f.anotacoes)                                       AS lojas_com_anotacao,
       CASE
           WHEN COALESCE(m.qtd_matriz, 0) = 0 THEN 'falta criar a Conta Matriz'
           WHEN m.qtd_matriz > 1              THEN 'ATENCAO: mais de uma matriz'
           ELSE                                    'pronto para propagar'
       END                                                      AS situacao,
       CASE
           WHEN count(*) FILTER (WHERE f.dt_cancel IS NOT NULL) > 0
            AND count(*) FILTER (WHERE f.dt_cancel IS NULL)     > 0
           THEN 'SIM' ELSE 'nao'
       END                                                      AS bom_para_demo_filtro
FROM filhas f
LEFT JOIN matrizes m
       ON m.company   = f.company
      AND m.group_key = f.group_key
GROUP BY f.company, f.group_key, m.qtd_matriz, m.matriz_nome
HAVING count(*) > 1                       -- grupo de verdade tem mais de uma loja
ORDER BY count(*) DESC
LIMIT 30;


-- ---------------------------------------------------------------------
-- 6.2 O numero do ganho operacional
--
-- Hoje o consultor repete o mesmo registro em cada loja ativa do grupo.
-- Depois, registra uma vez por grupo. A razao entre os dois e o slide
-- de abertura da apresentacao.
-- ---------------------------------------------------------------------
SELECT count(*)                                                AS registros_manuais_hoje,
       count(DISTINCT (company, upper(btrim("group"))))        AS registros_depois,
       round(
           count(*)::numeric
           / NULLIF(count(DISTINCT (company, upper(btrim("group")))), 0)
       , 1)                                                    AS vezes_menos_esforco
FROM public.customer
WHERE NULLIF(btrim("group"), '') IS NOT NULL
  AND NULLIF(btrim(cnpj), '')    IS NOT NULL
  AND dt_cancel IS NULL
  AND "group" NOT ILIKE '%TESTE%'
  AND cnpj    NOT LIKE '00.000.000%';


-- ---------------------------------------------------------------------
-- 6.3 Detalhe do grupo escolhido, loja a loja
--     >>> TROCAR o nome do grupo pelo que a 6.1 indicou.
--     Esta e a tela do "antes" e, depois de rodar, a do "depois".
-- ---------------------------------------------------------------------
SELECT CASE WHEN NULLIF(btrim(c.cnpj), '') IS NULL
            THEN '>> MATRIZ' ELSE '   loja' END                     AS papel,
       c.id,
       c.id_legacy,
       c.name                                                       AS conta,
       c.cnpj,
       CASE WHEN c.dt_cancel IS NULL
            THEN 'ativa' ELSE 'CANCELADA em ' || c.dt_cancel::text END AS situacao,
       c.custom_fields -> 'cs_feeling'           ->> 'value'         AS cs_feeling,
       c.custom_fields -> 'conta_matriz_nome'    ->> 'value'         AS veio_da_matriz,
       c.custom_fields -> 'grupo_atualizado_em_' ->> 'value'         AS atualizado_em,
       left(COALESCE(c.custom_fields -> 'anotacoes_grupo' ->> 'value', ''), 70) AS anotacoes,
       c.updated_at
FROM public.customer c
WHERE upper(btrim(c."group")) = upper(btrim('NOME DO GRUPO AQUI'))   -- <<< TROCAR
ORDER BY papel, c.name;


-- ---------------------------------------------------------------------
-- 6.4 A evidencia da fragmentacao
--
-- Grupos onde as lojas tem CS Feeling DIFERENTE entre si hoje. E a
-- prova visual da queixa do ticket: "o consultor perde muito tempo
-- procurando em qual CNPJ a informacao mais atualizada foi registrada".
-- Cada linha aqui e um grupo sem uma verdade unica.
-- ---------------------------------------------------------------------
SELECT btrim(c."group")                                                  AS grupo,
       count(*)                                                          AS lojas_avaliadas,
       count(DISTINCT c.custom_fields -> 'cs_feeling' ->> 'value')       AS avaliacoes_distintas,
       string_agg(DISTINCT c.custom_fields -> 'cs_feeling' ->> 'value', ' | ') AS quais,
       max(c.updated_at)                                                 AS ultima_atualizacao
FROM public.customer c
WHERE NULLIF(btrim(c."group"), '') IS NOT NULL
  AND NULLIF(btrim(c.cnpj), '')    IS NOT NULL
  AND c.dt_cancel IS NULL
  AND NULLIF(btrim(c.custom_fields -> 'cs_feeling' ->> 'value'), '') IS NOT NULL
  AND c."group" NOT ILIKE '%TESTE%'
GROUP BY c.company, btrim(c."group")
HAVING count(DISTINCT c.custom_fields -> 'cs_feeling' ->> 'value') > 1
ORDER BY avaliacoes_distintas DESC, lojas_avaliadas DESC;
