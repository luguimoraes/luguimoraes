-- Contatos TR — o arquivo da manutenção. Exporte e suba.
--
-- Obrigatórios da manutenção: Cliente (ID Original ou ID Sensedata) e
-- Telefone 1/Telefone 2 e/ou E-mail. Ela grava só as colunas presentes no
-- arquivo, então o arquivo tem três: as duas que identificam e a que muda.
-- O que não está aqui ela não toca — não há como apagar Cargo, Telefone ou
-- Benchmarking de ninguém, que era o risco de subir as 41 colunas.
--
-- ##########################################################################
-- A chave NÃO é o ID do contato, e por isso ela não separa duas linhas com
-- o mesmo e-mail na mesma conta — que é a forma do alvo. Uma linha daqui
-- pode acabar ativando os DOIS registros do par, e a pessoa termina com 2
-- ativos em vez de 1.
--
-- O e-mail sai com a caixa exata do registro escolhido pelo `rn = 1`. Se a
-- manutenção casar respeitando maiúscula/minúscula, ela acerta só o certo.
-- Se casar ignorando a caixa, pega os dois. Não dá para saber sem testar:
-- SUBA UMA CONTA PRIMEIRO e rode a conferência do rodapé.
-- ##########################################################################

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
g AS (
  SELECT *,
         bool_or(is_active)                       OVER par AS tem_ativo,
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
FROM g JOIN public.customer c ON c.id = g.id_customer
WHERE g.veio AND NOT g.tem_ativo AND g.rn = 1
  -- Os ~47 e-mails quebrados ficam de fora: a chave é o próprio e-mail, e um
  -- e-mail torto não casa com registro nenhum. Esses são correção manual na
  -- tela do SenseData, não têm como entrar em arquivo.
  AND g.email ~ '^[^@[:space:],;<>]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
  AND g.email !~ '\.\.'
  AND g.email !~* '\.(con|ne|cm|bra)$'
  AND g.id NOT IN (209338, 210078, 211563, 218790)  -- .co que era .com
ORDER BY 1, 2;

-- Piloto — suba UMA conta antes dos 7 mil. Escolha uma que tenha par:
--   acrescente ao WHERE   AND c.id_legacy = '125609-GTM'
--
-- Conferência depois do piloto. Tem que dar 1 em todas as linhas; se aparecer
-- 2, a manutenção ignorou a caixa e ativou o par inteiro — pare aí.
--   troque o SELECT final por
--   SELECT c.id_legacy, lower(g.email) AS pessoa,
--          count(*) FILTER (WHERE g.is_active) AS ativos_agora, count(*) AS no_par
--   FROM g JOIN public.customer c ON c.id = g.id_customer
--   WHERE g.veio AND c.id_legacy = '125609-GTM'
--   GROUP BY 1, 2 ORDER BY 3 DESC;
