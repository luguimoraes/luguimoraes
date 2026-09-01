# Runbook — Regra de Inatividade de 90 dias (CS Feeling + Anotações)

Configuração das ações **4 (Disparo de Regras de Inatividade)** e **5 (Lembretes e
Acompanhamento da Liderança)** dentro do SenseData.

---

## 1. O que precisa ficar claro antes de abrir a tela de Regras

Regras no SenseData filtram clientes por **campos e indicadores da tabela de clientes**.
Elas não sabem, sozinhas, responder "faz quantos dias que o CS escreveu a última
anotação?". Anotação é conteúdo de timeline, não é campo filtrável.

Consequência prática: **a inatividade precisa virar um campo do cliente antes de virar
regra.** Todo o resto deste runbook depende disso. É o passo 2.

O único campo nativo próximo disso é **Última interação** (data da última *atividade
concluída* do cliente). Ele serve como plano B, mas é global — qualquer atividade
concluída zera o contador, inclusive as que não têm nada a ver com CS Feeling. Não
recomendo usá-lo como fonte primária.

### A regra do "E", não do "OU"

O texto original diz: *"caso o CS fique 90 dias sem atualizar as notas **e** o CS feeling"*.
Isso é uma conjunção, e ela muda a fórmula:

```
dias_sem_atualizacao_cs = MIN(dias desde a última anotação,
                              dias desde a última alteração do CS Feeling)
```

Usa-se `MIN` justamente porque a condição é "os dois parados". Se o CS mexeu em
qualquer um dos dois há 10 dias, o grupo econômico não está abandonado, e o `MIN`
devolve 10 — abaixo do gatilho. Se você usar `MAX` (erro comum), a regra dispara para
cliente que teve anotação ontem só porque o feeling não muda há 4 meses.

Se a intenção do time for na verdade "qualquer um dos dois parado" (mais rígido),
troque para `MAX` no pipeline — é uma linha em `watchdog_cs_feeling.py`. **Vale
confirmar isso com a liderança de CS antes de ligar**, porque muda bastante o volume
de disparos.

---

## 2. Modelo de dados — campos customizados a criar

Menu: **Configurações → Campos Customizados** (ver `campos-customizados.md` para o
detalhe de cada um).

| Exibição | Nome interno | Tipo | Preenchido por |
|---|---|---|---|
| CS Feeling | `cs_feeling` | Lista (Verde / Amarelo / Vermelho) | CS, manualmente |
| Data última atualização do CS Feeling | `dt_ultima_atualizacao_cs_feeling` | Data | automação |
| Data da última anotação do CS | `dt_ultima_anotacao_cs` | Data | automação |
| Dias sem atualização do CS | `dias_sem_atualizacao_cs` | Número inteiro | automação |
| Nível de alerta de inatividade | `nivel_alerta_inatividade` | Lista (`nenhum`, `alerta_90`, `escalonamento_105`, `critico_120`) | automação |
| E-mail do líder de CS | `email_lider_cs` | Texto | integração de RH/estrutura |

> **Atenção ao nome interno.** O SenseData sufixa nomes internos quando há colisão —
> um campo exibido como "CS Feeling" pode ter nome interno `cs_feeling_2`. A API só
> aceita o nome interno real. Confira em Configurações → Campos Customizados e ajuste
> `automacao/.env` antes do primeiro run.

### Por que `nivel_alerta_inatividade` existe

Poderia-se fazer a regra direto em `dias_sem_atualizacao_cs >= 90`. Não faça: essa
condição fica verdadeira **todo dia** a partir do dia 90, e a regra roda diariamente.
O CS recebe o mesmo e-mail 30 vezes seguidas e cria uma pasta de arquivo morto pra
ele. Você mataria a regra em duas semanas.

A alternativa óbvia — condição de igualdade exata (`= 90`) — dispara uma vez só, mas é
frágil: se o job falhar no dia 90, o campo pula de 89 para 91 e o alerta nunca acontece.

