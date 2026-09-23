# Casos reais (anonimizados)

Implantações e incidentes de campo, sem nomes de clientes, pessoas ou tickets. Use para reconhecer o padrão e reaproveitar a solução.

---

## Caso 1 — Régua de inatividade do CS (90/105/120 dias)

**Pedido.** "Quando o CS ficar 90 dias sem atualizar as anotações **e** o CS Feeling de um grupo econômico, o SenseData avisa o CS; se ele não agir, a liderança acompanha."

**O ponto não óbvio.** Regras filtram por campos. "Dias desde a última anotação" não é campo: anotação é conteúdo de timeline. A inatividade precisa **virar campo** antes de virar regra. Por isso uma rotina diária (Airflow, dias úteis 06:00) é pré-requisito, não acessório.

**Desenho.**
- Seis campos (veja `campos-customizados.md`, 5.1), um preenchido pelo CS e cinco pela automação.
- `dias = MIN(dias desde a anotação, dias desde a mudança do feeling)`: a condição é "os dois parados". Com MAX, quem anotou ontem receberia alerta porque o feeling não muda há meses. É a inversão mais fácil e a mais cara.
- Anotações de integrações/bots (tickets sincronizados, log de NPS, cobrança) não contam; se contassem, o contador nunca chegaria a 90 e a régua morreria em silêncio.
- A API expõe o valor atual do feeling, não o histórico: a rotina guarda snapshot diário e registra mudança só quando o valor muda. A primeira leitura é **baseline** (não conta como atualização); senão, o go-live zeraria o contador da base toda e a régua ficaria muda por 90 dias, justamente quando a liderança está olhando.
- A decisão de alertar mora na rotina (estado por `(cliente, nível, data do marco)`) e sai no campo `nivel_alerta_inatividade`. A regra só compara texto. Dispara uma vez por nível e ciclo, tolera dia de falha, e silencia acima de 120 (o reincidente vai para uma visão ordenada por dias, não para mais alertas).
- Sem histórico de anotação por API (endpoint não liberado), a rotina lê do DW.

**Regras.**
- Filtro: status Ativo; nível/tipo = grupo econômico; CS responsável não vazio; contrato com mais de 90 dias; excluir em cancelamento.
- Condição: `nivel_alerta_inatividade = alerta_90` (e duplicatas para 105 e 120).
- Recorrência: dias úteis 09:00 (3h depois da rotina); "não repetir para o mesmo cliente em 30 dias" como trava extra, se existir.
- Ações D+90: atividade (prazo 7 dias) > e-mail (com registro como tarefa) > alerta. Sem playbook: é um toque único.
- D+105: e-mail ao CS com o líder em cópia, sem nova atividade. D+120: e-mail ao líder, CS em cópia, e alerta.

**Pontos a confirmar no tenant.** CC e destinatário por campo customizado na ação de e-mail (bloqueia a cópia dinâmica do líder); opção de não repetir por N dias; ação Atividade disponível no plano; nome interno real dos campos; header e endpoints da API; endpoint de anotações.

**Rollout.** Dry-run da rotina por 3 dias; medir o dia 1 (se > 10% da base, carência de 30 dias e limite diário de 50, do mais inativo para o menos); regra inativa com filtro "CS = eu"; ativar; medir conversão de `alerta_90` para `nenhum` em 7 dias.

---

## Caso 2 — Comunicado saindo em nome do CS em vez do comercial

**Sintoma.** Uma régua de comunicação enviou e-mails com remetente "Relacionamento CS" (usuário genérico) em vez do comercial da conta.

**Diagnóstico** (exports + e-mails enviados):
- A régua **já estava certa**: Remetente = "Comercial da Conta" (custom field do tipo lista de usuários).
- O campo estava vazio em 100% da base (nunca foi alimentado). Lido por cliente no momento do disparo e vazio, a plataforma caiu no CS da conta. Por isso o remetente coincidia sempre com o CS.
- O nome do comercial existia num campo **texto** ("Comercial"). Lista de usuários só aceita usuário: era preciso resolver nome → usuário.
- 94% dos clientes ativos resolvíveis automaticamente (nome ou e-mail do usuário, sem acento/caixa/espaço duplo); o resto virou pendência (nomes sem usuário cadastrado, "N/A", vazio).
- Um quarto da base tinha como CS um usuário genérico; nos clientes recentes, o CS diferia do comercial em 100% dos casos: a correção mudava o nome no e-mail de praticamente todas as contas.
- "Olá , tudo bem?": contatos sem nome ou com o login do e-mail no nome. Problema de cadastro, não da régua.

