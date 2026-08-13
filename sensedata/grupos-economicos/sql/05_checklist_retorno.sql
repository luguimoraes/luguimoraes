-- =====================================================================
-- 05 - CHECKLIST DE RETORNO  (rode este, me mande o resultado)
-- Ambiente: SENSEDATA_HOM (connection_id = 6)
--
-- Consolidacao do 00_descoberta_modelagem.sql em UMA UNICA query, para
-- nao depender de saber antes o nome da coluna de status. Devolve um
-- unico resultado (bloco / chave / valor), facil de copiar e colar.
--
-- PRIVACIDADE: nao devolve nenhum conteudo de cliente. Só nome de
-- coluna, nome de campo e contagem. Anotacoes e CS Feeling nao saem
-- daqui — apenas a ESTRUTURA em que estao guardados.
--
-- Somente leitura. Nao altera nada.
-- =====================================================================

WITH cols AS (
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'customer'
),

-- Colunas que PODEM ser o filtro de "loja ativa". Nao precisamos saber
-- o nome antes: to_jsonb(linha) ->> 'coluna' devolve NULL em vez de
-- erro quando a coluna nao existe, entao da para sondar com seguranca.
status_cand AS (
    SELECT column_name
    FROM cols
    WHERE column_name ILIKE ANY (ARRAY['%status%', '%activ%', '%situa%',
                                       '%churn%', '%cancel%', '%delet%'])
),

bloco_a AS (
    SELECT 'A. colunas de customer' AS bloco,
           column_name              AS chave,
           data_type                AS valor
    FROM cols
),

-- Aqui esta a resposta que destrava a query: qual coluna e quais
-- valores representam uma loja ativa.
bloco_b AS (
    SELECT 'B. valores por coluna de status'                       AS bloco,
           sc.column_name                                          AS chave,
           COALESCE(to_jsonb(c) ->> sc.column_name, '(null)')
             || '  ->  ' || count(*)::text || ' contas'            AS valor
    FROM public.customer c
    CROSS JOIN status_cand sc
    GROUP BY sc.column_name,
             COALESCE(to_jsonb(c) ->> sc.column_name, '(null)')
),

bloco_c AS (
    SELECT 'C. chaves de custom_fields'      AS bloco,
           k                                 AS chave,
           count(*)::text || ' contas'       AS valor
    FROM public.customer c
    CROSS JOIN LATERAL jsonb_object_keys(c.custom_fields::jsonb) AS k
    WHERE c.custom_fields IS NOT NULL
    GROUP BY k
),

-- Confirma se o valor esta mesmo em ->>'value' ou em outra chave
-- (id/label/text), sem expor o conteudo.
bloco_d AS (
    SELECT DISTINCT
           'D. estrutura interna do campo' AS bloco,
           f.campo                         AS chave,
           k                               AS valor
    FROM public.customer c
    CROSS JOIN LATERAL (VALUES ('cs_feeling'), ('anotacoes_grupo'), ('tipo_conta')) AS f(campo)
    CROSS JOIN LATERAL jsonb_object_keys(c.custom_fields::jsonb -> f.campo) AS k
    WHERE c.custom_fields IS NOT NULL
      AND c.custom_fields::jsonb ? f.campo
      AND jsonb_typeof(c.custom_fields::jsonb -> f.campo) = 'object'
),

bloco_e AS (
    SELECT 'E. chave de carga (id_legacy)' AS bloco, x.chave, x.valor
    FROM (
        SELECT 'total de contas' AS chave, count(*)::text AS valor
        FROM public.customer
        UNION ALL
        SELECT 'sem id_legacy', count(*)::text
        FROM public.customer
        WHERE NULLIF(btrim(id_legacy::text), '') IS NULL
        UNION ALL
        SELECT 'id_legacy distintos', count(DISTINCT id_legacy)::text
        FROM public.customer
        UNION ALL
        SELECT 'id_legacy duplicados', count(*)::text
        FROM (
            SELECT id_legacy
            FROM public.customer
            WHERE NULLIF(btrim(id_legacy::text), '') IS NOT NULL
            GROUP BY id_legacy
            HAVING count(*) > 1
        ) d
    ) x
),

