-- Contatos TR — o arquivo da manutenção. Exporte e suba.
--
-- A manutenção casa por ID do contato e grava só as colunas que estão no
-- arquivo. Então o arquivo tem duas: a chave e o que muda. O que não está
-- aqui ela não toca — não há como apagar Cargo, Telefone ou Benchmarking de
-- ninguém, que era o risco de subir as 41 colunas.
--
-- Como a chave é o ID, cada linha atinge um contato só. A pessoa com dois
-- registros de mesmo e-mail na mesma conta deixou de ser risco: o `rn = 1`
-- escolhe qual dos dois fica ativo e o ID diz exatamente qual é.
--
-- Se a tela não reconhecer o cabeçalho "ID Contato", troque pelo nome exato
-- que ela lista como obrigatório — "ID Contato (Sensedata)".

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
SELECT g.id  AS "ID Contato",
       'Sim' AS "Ativo"
FROM g
WHERE g.veio AND NOT g.tem_ativo AND g.rn = 1
  -- As quatro linhas abaixo tiram os ~47 e-mails quebrados. Elas existiam
  -- porque a manutenção casaria por e-mail, e e-mail torto não casa com nada.
  -- Com a chave sendo o ID isso deixou de valer: dá para reativar a pessoa
  -- agora e corrigir o e-mail depois, na tela. Apague as quatro para trazê-los
  -- de volta — aí o total sobe acima de 7.351 e precisa ser reconferido.
  AND g.email ~ '^[^@[:space:],;<>]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
  AND g.email !~ '\.\.'
  AND g.email !~* '\.(con|ne|cm|bra)$'
  AND g.id NOT IN (209338, 210078, 211563, 218790)  -- .co que era .com
ORDER BY 1;

-- Piloto de uma conta só, antes de soltar os 7 mil: acrescente ao WHERE
--   AND g.id_customer = (SELECT id FROM public.customer WHERE id_legacy = '132626-TAX')
--
-- Conferência depois de subir — cada pessoa-conta tem que ter 1 ativo, não 2:
--   troque o SELECT final por
--   SELECT count(*) FILTER (WHERE is_active) AS ativos_no_par, count(*)
--   FROM g WHERE g.veio GROUP BY lower(email), id_customer ORDER BY 1;