**Solução.**
- Rotina (só biblioteca padrão; DAG diária às 07:00, depois da carga e antes das réguas): lê o campo texto, descarta marcadores de "sem comercial", resolve para usuário ativo, grava **só se mudou**, **nunca limpa**; motivos registrados (`matched_by_email`, `matched_by_name`, `up_to_date`, `no_commercial_assigned`, `user_not_found`, `user_inactive`, `ambiguous_user`).
- Carga inicial por export + Manutenção via CSV foi avaliada, mas a tela avisa que só atualiza custom fields de data, número ou texto: lista de usuários foi pela API.
- Formato aceito pelo campo (e-mail, nome ou id) descoberto gravando **um** cliente e conferindo a Visão 360.
- Guarda na régua: não disparar com o campo vazio. Saudação com fallback neutro.
- Alternativa avaliada: estender a integração que já alimenta o campo texto para gravar também o custom field.

---

## Caso 3 — Conta matriz para grupos econômicos

**Pedido.** Registrar CS Feeling e anotações uma única vez numa conta matriz e refletir em todos os CNPJs (lojas) do grupo; valores editáveis; só lojas ativas; "em tempo real".

**Como ficou** (configuração; a integração está na skill sense-connect, Exemplo 6):
- Conta matriz = cliente sem CNPJ, com o campo Grupo idêntico ao das lojas (idealmente marcada por `tipo_conta = matriz`).
- Integração agendada lê a base espelho e grava nas lojas ativas: `cs_feeling_grupo`, `anotacoes_grupo`, `conta_matriz_nome`, `grupo_atualizado_em` (versão recomendada) — ou sobrescreve o `cs_feeling` da loja (versão mínima, que acaba com o feeling individual e reverte edições feitas na loja).
- Só o que mudou é gravado; loja que sai do grupo ou é cancelada tem os campos limpos.

**Decisões com o cliente** (lista usada na validação):
| Decisão | Sugestão |
|---|---|
| Frequência | 30–60 min + execução manual depois de reuniões estratégicas |
| Feeling individual por loja | Matriz como fonte única; comunicar o time |
| Matriz nos indicadores | Excluir de volumetria (centenas de grupos distorcem contagens e médias) |
| O que é loja inativa | Confirmar se é só cancelada |
| Loja que sai do grupo | Campos de grupo limpos |
| Quem edita a matriz | Só quem responde pela conta |
| Grafia do campo Grupo | Convenção única (grafias diferentes = grupos diferentes) |
| Atividades | **Não replicar**; tentativa anterior foi abandonada porque atividade replicada não se editava |

**Roteiro de validação** (20 min, pela tela, em homologação, com um grupo que tenha lojas ativas e canceladas): criar a matriz; preencher feeling e anotações; executar (N lojas ativas processadas); conferir uma ativa (valores + matriz + data) e uma cancelada (intocada); editar de novo e executar (propaga); executar sem mudar nada (0 processadas).

---

## Caso 4 — Contatos inativados e recriados por uma carga

**Do lado do CS** (a análise técnica está na skill sense-connect, `references/incidentes-reais.md`, Caso 1):
- Sintoma relatado: "toda a base foi inativada e recriada como contatos novos, e os campos preenchidos à mão sumiram". O combinado era inativar só quem não constava no arquivo do cliente.
- Os dados manuais estavam nos registros antigos, inativos: recuperação é migrar campo, não restaurar backup.
- Reativação pela Manutenção via CSV em lotes (veja `manutencao-csv.md`, seção 5).
- Comunicação ao cliente: separar os poucos contatos que realmente não vieram no arquivo (inativação correta) da grande maioria que veio e foi inativada por defeito de chave.
- Validação com uma conta conferida registro a registro (quantos contatos corretos ela deve mostrar) antes e depois.
