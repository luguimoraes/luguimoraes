-- ============================================================================
-- Contatos TR — conferência da manutenção: risco, base ANTES, base DEPOIS
-- ============================================================================
-- Tudo aqui é SELECT. Ordem de uso:
--
--   seção 1  ANTES de gerar o arquivo — mede o risco da chave (cliente, e-mail)
--   seção 2  ANTES de subir — exporte como `base-antes.csv`
--   seção 2  DEPOIS de subir — exporte como `base-depois.csv` (mesma query)
--   seção 3  DEPOIS de subir — o que precisa ter mudado, e o que não podia
--   seção 4  o caso da Jaqueline
--
-- POR QUE A SEÇÃO 1 EXISTE. A manutenção casa por (cliente, e-mail), não por ID
-- do contato. O alvo da reativação tem mais de um registro por pessoa-conta — o
-- antigo, inativado indevidamente, e a recriação de 13/14/20/08. Os dois têm o
-- mesmo e-mail na mesma conta. Se a manutenção ativar todos os registros do par,
-- 7.398 linhas viram ~15 mil contatos ativos: duplicação, e sem volta pela
-- própria manutenção, porque a chave para desativar seria a mesma.
-- A seção 1 diz o tamanho exato desse risco antes de qualquer upload.
-- ============================================================================


-- ============================================================================
-- 1. RISCO DA CHAVE (cliente, e-mail)
-- ============================================================================

-- 1.1 · Quantos registros cada par (conta, e-mail) alcança
-- Se `registros_no_par` = 1 para todo mundo, o arquivo é seguro como está.
-- Some `registros_alcancados`: é o total que a manutenção pode ativar.
WITH cc AS (
  SELECT c.id, c.id_customer, c.name AS nome,
         lower(trim(c.email)) AS email_chave,
         c.is_active, c.created_at
  FROM public.customer_contact c
  WHERE c.custom_fields->'origem'->>'value' = 'Integração Sistema'
),
grupo AS (
  SELECT email_chave, id_customer,
         bool_or(is_active)                       AS tem_ativo,
         bool_or(created_at >= DATE '2026-08-13') AS veio_no_arquivo
  FROM cc GROUP BY 1, 2
),
alvo AS (
  SELECT cc.*
  FROM cc JOIN grupo g ON g.email_chave = cc.email_chave AND g.id_customer = cc.id_customer
  WHERE g.veio_no_arquivo AND NOT g.tem_ativo
)
SELECT registros_no_par,
       count(*)                        AS pessoas_conta,
       count(*) * registros_no_par     AS registros_alcancados
FROM (SELECT email_chave, id_customer, count(*) AS registros_no_par
        FROM alvo GROUP BY 1, 2) t
GROUP BY registros_no_par
ORDER BY registros_no_par;
-- `pessoas_conta` somado = 7.398. Se `registros_alcancados` somar perto de
-- 15.000, NÃO suba o arquivo inteiro sem o piloto do rodapé de `reativar-csv.sql`.


-- 1.2 · O mesmo e-mail é de duas pessoas diferentes na mesma conta?
-- Se sim, a chave junta as duas e a manutenção mexe em quem não devia.
WITH cc AS (
  SELECT c.id, c.id_customer, c.name AS nome, lower(trim(c.email)) AS email_chave,
         c.is_active, c.created_at
  FROM public.customer_contact c
  WHERE c.custom_fields->'origem'->>'value' = 'Integração Sistema'
),
grupo AS (
  SELECT email_chave, id_customer, bool_or(is_active) AS tem_ativo,
         bool_or(created_at >= DATE '2026-08-13') AS veio_no_arquivo
  FROM cc GROUP BY 1, 2
),
alvo AS (
  SELECT cc.* FROM cc JOIN grupo g ON g.email_chave = cc.email_chave AND g.id_customer = cc.id_customer
  WHERE g.veio_no_arquivo AND NOT g.tem_ativo
)
SELECT cli.id_legacy                          AS conta,
       a.email_chave                          AS email,
       count(DISTINCT lower(trim(a.nome)))    AS nomes_distintos,
       string_agg(DISTINCT a.nome, ' | ')     AS nomes
