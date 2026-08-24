-- ============================================================================
-- Descoberta de esquema — para montar as 41 colunas do arquivo da Jaqueline
-- ============================================================================
-- Três consultas, todas somente leitura. Me mande as três saídas.

-- 1 · Colunas físicas de customer_contact
--     (Apelido, Cargo, Tel, Tel 2, Sponsor, Skype, Endereço, Tipo Contato,
--      Favorito, Blacklist, Nível do Cargo podem estar aqui)
SELECT ordinal_position AS pos, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'customer_contact'
ORDER BY ordinal_position;


-- 2 · Chaves do custom_fields dos contatos da origem, com exemplo de valor
--     (é aqui que devem estar Benchmarking, Produto, Data Benchmark, Origem,
--      Brand, País, Motivo Unsubscribe e os campos de NPS)
SELECT k.key                                              AS chave,
       count(*)                                           AS registros,
       count(*) FILTER (WHERE c.custom_fields #>> ARRAY[k.key,'value'] IS NOT NULL
                          AND c.custom_fields #>> ARRAY[k.key,'value'] <> '') AS preenchidos,
       string_agg(DISTINCT jsonb_typeof(c.custom_fields #> ARRAY[k.key,'value']), '/') AS tipos,
       min(c.custom_fields #>> ARRAY[k.key,'value'])       AS exemplo
FROM public.customer_contact c,
     jsonb_object_keys(c.custom_fields) AS k(key)
WHERE c.custom_fields->'origem'->>'value' = 'Integração Sistema'
GROUP BY k.key
ORDER BY preenchidos DESC, chave;


-- 3 · Colunas de customer
--     (Grupo Econômico, Status do cliente, País do cliente devem sair daqui)
SELECT ordinal_position AS pos, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'customer'
ORDER BY ordinal_position;


-- 4 · Confirma que dá para usar "ID Original" como chave da importação
--     Esta lista não tem coluna de ID Sensedata, então a chave vira
--     (ID Original, Email). Precisa dar 0 em sem_codigo e 0 em codigo_repetido.
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
