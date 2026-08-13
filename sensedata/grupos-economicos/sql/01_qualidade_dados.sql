-- =====================================================================
-- 01 - QUALIDADE DE DADOS DOS GRUPOS ECONOMICOS
-- Ambiente: SENSEDATA_HOM (connection_id = 6)
-- Objetivo: provar, com numero, os riscos que a query atual tem hoje.
--           Rodar antes e depois de subir a correcao.
-- Somente leitura.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1.1 RISCO CRITICO: grupo com MAIS DE UMA conta matriz
--     A query atual faz INNER JOIN sem garantia de unicidade. Com 2
--     matrizes no mesmo grupo, cada loja filha aparece DUPLICADA no
--     resultado e o valor gravado vira loteria (o ultimo que chegar).
-- ---------------------------------------------------------------------
SELECT company,
       btrim("group")                     AS grupo,
       count(*)                           AS qtd_matrizes,
       string_agg(name || ' (id ' || id || ')', ' | ' ORDER BY id) AS matrizes
FROM public.customer
WHERE "group" IS NOT NULL
  AND btrim("group") <> ''
  AND NULLIF(btrim(cnpj), '') IS NULL
GROUP BY company, btrim("group")
HAVING count(*) > 1
ORDER BY qtd_matrizes DESC;


-- ---------------------------------------------------------------------
-- 1.2 Grupos ORFAOS: lojas com grupo preenchido e sem conta matriz
--     Essas lojas nunca recebem propagacao (INNER JOIN as descarta em
--     silencio). E o cliente nao percebe que faltou.
-- ---------------------------------------------------------------------
SELECT f.company,
       btrim(f."group")     AS grupo,
       count(*)             AS lojas_sem_matriz,
       string_agg(f.name, ' | ' ORDER BY f.name) AS exemplos
FROM public.customer f
WHERE NULLIF(btrim(f.cnpj), '') IS NOT NULL
  AND f."group" IS NOT NULL
  AND btrim(f."group") <> ''
  AND NOT EXISTS (
        SELECT 1
        FROM public.customer m
        WHERE m.company = f.company
          AND upper(btrim(m."group")) = upper(btrim(f."group"))
          AND NULLIF(btrim(m.cnpj), '') IS NULL
  )
GROUP BY f.company, btrim(f."group")
ORDER BY lojas_sem_matriz DESC;


-- ---------------------------------------------------------------------
-- 1.3 Matriz sem filhos (conta fantasma inutil ou grafia divergente)
-- ---------------------------------------------------------------------
SELECT m.company,
       m.id   AS matriz_id,
       m.name AS matriz_nome,
       btrim(m."group") AS grupo
FROM public.customer m
WHERE NULLIF(btrim(m.cnpj), '') IS NULL
  AND m."group" IS NOT NULL
  AND btrim(m."group") <> ''
  AND NOT EXISTS (
        SELECT 1
        FROM public.customer f
        WHERE f.company = m.company
          AND upper(btrim(f."group")) = upper(btrim(m."group"))
          AND NULLIF(btrim(f.cnpj), '') IS NOT NULL
  )
ORDER BY m.company, grupo;


-- ---------------------------------------------------------------------
-- 1.4 RISCO SILENCIOSO: grafia divergente do campo "group"
--     O JOIN atual e igualdade exata. "RM Farma", "RM FARMA " e
--     "rm farma" sao tres grupos diferentes para o Postgres.
-- ---------------------------------------------------------------------
SELECT company,
       upper(btrim("group"))                            AS grupo_normalizado,
       count(DISTINCT "group")                          AS variacoes_de_grafia,
       string_agg(DISTINCT '[' || "group" || ']', ' | ') AS grafias_encontradas
FROM public.customer
WHERE "group" IS NOT NULL
  AND btrim("group") <> ''
GROUP BY company, upper(btrim("group"))
HAVING count(DISTINCT "group") > 1
ORDER BY variacoes_de_grafia DESC;


-- ---------------------------------------------------------------------
-- 1.5 Contas sem a chave de carga (id_legacy) dentro de grupos
--     Se cair no resultado da integracao, a linha nao atualiza nada.
-- ---------------------------------------------------------------------
SELECT company,
       btrim("group") AS grupo,
       id,
       name,
       cnpj
FROM public.customer
WHERE NULLIF(btrim(cnpj), '') IS NOT NULL
  AND "group" IS NOT NULL
  AND btrim("group") <> ''
  AND NULLIF(btrim(id_legacy::text), '') IS NULL
ORDER BY grupo, name;


-- ---------------------------------------------------------------------
-- 1.6 Matrizes com o conteudo vazio
--     Hoje a query propaga NULL/vazio por cima do que a loja tinha.
--     Ou seja: matriz em branco APAGA a informacao das filhas.
-- ---------------------------------------------------------------------
SELECT m.company,
       m.id,
       m.name,
       btrim(m."group") AS grupo,
       COALESCE(m.custom_fields::jsonb -> 'cs_feeling'      ->> 'value', '(vazio)') AS cs_feeling,
       COALESCE(m.custom_fields::jsonb -> 'anotacoes_grupo' ->> 'value', '(vazio)') AS anotacoes
FROM public.customer m
WHERE NULLIF(btrim(m.cnpj), '') IS NULL
  AND m."group" IS NOT NULL
  AND btrim(m."group") <> ''
  AND (NULLIF(btrim(COALESCE(m.custom_fields::jsonb -> 'cs_feeling'      ->> 'value', '')), '') IS NULL
    OR NULLIF(btrim(COALESCE(m.custom_fields::jsonb -> 'anotacoes_grupo' ->> 'value', '')), '') IS NULL)
ORDER BY grupo;
