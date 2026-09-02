-- Auditoria do campo customizado `comercial_da_conta`.
--
-- Mesma regra de negócio da rotina Python, escrita em SQL para conferência na
-- base espelho / DW do SenseData: mostra, por cliente, qual comercial *deveria*
-- estar no campo, o que está lá hoje e a situação resultante.
--
-- Ajuste os nomes de schema/tabela conforme o modelo espelhado na sua base.

WITH contatos_comerciais AS (
    SELECT
        ct.customer_id,
        ct.name  AS contato_nome,
        ct.email AS contato_email,
        ROW_NUMBER() OVER (
            PARTITION BY ct.customer_id
            ORDER BY
                CASE WHEN ct.main THEN 0 ELSE 1 END,  -- contato principal primeiro
                ct.updated_at DESC,
                ct.name
        ) AS prioridade
    FROM contacts ct
    WHERE ct.active = TRUE
      AND LOWER(TRIM(ct.type)) IN ('comercial', 'responsavel comercial', 'executivo comercial', 'vendas')
),
comercial_por_cliente AS (
    SELECT customer_id, contato_nome, contato_email
    FROM contatos_comerciais
    WHERE prioridade = 1
),
esperado AS (
    SELECT
        c.id                AS id_sensedata,
        c.id_original,
        c.name              AS cliente,
        c.comercial_da_conta AS valor_atual,
        u.id                AS usuario_id,
        u.email             AS valor_esperado
    FROM customers c
    LEFT JOIN comercial_por_cliente cpc ON cpc.customer_id = c.id
    LEFT JOIN users u
           ON u.active = TRUE
          AND (LOWER(u.email) = LOWER(cpc.contato_email)
               OR LOWER(u.name) = LOWER(cpc.contato_nome))
    WHERE c.status = 'Ativo'
)
SELECT
    id_original,
    cliente,
    valor_atual,
    valor_esperado,
    CASE
        WHEN valor_esperado IS NULL AND valor_atual IS NULL THEN 'SEM COMERCIAL - regra 304 usaria o remetente padrao'
        WHEN valor_esperado IS NULL                          THEN 'CONTATO COMERCIAL SEM USUARIO CORRESPONDENTE'
        WHEN valor_atual IS NULL                             THEN 'A PREENCHER'
        WHEN LOWER(valor_atual) <> LOWER(valor_esperado)      THEN 'DIVERGENTE'
        ELSE 'OK'
    END AS situacao
FROM esperado
ORDER BY situacao, cliente;