bloco_f AS (
    SELECT 'F. volumetria de grupos' AS bloco, x.chave, x.valor
    FROM (
        SELECT 'contas COM CNPJ (lojas)' AS chave, count(*)::text AS valor
        FROM public.customer
        WHERE NULLIF(btrim(cnpj), '') IS NOT NULL
        UNION ALL
        SELECT 'contas SEM CNPJ (candidatas a matriz)', count(*)::text
        FROM public.customer
        WHERE NULLIF(btrim(cnpj), '') IS NULL
        UNION ALL
        SELECT 'grupos distintos', count(DISTINCT upper(btrim("group")))::text
        FROM public.customer
        WHERE NULLIF(btrim("group"), '') IS NOT NULL
        UNION ALL
        -- Se este numero for > 0, tem duplicacao esperando para acontecer.
        SELECT 'grupos com MAIS DE UMA matriz', count(*)::text
        FROM (
            SELECT company, upper(btrim("group")) AS g
            FROM public.customer
            WHERE NULLIF(btrim("group"), '') IS NOT NULL
              AND NULLIF(btrim(cnpj), '') IS NULL
            GROUP BY company, upper(btrim("group"))
            HAVING count(*) > 1
        ) d
        UNION ALL
        -- Grafia divergente do mesmo grupo quebra o JOIN em silencio.
        SELECT 'grupos com grafia divergente', count(*)::text
        FROM (
            SELECT company, upper(btrim("group")) AS g
            FROM public.customer
            WHERE NULLIF(btrim("group"), '') IS NOT NULL
            GROUP BY company, upper(btrim("group"))
            HAVING count(DISTINCT "group") > 1
        ) d
    ) x
),

-- Bloco G: adicionado depois de confirmar que status e INTEGER nesta
-- base. Cruza cada codigo com dt_cancel / cancel_tag / stage para
-- descobrir qual numero significa "loja ativa" — o codigo sozinho nao
-- diz nada, a correlacao diz.
bloco_g AS (
    SELECT 'G. decodificar o status'                                    AS bloco,
           'status = ' || COALESCE(status::text, '(null)')              AS chave,
           count(*)::text || ' contas'
             || ' | com dt_cancel: '  || (count(*) FILTER (WHERE dt_cancel IS NOT NULL))::text
             || ' | com cancel_tag: ' || (count(*) FILTER (WHERE NULLIF(btrim(cancel_tag), '') IS NOT NULL))::text
             || ' | sem CNPJ: '       || (count(*) FILTER (WHERE NULLIF(btrim(cnpj), '') IS NULL))::text
             || ' | stages: '         || COALESCE(string_agg(DISTINCT stage, ','), '(nenhum)') AS valor
    FROM public.customer
    GROUP BY status
),

-- Bloco H: updated_at e "timestamp without time zone". Precisamos saber
-- se o valor guardado esta em UTC ou ja em horario de Brasilia, senao a
-- data exibida no campo grupo_atualizado_em sai 3 horas errada.
bloco_h AS (
    SELECT 'H. relogio do banco' AS bloco, x.chave, x.valor
    FROM (
        SELECT 'now() no banco' AS chave,
               to_char(now(), 'DD/MM/YYYY HH24:MI:SS TZ') AS valor
        UNION ALL
        SELECT 'TimeZone da sessao', current_setting('TimeZone')
        UNION ALL
        SELECT 'max(updated_at) em customer',
               COALESCE(to_char(max(updated_at), 'DD/MM/YYYY HH24:MI:SS'), '(vazio)')
        FROM public.customer
    ) x
)

SELECT bloco, chave, valor
FROM (
    SELECT * FROM bloco_a
    UNION ALL SELECT * FROM bloco_b
    UNION ALL SELECT * FROM bloco_c
    UNION ALL SELECT * FROM bloco_d
    UNION ALL SELECT * FROM bloco_e
    UNION ALL SELECT * FROM bloco_f
    UNION ALL SELECT * FROM bloco_g
    UNION ALL SELECT * FROM bloco_h
) t
ORDER BY bloco, chave, valor;
