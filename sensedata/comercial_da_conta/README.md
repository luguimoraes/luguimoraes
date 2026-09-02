# Rotina de atualização do campo `comercial_da_conta` (SenseData)

Rotina diária que preenche o campo customizado **`comercial_da_conta`** (tipo
*lista de usuários*) na tabela de clientes do SenseData, cruzando os **contatos
ativos de tipo comercial** de cada cliente com os **usuários** da plataforma.

Origem: ticket Zenvia **496060** (Thomson Reuters) — a régua
[regra/304](https://thomson-reuters.sensedata.io/regra/304) enviou o comunicado
do caso `143468-TAX` como *Relacionamento CS* em vez de *Luciana Pasquarelli
Fernandes*.

## Diagnóstico

Não há bug na régua. O campo `comercial_da_conta` foi criado como *lista de
usuários*, mas **nenhuma rotina o alimenta** — ele não é atualizado pela carga
diária. Para `LEGAL MARIMEX DESPACHOS TRANSPORTES E SERVICOS LTDA` o campo
retorna `null`, e a régua 304, sem usuário definido no campo, cai no **remetente
padrão** (`relacionamentocs@thomsonreuters.com`). O nome errado é consequência
do campo vazio, não da configuração da régua.

Duas frentes resolvem o problema:

1. **Esta rotina** — mantém o campo preenchido em todas as cargas (corrige a causa);
2. **Guarda na régua 304** — condição para não disparar quando `comercial_da_conta`
   estiver vazio, para que nenhum comunicado volte a sair com remetente incorreto
   enquanto uma pendência não é tratada (defesa em profundidade, configurada na UI).

## Regra de preenchimento

Para cada cliente ativo:

1. Seleciona os contatos **ativos** cujo tipo está em `SENSEDATA_COMMERCIAL_TYPES`
   (padrão: `Comercial`, `Responsável Comercial`, `Executivo Comercial`, `Vendas`);
2. Desempata por **contato principal** → **atualização mais recente** → nome;
3. Resolve o contato para um **usuário do SenseData**: e-mail primeiro (comparação
   normalizada), nome completo como fallback;
4. Grava o valor no CF **apenas se for diferente do atual** (execução idempotente);
5. Nunca limpa um valor existente. Sem contato comercial, sem usuário
   correspondente, usuário inativo ou homônimo ambíguo → o cliente entra no CSV de
   **pendências** para tratamento do CS, com o motivo.

Motivos possíveis: `matched_by_email`, `matched_by_name`, `up_to_date`,
`no_active_commercial_contact`, `user_not_found`, `user_inactive`, `ambiguous_user`.

## Estrutura

| Arquivo | Função |
| --- | --- |
| `resolver.py` | Regra de negócio pura (seleção do contato, match do usuário, plano de atualização) |
| `sensedata_client.py` | Cliente da API v2 (só stdlib): paginação, retry com backoff em 429/5xx |
| `sync.py` | CLI: `dry-run`, `apply` e geração do CSV de manutenção |
| `airflow/dag_sensedata_comercial_da_conta.py` | DAG diária (07h America/Sao_Paulo, após a carga) |
| `sql/auditoria_comercial_da_conta.sql` | Consulta de conferência na base espelho/DW |
| `tests/` | 37 testes (`unittest`), sem rede |

Sem dependências externas: Python 3.9+ e biblioteca padrão.

## Como usar

```bash
cp .env.example .env && set -a && . ./.env && set +a

# 1. Conferir o que mudaria (não grava nada)
python3 sync.py --mode dry-run

# 2. Validar o caso do ticket antes de rodar na base toda
python3 sync.py --mode dry-run --only-customer 143467-LEGAL 143468-TAX

# 3. Backfill inicial via Configurações > Clientes > Manutenção via CSV (ação: Atualização)
python3 sync.py --mode csv --csv-path carga_comercial_da_conta.csv

# 4. Execução definitiva pela API
python3 sync.py --mode apply
```

Em todos os modos é gerado `pendencias_comercial_da_conta.csv` com os clientes
sem comercial resolvido.

Testes:

```bash
python3 -m unittest discover -s tests
```

## Agendamento

A DAG `sensedata_comercial_da_conta` roda às **07h (America/Sao_Paulo)**, depois
da carga diária e antes da janela de disparo das réguas. Variáveis do Airflow:
`sensedata_api_key`, `sensedata_base_url` (opcional) e
`sensedata_cf_value_mode` (opcional).

Alternativa sem Airflow (cron):

```cron
0 7 * * * cd /opt/sensedata/comercial_da_conta && . ./.env && python3 sync.py --mode apply >> /var/log/sensedata_comercial.log 2>&1
```

## Parâmetros a confirmar na instância

A rotina foi escrita com esses pontos configuráveis justamente porque dependem
de como o CF foi criado no ambiente da Thomson Reuters — confirmar antes do
primeiro `--mode apply`:

- **Identificação do CF**: `SENSEDATA_CF_KEY_MODE=name` (alias `comercial_da_conta`)
  ou `id` (então preencher `SENSEDATA_CF_ID`);
- **Formato do valor** aceito pelo campo de lista de usuários:
  `SENSEDATA_CF_VALUE_MODE=email` (padrão), `name` ou `id`;
- **Tipos de contato** que a operação considera comercial (`SENSEDATA_COMMERCIAL_TYPES`);
- **Colunas do CSV** de manutenção (`SENSEDATA_CSV_ID_COLUMN`, `SENSEDATA_CSV_FIELD_COLUMN`),
  que devem bater com o cabeçalho aceito pela tela de Manutenção via CSV.

O caminho seguro é: `--mode dry-run` → `--mode csv` com um lote pequeno →
`--mode apply` na base completa.
