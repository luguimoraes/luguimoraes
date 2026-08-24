-- ============================================================================
-- Contatos TR — do export do dia 10 até o CSV da manutenção (reativação)
-- ============================================================================
-- Fluxo completo, na ordem de execução:
--   1. criar a tabela de staging e importar o export do dia 10
--   2. conferir o import (não pule — define se o número é confiável)
--   3. ver O QUE MUDOU entre 10/08 e hoje
--   4. gerar o CSV da manutenção
--   5. validar depois da carga
--
-- PRÉ-REQUISITO: pausar `Pré-processing_Inativa_Contatos` (2012) e
-- `Contatos_S3_V4` (2036) ANTES do passo 4. Sem isso a próxima execução
-- desfaz a reativação — a carga rodou em 13, 14, 20, 21 e 24/08.
-- ============================================================================


-- ============================================================================
-- 1. STAGING — layout do export do SenseData (41 colunas, separador '|')
-- ============================================================================
-- Tudo como text de propósito: o import não pode falhar por causa de tipo.
-- A conversão acontece nas consultas.

DROP TABLE IF EXISTS stg_contatos_10ago;

CREATE TABLE stg_contatos_10ago (
  cliente                        text,
  nome                           text,
  grupo_economico                text,
  id_original                    text,   -- código da conta: '132626-TAX'
  id_contato                     text,   -- id do contato no SenseData
  apelido                        text,
  email                          text,
  cargo                          text,
  ativo                          text,   -- 'True' / 'False'
  tel                            text,
  tel2                           text,
  sponsor                        text,
  skype                          text,   -- atenção: carrega produto (CR-3)
  endereco                       text,
  email_unsubscribe              text,
  motivo_unsubscribe             text,
  sms_unsubscribe                text,
  sms_unsubscribe_2              text,
  ultima_atualizacao             text,
  data_insercao_sd               text,
  tipo_contato                   text,
  pais                           text,
  favorito                       text,
  status_cliente                 text,
  benchmarking                   text,
  blacklist                      text,
  pais_2                         text,
  brand                          text,
  produto                        text,
  data_benchmark                 text,
  data_resposta_nps              text,
  nota_ultimo_nps                text,
  sentimento_nps                 text,
  request_for_contact_nps        text,
  pesquisas                      text,
  avaliacao_nps                  text,
  solicitar_contato_nps_digital  text,
  origem                         text,
  nivel_do_cargo                 text,
  nota_ultimo_nps_digital        text,
  data_resp_nps_digital          text
);

-- Import no psql (\copy roda no cliente, não precisa de permissão de servidor):
--
--   \copy stg_contatos_10ago FROM 'export_sensedata_contatos_20260810.csv' \
--        WITH (FORMAT csv, HEADER true, DELIMITER '|', QUOTE '"', ENCODING 'UTF8')
--
-- Se der erro de contagem de colunas, o export tem layout diferente: confira o
-- cabeçalho e ajuste a ordem do CREATE TABLE. A ordem importa, o nome não.

CREATE INDEX ON stg_contatos_10ago ((id_contato::bigint)) WHERE id_contato ~ '^[0-9]+$';


-- ============================================================================
-- 2. CONFERIR O IMPORT — decide se o número é confiável
-- ============================================================================

SELECT count(*)                                                     AS linhas,
       count(*) FILTER (WHERE lower(ativo) IN ('true','t','1','sim')) AS ativos,
       count(DISTINCT id_original)                                  AS contas,
       count(*) FILTER (WHERE id_contato !~ '^[0-9]+$')             AS sem_id_valido,
       min(nullif(ultima_atualizacao,''))                           AS alteracao_mais_antiga,
       max(nullif(ultima_atualizacao,''))                           AS alteracao_mais_recente
FROM stg_contatos_10ago;

-- COMO LER `alteracao_mais_recente`:
--   anterior a 2026-08-13 22:43  → export PRÉ-primeira-onda. É a linha de base real.
--   posterior                    → já contaminado; mede a diferença entre ondas,
--                                  e o número subestima a perda.
--
-- E `ativos`: perto de 6.257 é o patamar PÓS-primeira-onda. Acima disso, é pré.

