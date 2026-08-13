-- =====================================================================
-- 15 - QUERY v1.5  |  HIBRIDA  (versao recomendada)
-- Integracao: Grupos_Economicos (id 20) > step 122 (data_source)
--
-- POR QUE ESTA VERSAO:
--   A v1 entrega o pedido central do ticket, mas deixa dois buracos:
--   nao diz de onde veio o dado e nunca limpa informacao orfa.
--   A v2 resolve os dois, mas escreve em um campo novo
--   (cs_feeling_grupo), o que deixaria o cs_feeling individual de cada
--   loja vazio -- e as regras de ciclo e alerta de CS Feeling definidas
--   na ata de 23/07 observam justamente o cs_feeling. Todas as lojas do
--   grupo apareceriam como vencidas ate alguem reconfigurar as regras.
--
--   Esta versao propaga NO PROPRIO cs_feeling (ciclos e alertas seguem
--   funcionando sem mexer em nada) e adiciona dois campos de rastreio.
--
-- CAMPOS GRAVADOS NA LOJA:
--   cs_feeling           (ja existe)  valor registrado na matriz
--   anotacoes_grupo      (ja existe)  anotacoes registradas na matriz
--   conta_matriz_nome    (NOVO)       qual matriz originou o dado
--   grupo_atualizado_em  (NOVO)       quando a matriz foi atualizada
--
-- A LIMPEZA SEGURA:
--   conta_matriz_nome preenchido = este valor foi escrito por esta
--   integracao. E isso que autoriza a limpeza: quando a loja deixa de
--   ser elegivel (cancelada, saiu do grupo, matriz esvaziada ou
--   removida), os quatro campos sao zerados -- mas SO se tiverem sido
--   nossos. Avaliacao que o consultor fez na mao nunca e tocada.
--
-- MODELAGEM CONFIRMADA EM 13/08/2026:
--   custom_fields jsonb | id_legacy varchar | updated_at timestamp s/ fuso
--   status INTEGER (por isso o filtro de ativa usa dt_cancel)
-- =====================================================================

