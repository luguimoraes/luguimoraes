# Incidentes reais (anonimizados)

Casos de campo, sem nomes de clientes, pessoas ou tickets. Servem para reconhecer o padrão rápido e seguir a investigação que já funcionou. Os números são reais e ilustram a escala.

---

## Caso 1 — A base de contatos era recriada a cada carga

**Contexto.** Cliente B2B com contatos por produto. Duas integrações em sequência, ligadas a um arquivo CSV com nome fixo num bucket S3 da SenseData:
1. "Pré-processamento": lê **todos** os contatos da origem "Integração Sistema" (`load_type: total`), filtra por origem, grava `is_active = False` em **todas** as linhas (`create_column` sem condição) e carrega com `update` pela chave `id_legacy`.
2. "Contatos S3": lê o CSV, cruza com os clientes, monta uma chave composta, grava `status = "Sim"` (→ `is_active`) e carrega com `upsert` em contatos.

**Sintoma relatado.** "Toda a base foi inativada e recriada como contatos novos, mais de uma vez, e os registros novos nascem sem os campos preenchidos à mão" (uma marcação de referência usada pelo time comercial).

**O que a investigação mostrou.**
- Cinco "ondas" em 11 dias. Numa delas, ~7.100 contatos tocados em 13 minutos, 7.096 terminaram inativos.
- Volume por execução: ~3,3 contatos por conta no padrão histórico; numa execução, **~1,0 contato por conta**.
- **Três formatos de chave** convivendo em `id_legacy`: numérica (carga original), `email:documento`, `email:documento:produto` e, por fim, o **código da conta**. Cada troca de composição zerou o match do `upsert`: a base inteira virou "registro novo".
- A composição incluía um campo volátil (produto, guardado no campo "Skype").
- Quando a chave passou a ser o código da conta, todas as linhas da conta calcularam a mesma chave: **só um contato por conta sobreviveu**. Isso explicou o ~1,0 por conta com mecanismo, não correlação.
- 98,6% dos registros antigos inativos reapareciam como registro novo da mesma pessoa na mesma conta: eles **estavam no arquivo**. A inativação não foi por ausência na origem, foi falha de match. Só 1,4% realmente não vieram (para esses, inativar era o combinado).
- Os registros com chave numérica nunca mais casariam com nenhuma execução da carga atual: só podiam ser desativados, nunca reativados. Por isso reapareciam em toda onda.
- A carga não foi pausada depois de aberto o incidente e rodou de novo; cada execução reduzia o que era recuperável por pareamento direto (280 → 120 em uma semana) e sobrescrevia `updated_at`, apagando evidência.
- Os dados manuais **não estavam perdidos**: estavam nos registros antigos, inativos. Recuperação = migrar campo entre registros pareados, não restaurar backup.
- O backup tinha retenção de 7 dias; a primeira onda já estava fora da janela quando o problema foi percebido.

**Correções (CRs).**
- CR-0: pausar as duas integrações; bloquear expurgo de inativos.
- CR-1: chave estável (pessoa + conta; produto como atributo) e documentada.
- CR-1b: migrar as chaves antigas para o formato novo antes de religar.
- CR-2: inativação seletiva (anti-join) no lugar do "inativar todos".
- CR-3: produto no campo certo.
- CR-4: guardrails (match < 90%, desativar > 10%, inserir > 10% → abortar).
- CR-5: deduplicar as gerações, preservando o registro com dado manual.
- Arquivo com data no nome; processar só se for mais novo que a última execução.
- Aceite: duas execuções seguidas → 0 inserções e 0 desativações na segunda.

**Reativação** via Manutenção via CSV (veja a skill sense-data): a manutenção casa por (cliente, e-mail), não pelo ID do contato. Separar em lote A (a dupla acha um contato só: sobe direto) e lote B (acha mais de um: sobe depois de um piloto), e nunca reativar quem já tem outro contato ativo na mesma conta.

**Lições.** Chave estável; nunca inativar em massa; pausar antes de investigar; os dados "perdidos" costumam estar nos registros antigos; medir com queries (`sql-base-espelho.md`, seção 8).

---

## Caso 2 — O Base64 do documento de implantação estava quebrado

