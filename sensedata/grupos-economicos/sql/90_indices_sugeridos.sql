-- =====================================================================
-- 90 - INDICES SUGERIDOS (opcional, depende de permissao de DDL)
-- A base e gerenciada pelo SenseData; provavelmente sera necessario
-- abrir chamado para o time deles aplicar. Nao e bloqueante: a tabela
-- customer costuma ser pequena e o seq scan resolve.
-- Avaliar APENAS se o EXPLAIN ANALYZE mostrar custo relevante.
-- =====================================================================

-- Antes de tudo, medir:
--   EXPLAIN (ANALYZE, BUFFERS) <query do arquivo 10 ou 20>;

-- Suporta os dois lados do JOIN normalizado (matriz e filhas).
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_customer_company_group_norm
    ON public.customer (company, upper(btrim("group")))
    WHERE "group" IS NOT NULL AND btrim("group") <> '';

-- Acelera a selecao das matrizes (poucas linhas, indice parcial barato).
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_customer_matriz
    ON public.customer (company, upper(btrim("group")))
    WHERE NULLIF(btrim(cnpj), '') IS NULL;

-- Se custom_fields for jsonb e as leituras crescerem:
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_customer_custom_fields
--     ON public.customer USING gin (custom_fields jsonb_path_ops);

-- Observacao: CONCURRENTLY nao pode rodar dentro de transacao/bloco.
-- Executar cada comando isoladamente.
