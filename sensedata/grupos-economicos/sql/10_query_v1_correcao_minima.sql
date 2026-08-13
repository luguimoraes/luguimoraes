-- =====================================================================
-- 10 - QUERY v1  |  CORRECAO MINIMA (drop-in)
-- Integracao: Grupos_Economicos (id 20) > step 122 (data_source)
-- Mantem exatamente o mesmo mapeamento de carga do step 123.
-- Substitui a query atual sem exigir nenhum campo novo no SenseData.
--
-- O QUE MUDA EM RELACAO A QUERY ATUAL:
--   1. Filtro de lojas ativas                          (pedido de 30/07)
--   2. DISTINCT ON -> elimina duplicacao quando o grupo tem 2 matrizes
--   3. Normalizacao do "group" (btrim/upper) no JOIN
--   4. Matriz identificada por flag explicita, com fallback para "sem CNPJ"
--   5. Filtro anti-churn: so devolve linhas que REALMENTE mudaram
--   6. Nao propaga matriz vazia por cima de conteudo preenchido
--
-- >>> ATENCAO: a linha marcada com [AJUSTAR] depende do resultado de
--     00_descoberta_modelagem.sql. Nao publique sem confirmar.
-- =====================================================================

WITH matriz AS (
    SELECT DISTINCT ON (m.company, upper(btrim(m."group")))
           m.company,
           upper(btrim(m."group"))                                  AS group_key,
           m.id                                                     AS matriz_id,
           m.name                                                   AS matriz_name,
           m.custom_fields::jsonb -> 'cs_feeling'      ->> 'value'  AS cs_feeling_matriz,
           m.custom_fields::jsonb -> 'anotacoes_grupo' ->> 'value'  AS anotacoes_matriz
    FROM public.customer m
    WHERE m."group" IS NOT NULL
      AND btrim(m."group") <> ''
      -- Conta Matriz: flag explicita e o caminho correto; a ausencia de
      -- CNPJ fica como fallback ate a migracao do campo tipo_conta.
      AND (
            lower(m.custom_fields::jsonb -> 'tipo_conta' ->> 'value') IN ('matriz', 'conta matriz')
         OR NULLIF(btrim(m.cnpj), '') IS NULL
      )
      -- Matriz em branco nao deve apagar o que a loja ja tem.
      AND (
            NULLIF(btrim(COALESCE(m.custom_fields::jsonb -> 'cs_feeling'      ->> 'value', '')), '') IS NOT NULL
         OR NULLIF(btrim(COALESCE(m.custom_fields::jsonb -> 'anotacoes_grupo' ->> 'value', '')), '') IS NOT NULL
      )
    -- Desempate deterministico caso exista mais de uma matriz no grupo:
    -- vence a atualizada mais recentemente. Se a coluna updated_at nao
    -- existir, troque por  m.id DESC  apenas.
    ORDER BY m.company,
             upper(btrim(m."group")),
             m.updated_at DESC NULLS LAST,
             m.id DESC
)
SELECT
    filho.id                    AS customer_id,
    filho.id_legacy             AS customer_id_legacy,
    filho.name                  AS customer_name,
    filho.cnpj                  AS customer_cnpj,
    filho."group"               AS customer_group,
    matriz.cs_feeling_matriz    AS cs_feeling,
    matriz.anotacoes_matriz     AS anotacoes_grupo
FROM public.customer filho
INNER JOIN matriz
        ON matriz.company   = filho.company
       AND matriz.group_key = upper(btrim(filho."group"))
WHERE NULLIF(btrim(filho.cnpj), '') IS NOT NULL          -- e loja (tem CNPJ)
  AND NULLIF(btrim(filho.id_legacy::text), '') IS NOT NULL -- tem chave de carga
  -- CRITERIO DE LOJA ATIVA
  -- O status desta base e INTEGER, nao texto: o  status = 'active'  do
  -- documento nao roda, da "invalid input syntax for type integer".
  -- Enquanto o codigo numerico de ativo nao esta confirmado, usamos
  -- dt_cancel, que e um criterio real e disponivel: loja cancelada tem
  -- data de cancelamento preenchida.
  -- Depois do bloco G do 05_checklist_retorno.sql, trocar por (ou somar
  -- com):  AND filho.status = <codigo de ativo>
  AND filho.dt_cancel IS NULL
  -- Anti-churn: sem isso, toda execucao reescreve TODAS as lojas do
  -- grupo, poluindo historico/timeline e podendo disparar regras de
  -- alerta de CS Feeling sem nenhuma mudanca real ter acontecido.
  AND (
        filho.custom_fields::jsonb -> 'cs_feeling'      ->> 'value' IS DISTINCT FROM matriz.cs_feeling_matriz
     OR filho.custom_fields::jsonb -> 'anotacoes_grupo' ->> 'value' IS DISTINCT FROM matriz.anotacoes_matriz
  );