FROM alvo a
JOIN public.customer cli ON cli.id = a.id_customer
GROUP BY 1, 2
HAVING count(DISTINCT lower(trim(a.nome))) > 1
ORDER BY 3 DESC, 1;
-- Vazio = ótimo. Cada linha aqui é uma pessoa que pode ser ativada por engano.


-- 1.3 · O par (conta, e-mail) já existe em OUTRA origem?
-- O filtro de origem esconde esses registros de nós; a manutenção enxerga todos.
WITH cc AS (
  SELECT c.id, c.id_customer, lower(trim(c.email)) AS email_chave, c.is_active, c.created_at
  FROM public.customer_contact c
  WHERE c.custom_fields->'origem'->>'value' = 'Integração Sistema'
),
grupo AS (
  SELECT email_chave, id_customer, bool_or(is_active) AS tem_ativo,
         bool_or(created_at >= DATE '2026-08-13') AS veio_no_arquivo
  FROM cc GROUP BY 1, 2
),
par AS (
  SELECT DISTINCT cc.id_customer, cc.email_chave
  FROM cc JOIN grupo g ON g.email_chave = cc.email_chave AND g.id_customer = cc.id_customer
  WHERE g.veio_no_arquivo AND NOT g.tem_ativo
)
SELECT coalesce(o.custom_fields->'origem'->>'value', '(sem origem)') AS origem_do_vizinho,
       count(*)                                AS registros,
       count(*) FILTER (WHERE o.is_active)     AS ativos
FROM par p
JOIN public.customer_contact o
  ON o.id_customer = p.id_customer
 AND lower(trim(o.email)) = p.email_chave
WHERE coalesce(o.custom_fields->'origem'->>'value', '') <> 'Integração Sistema'
GROUP BY 1
ORDER BY 2 DESC;
-- `ativos` > 0 significa: existe contato ATIVO com esse e-mail nessa conta, de
-- outra origem. Para esses pares a reativação pode ser desnecessária — e a
-- manutenção pode acabar reescrevendo o contato manual em vez do da carga.


-- 1.4 · Dá para usar "Cliente (ID Original)" no lugar do ID Sensedata?
WITH cc AS (
  SELECT c.id_customer, lower(trim(c.email)) AS email_chave, c.is_active, c.created_at
  FROM public.customer_contact c
  WHERE c.custom_fields->'origem'->>'value' = 'Integração Sistema'
),
grupo AS (
  SELECT email_chave, id_customer, bool_or(is_active) AS tem_ativo,
         bool_or(created_at >= DATE '2026-08-13') AS veio_no_arquivo
  FROM cc GROUP BY 1, 2
),
conta_alvo AS (
  SELECT DISTINCT cc.id_customer
  FROM cc JOIN grupo g ON g.email_chave = cc.email_chave AND g.id_customer = cc.id_customer
  WHERE g.veio_no_arquivo AND NOT g.tem_ativo
)
SELECT count(*)                                                                  AS contas_no_alvo,
       count(*) FILTER (WHERE cli.id_legacy IS NULL OR btrim(cli.id_legacy) = '') AS sem_codigo,
       count(*) FILTER (WHERE dup.n > 1)                                          AS codigo_repetido
FROM conta_alvo a
JOIN public.customer cli ON cli.id = a.id_customer
LEFT JOIN LATERAL (SELECT count(*) AS n FROM public.customer x WHERE x.id_legacy = cli.id_legacy) dup ON true;
-- `sem_codigo` = 0 e `codigo_repetido` = 0 → pode trocar a coluna do CSV para
-- `cli.id_legacy AS "Cliente (ID Original)"`. Qualquer valor > 0 → fique no ID
-- Sensedata, que é único por construção.


