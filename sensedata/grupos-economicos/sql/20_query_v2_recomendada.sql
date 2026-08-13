-- =====================================================================
-- 20 - QUERY v2  |  MODELO RECOMENDADO
-- Integracao: Grupos_Economicos (id 20) > step 122 (data_source)
--
-- DIFERENCA CONCEITUAL PARA A v1:
--   a) A informacao do grupo passa a viver em campos PROPRIOS
--      (cs_feeling_grupo, anotacoes_grupo, conta_matriz_nome,
--       grupo_atualizado_em) em vez de sobrescrever o campo individual
--      da loja. Resolve o "quem escreveu isso?" e preserva a analise
--      por CNPJ, que o proprio cliente quer manter ("permitindo
--      detalhar por CNPJ", ata de 25/06).
--   b) Faz LIMPEZA: loja que saiu do grupo, ficou inativa ou perdeu a
--      matriz recebe valor vazio. Sem isso a informacao antiga fica
--      congelada na conta para sempre (a integracao so toca no que
--      aparece no resultado).
--   c) Carrega rastreabilidade (nome da matriz + data), que e o que
--      resolve de fato a "passagem de bastao" citada no ticket.
--
-- PRE-REQUISITO: criar no SenseData os custom fields
--   cs_feeling_grupo | anotacoes_grupo | conta_matriz_nome | grupo_atualizado_em
--
-- MODELAGEM CONFIRMADA EM 13/08/2026:
--   custom_fields e jsonb        -> os casts ::jsonb sao no-op, ficam por seguranca
--   id_legacy e character varying-> o cast ::text e no-op
--   updated_at e timestamp WITHOUT time zone
--   status e INTEGER             -> ver [AJUSTAR] abaixo
-- =====================================================================

WITH matriz AS (
    SELECT DISTINCT ON (m.company, upper(btrim(m."group")))
           m.company,
           upper(btrim(m."group"))                                  AS group_key,
           m.id                                                     AS matriz_id,
           m.name                                                   AS matriz_name,
           m.custom_fields::jsonb -> 'cs_feeling'      ->> 'value'  AS cs_feeling_matriz,
           m.custom_fields::jsonb -> 'anotacoes_grupo' ->> 'value'  AS anotacoes_matriz,
           m.updated_at                                             AS matriz_updated_at
    FROM public.customer m
    WHERE m."group" IS NOT NULL
      AND btrim(m."group") <> ''
      -- Conta Matriz: flag explicita e o caminho correto; a ausencia de
      -- CNPJ fica como fallback ate a migracao do campo tipo_conta.
      AND (
            lower(m.custom_fields::jsonb -> 'tipo_conta' ->> 'value') IN ('matriz', 'conta matriz')
         OR NULLIF(btrim(m.cnpj), '') IS NULL
      )
    -- Desempate deterministico caso exista mais de uma matriz no grupo.
    ORDER BY m.company,
             upper(btrim(m."group")),
             m.updated_at DESC NULLS LAST,
             m.id DESC
),
base AS (
    SELECT f.id                          AS customer_id,
           f.id_legacy                   AS customer_id_legacy,
           f.name                        AS customer_name,
           f.cnpj                        AS customer_cnpj,
           f."group"                     AS customer_group,
           f.custom_fields               AS filho_custom_fields,
           m.matriz_id,
           m.matriz_name,
           m.cs_feeling_matriz,
           m.anotacoes_matriz,
           m.matriz_updated_at,
           -- CRITERIO DE LOJA ATIVA
           -- O status desta base e INTEGER, nao texto: o
           -- status = 'active' do documento nao roda, da "invalid input
           -- syntax for type integer". Enquanto o codigo numerico de
           -- ativo nao esta confirmado, usamos dt_cancel, que e um
           -- criterio real e disponivel: loja cancelada tem data de
           -- cancelamento preenchida.
           -- Depois do bloco G do 05_checklist_retorno.sql, trocar por
           -- (ou somar com):  AND f.status = <codigo de ativo>
           (m.matriz_id IS NOT NULL AND f.dt_cancel IS NULL) AS elegivel
    FROM public.customer f
    LEFT JOIN matriz m
           ON m.company   = f.company
          AND m.group_key = upper(btrim(f."group"))
    WHERE NULLIF(btrim(f.cnpj), '') IS NOT NULL
      AND NULLIF(btrim(f.id_legacy::text), '') IS NOT NULL
),
alvo AS (
    SELECT
        b.customer_id,
        b.customer_id_legacy,
        b.customer_name,
        b.customer_cnpj,
        b.customer_group,

        -- Nao elegivel recebe '' (limpeza), em vez de ficar com lixo velho.
        CASE WHEN b.elegivel THEN COALESCE(b.cs_feeling_matriz, '') ELSE '' END AS cs_feeling_grupo,
        CASE WHEN b.elegivel THEN COALESCE(b.anotacoes_matriz,  '') ELSE '' END AS anotacoes_grupo,
        CASE WHEN b.elegivel THEN COALESCE(b.matriz_name,       '') ELSE '' END AS conta_matriz_nome,

        -- updated_at e "timestamp without time zone". Se o SenseData
        -- grava em UTC (o padrao), a conversao correta para exibicao e
        -- interpretar como UTC e so entao converter para Sao Paulo.
        -- Confirmar com o bloco H do 05_checklist_retorno.sql: se o
        -- relogio do banco ja estiver em horario de Brasilia, remover o
        -- primeiro AT TIME ZONE 'UTC'.
        CASE WHEN b.elegivel
             THEN COALESCE(to_char((b.matriz_updated_at AT TIME ZONE 'UTC')
                                        AT TIME ZONE 'America/Sao_Paulo',
                                   'DD/MM/YYYY HH24:MI'), '')
             ELSE '' END                                                       AS grupo_atualizado_em,

        -- Valores atuais na loja, usados apenas para o filtro de delta
        COALESCE(b.filho_custom_fields::jsonb -> 'cs_feeling_grupo'  ->> 'value', '') AS cs_feeling_grupo_atual,
        COALESCE(b.filho_custom_fields::jsonb -> 'anotacoes_grupo'   ->> 'value', '') AS anotacoes_grupo_atual,
        COALESCE(b.filho_custom_fields::jsonb -> 'conta_matriz_nome' ->> 'value', '') AS conta_matriz_nome_atual
    FROM base b
)
SELECT customer_id,
       customer_id_legacy,
       customer_name,
       customer_cnpj,
       customer_group,
       cs_feeling_grupo,
       anotacoes_grupo,
       conta_matriz_nome,
       grupo_atualizado_em
FROM alvo
-- So trafega o que mudou de verdade (delta), inclusive as limpezas.
WHERE cs_feeling_grupo_atual  IS DISTINCT FROM cs_feeling_grupo
   OR anotacoes_grupo_atual   IS DISTINCT FROM anotacoes_grupo
   OR conta_matriz_nome_atual IS DISTINCT FROM conta_matriz_nome;
