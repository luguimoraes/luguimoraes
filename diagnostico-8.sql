-- O que a manutenção fez com as 8 linhas do ajuste manual.
--
-- Lista TODOS os registros dessas pessoas-conta, sem filtro de origem, com
-- created_at e updated_at. Somente leitura.
--
-- O que procurar:
--
--   registro criado hoje       a importação inseriu contato novo em vez de
--                              atualizar o id que foi enviado. É o pior caso:
--                              gera duplicata. NÃO reenviar nada até decidir.
--
--   updated_at de hoje no id   a importação achou o registro certo mas não
--   que eu mandei              gravou o campo. Aí o problema é o nome da
--                              coluna ou o modo da importação.
--
--   nada com data de hoje      a importação não chegou nesses registros.
--                              Confira se o arquivo subiu mesmo.

SELECT c.id_legacy                                   AS "Cliente (ID Original)",
       cc.id                                         AS "ID Contato",
       cc.name                                       AS "Nome",
       cc.email                                      AS "Email",
       cc.is_active                                  AS "Ativo",
       cc.custom_fields->'origem'->>'value'          AS "Origem",
       cc.custom_fields#>>'{benchmarking,value}'     AS "Benchmarking",
       cc.custom_fields->'data_benchmark'->>'value'  AS "Data Benchmark",
       cc.created_at                                 AS "Criado em",
       cc.updated_at                                 AS "Atualizado em",
       cc.created_at::date = CURRENT_DATE            AS "criado_hoje",
       cc.updated_at::date = CURRENT_DATE            AS "atualizado_hoje"
FROM public.customer_contact cc
JOIN public.customer c ON c.id = cc.id_customer
WHERE (c.id_legacy, lower(btrim(cc.email))) IN (
        ('127527-TAX',   'nelson.silva@stahl.com'),
        ('128975-TAX',   'felipe.torres@beamsuntory.com'),
        ('134900-LEGAL', 'joao.junior@brbcard.com.br'),
        ('134911-TAX',   'william.lopes@smurfitwestrock.com.br'),
        ('1456-GTM',     'cintia.catharina@br.bosch.com'),
        ('15772-LEGAL',  'l.teofilo@coimbrachaves.com.br'),
        ('17378-TAX',    'paulo.satiro@loccitane.com'),
        ('5965-TAX',     'metges@trombini.com.br')
      )
ORDER BY 1, lower(cc.email), cc.created_at;