-- 1.5 · E-mails que o arquivo vai gravar diferente do que está no banco
-- A chave é gravada junto com o "Ativo". O CSV manda `btrim(email)`, então onde
-- o e-mail tem espaço na ponta a manutenção limpa o campo. É a única alteração
-- fora de "Ativo" — esta query diz em quantos contatos isso acontece.
WITH cc AS (
  SELECT c.id, c.id_customer, c.email, lower(trim(c.email)) AS email_chave,
         c.is_active, c.created_at,
         coalesce(c.custom_fields->'produto_contact'->>'value', '') AS produto,
         (SELECT string_agg(v.val, '; ')
            FROM jsonb_array_elements_text(
                   CASE jsonb_typeof(c.custom_fields #> '{benchmarking,value}')
                     WHEN 'array'  THEN c.custom_fields #> '{benchmarking,value}'
                     WHEN 'string' THEN jsonb_build_array(c.custom_fields #> '{benchmarking,value}')
                     ELSE '[]'::jsonb END) AS v(val)
           WHERE v.val <> '' AND v.val <> 'N/A') AS benchmarking
  FROM public.customer_contact c
  WHERE c.custom_fields->'origem'->>'value' = 'Integração Sistema'
),
grupo AS (
  SELECT email_chave, id_customer, bool_or(is_active) AS tem_ativo,
         bool_or(created_at >= DATE '2026-08-13') AS veio_no_arquivo
  FROM cc GROUP BY 1, 2
),
alvo AS (
  SELECT cc.* FROM cc JOIN grupo g ON g.email_chave = cc.email_chave AND g.id_customer = cc.id_customer
  WHERE g.veio_no_arquivo AND NOT g.tem_ativo
),
escolhido AS (
  SELECT DISTINCT ON (email_chave, id_customer) *
  FROM alvo
  ORDER BY email_chave, id_customer,
           (benchmarking IS NOT NULL) DESC, (produto <> '') DESC, created_at DESC
)
SELECT count(*)                                              AS linhas_no_csv,
       count(*) FILTER (WHERE email <> btrim(email))         AS email_sera_limpo,
       count(*) FILTER (WHERE btrim(email) <> lower(btrim(email))) AS tem_maiuscula_preservada
FROM escolhido;
-- `email_sera_limpo` são os contatos em que o CSV altera o e-mail (só tira
-- espaço). `tem_maiuscula_preservada` é informativo: esses continuam com a
-- grafia original, o CSV não mexe na caixa.


-- ============================================================================
-- 2. BASE ANTES / BASE DEPOIS — a mesma query, rodada duas vezes
-- ============================================================================
-- Traz TODO registro que a chave (conta, e-mail) alcança, não só os 7.398 do
-- arquivo: é esse o raio de alcance da manutenção. `no_csv` marca quem está no
-- arquivo. Ordenada por `id_contato`, então os dois CSVs comparam linha a linha.
--
--   rode agora            → salve como `base-antes.csv`
--   rode depois de subir  → salve como `base-depois.csv`
--
-- Só podem diferir: `ativo` (false → true) e `atualizado_em`. Qualquer outra
-- coluna diferente é campo sobrescrito pela manutenção — é exatamente isso que
-- essa comparação existe para pegar.

WITH cc AS (
  SELECT c.id,
         c.id_customer,
         lower(trim(c.email))                                       AS email_chave,
         c.is_active,
         c.created_at,
         coalesce(c.custom_fields->'produto_contact'->>'value', '')  AS produto,
         (SELECT string_agg(v.val, '; ')
            FROM jsonb_array_elements_text(
                   CASE jsonb_typeof(c.custom_fields #> '{benchmarking,value}')
                     WHEN 'array'  THEN c.custom_fields #> '{benchmarking,value}'
                     WHEN 'string' THEN jsonb_build_array(c.custom_fields #> '{benchmarking,value}')
                     ELSE '[]'::jsonb
                   END) AS v(val)
           WHERE v.val <> '' AND v.val <> 'N/A')                    AS benchmarking
  FROM public.customer_contact c
  WHERE c.custom_fields->'origem'->>'value' = 'Integração Sistema'
),
grupo AS (
  SELECT email_chave, id_customer,
         bool_or(is_active)                       AS tem_ativo,
         bool_or(created_at >= DATE '2026-08-13') AS veio_no_arquivo
  FROM cc GROUP BY 1, 2
),
alvo AS (
  SELECT cc.*
  FROM cc JOIN grupo g ON g.email_chave = cc.email_chave AND g.id_customer = cc.id_customer
  WHERE g.veio_no_arquivo AND NOT g.tem_ativo
),
par AS (
  SELECT DISTINCT id_customer, email_chave FROM alvo
),
escolhido AS (
  SELECT DISTINCT ON (email_chave, id_customer) id
  FROM alvo
  ORDER BY email_chave, id_customer,
           (benchmarking IS NOT NULL) DESC,
           (produto <> '') DESC,
           created_at DESC
)
SELECT t.id                                                        AS id_contato,
       cli.id_legacy                                               AS conta,
       cli.name                                                    AS cliente,
       t.name                                                      AS nome,
       t.email                                                     AS email,
       t.is_active                                                 AS ativo,
       t.email_unsubscribe                                         AS optout,
       coalesce(t.custom_fields->'origem'->>'value', '')           AS origem,
       coalesce(t.custom_fields->'produto_contact'->>'value', '')  AS produto,
       (SELECT string_agg(v.val, '; ')
          FROM jsonb_array_elements_text(
                 CASE jsonb_typeof(t.custom_fields #> '{benchmarking,value}')
                   WHEN 'array'  THEN t.custom_fields #> '{benchmarking,value}'
                   WHEN 'string' THEN jsonb_build_array(t.custom_fields #> '{benchmarking,value}')
                   ELSE '[]'::jsonb
                 END) AS v(val)
         WHERE v.val <> '' AND v.val <> 'N/A')                     AS benchmarking,
       nullif(t.custom_fields->'data_benchmark'->>'value', '')      AS data_benchmark,
       t.id_legacy                                                 AS chave_gravada,
       t.created_at                                                AS criado_em,
       t.updated_at                                                AS atualizado_em,
       (t.id IN (SELECT id FROM escolhido))                        AS no_csv
FROM par p
JOIN public.customer_contact t
  ON t.id_customer = p.id_customer
 AND lower(trim(t.email)) = p.email_chave
JOIN public.customer cli ON cli.id = t.id_customer
ORDER BY t.id;


-- ============================================================================
-- 3. DEPOIS DE SUBIR
-- ============================================================================

-- 3.1 · O teste que decide se deu certo: quantos ativos por pessoa-conta
-- Esperado: 7.398 pares com exatamente 1 ativo, nenhum com 2+.
WITH cc AS (
  SELECT c.id_customer, lower(trim(c.email)) AS email_chave, c.is_active, c.created_at
  FROM public.customer_contact c
  WHERE c.custom_fields->'origem'->>'value' = 'Integração Sistema'
),
grupo AS (
  SELECT email_chave, id_customer, bool_or(is_active) AS tem_ativo,
         bool_or(created_at >= DATE '2026-08-13') AS veio_no_arquivo
  FROM cc GROUP BY 1, 2
),
par AS (
  SELECT DISTINCT cc.id_customer, cc.email_chave
  FROM cc JOIN grupo g ON g.email_chave = cc.email_chave AND g.id_customer = cc.id_customer
  WHERE g.veio_no_arquivo   -- NÃO repita `AND NOT g.tem_ativo`: depois da
)                           -- manutenção eles TÊM ativo, e o par sumiria daqui.
SELECT ativos_no_par, count(*) AS pessoas_conta
FROM (SELECT p.id_customer, p.email_chave,
             count(*) FILTER (WHERE t.is_active) AS ativos_no_par
        FROM par p
        JOIN public.customer_contact t
          ON t.id_customer = p.id_customer AND lower(trim(t.email)) = p.email_chave
       GROUP BY 1, 2) x
GROUP BY 1
ORDER BY 1;
-- 0 ativos = não pegou. 2+ ativos = duplicou (a manutenção casou com todos os
-- registros do par). Rode isto logo depois do PILOTO, antes do arquivo inteiro.

-- 3.2 · Alguém foi tocado sem estar no arquivo?
-- Troque o horário pelo início do upload.
SELECT coalesce(custom_fields->'origem'->>'value', '(sem origem)') AS origem,
       count(*)                                AS tocados,
       count(*) FILTER (WHERE is_active)       AS terminaram_ativos
FROM public.customer_contact
WHERE updated_at >= TIMESTAMP '2026-08-24 00:00'
GROUP BY 1
ORDER BY 2 DESC;
-- Origem diferente de 'Integração Sistema' aparecendo aqui = a manutenção
-- alcançou contato de outra origem pelo mesmo e-mail (ver seção 1.3).

-- 3.3 · Nenhum opt-out perdido
SELECT count(*) AS ativos_sem_optout_mas_com_historico
FROM public.customer_contact a
WHERE a.is_active AND NOT a.email_unsubscribe
  AND EXISTS (SELECT 1 FROM public.customer_contact i
               WHERE i.email_unsubscribe
                 AND lower(i.email) = lower(a.email)
                 AND i.id_customer  = a.id_customer);
-- Deve retornar 0. Retornava 0 em 24/08.

-- 3.4 · A carga voltou a rodar? (seção 3.2 de `manutencao-reativacao-csv.sql`)
--       Hora nova depois da manutenção = os jobs 2012/2036 destravaram.


-- ============================================================================
-- 4. O CASO DA JAQUELINE
-- ============================================================================
-- Todos os registros dela, o veredito do grupo e se ela está no arquivo.
-- Troque o filtro se for outro nome, ou use o e-mail exato se souber.

WITH cc AS (
  SELECT c.id, c.id_customer, c.name AS nome, c.email,
         lower(trim(c.email)) AS email_chave, c.is_active, c.created_at, c.updated_at,
         c.id_legacy AS chave_gravada, c.email_unsubscribe AS optout,
         coalesce(c.custom_fields->'produto_contact'->>'value', '') AS produto,
         nullif(c.custom_fields->'data_benchmark'->>'value', '')    AS data_benchmark,
         (SELECT string_agg(v.val, '; ')
            FROM jsonb_array_elements_text(
                   CASE jsonb_typeof(c.custom_fields #> '{benchmarking,value}')
                     WHEN 'array'  THEN c.custom_fields #> '{benchmarking,value}'
                     WHEN 'string' THEN jsonb_build_array(c.custom_fields #> '{benchmarking,value}')
                     ELSE '[]'::jsonb
                   END) AS v(val)
           WHERE v.val <> '' AND v.val <> 'N/A') AS benchmarking
  FROM public.customer_contact c
  WHERE c.custom_fields->'origem'->>'value' = 'Integração Sistema'
),
grupo AS (
  SELECT email_chave, id_customer,
         bool_or(is_active)                       AS tem_ativo,
         bool_or(created_at >= DATE '2026-08-13') AS veio_no_arquivo
  FROM cc GROUP BY 1, 2
),
alvo AS (
  SELECT cc.* FROM cc JOIN grupo g ON g.email_chave = cc.email_chave AND g.id_customer = cc.id_customer
  WHERE g.veio_no_arquivo AND NOT g.tem_ativo
),
escolhido AS (
  SELECT DISTINCT ON (email_chave, id_customer) id
  FROM alvo
  ORDER BY email_chave, id_customer,
           (benchmarking IS NOT NULL) DESC, (produto <> '') DESC, created_at DESC
)
SELECT cli.id_legacy      AS conta,
       cli.name           AS cliente,
       cc.id              AS id_contato,
       cc.nome,
       cc.email,
       cc.is_active       AS ativo_hoje,
       CASE WHEN g.tem_ativo            THEN 'OK — tem contato ativo'
            WHEN NOT g.veio_no_arquivo  THEN 'inativo correto — nao veio no arquivo'
            ELSE 'AFETADO — veio no arquivo e esta sem ativo' END AS veredito,
       (cc.id IN (SELECT id FROM escolhido)) AS no_csv,
       cc.produto,
       cc.benchmarking,
       cc.data_benchmark,
       cc.optout,
       cc.chave_gravada,
       cc.created_at::date AS criado_em,
       cc.updated_at       AS atualizado_em
FROM cc
JOIN grupo g ON g.email_chave = cc.email_chave AND g.id_customer = cc.id_customer
JOIN public.customer cli ON cli.id = cc.id_customer
WHERE cc.nome ILIKE '%jaqueline%' OR cc.email ILIKE '%jaqueline%'
ORDER BY cli.id_legacy, cc.email_chave, cc.created_at;

-- Como ler: uma linha `no_csv = true` é o registro que a manutenção vai ativar.
-- Se ela aparecer com duas ou três linhas no mesmo par (conta, e-mail), é o
-- retrato do problema da seção 1.1 em um caso concreto — dá para levar essa
-- tela para a decisão do piloto.
--
-- Se "as informações da Jaqueline" for uma lista que ela mandou, e não o
-- contato dela na base: me mande a lista e eu comparo com este resultado
-- (nome, e-mail, conta, produto), apontando o que bate e o que diverge.
