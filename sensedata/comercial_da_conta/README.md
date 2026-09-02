# Rotina de atualização do campo `comercial_da_conta` (SenseData)

Preenche e mantém atualizado o campo customizado **`comercial_da_conta`** (tipo
*lista de usuários*) na tabela de clientes do SenseData da Thomson Reuters,
resolvendo o nome que está no campo **`Comercial`** do cliente para o **usuário**
correspondente da plataforma.

Origem: ticket Zenvia **496060** — a régua
[regra/304](https://thomson-reuters.sensedata.io/regra/304) enviou o comunicado
com remetente *Relacionamento CS* em vez do comercial da conta.

## Diagnóstico (exports de 02/09/2026 + e-mails disparados)

São **dois problemas independentes**, e o segundo é o que faz o e-mail sair com
o nome errado.

### 1. O campo `comercial_da_conta` nunca foi alimentado

| Medição | Resultado |
| --- | --- |
| Clientes no export | 4.461 (2.070 ativos) |
| CF `comercial_da_conta` (coluna `"Comercial "`) preenchido | **0 de 4.461** |
| Campo `Comercial` (texto, origem) preenchido | 4.442 de 4.461 |
| Usuários na plataforma | 112, todos ativos, sem homônimos |
| Clientes ativos resolvíveis automaticamente | **1.946 (94%)** |
| Clientes ativos sem correspondência | 124 (120 nomes órfãos + 4 sem comercial) |

### 2. Sem valor no campo, a régua cai no CS da conta

Conferência dos comunicados enviados contra a base:

| Cliente | Enviado | Remetente do e-mail | `CS` na base | `Comercial` |
| --- | --- | --- | --- | --- |
| `143493-LEGAL` SINDICATO | 29/08 | Patricia Monteiro | **Patricia Monteiro** ✅ | Luciano Neves ❌ |
| `143506-TAX` AMERICAN TOWER | 01/09 | Fernando Santos | **Fernando Santos** ✅ | Erika Simoes ❌ |
| `143467-LEGAL` MARIMEX | 20/08 | Relacionamento CS | **Relacionamento CS** ✅ | Lorraine Ferreira ❌ |
| `143496-TAX` SUMIDENSO | 29/08 | Relacionamento CS | Fernando Santos¹ | Kelly Cristina Leal ❌ |

¹ Conta registrada em 27/08 e comunicado em 29/08: o CS nomeado entrou depois do
disparo — o export é um retrato de 02/09.

A régua **já está configurada corretamente**: o campo REMETENTE aponta para
*Comercial da Conta*. Como o campo é lido por cliente no momento do disparo e
está nulo em toda a base, não há usuário para usar e a plataforma cai no CS da
conta — por isso o remetente coincide com o `CS` e nunca com o `Comercial`.

Preencher o campo resolve o disparo, sem mexer na régua. Dimensionamento da
mudança: 522 dos 2.070 clientes ativos (25%) têm `CS` = *Relacionamento Customer
Success*, e nos 16 clientes registrados desde 01/08 o `CS` difere do `Comercial`
em **16 de 16** — ou seja, o nome no e-mail muda em praticamente todas as contas.

Como o campo é do tipo *lista de usuários*, ele só aceita um **usuário** da
plataforma: o texto do campo `Comercial` não serve como remetente, e é essa
tradução (nome em texto → usuário) que a rotina faz.

### 3. Saudação vazia ("Olá , Tudo bem?")

Problema de cadastro de contato, não da régua: a saudação usa o nome do contato
destinatário. Nos comunicados enviados para `jaqueline.c.rodrigues` (cópia de
teste) o contato não tem nome preenchido — daí `Olá ,`. No caso do SINDICATO o
contato está cadastrado como `patricia.damasio` (login do e-mail), e foi isso que
saiu no texto. Entre os 16 clientes recentes há 3 com *Sponsor* vazio.

### Pendências que a rotina não resolve sozinha

Três nomes do campo `Comercial` não existem na tabela de usuários (é preciso
criar o usuário ou corrigir o cadastro das contas):

| Nome no campo `Comercial` | Clientes ativos afetados |
| --- | --- |
| Cintia Thomé | 90 |
| Henrique De Oliveira | 28 |
| Alexandre Fornes | 2 |

Mais 4 clientes ativos estão com `N/A AM` ou em branco
(`143449-LEGAL`, `138853-LEGAL`, `135344-GTM`, `135351-GTM`).

## Regra de preenchimento

Para cada cliente ativo:

1. Lê o campo `Comercial` do cliente (`--source customer_field`, padrão). Também
   há o modo `--source contacts`, que usa os contatos ativos de tipo comercial;
2. Descarta marcadores de "sem comercial" (`N/A AM`, `N/A`, vazio);
3. Resolve o nome para um usuário: e-mail quando disponível, senão nome
   normalizado (sem acento, sem diferença de caixa ou espaço duplo);
4. Grava **só se o valor for diferente do atual** (idempotente);
5. **Nunca limpa** valor existente — sem comercial, sem usuário correspondente,
   usuário inativo ou homônimo ambíguo vira linha no CSV de pendências.

Motivos registrados: `matched_by_email`, `matched_by_name`, `up_to_date`,
`no_commercial_assigned`, `no_active_commercial_contact`, `user_not_found`,
`user_inactive`, `ambiguous_user`.

## Estrutura

| Arquivo | Função |
| --- | --- |
| `resolver.py` | Regra de negócio pura (fonte do comercial, match do usuário, plano de atualização) |
| `sensedata_client.py` | Cliente da API v2 (só stdlib): paginação e retry com backoff em 429/5xx |
| `sync.py` | Rotina diária via API: `dry-run`, `apply`, `csv` |
| `backfill_from_export.py` | Carga inicial offline a partir dos exports (sem API) |
| `airflow/dag_sensedata_comercial_da_conta.py` | DAG diária (07h America/Sao_Paulo, após a carga) |
| `sql/auditoria_comercial_da_conta.sql` | Conferência da mesma regra na base espelho |
| `tests/` | 60 testes (`unittest`), sem rede |

Python 3.9+ e biblioteca padrão — sem dependências externas.

## Carga inicial (sem API)

Exportar *Tabelas > Clientes* e *Configurações > Usuários* e rodar:

```bash
python3 backfill_from_export.py \
  --customers customers_20260902.csv \
  --users "Tabela de Usuários.csv" \
  --out carga_comercial_da_conta.csv \
  --pending pendencias_comercial_da_conta.csv
```

Sobe-se `carga_comercial_da_conta.csv` em *Configurações > Clientes > Manutenção
via CSV*, ação **Atualização**. Opções úteis:

- `--value-mode name` gera o nome do usuário em vez do e-mail (usar se o campo
  de lista de usuários não aceitar e-mail);
- `--id-column "ID Sensedata"` troca a chave do arquivo;
- `--status ""` inclui também os clientes inativos;
- `--report relatorio.csv` gera a comparação "remetente hoje (CS) x comercial
  resolvido", usada para dimensionar a troca na régua.

> O export traz duas colunas parecidas: `Comercial` (texto de origem) e
> `Comercial ` — **com espaço no fim** — que é o CF alvo. O script lê as duas
> pelo nome exato; não renomeie as colunas do arquivo exportado.

> **Limitação a confirmar:** a tela de Manutenção via CSV informa que campos
> customizados "somente serão atualizados se forem do tipo data, número ou
> texto". O `comercial_da_conta` é do tipo *lista de usuários*, que pode não
> estar contemplado. Teste com uma linha antes da carga completa; se o campo não
> for gravado, o caminho é a rotina via API (`sync.py --mode apply`).

## Rotina diária (via API)

```bash
cp .env.example .env && set -a && . ./.env && set +a

python3 sync.py --mode dry-run                                   # simula
python3 sync.py --mode dry-run --only-customer 143467-LEGAL      # valida um caso
python3 sync.py --mode apply                                     # grava
```

A DAG `sensedata_comercial_da_conta` roda às **07h (America/Sao_Paulo)**, depois
da carga e antes da janela das réguas. Variáveis do Airflow: `sensedata_api_key`,
`sensedata_base_url` e `sensedata_cf_value_mode` (as duas últimas opcionais).

Testes: `python3 -m unittest discover -s tests`

## Ajustes complementares na régua 304 (UI, fora deste repositório)

O remetente já aponta para *Comercial da Conta* — não precisa mexer nisso. O que
ainda vale configurar:

1. **Condição de guarda**: não disparar quando `comercial_da_conta` estiver
   vazio. Os ~124 clientes sem comercial resolvível continuariam saindo em nome
   do CS, que é o comportamento padrão da plataforma quando o campo é nulo;
2. **Fallback na saudação**: usar o nome do contato e, quando vazio, um texto
   neutro — hoje sai `Olá ,`.

## Parâmetros a confirmar antes do primeiro `apply`

- Formato aceito pelo CF de lista de usuários: **e-mail** (padrão), nome ou ID
  (`SENSEDATA_CF_VALUE_MODE`) — a carga por CSV resolve isso na prática;
- Identificação do CF na API: alias `comercial_da_conta` ou ID numérico
  (`SENSEDATA_CF_KEY_MODE` / `SENSEDATA_CF_ID`);
- Cabeçalho aceito pela tela de Manutenção via CSV (`--out-field-column`).