-- 2.1 · Quantos ativos por origem (só 'Integração Sistema' foi atingida)
SELECT coalesce(nullif(origem,''), tipo_contato)                    AS origem,
       count(*) FILTER (WHERE lower(ativo) IN ('true','t','1','sim')) AS ativos,
       count(*)                                                     AS total
FROM stg_contatos_10ago
GROUP BY 1
ORDER BY 3 DESC;
-- Em 24/08: Integração Sistema 2.052 ativos · Zendesk 5.576 · GSI_GTM 164 · GSI_LEGAL 81.
-- Zendesk e GSI têm ZERO inativos — o Filtro_Type do pré-processing os exclui.


-- ============================================================================
-- 3. O QUE MUDOU — de-para dia 10 x hoje
-- ============================================================================

-- 3.1 · Quadro geral: o que aconteceu com quem estava ativo no dia 10
WITH dez AS (
  SELECT id_contato::bigint AS id
  FROM stg_contatos_10ago
  WHERE id_contato ~ '^[0-9]+$'
    AND lower(ativo) IN ('true','t','1','sim')
)
SELECT CASE
         WHEN cc.id IS NULL THEN 'SUMIU DA BASE'
         WHEN cc.is_active  THEN 'continua ativo'
         ELSE 'DESATIVADO depois do dia 10'
       END        AS resultado,
       count(*)   AS contatos
FROM dez
LEFT JOIN public.customer_contact cc ON cc.id = dez.id
GROUP BY 1
ORDER BY 2 DESC;

-- 'SUMIU DA BASE' precisa ser investigado ANTES de reativar: não é desativação,
-- é ausência do registro. No cruzamento 13/08 x 24/08 apareceram 200 casos em
-- 24 contas. Reativação não recupera registro que não existe mais.

-- 3.2 · O mesmo quadro por conta — é a lista que o cliente pediu para validar
WITH dez AS (
  SELECT id_contato::bigint AS id, id_original AS conta, cliente
  FROM stg_contatos_10ago
  WHERE id_contato ~ '^[0-9]+$'
    AND lower(ativo) IN ('true','t','1','sim')
)
SELECT dez.conta,
       min(dez.cliente)                                        AS cliente,
       count(*)                                                AS ativos_em_10,
       count(*) FILTER (WHERE cc.is_active)                    AS ainda_ativos,
       count(*) FILTER (WHERE cc.id IS NOT NULL AND NOT cc.is_active) AS desativados,
       count(*) FILTER (WHERE cc.id IS NULL)                   AS sumiram
FROM dez
LEFT JOIN public.customer_contact cc ON cc.id = dez.id
GROUP BY dez.conta
HAVING count(*) FILTER (WHERE cc.is_active) < count(*)
ORDER BY desativados DESC, dez.conta;

