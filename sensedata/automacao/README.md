# Pipeline de inatividade — CS Feeling e anotações

Calcula, uma vez por dia, há quanto tempo cada grupo econômico está sem anotação e
sem atualização de CS Feeling, e grava o resultado nos campos customizados que as
regras do SenseData leem.

```
API SenseData ──> watchdog_cs_feeling.py ──> campos customizados ──> Regras ──> e-mail/tarefa
                          │
                  controle_inatividade.sqlite
                  (histórico de feeling + dedup de alertas)
```

## Arquivos

| Arquivo | O que faz |
|---|---|
| `sensedata_client.py` | Cliente HTTP da API v2: retry com backoff, paginação, escrita em lote |
| `watchdog_cs_feeling.py` | A lógica: cálculo, decisão de nível, deduplicação, gravação |
| `dag_cs_feeling_watchdog.py` | DAG Airflow, dias úteis 06:00 America/Sao_Paulo |
| `test_watchdog.py` | 13 testes da lógica de cálculo e deduplicação |
| `test_integracao.py` | Teste ponta a ponta de `executar()` com API falsa |

## Rodando

```bash
cp .env.example .env      # preencha a API key e os nomes internos dos campos
set -a; source .env; set +a
pip install -r requirements.txt

python watchdog_cs_feeling.py --dry-run --verbose   # não grava nada
python watchdog_cs_feeling.py --limite-diario 50    # rollout controlado
python watchdog_cs_feeling.py                       # produção
python test_watchdog.py                             # 13 testes de unidade
python test_integracao.py                           # ponta a ponta, API falsa
```

`--data 2026-06-01` recalcula com outra data de referência, útil para reconstruir a
série antes de ligar as regras.

## As três decisões de projeto que importam

**1. `MIN`, não `MAX`.** `dias_sem_atualizacao_cs = MIN(dias desde a anotação, dias
desde o feeling)`, porque a regra do processo é "os dois parados". Com `MAX`, um
cliente com anotação de ontem dispararia alerta só porque o feeling não muda há quatro
meses. É a inversão mais fácil de fazer sem perceber e a mais cara: enche a caixa do
CS de alerta falso e a régua perde credibilidade em duas semanas.

**2. A decisão de alertar mora no pipeline, não na regra.** A regra do SenseData só
compara `nivel_alerta_inatividade` com uma string. O pipeline é quem sabe se aquele
cliente já foi alertado naquele ciclo.

O motivo é que as duas alternativas dentro do SenseData são ruins. Condição
`dias >= 90` fica verdadeira todo dia a partir do dia 90 e manda o mesmo e-mail 30
vezes. Condição `dias = 90` dispara uma vez só, mas se o job falhar no dia 90 o campo
pula de 89 para 91 e o alerta nunca acontece — falha silenciosa. Com estado no
pipeline, os dois problemas somem: `test_dispara_uma_vez_so` e
`test_job_que_falhou_nao_perde_o_alerta` cobrem exatamente esses casos.

A chave de deduplicação é `(cliente, nível, dt_marco)`, onde `dt_marco` é o dia da
última atualização. Quando o CS finalmente atualiza, o marco anda e um novo ciclo de
inatividade é alertado normalmente — não é um "já avisei uma vez, nunca mais".

**3. O histórico do CS Feeling é reconstruído aqui.** A API v2 expõe o valor *atual*
de um campo customizado, não o histórico de alteração. Sem histórico não dá para saber
*quando* o feeling mudou. Então o pipeline monta o seu: snapshot diário, gravando
apenas quando o valor **muda** de fato — reabrir o cliente e sair sem mexer não conta
como atualização.

O primeiro registro de cada cliente é marcado como **baseline** e não conta como
atualização. A distinção importa mais do que parece. A versão ingênua — gravar
"atualizado hoje" na primeira vez que o pipeline vê o cliente — afirma um fato que o
pipeline não observou: ele viu o *valor*, não uma *mudança*. O efeito seria zerar o
contador da base inteira no dia 1 e deixar a régua muda pelos 90 dias seguintes ao
go-live, justamente a janela em que a liderança está olhando para ela. Enquanto só
existe baseline, o cálculo cai para a anotação, que é um dado real com data real.

`test_integracao.py` fixa esse comportamento: um cliente com anotação de 153 dias
atrás dispara `critico_120` já no primeiro run.

Se o seu contrato expuser histórico de campo customizado nativamente, troque essa
fonte — reconstruir é a saída pragmática, não a ideal.

**4. Acima de 120 dias o alerta silencia.** Não há nível acima de `critico_120`, e a
deduplicação é por `(cliente, nível, dt_marco)` — então um cliente parado há 300 dias
não gera e-mail novo, porque já gerou o dele. Isso é intencional: reenviar o mesmo
alerta indefinidamente treina o time a ignorá-lo.

O reincidente crônico não some, ele muda de canal: `dias_sem_atualizacao_cs` continua
subindo e é por ele que a liderança ordena a fila, seja no digest semanal (seção 4.3
do runbook) seja numa visão salva na tabela de clientes. Alerta serve para interromper
alguém; relatório serve para acompanhar um problema em aberto. São coisas diferentes e
usar alerta como relatório quebra as duas.

## Fonte de dados alternativa (sem endpoint de anotações)

Se `GET /notes` não estiver liberado no seu contrato, `aplicar_anotacoes()` loga um
aviso e segue com `dt_ultima_anotacao` vazia — o cálculo passa a considerar só o
feeling, o que subestima a atividade do CS e gera alerta a mais.

Substitua a função por uma consulta ao seu DW. A assinatura que ela precisa devolver é
`{id_cliente: date}`:

```python
def aplicar_anotacoes(clientes, client, cfg):
    with engine.connect() as conn:          # SQL Server / MySQL / Oracle
        linhas = conn.execute(text("""
            SELECT id_cliente, MAX(dt_anotacao) AS dt
              FROM stg_sensedata_anotacoes
             WHERE autor NOT IN :ignorados
             GROUP BY id_cliente
        """), {"ignorados": tuple(cfg.autores_ignorados)})
    por_cliente = {str(l.id_cliente): l.dt for l in linhas}
    for cliente in clientes:
        cliente.dt_ultima_anotacao = por_cliente.get(cliente.id_cliente)
```

Se você já tem extração do SenseData caindo no DW, esse caminho é melhor que a API de
qualquer forma: é mais rápido, não consome rate limit e o histórico de feeling pode
sair de lá também, dispensando a reconstrução da seção anterior.

## Operação

- **Agende antes das regras.** DAG 06:00, regras 09:00. Regra que roda antes do
  pipeline lê o campo do dia anterior.
- **`max_active_runs=1`** no DAG. Duas execuções simultâneas corrompem o banco de
  controle.
- **`controle_inatividade.sqlite` é estado, não cache.** Apagar significa perder o
  histórico de feeling e o registro de quem já foi alertado — o efeito prático é uma
  segunda onda de e-mails para gente que já recebeu. Coloque em volume persistente e
  no backup. Em cluster com múltiplos workers, migre para o Postgres do próprio
  Airflow ou para o seu DW: SQLite em NFS compartilhado dá corrupção sob escrita
  concorrente.
- **Segredos** vêm de Airflow Variables (ver `carregar_config` no DAG). O `.env` é
  para rodar na sua máquina; não comite o `.env` preenchido.