WITH matriz AS (
    SELECT DISTINCT ON (m.company, upper(btrim(m."group")))
           m.company,
           upper(btrim(m."group"))                                          AS group_key,
           m.id                                                             AS matriz_id,
           m.name                                                           AS matriz_name,
           COALESCE(m.custom_fields -> 'cs_feeling'      ->> 'value', '')   AS cs_feeling_matriz,
           COALESCE(m.custom_fields -> 'anotacoes_grupo' ->> 'value', '')   AS anotacoes_matriz,
           m.updated_at                                                     AS matriz_updated_at
    FROM public.customer m
    WHERE m."group" IS NOT NULL
      AND btrim(m."group") <> ''
      -- Conta Matriz: flag explicita e o caminho correto; ausencia de
      -- CNPJ fica como fallback ate a migracao do campo tipo_conta.
      AND (
            lower(m.custom_fields -> 'tipo_conta' ->> 'value') IN ('matriz', 'conta matriz')
         OR NULLIF(btrim(m.cnpj), '') IS NULL
      )
      -- Matriz totalmente vazia nao propaga. Se o consultor esvaziar a
      -- matriz de proposito, o grupo cai para "nao elegivel" e a limpeza
      -- abaixo desfaz a propagacao anterior -- que e o comportamento
      -- esperado de uma fonte da verdade.
      AND (
            NULLIF(btrim(COALESCE(m.custom_fields -> 'cs_feeling'      ->> 'value', '')), '') IS NOT NULL
         OR NULLIF(btrim(COALESCE(m.custom_fields -> 'anotacoes_grupo' ->> 'value', '')), '') IS NOT NULL
      )
    -- Desempate deterministico caso o grupo tenha mais de uma matriz.
    ORDER BY m.company,
             upper(btrim(m."group")),
             m.updated_at DESC NULLS LAST,
             m.id DESC
),
base AS (
    SELECT f.id                                                                 AS customer_id,
           f.id_legacy                                                          AS customer_id_legacy,
           f.name                                                               AS customer_name,
           f.cnpj                                                               AS customer_cnpj,
           f."group"                                                            AS customer_group,
           COALESCE(f.custom_fields -> 'cs_feeling'      ->> 'value', '')       AS cs_feeling_atual,
           COALESCE(f.custom_fields -> 'anotacoes_grupo' ->> 'value', '')       AS anotacoes_atual,
           -- A ESCRITA usa o label do campo; a LEITURA usa a chave interna,
           -- que o SenseData deriva do label na criacao. O campo foi criado
           -- como "Conta Matriz", entao a chave pode ser conta_matriz em vez
           -- de conta_matriz_nome. Aceitamos as duas grafias para nao depender
           -- disso: se a chave errada fosse lida, escrito_por_nos ficaria
           -- sempre falso, a limpeza nunca aconteceria e o filtro de delta
           -- dispararia em toda execucao -- tudo isso em silencio.
           COALESCE(f.custom_fields -> 'conta_matriz_nome'   ->> 'value',
                    f.custom_fields -> 'conta_matriz'        ->> 'value', '')   AS matriz_nome_atual,
           COALESCE(f.custom_fields -> 'grupo_atualizado_em' ->> 'value',
                    f.custom_fields -> 'grupo_atualizado'    ->> 'value', '')   AS atualizado_em_atual,
           m.matriz_id,
           m.matriz_name,
           m.cs_feeling_matriz,
           m.anotacoes_matriz,
           m.matriz_updated_at,
           -- Loja ativa: status e INTEGER nesta base e o codigo de ativo
           -- ainda nao esta confirmado, entao usamos dt_cancel, que e um
           -- criterio real e verificavel hoje. Depois do bloco G do
           -- 05_checklist_retorno.sql da para somar:
           --   AND f.status = <codigo de ativo>
           (m.matriz_id IS NOT NULL AND f.dt_cancel IS NULL)                    AS elegivel
    FROM public.customer f
    LEFT JOIN matriz m
           ON m.company   = f.company
          AND m.group_key = upper(btrim(f."group"))
    WHERE NULLIF(btrim(f.cnpj), '') IS NOT NULL
      AND NULLIF(btrim(f.id_legacy), '') IS NOT NULL
),
alvo AS (
    SELECT b.customer_id,
           b.customer_id_legacy,
           b.customer_name,
           b.customer_cnpj,
           b.customer_group,
           b.cs_feeling_atual,
           b.anotacoes_atual,
           b.matriz_nome_atual,
           b.atualizado_em_atual,
           b.elegivel,

           -- A marca de autoria: se conta_matriz_nome esta preenchido,
           -- o conteudo atual da loja veio desta integracao.
           (NULLIF(btrim(b.matriz_nome_atual), '') IS NOT NULL)               AS escrito_por_nos,

           CASE WHEN b.elegivel THEN b.cs_feeling_matriz ELSE '' END          AS cs_feeling_novo,
           CASE WHEN b.elegivel THEN b.anotacoes_matriz  ELSE '' END          AS anotacoes_novo,
           CASE WHEN b.elegivel THEN b.matriz_name       ELSE '' END          AS matriz_nome_novo,

           -- updated_at e timestamp sem fuso. Assumindo que o SenseData
           -- grava em UTC, interpretamos como UTC e convertemos para
           -- Sao Paulo. Se o bloco H do 05 mostrar que o banco ja esta
           -- em horario de Brasilia, remover o AT TIME ZONE 'UTC'.
           CASE WHEN b.elegivel
                THEN COALESCE(to_char((b.matriz_updated_at AT TIME ZONE 'UTC')
                                           AT TIME ZONE 'America/Sao_Paulo',
                                      'DD/MM/YYYY HH24:MI'), '')
                ELSE '' END                                                    AS atualizado_em_novo
    FROM base b
)
SELECT customer_id,
       customer_id_legacy,
       customer_name,
       customer_cnpj,
       customer_group,
       cs_feeling_novo     AS cs_feeling,
       anotacoes_novo      AS anotacoes_grupo,
       matriz_nome_novo    AS conta_matriz_nome,
       atualizado_em_novo  AS grupo_atualizado_em
FROM alvo
-- Duas travas antes do delta:
--   elegivel        -> propaga
--   escrito_por_nos -> autoriza limpar o que ficou orfao
-- Conta que a integracao nunca tocou e nao e elegivel jamais entra aqui.
WHERE (elegivel OR escrito_por_nos)
  AND (   cs_feeling_atual    IS DISTINCT FROM cs_feeling_novo
       OR anotacoes_atual     IS DISTINCT FROM anotacoes_novo
       OR matriz_nome_atual   IS DISTINCT FROM matriz_nome_novo
       OR atualizado_em_atual IS DISTINCT FROM atualizado_em_novo);