Por isso a decisão de "alertar hoje ou não" fica no pipeline, que tem estado (tabela de
controle) e sabe se aquele cliente já foi alertado naquele nível. O campo
`nivel_alerta_inatividade` carrega uma decisão já tomada, e a regra no SenseData vira
uma comparação boba de string. Isso deixa a regra idempotente e tolerante a job que
falhou.

---

## 3. Regra 4 — o disparo de 90 dias

**Configurações → Regras → Criar Regra**

### 3.1 Identificação

- **Nome:** `[CS Ops] Inatividade 90d — CS Feeling e Anotações`
- **Descrição:** `Alerta o CS responsável quando o grupo econômico fica 90 dias sem atualização de anotações E de CS Feeling. Campo-fonte: nivel_alerta_inatividade (pipeline Airflow).`

### 3.2 Filtro de clientes

Quem entra na população avaliada:

| Campo | Operador | Valor |
|---|---|---|
| Status do cliente | igual a | `Ativo` |
| Tipo / nível do cliente | igual a | `Grupo Econômico` (ou o marcador de matriz do seu tenant) |
| CS responsável | diferente de | vazio |
| Data de início do contrato | anterior a | `hoje - 90 dias` |

As duas últimas linhas não são decorativas:

- **CS responsável ≠ vazio** — sem isso a regra tenta enviar e-mail para ninguém e
  aparece como falha de envio no relatório, poluindo a medição da regra.
- **Contrato com mais de 90 dias** — cliente em onboarding ainda não teve tempo físico
  de acumular 90 dias de inatividade. Sem esse filtro, todo cliente novo entra na fila
  de alerta no dia 91 de vida mesmo com o CS trabalhando nele. Se o CS Feeling é
  preenchido já no onboarding, esse filtro fica redundante, mas é barato mantê-lo.

Considere também excluir status `Em cancelamento` / `Churn` — não faz sentido cobrar
CS Feeling de conta que já está saindo.

### 3.3 Condição

| Campo | Operador | Valor |
|---|---|---|
| `nivel_alerta_inatividade` | igual a | `alerta_90` |

Só isso. Toda a lógica de "faz 90 dias" e "já avisei esse aqui" ficou no pipeline.

### 3.4 Periodicidade

- **Diária**, em horário útil (sugestão: **09:00**, dias úteis).
- Agende **depois** do job do Airflow. Se o DAG roda 06:00, a regra às 09:00 dá três
  horas de folga para retry. Regra que roda antes do pipeline lê o campo do dia
  anterior — e no dia da virada isso significa alerta com 24h de atraso ou, pior,
  alerta perdido.
- Se o seu tenant tiver a opção "não repetir disparo para o mesmo cliente em N dias",
  ligue com **N = 30**. É cinto e suspensório: o pipeline já garante isso, mas a trava
  na regra protege contra alguém rodar o DAG duas vezes no mesmo dia.

### 3.5 Ações

Configure as três, nesta ordem de importância:

**a) Criar atividade / tarefa** — é a ação que realmente resolve. E-mail some na caixa
de entrada; tarefa fica na fila do CS e aparece em relatório de pendências.

- Título: `Atualizar CS Feeling e anotações — {{nome_cliente}}`
- Responsável: **CS responsável pelo cliente**
- Prazo: **7 dias corridos**
- Tipo: `Acompanhamento` (ou o tipo que seu tenant usa para tarefas internas)

**b) Enviar e-mail** — o lembrete do item 5. Destinatário: **CS responsável**.
Template em `templates-email.md`, seção "D+90".

Na ação de e-mail existe a opção de **registrar o e-mail como tarefa na visão do
cliente** — deixe ligada. Isso dá rastro na timeline do grupo econômico de que a
cobrança foi feita, o que é exatamente o que a liderança vai querer ver depois.