**Contexto.** Integração com fonte PostgreSQL lendo a base espelho para propagar um campo da conta matriz para as lojas do grupo. O documento de implantação trazia o SQL revisado e, separadamente, o Base64 para colar na etapa da fonte.

**Achado.** O Base64 não era o SQL revisado: ao decodificar, aparecia `WHERE "group",  IS NOT NULL` (vírgula a mais). O parser do PostgreSQL acusava `syntax error at or near ","`. Colado na etapa, a integração quebraria na primeira execução.

**Correção.** Gerar o JSON/Base64 a partir do `.sql` revisado com um script que faz round-trip (`scripts/integracao_json.py build`) e validar a sintaxe antes (ex.: `pglast`/libpg_query). Encode manual não deve acontecer.

---

## Caso 3 — Propagação matriz → lojas: seis defeitos silenciosos numa query de 20 linhas

Mesma integração do caso 2. A query original fazia `INNER JOIN` das lojas com a matriz (conta sem CNPJ) pelo texto do grupo e gravava com `update` + Sobrescrever.

| Defeito | Efeito | Correção |
|---|---|---|
| Nada garante uma matriz por grupo | Com duas contas sem CNPJ no grupo, cada loja aparece duas vezes e o valor gravado vira "loteria", sem erro | `DISTINCT ON` com desempate `updated_at DESC, id DESC` |
| Reescreve todas as lojas a cada execução | Histórico poluído; regras de "CS Feeling em dia" enganadas | Filtro de delta `IS DISTINCT FROM` |
| `update` não toca linha ausente | Loja que sai do grupo ou é cancelada fica com o dado velho para sempre; o filtro de "lojas ativas" piora isso | Emitir `''` para quem deixou de ser elegível |
| Junção por texto exato | "Rede Alfa" × "REDE ALFA " não casam; a loja não recebe nada | `upper(btrim(...))` nos dois lados |
| Matriz vazia propaga `NULL` com Sobrescrever | Apaga o que a loja tinha | Ignorar matriz vazia (versão mínima) ou limpeza controlada (versão recomendada) |
| "Sem CNPJ" como definição de matriz | Qualquer cadastro incompleto vira matriz | Campo `tipo_conta = 'matriz'`, CNPJ vazio só como fallback |

Outros pontos do caso:
- O documento assumia `status = 'active'`; na base, `status` era **inteiro** (`invalid input syntax for type integer`). Critério provisório: `dt_cancel IS NULL`, até decodificar os códigos.
- `updated_at` era `timestamp without time zone`: a data exibida sairia 3 horas errada sem conversão de fuso.
- O cliente pediu "tempo real"; integração é batch. Alinhado: agendar a cada 30–60 min + "Executar agora" depois de reuniões; hierarquia nativa de contas registrada como pedido de produto.
- A integração exportada apontava para a conexão de **homologação**: trocar na virada.
- Recomendação de não replicar atividades para as lojas (a tentativa anterior do cliente tinha sido abandonada porque atividade replicada não podia ser editada).
- Roteiro de aceite com o cliente em homologação (20 minutos, só pela tela): criar a matriz, preencher, executar (N lojas ativas processadas), conferir uma loja ativa e uma cancelada, editar de novo e executar (propaga), executar sem mudar nada (0 processadas).

---

## Caso 4 — O campo de remetente estava vazio em toda a base

**Contexto.** Régua de e-mail configurada com Remetente = "Comercial da Conta" (um custom field do tipo lista de usuários). Os e-mails saíam em nome do CS, não do comercial.

**Achado.** O campo nunca tinha sido alimentado (0 de 4.461 clientes). Com o campo vazio, a plataforma usa o remetente padrão (o CS da conta). A régua estava certa; faltava o dado. O nome do comercial existia num campo texto, mas lista de usuários só aceita um **usuário** da plataforma: era preciso resolver nome → usuário (e-mail ou nome normalizado) e gravar.

**Pontos para integrações:**
- A Manutenção via CSV só atualiza custom fields do tipo data, número ou texto; lista de usuários ficou para a API.
- Teste o formato aceito (e-mail, nome ou id do usuário) com **um** cliente antes da base toda.
- Nunca limpe valor existente numa rotina de preenchimento; o que não resolver vira lista de pendências.
- Rotina idempotente: grava só quando o valor muda; agendada depois da carga diária e antes da janela das réguas.
Detalhes de configuração na skill sense-data.
