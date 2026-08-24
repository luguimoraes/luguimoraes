-- Contatos TR — o arquivo da manutenção. Rode, exporte, suba.
--
-- Obrigatórios da manutenção: Cliente (ID Original ou ID Sensedata) e
-- Telefone 1/Telefone 2 e/ou E-mail. Ela grava só as colunas presentes no
-- arquivo, então o arquivo tem três: as duas que identificam e a que muda.
-- O que não está aqui ela não toca — não há como apagar Cargo, Telefone ou
-- Benchmarking de ninguém, que era o risco de subir as 41 colunas.
--
-- ==========================================================================
-- O `todos` olha a base INTEIRA, não só os contatos da integração. Isso vale
-- para duas coisas, e as duas importam:
--
--   1. "essa pessoa já tem contato ativo nesta conta?" — se tiver, mesmo que
--      seja um contato criado à mão, reativar o da integração dá 2 ativos
--      para a mesma pessoa. Ele fica de fora.
--   2. "quantos contatos a dupla acha?" — é o que separa os dois lotes.
--
-- DOIS LOTES. A chave é (Cliente, E-mail), e ela não separa dois contatos
-- que dividem o mesmo e-mail na mesma conta.
--
--   Lote A  (t.n = 1)   a dupla identifica um contato só. Sem ambiguidade
--                       possível. SOBE AGORA, não precisa de teste.
--
--   Lote B  (t.n > 1)   a dupla acha mais de um. O e-mail sai com a caixa
--                       exata do registro escolhido; se a manutenção casar
--                       respeitando maiúscula/minúscula, acerta só ele. Se
--                       ignorar, ativa o par inteiro e a pessoa fica com 2
--                       ativos. SOBE DEPOIS do piloto do rodapé.
--
-- Troque a linha marcada LOTE lá embaixo e rode de novo para tirar o outro.
-- ==========================================================================

WITH b AS (
  SELECT id, id_customer, btrim(email) AS email, is_active, created_at,
         coalesce(custom_fields->'produto_contact'->>'value','') AS produto,
         (SELECT string_agg(v,'; ') FROM jsonb_array_elements_text(
            CASE jsonb_typeof(custom_fields#>'{benchmarking,value}')
              WHEN 'array'  THEN custom_fields#>'{benchmarking,value}'
              WHEN 'string' THEN jsonb_build_array(custom_fields#>'{benchmarking,value}')
              ELSE '[]'::jsonb END) v
           WHERE v NOT IN ('','N/A'))                            AS benchmarking
  FROM public.customer_contact
  WHERE custom_fields->'origem'->>'value' = 'Integração Sistema'
),
todos AS (   -- o que a dupla (conta, e-mail) acha na base INTEIRA, não só na
             -- integração: a manutenção também não olha só para ela
  SELECT id_customer, lower(btrim(email)) AS chave,
         count(*)           AS n,
         bool_or(is_active) AS tem_ativo
  FROM public.customer_contact
  GROUP BY 1, 2
),
g AS (
  SELECT *,
         bool_or(created_at >= DATE '2026-08-13') OVER par AS veio,
         row_number() OVER (PARTITION BY lower(email), id_customer
                            ORDER BY (benchmarking IS NOT NULL) DESC,  -- preserva o dado manual
                                     (produto <> '') DESC,             -- registro com produto
                                     created_at DESC) AS rn            -- o mais recente
  FROM b WINDOW par AS (PARTITION BY lower(email), id_customer)
)
SELECT c.id_legacy AS "Cliente (ID Original)",
       g.email     AS "E-mail",
       'Sim'       AS "Ativo"
FROM g
JOIN public.customer c ON c.id = g.id_customer
JOIN todos t ON t.id_customer = g.id_customer AND t.chave = lower(g.email)
WHERE g.veio AND NOT t.tem_ativo AND g.rn = 1
  AND t.n = 1     -- LOTE A: sobe agora.  Lote B: troque por  t.n > 1
  -- Os ~47 e-mails quebrados ficam de fora: a chave é o próprio e-mail, e um
  -- e-mail torto não casa com registro nenhum. Esses são correção manual na
  -- tela do SenseData, não têm como entrar em arquivo.
  AND g.email ~ '^[^@[:space:],;<>]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
  AND g.email !~ '\.\.'
  AND g.email !~* '\.(con|ne|cm|bra)$'
  AND g.id NOT IN (209338, 210078, 211563, 218790)  -- .co que era .com
ORDER BY 1, 2;


-- --------------------------------------------------------------------------
-- Tamanho dos dois lotes, antes de exportar. Troque o SELECT final por:
--
--   SELECT count(*) FILTER (WHERE t.n = 1) AS lote_a,
--          count(*) FILTER (WHERE t.n > 1) AS lote_b,
--          count(*)                        AS total
--   FROM g
--   JOIN todos t ON t.id_customer = g.id_customer AND t.chave = lower(g.email)
--   WHERE g.veio AND NOT t.tem_ativo AND g.rn = 1
--     AND g.email ~ '^[^@[:space:],;<>]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
--     AND g.email !~ '\.\.' AND g.email !~* '\.(con|ne|cm|bra)$'
--     AND g.id NOT IN (209338, 210078, 211563, 218790);
--
-- `total` tem que dar 7.351.
-- --------------------------------------------------------------------------
-- Piloto do lote B — uma conta só, antes de soltar o resto. Acrescente ao
-- WHERE do lote B:   AND c.id_legacy = '125609-GTM'
--
-- Conferência depois de subir o piloto. Tem que dar 1 em ativos_agora; se
-- aparecer 2, a manutenção ignorou a caixa — pare e não suba o resto do B.
--
--   SELECT c.id_legacy, lower(g.email) AS pessoa,
--          count(*) FILTER (WHERE g.is_active) AS ativos_agora,
--          count(*)                            AS no_par
--   FROM g JOIN public.customer c ON c.id = g.id_customer
--   WHERE g.veio AND c.id_legacy = '125609-GTM'
--   GROUP BY 1, 2 ORDER BY 3 DESC;
-- --------------------------------------------------------------------------