**c) Disparar alerta (sino)** — notificação in-app para o CS responsável. Custo zero,
pega o CS que está com a plataforma aberta antes do e-mail.

> **Não** dispare playbook nesta regra. Playbook é processo de várias etapas; aqui a
> ação é um único toque. Se no futuro a inatividade virar um processo de recuperação
> de conta (diagnóstico → contato → plano), aí sim vira playbook.

---

## 4. Regra 5 — escalonamento para a liderança

O texto original levanta a possibilidade de **colocar a liderança em cópia nos
alertas**. Cabem duas leituras, e a escolha entre elas é da liderança de CS:

**Opção A — liderança em cópia desde o primeiro disparo.**
Uma regra só (a Regra 4), com o líder em cópia no e-mail. Transparência total.
O custo é ruído: o líder recebe 100% dos alertas, inclusive os que o CS resolve no dia
seguinte. Em times grandes isso vira filtro de e-mail em duas semanas e a liderança
para de ler — que é o oposto do objetivo de "acompanhar de perto".

**Opção B — escalonamento (recomendada).**
A liderança só entra quando o CS já foi avisado e não agiu. O e-mail que chega para o
líder passa a significar alguma coisa, porque é raro.

### 4.1 Escada de escalonamento

| Nível | `nivel_alerta_inatividade` | Quem recebe | Ação |
|---|---|---|---|
| D+90 | `alerta_90` | CS responsável | E-mail + tarefa (7d) + alerta in-app |
| D+105 | `escalonamento_105` | CS responsável, **líder em cópia** | E-mail |
| D+120 | `critico_120` | Líder (CS em cópia) | E-mail + alerta in-app |

D+105 dá ao CS os 7 dias de prazo da tarefa mais uma semana de folga antes de a
liderança ver. D+120 é o ponto em que o problema deixou de ser do CS e virou de gestão.

### 4.2 As duas regras adicionais

Duplique a Regra 4 (a maioria dos tenants tem "duplicar regra" no menu de contexto) e
altere apenas:

**Regra `[CS Ops] Inatividade 105d — escalonamento liderança`**
- Condição: `nivel_alerta_inatividade` **igual a** `escalonamento_105`
- Ação: e-mail para **CS responsável**, com **cópia para o líder** (ver 4.3)
- Sem criação de tarefa — a tarefa de D+90 ainda está aberta; criar outra duplica a fila

**Regra `[CS Ops] Inatividade 120d — crítico`**
- Condição: `nivel_alerta_inatividade` **igual a** `critico_120`
- Ação: e-mail para o **líder**, CS em cópia + alerta in-app para ambos

### 4.3 O ponto de atrito: como endereçar o líder

Este é o item que mais provavelmente vai travar a configuração, então trate com
antecedência. A ação de e-mail de regra endereça, tipicamente, **contatos do cliente**
ou **usuários do SenseData** (como "o CS responsável"). "O gestor do CS responsável"
não é uma relação que a plataforma conheça por padrão — ela sabe quem é o CS do
cliente, não quem é o chefe do CS.

Três saídas, em ordem de preferência:

1. **Campo customizado `email_lider_cs` no cliente.** Sua integração preenche o e-mail
   do líder do CS que atende aquele grupo econômico. A ação de e-mail usa esse campo
   como destinatário/cópia. É a única opção que dá cópia *dinâmica* — se o cliente
   trocar de CS, a cópia acompanha. `watchdog_cs_feeling.py` já tem o gancho para isso
   (`LIDER_POR_CS`).
2. **Lista de distribuição fixa** (`lideranca-cs@suaempresa.com.br`) como cópia
   estática. Funciona em qualquer tenant, é 5 minutos de trabalho. Serve bem se o time
   de CS tem um único líder ou se a liderança prefere ver tudo num canal só.
3. **Regra separada de digest semanal** para a liderança: uma regra semanal
   (segunda-feira) filtrando `nivel_alerta_inatividade ≠ nenhum`, enviando para o líder
   uma visão consolidada. Menos granular, muito menos ruído. Boa combinação com a
   Opção B acima.

