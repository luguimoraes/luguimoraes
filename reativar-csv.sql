-- ============================================================================
-- Contatos TR — arquivo da manutenção (somente leitura)
-- ============================================================================
-- Exporte o resultado como CSV e suba. Não precisa editar nada depois.
-- Esperado: 7.398 linhas.
--
-- COLUNAS — pelas regras da manutenção que você passou:
--   obrigatório: Cliente (ID Original) OU Cliente (ID Sensedata)
--   obrigatório: Telefone 1 / Telefone 2 e/ou E-mail
-- Ou seja: a manutenção NÃO casa por ID do contato, casa por (cliente, e-mail).
-- Por isso o arquivo saiu de 2 colunas ("ID Contato", "Ativo") para 3.
--
-- O QUE MUDA NO BANCO: só o campo do arquivo. Coluna que não vai no CSV não é
-- tocada — nome, produto, benchmarking, data_benchmark, opt-out e a chave em
-- `id_legacy` ficam como estão. Mas atenção: as colunas-chave TAMBÉM são
-- gravadas. Por isso o e-mail sai como está no banco, sem `lower()` — só com
-- `btrim()`, para não reescrever o e-mail do contato com outra grafia.
-- O `btrim` existe porque há e-mail gravado com espaço na ponta, e espaço na
-- chave provavelmente impede o casamento. Meça quantos são na seção 1.5 de
-- `conferencia-antes-depois.sql`: nesses o e-mail sai sem os espaços, ou seja,
-- a manutenção limpa o campo. É a única alteração fora de "Ativo" — se preferir
-- zero alteração, tire esses poucos contatos do arquivo e trate à parte.
--
-- ANTES DE SUBIR O ARQUIVO INTEIRO, RODE A SEÇÃO 1 DE `conferencia-antes-depois.sql`.
-- Casando por (cliente, e-mail), a manutenção alcança TODOS os registros com
-- aquele e-mail naquela conta — e o alvo tem, em média, mais de um registro por
-- pessoa-conta (o antigo + a recriação de 13/14/20/08). Se a manutenção ativar
-- todos, o resultado é ~15 mil ativos em vez de 7.398, ou seja, duplicação.
-- Não dá para desfazer isso com outra manutenção: a chave é a mesma.
-- Suba o PILOTO do rodapé primeiro e confira o que aconteceu.
--
-- PRÉ-REQUISITO (você já fez): `Pré-processing_Inativa_Contatos` (2012) e
-- `Contatos_S3_V4` (2036) pausados. Se a carga rodar depois, desfaz tudo.
--
-- CABEÇALHO: "Ativo" é o único nome que ainda não está confirmado na
-- documentação da manutenção. Se ela pedir outro, troque só o alias.
-- ============================================================================

WITH cc AS (
  SELECT c.id,
         c.id_customer,
         btrim(c.email)                                             AS email_gravado,
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
  SELECT email_chave,
         id_customer,
         bool_or(is_active)                        AS tem_ativo,
         bool_or(created_at >= DATE '2026-08-13')  AS veio_no_arquivo
  FROM cc
  GROUP BY email_chave, id_customer
),
escolhido AS (
  SELECT DISTINCT ON (cc.email_chave, cc.id_customer)
         cc.id_customer,
         cc.email_gravado
  FROM cc
  JOIN grupo g
    ON g.email_chave = cc.email_chave
   AND g.id_customer = cc.id_customer
  WHERE g.veio_no_arquivo
    AND NOT g.tem_ativo
  ORDER BY cc.email_chave,
           cc.id_customer,
           (cc.benchmarking IS NOT NULL) DESC,   -- 1o: preserva o dado manual
           (cc.produto <> '') DESC,              -- 2o: registro com produto preenchido
           cc.created_at DESC                    -- 3o: o mais recente
)
SELECT e.id_customer     AS "Cliente (ID Sensedata)",
       e.email_gravado   AS "E-mail",
       'True'            AS "Ativo"
FROM escolhido e
JOIN public.customer cli ON cli.id = e.id_customer
ORDER BY cli.id_legacy, e.email_gravado;

-- ----------------------------------------------------------------------------
-- FILTRO OPCIONAL — pares que já têm contato ativo de OUTRA origem
-- ----------------------------------------------------------------------------
-- `tem_ativo` só enxerga a origem 'Integração Sistema'. A manutenção não: ela
-- casa por (cliente, e-mail) em qualquer origem. Onde já existe contato ATIVO
-- manual com o mesmo e-mail na mesma conta, reativar cria um segundo ativo.
-- A seção 1.3 de `conferencia-antes-depois.sql` diz quantos casos são; se for
-- material, acrescente este NOT EXISTS ao WHERE da CTE `escolhido` — o total
-- cai exatamente pelo número que a 1.3 reporta em `ativos`:
--
--     AND NOT EXISTS (
--           SELECT 1 FROM public.customer_contact o
--            WHERE o.id_customer = cc.id_customer
--              AND lower(trim(o.email)) = cc.email_chave
--              AND o.is_active
--              AND coalesce(o.custom_fields->'origem'->>'value','') <> 'Integração Sistema')
--
-- Não deixei ligado por padrão porque mudaria as 7.398 linhas já combinadas com
-- o cliente sem você decidir.

-- Prefere mandar a conta pelo código ('132626-TAX')? Troque a primeira coluna
-- por `cli.id_legacy AS "Cliente (ID Original)"`. Mande UMA das duas, não as
-- duas: se divergirem, a manutenção pode recusar a linha. Antes de trocar,
-- rode a seção 1.4 de `conferencia-antes-depois.sql` — ela verifica se todas
-- as contas do alvo têm `id_legacy` preenchido e único.


-- ----------------------------------------------------------------------------
-- PILOTO — suba isto primeiro, confira, depois suba o arquivo inteiro
-- ----------------------------------------------------------------------------
-- Mesma query, uma conta só. Escolha uma conta pequena na lista da seção 3.1 de
-- `manutencao-reativacao-csv.sql`, troque o código abaixo e descomente o bloco.
-- Depois de subir, rode a seção 4 de `conferencia-antes-depois.sql` filtrando
-- pela mesma conta: se cada pessoa-conta terminar com exatamente 1 ativo, o
-- arquivo inteiro é seguro. Se terminar com 2+, pare — a manutenção está
-- casando com todos os registros do par e vai duplicar 7 mil contatos.
--
--   ... (mesmas CTEs acima) ...
--   SELECT e.id_customer   AS "Cliente (ID Sensedata)",
--          e.email_gravado AS "E-mail",
--          'True'          AS "Ativo"
--   FROM escolhido e
--   JOIN public.customer cli ON cli.id = e.id_customer
--   WHERE cli.id_legacy = '132626-TAX'
--   ORDER BY e.email_gravado;