-- 3.3 · O que mudou campo a campo (para os que continuam existindo)
--       Mostra se a carga também sobrescreveu dado além do status.
WITH dez AS (
  SELECT id_contato::bigint AS id, nome, email, benchmarking, data_benchmark,
         produto, skype, email_unsubscribe
  FROM stg_contatos_10ago
  WHERE id_contato ~ '^[0-9]+$'
)
SELECT count(*)                                                          AS comparados,
       count(*) FILTER (WHERE lower(trim(dez.email)) IS DISTINCT FROM lower(trim(cc.email)))
                                                                         AS email_mudou,
       count(*) FILTER (WHERE nullif(dez.benchmarking,'') IS NOT NULL
                          AND cc.custom_fields #> '{benchmarking,value}' IS NULL)
                                                                         AS perdeu_benchmarking,
       count(*) FILTER (WHERE lower(dez.email_unsubscribe) IN ('true','t','1','sim')
                          AND NOT cc.email_unsubscribe)                  AS perdeu_optout
FROM dez
JOIN public.customer_contact cc ON cc.id = dez.id;

-- `perdeu_optout` > 0 é problema de conformidade, não de dado: significa que
-- alguém que pediu descadastro voltou a ser passível de disparo. Trate antes
-- de qualquer reativação.


-- ============================================================================
-- 4. O CSV DA MANUTENÇÃO — só depois de pausar as integrações
-- ============================================================================
-- CONFIRME O CABEÇALHO ESPERADO pela manutenção do SenseData antes de subir.
-- O mínimo abaixo (identificador + status) é o que a operação precisa; se a
-- tela exigir outras colunas obrigatórias, acrescente aqui e regere.

-- 4.1 · Arquivo mínimo (é este que sobe)
COPY (
  WITH dez AS (
    SELECT id_contato::bigint AS id
    FROM stg_contatos_10ago
    WHERE id_contato ~ '^[0-9]+$'
      AND lower(ativo) IN ('true','t','1','sim')
  )
  SELECT cc.id AS "ID Contato",
         'True' AS "Ativo"
  FROM dez
  JOIN public.customer_contact cc ON cc.id = dez.id
  WHERE NOT cc.is_active
  ORDER BY cc.id
) TO STDOUT WITH (FORMAT csv, HEADER true, DELIMITER ';');
-- No psql, troque `COPY (...) TO STDOUT` por `\copy (...) TO 'reativar.csv'`
-- para gravar direto no seu computador.

-- 4.2 · Mesma lista com nome e conta, para conferir antes de subir
WITH dez AS (
  SELECT id_contato::bigint AS id
  FROM stg_contatos_10ago
  WHERE id_contato ~ '^[0-9]+$'
    AND lower(ativo) IN ('true','t','1','sim')
)
SELECT cli.id_legacy AS conta,
       cli.name      AS cliente,
       cc.id         AS id_contato,
       cc.name       AS nome,
       cc.email,
       cc.custom_fields->'produto_contact'->>'value'  AS produto,
       cc.id_legacy  AS chave_gravada,
       cc.email_unsubscribe AS optout
FROM dez
JOIN public.customer_contact cc ON cc.id = dez.id
JOIN public.customer cli        ON cli.id = cc.id_customer
WHERE NOT cc.is_active
ORDER BY cli.id_legacy, cc.name;

-- POR QUE `update` E NUNCA `upsert`: a carga é chaveada pelo `ID Contato`, que
-- é o identificador do próprio registro. Upsert recalcula `id_legacy` e recria
-- a base — é exatamente o bug em apuração.


-- ============================================================================
-- 5. VALIDAÇÃO DEPOIS DA CARGA
-- ============================================================================

-- 5.1 · Sobrou alguém para trás?
WITH dez AS (
  SELECT id_contato::bigint AS id
  FROM stg_contatos_10ago
  WHERE id_contato ~ '^[0-9]+$' AND lower(ativo) IN ('true','t','1','sim')
)
SELECT count(*) AS ainda_inativos
FROM dez JOIN public.customer_contact cc ON cc.id = dez.id
WHERE NOT cc.is_active;
-- Deve retornar 0.

-- 5.2 · A contagem por conta voltou ao patamar do dia 10?  (reuse 3.2)

-- 5.3 · Nenhum opt-out foi perdido no caminho
SELECT count(*) AS ativos_sem_optout_mas_com_historico
FROM public.customer_contact a
WHERE a.is_active AND NOT a.email_unsubscribe
  AND EXISTS (SELECT 1 FROM public.customer_contact i
               WHERE i.email_unsubscribe
                 AND lower(i.email) = lower(a.email)
                 AND i.id_customer  = a.id_customer);
-- Deve retornar 0. Retornava 0 em 24/08 — manter assim.

-- 5.4 · Benchmarking: a reativação NÃO resolve esta frente
SELECT count(*) FILTER (WHERE is_active)     AS marcacoes_ativas,
       count(*) FILTER (WHERE NOT is_active) AS marcacoes_inativas
FROM public.customer_contact
WHERE (SELECT count(*) FROM jsonb_array_elements_text(
         CASE jsonb_typeof(custom_fields #> '{benchmarking,value}')
           WHEN 'array' THEN custom_fields #> '{benchmarking,value}'
           ELSE '[]'::jsonb END) AS v(val)
        WHERE v.val <> '' AND v.val <> 'N/A') > 0;
-- Em 24/08: 7 ativas · 448 inativas. As 431 marcações inativas estão em
-- registros que JÁ constavam inativos em 13/08 — população diferente dos
-- 6.203 desativados pelas ondas. Rode o passo 2 no export do dia 10 para
-- saber se esses registros estavam ativos naquele dia: é isso que define se
-- a recuperação do Benchmarking entra nesta mesma carga ou vira pareamento
-- à parte (ver seção C de `queries-depara-contatos.sql`).