**Confirme com o seu CSM da SenseData** se a ação de e-mail do seu plano aceita cópia
(CC) e se aceita um campo customizado como destinatário. Se não aceitar campo
customizado no CC, caia para a saída 2 ou 3.

---

## 5. Antes de ligar — checklist de validação

Não publique as três regras direto em produção. A falha clássica aqui é disparar
alerta retroativo para a base inteira no primeiro run: no dia 1, *todo* cliente que
nunca teve CS Feeling preenchido tem inatividade infinita, e 400 CSs recebem e-mail ao
mesmo tempo. Isso queima a iniciativa antes de ela começar.

1. **Rode o pipeline em `--dry-run`** por 3 dias. Ele calcula e grava os campos, mas
   não marca nada como alertado. Confira a distribuição de `dias_sem_atualizacao_cs`.
2. **Meça o volume do dia 1.** Quantos clientes cairiam em `alerta_90` no primeiro
   run? Se for mais de ~10% da base, use as duas travas de rollout do pipeline:
   - `DATA_ATIVACAO_REGRA` + `CARENCIA_INICIAL=30` no `.env` — os campos continuam
     sendo calculados e gravados, mas nenhum alerta sai nos primeiros 30 dias. É a
     janela para o time preencher o CS Feeling antes de a régua cobrar.
   - `--limite-diario 50` — teto de alertas por execução, do mais inativo para o
     menos. Espalha a onda inicial por semanas em vez de um único disparo em massa.
3. **Crie a regra desativada**, com filtro adicional `CS responsável = você mesmo`.
   Dispare manualmente e confira o e-mail que chega — principalmente se as variáveis
   de merge foram resolvidas (nome do cliente, dias, data) ou vieram literais.
4. **Remova o filtro de teste, ative a regra.**
5. **Monte o acompanhamento no SenseAnalytics.** Dá para criar relatório sobre Regras
   lá — acompanhe disparos/semana e, principalmente, **taxa de conversão**: % de
   clientes que saíram de `alerta_90` para `nenhum` dentro de 7 dias. Essa é a métrica
   que diz se a regra está funcionando ou virando spam. Se ela cair abaixo de ~50%,
   o problema não é a regra, é o processo de CS Feeling.

---

## 6. Pontos a confirmar no seu tenant

Não consegui acessar a documentação autenticada do SenseData desta sessão (os domínios
de ajuda estão bloqueados pelo proxy de rede), então estes pontos vieram de
documentação pública e precisam de confirmação antes da configuração:

- [ ] A ação de e-mail de regra aceita **CC** e aceita **campo customizado** como
      destinatário (bloqueia a seção 4.3)
- [ ] Existe a opção **"não repetir disparo para o mesmo cliente em N dias"** (seção 3.4)
- [ ] Existe a ação **"criar atividade"** no seu plano (seção 3.5a) — em alguns planos
      é "disparar playbook" apenas
- [ ] O nome interno real dos campos customizados criados (seção 2)
- [ ] O endpoint e o header de autenticação da API v2 no seu contrato — a base é
      `https://api.sensedata.io/v2` e a referência é o ReDoc em `/v2/redoc`, mas
      confirme o nome do header da API key antes de rodar o pipeline
- [ ] Se a API expõe leitura de **anotações** por cliente. Se não expuser, o pipeline
      cai para a fonte de dados alternativa (extração/DW) — ver `automacao/README.md`

---

## 7. Arquivos deste diretório

| Arquivo | O que é |
|---|---|
| `runbook-inatividade-90d.md` | Este documento — a configuração das regras |
| `campos-customizados.md` | Especificação dos campos a criar no SenseData |
| `templates-email.md` | Corpo dos e-mails de D+90, D+105 e D+120 |
| `automacao/` | Pipeline que calcula a inatividade e alimenta os campos |
