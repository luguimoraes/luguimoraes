---
name: sense-data
description: "Guia de configuração da plataforma SenseData (Zenvia) para transformar casos de uso de Customer Success em regras, playbooks e automações. Cobre regras (gatilhos) e ações, carteirização, playbooks e onboarding playbooks, atividades, jornada da carteira, automação de fases, NPS/CSAT, templates e disparos de e-mail (remetente, marcadores), inadimplência, renovação, churn e inativação, segmentação, tickets/SLA, planos de ação NPS, campos customizados, réguas com escalonamento, manutenção via CSV e API v2. Use quando o usuário pedir para configurar ou revisar uma regra, carteirizar clientes, criar ou associar playbook, montar jornada, disparar NPS, criar template de e-mail, alertar inadimplência ou renovação, tratar churn ou detratores, segmentar por tier/MRR, acompanhar SLA, criar campo customizado, montar régua de inatividade, corrigir remetente ou marcador de e-mail, atualizar clientes em massa, ou desenhar um caso de uso (situação → ação)."
---

# SenseData — Configurações e Casos de Uso (guia completo)

## Overview
Esta skill traduz necessidades de Customer Success em configurações da plataforma SenseData. Um **caso de uso** descreve uma interação com o cliente: as situações e as ações, de pessoas ou ferramentas, que entregam valor. Quase tudo é executado por **Regras** (também chamadas de gatilhos ou automações), que selecionam clientes ou contatos e disparam ações no momento certo. O restante envolve playbooks, jornadas, pesquisas, templates e campos customizados.

Fontes:
- **"Guia de Configurações e Casos de Uso"** (oficial, SenseData): telas, passos e exemplos. Tudo o que vem dele aparece sem marcação.
- **Experiência de campo** (réguas, campos e rotinas implantados em clientes reais): padrões de desenho de regras, campos customizados, remetente dinâmico, Manutenção via CSV, API v2. Esses pontos aparecem marcados como **(campo)**. São padrões observados, não documentação oficial; confirme no tenant antes de afirmar como regra do produto.

Para integrações de dados (SenseConnect: conexões, fontes, carregamento, workflow, agendador), use a skill **sense-connect**.

## Como usar esta skill

### Triagem do pedido
| Pedido | Onde olhar |
|---|---|
| Criar ou entender uma regra | Seções 2 e 3 |
| Carteirizar clientes ou distribuir entre CSs | Seção 4 e Exemplo 3 |
| Criar ou associar playbooks | Seção 5 |
| Registrar atividades | Seção 6 e Exemplo 11 |
| Jornada da carteira e troca de fases | Seções 7 e 8, Exemplo 10 |
| Pesquisas NPS/CSAT | Seção 9, Exemplos 1 e 8 |
| Templates e disparos de e-mail | Seção 10, Exemplo 2, `references/templates-email.md` |
| Inadimplência | Seção 11, Exemplo 5 |
| Renovação | Seção 12, Exemplo 6 |
| Churn e inativação | Seção 13, Exemplo 7 |
| Segmentação (tier, produto, touch) | Seção 14, Exemplo 4 |
| Tickets e SLA | Seção 15, Exemplo 9 |
| Promotores e detratores | Seção 16, Exemplo 8 |
| Criar ou especificar campo customizado | Seção 17, `references/campos-customizados.md` |
| Régua com vários níveis, alerta que dispara todo dia, escalonar para liderança | Seção 18, Exemplo 12, `references/regras-avancadas.md` |
| Remetente errado, marcador que chega literal, saudação vazia | Seção 19, Exemplo 13 |
| Atualizar muitos clientes ou contatos de uma vez | Seção 20, Exemplo 15, `references/manutencao-csv.md`, `references/api-v2.md` |
| Saber se a regra está funcionando | Seção 21 |
| Dado derivado de outras contas (ex.: conta matriz → lojas) | Exemplo 14 e skill sense-connect |
| Algo não funcionou | Seção 22 (diagnóstico) |
| Revisar uma regra antes de ativar | `scripts/ficha_regra.py` e `references/checklists.md` |

### Do pedido à configuração
1. Descreva o caso de uso em pares **Situação → Ação** (veja o Exemplo 1).
2. Para cada par, defina quem é atingido (Clientes ou Contatos), as condições, a recorrência e as ações.
3. Cada par costuma virar uma regra. Se a ação for uma sequência padronizada de tarefas, crie um **Playbook** e dispare-o pela regra, em vez de criar atividades soltas.
4. Crie primeiro os insumos que as ações vão usar: templates de e-mail, formulários, playbooks, campos customizados, jornadas, categorias e tipos de atividade.
5. **(campo)** Se a situação não é um campo filtrável (ex.: "dias desde a última anotação", "dado da conta matriz"), ela precisa **virar um campo** antes de virar regra: por integração (sense-connect), por API ou por outra regra. Regra que aponta para um campo vazio não dispara e não dá erro.
6. Organize as regras em pastas e confira a ordem de execução (seção 2) e a ordem em relação às cargas (seção 18).

### O que levantar antes
Pergunte só o que faltar:
- **Objetivo** do caso de uso e **público**: Clientes ou Contatos.
- **Critérios** que definem quem é atingido: status, fase, MRR, datas, KPIs, NPS, chamados etc.
- **Frequência**: todo dia, uma vez só, dias úteis, intervalos; e se o mesmo cliente pode ser atingido de novo.
- **Insumos**: quais templates, formulários, playbooks, campos e destinatários já existem.
- **Responsáveis**: quem recebe alertas, atividades e playbooks (CS, CS da conta, perfis, usuários).
- **(campo)** **Volume esperado no primeiro disparo**: quantos clientes a regra atinge hoje. Regra nova sobre base antiga costuma disparar para muita gente de uma vez.
- **(campo)** **Exclusões**: clientes em onboarding, em cancelamento, sem responsável, contas técnicas (ex.: conta matriz).

### Formato de resposta recomendado
Para cada regra, entregue esta ficha:
```
Regra: <nome>
1. Informações — Nome | Status | Localização (pasta) | Atingir (Cliente/Contato)
2. Condições — Grupo A: Categoria | Campo | Operação | Valor (… E/OU Grupo B)
3. Agendamento e recorrência — Data de início | Executar regra | Parar execução | Atingir novamente o mesmo cliente
4. Ações — <ação>: <configurações>
```
Depois da ficha, liste os insumos que precisam existir antes, os pontos de atenção da seção 22 e como testar (seção 21). Os nomes de campos, categorias e valores disponíveis variam por ambiente. Quando o guia não mostra o campo necessário, peça ao usuário para confirmar o que aparece na tela dele, em vez de supor.

Para revisar uma ficha, descreva-a em JSON e rode `python3 scripts/ficha_regra.py regra.json`: o script imprime a ficha formatada e aponta armadilhas conhecidas (condição impossível no mesmo grupo, "Maior que 1", disparo diário repetido, atingir Clientes em regra de NPS, remetente dinâmico sem guarda, transferência de atividades desmarcada etc.).

### Arquivos de apoio
| Arquivo | Quando abrir |
|---|---|
| `references/guia-telas.md` | O que cada tela do guia mostra: campos, dicas, botões |
| `references/regras-avancadas.md` | Idempotência, campo de "nível", guardas, ordem regra × carga, rollout, escalonamento, anti-padrões |
| `references/campos-customizados.md` | Convenções, tipos, nome interno, especificação modelo, como o campo aparece em regra, e-mail, API e SQL |
| `references/templates-email.md` | Biblioteca de templates (boas-vindas, NPS, detrator, renovação, inadimplência, churn, inatividade) e boas práticas |
| `references/api-v2.md` | API SenseData v2: base, autenticação, paginação, retry, endpoints observados, gravação de custom fields |
| `references/manutencao-csv.md` | Manutenção via CSV de clientes e contatos: obrigatórios, limitações, lotes, piloto |
| `references/casos-reais.md` | Casos anonimizados: régua de inatividade, remetente = comercial da conta, conta matriz, reativação de contatos |
| `references/checklists.md` | Antes de ativar uma regra, antes de disparar comunicação, auditoria periódica |
| `scripts/ficha_regra.py` | Formata e revisa uma regra descrita em JSON |
| `scripts/nome_interno.py` | Converte nome de exibição em nome interno (`a-z0-9_`) |

## Instructions

### 1. Conceitos
- **Caso de uso**: descreve uma interação com o cliente e todos os processos que a viabilizam, ou seja, as etapas e ações, feitas por pessoas ou ferramentas, que entregam valor. Na prática, lista uma ou mais situações e as ações que devem acontecer em seguida.
- **Regra** (gatilho, automação): executa ações de interação no momento ideal, para o cliente correto. Criar uma regra é ensinar a plataforma a fazer sozinha as rotinas da operação. Ela seleciona grupos de clientes, segmenta perfis e personaliza ações, o que deixa as interações mais relevantes e oportunas e economiza tempo do time.

### 2. Regras
Caminho: **Configurações > Regras** (tela principal do SenseData > ícone de Configurações > Regras).
- O menu de Regras tem: Regras Gerais, Regras Individuais, Regras de Terceiros e Arquivos Exportados.
- A tela tem os botões **Criar Regra** e **Criar Pasta**.
- **Ordem de execução**: as regras rodam na ordem da lista. Arraste e solte para reordenar. Pastas e as regras dentro delas também seguem essa ordem.

**Passo 1 — Informações**
- **Nome**: campo livre. Prefira nomes claros e objetivos (ex.: "Chamados acima do SLA", "NPS - RESPOSTA DETRATORA | ACIMA DE 5K"). **(campo)** Um prefixo de área ajuda a achar e medir depois (ex.: "[CS Ops] Inatividade 90d").
- **Status**: *Ativo* roda na próxima atualização de dados do ambiente; *Inativo* não roda até voltar a Ativo.
- **Localização**: a pasta da regra, ou "Fora das pastas". Crie pastas para organizar; para mover a regra de pasta, altere este campo.
- **Atingir**: **Clientes** ou **Contatos**.

**Passo 2 — Condições** (os gatilhos: as condições em que o cliente ou contato precisa se encaixar para receber a ação)
- Cada condição tem quatro campos: **Categoria**, **Campo**, **Operação** e **Valor**.
  - **Categoria** é a origem do dado (a tabela onde a informação é buscada). Exemplos vistos no guia: Cliente, Contato, Contrato, KPIs Padrões, Atividades, NPS e Suporte – Chamados. Campos customizados aparecem junto da tabela a que pertencem.
  - **Operação** varia conforme o tipo do campo (texto, número ou data). Operações vistas no guia: "Igual a", "Contém", "Maior que", "Menor que", "Há 'X' ou menos dias" e "Em 'X' ou menos dias".
  - **Valor**: o valor a comparar. Em campos de **texto**, maiúsculas e minúsculas fazem diferença.
- Dentro de um grupo, cada condição pode ser duplicada (⧉), adicionada (⊕) ou removida (⊖). As condições de um mesmo grupo são combinadas com **E**.
- "Adicionar Grupo", "Duplicar Grupo" e "Excluir Grupo" gerenciam os grupos. Os grupos são combinados pelo seletor **E/OU** entre eles: E para união de critérios, OU para alternativas.
- "Ver amostra de clientes/contatos" mostra quantos e quais serão atingidos (ex.: "3 condições afetando 126 Contatos").
- Exemplo do guia — clientes inseridos há 3 dias ou menos e com status ativo:
  - Cliente | Data de Inserção no SD | Há 'X' ou menos dias | 3
  - **E** Cliente | Status | Igual a | Ativo

**Passo 3 — Agendamento e recorrência**
- **Data de início**: a regra roda a partir dela, incluindo o próprio dia.
- **Executar regra**: a periodicidade. Opções vistas: Todos os dias, Somente uma vez, Segundas às sextas. O guia também cita uma vez por mês, a cada 15 dias e uma vez por semana.
- **Parar execução**: Nunca, Em uma data, ou Após N ocorrências.
- **Atingir novamente o mesmo cliente**: define se o cliente pode ser atingido mais de uma vez num período, desde que continue dentro das condições. Opções vistas: Nunca, Sempre, A cada intervalo de N dias.

**Passo 4 — Ações**
- Clique em **Adicionar Ação** e escolha na lista. Não há limite: uma regra pode executar várias ações.
- Ações da lista: Alerta, Atualização, Playbook, Atividade, Distribuição automática, Email, SMS, Webhook, Formulário, Relatório, Atualização da Jornada e WhatsApp.
- Clique em **Criar Regra** para salvar.

### 3. Configuração das ações
- **Alerta**
  - Texto do **Alerta** e **Destinatário** (ex.: CS).
  - O alerta interno aparece para o destinatário no ícone de **sino**, no canto superior direito. Todos os usuários também o veem na Visão 360 do cliente.
- **Atualização**
  - **Atualizar atributo para** (ex.: Cliente), **Campo** (ex.: CS, Fase, Porte, Status ou um campo customizado) e **Valor**.
  - Ao atualizar o responsável (CS), há duas opções: "Transferir todas as atividades em aberto atreladas ao antigo responsável" e "Transferir todas as atividades em aberto independente do responsável".
- **Distribuição automática**
  - Escolha os usuários (CSs/CSMs) que vão receber os clientes e, se quiser, um limite de clientes por carteira.
  - A plataforma divide os clientes atingidos em quantidades iguais, ou o mais perto disso possível.
- **Playbook**
  - **Playbook associado** e **Responsável**. A opção "Manter padrão template" usa o responsável configurado no próprio playbook.
  - É possível adicionar categorias, para classificar o playbook.
- **Atividade**: título, instruções e checklist, tipo, categoria, prazo em dias e a caixa que notifica o responsável quando a atividade é criada.
- **Atualização da Jornada**: **Atualizar jornada para** e **Atualizar fase para**.
- **Formulário**
  - **Tipo do formulário** (ex.: Formulário NPS), **Disparar por** (ex.: Email) e **Selecionar template do formulário** (criado antes).
  - **Enviar para**: grupos de destinatários, com a opção "Criar tarefa de formulário".
  - "Remover emails duplicados entre clientes" e **Não enviar para**.
  - **Enviar email às** (hora), com a opção "Não enviar mensagem após o horário".
  - **Remetente** (ex.: CS da Conta) e **Responder para**.
- **Email**
  - **Criar email a partir de**: o template criado antes, com os links "Configurar Email" e "Visualizar Template".
  - **Enviar para** (ex.: Sponsor), com a opção "Criar tarefa de email". Campos **CC** e **CCO** (cópia e cópia oculta).
  - "Remover e-mails duplicados entre clientes", "Ver amostra de destinatários" e **Não enviar para**.
  - **Enviar email às** (o horário do disparo), com a opção "Não enviar mensagem após o horário".
  - **Remetente** (o endereço usado como remetente; ex.: CS da Conta, Implementador da Conta), **Responder-para** (o destino das respostas) e a caixa "Email transacional".
- **SMS, Webhook, Relatório e WhatsApp** aparecem na lista de ações, mas o guia não detalha como configurá-los.

### 4. Carteirização
Carteirizar é colocar o cliente numa carteira, o grupo de clientes atendido por um CS ou CSM. Há três formas.

**Manual** — quando não há um critério específico, ou para migrar clientes de um CS para outro:
1. Vá em Tabelas > Clientes.
2. Busque os clientes e marque a caixa de seleção no início da tabela.
3. Clique em **Editar**, selecione os campos a editar e escolha o usuário responsável.
4. Clique em **Próximo** e confirme. Deve aparecer "Sucesso!".

**Por regra** — por um critério (MRR, segmento, região, porte…): coloque o critério nas condições, defina o agendamento e use a ação **Atualização** no campo do responsável com o novo valor. Veja o Exemplo 3.

**Distribuição automática** — equilibra as carteiras, com um limite opcional por CS: condições, recorrência e ação **Distribuição automática**. No exemplo do guia, os clientes atingidos são divididos entre dois CSs em quantidades iguais ou o mais próximas possível.

### 5. Playbooks
Um playbook é um conjunto de atividades que o usuário deve realizar: ele transforma a estratégia da operação em tarefas com um objetivo. Serve para criar, compartilhar e descrever esse conjunto. Há dois tipos: **Playbook** e **Onboarding Playbook**.
- Exemplo do guia, o Playbook de Execução de Cancelamento: extrair o feedback do cliente, enviar o e-mail do financeiro e desligar o ambiente. As atividades são independentes e podem ser feitas em sequência ou não.

**Criar** — Configurações > Atividades > **Playbook** (ou **Onboarding Playbook**) > **Criar playbook**. A mesma tela também edita playbooks existentes.
1. **Dados gerais**:
   - **Nome**: de acordo com a ação.
   - **Status**: Ativo (disponível para uso) ou Inativo (criado, mas indisponível). Dá para mudar a qualquer momento.
   - **Responsável**: um perfil ou um usuário.
2. **Marcações opcionais**: "Permitir editar playbooks em andamento" e "Considerar somente dias úteis ao calcular previsão de conclusão".
3. **Tarefas do playbook** — para cada tarefa:
   - **Tipo**: novos tipos são criados em "Tipos de Atividades". Tipos vistos no guia: Tarefa, Ligação, Contato, Acompanhamento, Milestone.
   - **Prioridade** (ex.: Normal, Alta) e **Descrição** (o título que descreve a atividade).
   - **Responsável**: não precisa ser o mesmo do playbook; pode ser outro perfil ou usuário.
   - **Categoria**: opcional; serve para gerar gatilhos em outras regras.
   - **Dias**: quantos dias depois da atribuição o prazo começa a contar.
   - **Hora de início**, **Hora de fim** e **Horas utilizadas**.
   - **Adicionar instruções** (como conduzir), **Adicionar checklist** (as etapas, para nada ser esquecido) e **Adicionar notas**.
   - Os ícones ⧉ ⊕ ⊖ duplicam, adicionam e excluem tarefas.
4. Clique em **Salvar playbook**. **Criar Pasta** ajuda a organizar.
- **Importante:** um playbook ativo e associado a uma regra é disparado quando a carga roda. Sem regra associada, ele só pode ser incluído manualmente.

**Onboarding Playbook**
- As ações são divididas em **fases**, totalmente customizáveis (ex.: Kick-off, Formação, Acompanhamento, Encerramento). O cliente avança de fase conforme as atividades são concluídas.
- Diferenciais: quadro Kanban mostrando onde cada cliente está, prazo de cada atividade em dias e barra de progresso com o percentual concluído.
- Na criação, cada tarefa também recebe a **fase** a que pertence e o **prazo final em dias** para conclusão.
- Visualizações: lista, quadro e tabela. As atividades aparecem separadas em concluídas, a vencer hoje, atrasadas e todas.

**Associar um playbook a um cliente**
- *Onboarding Playbook, manual*:
  1. Na barra superior, clique em **Onboarding** > **Adicionar Playbook**.
  2. Preencha Cliente, Playbook e Responsável e clique em **Adicionar Playbook**.
  - Para só visualizar, procure o cliente no quadro.
- *Playbook, manual*:
  1. Vá em Tabelas > Clientes e abra o cliente.
  2. Na aba **Atividades**, clique em **Adicionar Playbook**.
  3. Preencha Cliente, Playbook e Responsável e clique em **Adicionar Playbook**.
  - Para só visualizar, procure o playbook na lista.
- *Por regra*: em Configurações > Regras > Criar Regra, defina o público nas condições e escolha a ação **Playbook** > Playbook associado. Para incluir um playbook numa regra que já existe, basta editá-la.

### 6. Atividades
Atividades registram todas as ações feitas com os clientes, para uma visão completa das interações. Quando várias ações seguem um padrão e uma sequência, prefira um playbook.

**Criação manual**:
- Onde criar: tela **Atividades** > **Adicionar atividade**, ou **Visão 360** do cliente > aba **Atividades** > **Adicionar atividade**.
- Campos (os obrigatórios são marcados com *): cliente (a quem a atividade é atribuída), receptor da atividade, título, tipo, categoria, usuário responsável pela execução e notas.
- Também dá para anexar arquivos, criar checklist e instruções e marcar a atividade como concluída.
- Os tipos ficam em **Configurações > Atividades > Tipos de Atividades**; as categorias, em **Configurações > Atividades > Categorias**.

**Por regra**: quando uma ação pontual precisa acontecer num momento conhecido (ex.: sempre que entra um cliente novo, o CS verifica os contatos cadastrados), use a ação **Atividade** (seção 3). Veja o Exemplo 11.

**Visão 360**:
- Abas: Visão 360, Atividades, Arquivos, Contratos, Histórico, Lista de contatos, Notas e Formulários.
- Na aba Atividades, os filtros são: Todos, Vencem hoje, A vencer, Atrasadas e Em pausa.

**(campo)** Atividade × anotação: anotação (nota da timeline) não é um campo filtrável em regras. Se uma regra precisa de "dias desde a última anotação", esse número precisa ser calculado fora e gravado num campo customizado (Exemplo 12). O campo nativo **Última interação** (data da última atividade concluída) é global: qualquer atividade concluída zera o contador.

### 7. Jornada da Carteira
A Jornada da Carteira organiza as fases do relacionamento com o cliente, em vários tipos de produto, e melhora a visualização da base. Com ela você acompanha o ciclo de vida de cada cliente, as etapas da jornada e os indicadores.

**Habilitar no perfil**:
1. Vá em Configurações > Contas > Perfis e clique em Editar no perfil desejado.
2. Em "Definir menu", selecione **Telas Jornada da carteira** e clique na seta para a direita.
3. Em "Definir ações", selecione **Jornada da carteira** e **Regras** (esta última permite automatizar a jornada) e clique na seta.
4. Clique em **Salvar perfil**.

**Criar**:
1. Vá em Configurações > Clientes > Jornada da carteira > **Criar jornada**.
2. Preencha o nome e os **Perfis com acesso**.
3. Para cada fase, defina nome, **tempo estimado em dias** e cor. O ⊕ à direita adiciona fases.
4. Clique em **Salvar**.
- O tempo estimado precisa ser realista, porque serve de indicador de atraso.
- O limite é de 20 fases, ligado à quantidade de cores disponíveis.

**Visualizar**:
- Na barra superior, clique em **Jornada da carteira** e escolha a jornada.
- Formas de ver: visão geral (cada fase expande pela seta à direita), por fase, ou em Kanban (ícone à direita).
- A tela tem Adicionar cliente, Exportar, Pesquisar cliente, Ordenar por, Minha carteira e Filtros.

**Adicionar clientes**:
- *Manual*: clique em **Adicionar cliente**, escolha a fase e o cliente, e salve.
- *Por regra*:
  1. Defina nas condições as situações que levam o cliente à jornada ou fase.
  2. Use a ação **Atualização da jornada**, preenchendo "Atualizar jornada para" e "Atualizar fase para".
  3. Salve e execute, confira de novo os clientes selecionados e clique em **Disparar regra**.

**Exemplos de organização**:
- *Por colaborador*: ex.: a jornada "Carteira Onboarding", com uma aba por pessoa do time. O líder vê a perspectiva de cada liderado sobre seus clientes.
- *Por comportamento da base*: ex.: a jornada "CS Felling", com as fases Sem mapeamento, Em cancelamento, Integração Instável, Baixo Engajamento, Troca de Sponsor e Insatisfação Produto. Dá visibilidade a quem é responsável pelas ações com esses clientes.

**Jornada × Onboarding Playbook**: a Jornada mede em que etapa o cliente está, definida manualmente ou por regra; o foco são os indicadores do momento do cliente. O Onboarding Playbook avalia o cliente pelas atividades em andamento ou concluídas; o foco são as tarefas que o time interno precisa executar.

### 8. Automação de fases
Troca a fase do cliente a partir de marcos, como a conclusão de atividades ou playbooks:
1. **Condições**: o marco (ex.: conclusão do playbook de Onboarding).
2. **Ação**: **Atualização** do Cliente para a nova fase (ex.: "Adoção").
3. Outras ações, se precisar (ex.: disparar o playbook de "Adoção").

Veja o Exemplo 10.

### 9. Pesquisas (NPS, CSAT, formulário livre)
**Criar o formulário**:
1. Vá em Configurações > Comunicação > **Templates de formulário** > **Criar formulário**.
2. Escolha o template (NPS, CSAT ou outro) e defina o nome.
3. Edite o formulário e clique em **Salvar**.
- Para outros tipos de pesquisa, ou para mais personalização, use "Formulário livre".

**Disparo por regra**: em Configurações > Regras > Criar Regra, defina as condições, o agendamento e a recorrência, use a ação **Formulário** (tipo, forma de disparo e template; para quem enviar, horário e remetente; seção 3) e clique em **Criar Regra**.

**Disparo manual pela Visão 360**:
1. Na Visão 360 do cliente, vá em **Formulários** > **Adicionar formulário**.
2. Escolha o tipo (NPS ou livre), o formulário, o meio de envio (SMS ou e-mail) e o contato.
3. Se quiser que o disparo fique registrado como atividade concluída, ative a flag "Criar tarefa de formulário".
4. Clique em **Prosseguir**.

### 10. E-mails
O SenseData tem funções de customização e disparo de e-mails para padronizar a comunicação e reduzir tarefas manuais (boas-vindas, newsletter, avisos). Os templates podem ter **formulários integrados**, que facilitam o acesso às pesquisas e seguem a identidade visual da empresa.

**Criar o template**: Configurações > Comunicação > **Templates de email** > **Criar template**. **Criar Pasta** ajuda a organizar.
- **Editor**:
  - Arraste os blocos da coluna da direita para o corpo do e-mail: Colunas (organizar e dividir o conteúdo), Título, Texto, Imagem, Botão (CTA para links externos, bom para a taxa de cliques), Divisor (separar assuntos no mesmo envio), HTML, Menu e Social (redes da empresa).
  - Todo bloco pode ser duplicado ou apagado a qualquer momento.
  - O texto aceita fonte, cor, alinhamento e espaçamento. O e-mail também pode ser editado direto em HTML.
- **Mesclar Marcadores** insere variáveis, campos customizados e KPIs (ex.: o nome do cliente ou a assinatura do remetente).
- Botões do editor: Enviar Teste, Salvar, Salvar e Sair.
- Dicas do guia:
  - Use um título claro e descritivo, que diga o objetivo sem abrir a configuração (ex.: "Email de boas-vindas ao Onboarding").
  - Escreva um assunto que estimule a abertura.
  - Antes de enviar a clientes, faça um teste para o seu próprio e-mail e confira links, imagens, fontes e erros de digitação.

**Disparo por regra**: ação **Email** (seção 3). Veja o Exemplo 2 e a seção 19 (remetente e marcadores).

**Envio manual pela Visão 360**:
1. Na Visão 360, vá em **Lista de Contatos** e clique no ícone de e-mail. Alguns campos já vêm preenchidos.
2. Preencha "Responder para" e o Assunto.
3. Escolha um template e ajuste, ou escreva e formate o texto.
4. Clique em **Enviar**.

### 11. Inadimplência
Acompanhe os pagamentos em atraso, identifique padrões e aja cedo; os alertas permitem resolver de forma amigável e evitar prejuízos maiores.
- **Tabela Clientes**: Tabelas > Clientes > coluna **"Títulos Vencidos"**. Aplique filtros para ver quem tem títulos em atraso.
- **Tabela Financeiro**: Tabelas > Financeiro > coluna **"Status Financeiro"**. A plataforma preenche essa coluna a partir da data de pagamento: **Pago**, **Vencido** ou **Em aberto**. Filtre pelos títulos vencidos.
- **Alerta**: uma regra avisa o CS quando o cliente fica inadimplente e, se quiser, também manda um e-mail ao cliente. Veja o Exemplo 5.

### 12. Renovação
Acompanhe os contratos perto de expirar usando os dados da tabela **Contratos**. Isso dá tempo para criar pontos de contato que favoreçam a renovação e para mapear upsell e cross-sell.
- Os exemplos do guia usam 60 dias antes do fim do contrato, mas o ideal é ajustar para o momento em que as ações funcionam melhor com seus clientes.
- Tudo depende de um cadastro de contratos consistente.
- Alerta, e-mail e playbook de renovação: veja o Exemplo 6.

### 13. Churn e inativação
**Fluxo de churn**
- Pode começar a partir de um playbook de cliente em crise, que reúne as ações feitas quando se percebe que o cliente pode pedir, ou já pediu, o cancelamento.
- A última atividade desse playbook indica se houve reversão. Se não houve, esse é o gatilho do churn.
- Para marcar isso, aplique a **categoria "Não revertido"** ao concluir a atividade. A categoria é criada em Atividades > Categorias.
- Ações sugeridas pelo guia:
  - e-mail de cancelamento, explicando as etapas pelas quais a empresa vai passar;
  - e-mail comunicando o financeiro;
  - playbook para o CS/CSM com as ações necessárias para o cancelamento;
  - atualização do status para "Em cancelamento".
- Veja o Exemplo 7.

**Inativar o cliente** (registrar a inativação, a data e o motivo do cancelamento):
- *Manual*:
  1. Na Visão 360, clique no ícone de edição do campo **Status** e escolha "Inativo".
  2. Escolha o **Motivo do Cancelamento** e detalhe nos comentários o que for importante.
  3. Se o cancelamento aconteceu em outro dia, ajuste a **Data de Alteração**.
- *Por regra*: ação **Atualização** > campo **Status** > o novo status. A regra altera **só o status**; a data e o motivo do cancelamento precisam ser preenchidos à mão.
- Os status são configurados em **Configurações > Status dos Clientes**, e os motivos em **Configurações > Motivos de Cancelamento**.

### 14. Segmentação por produto, plano ou serviço
Segmentar permite estratégias por perfil de cliente. Por exemplo, segmentando pelo MRR, os clientes maiores podem ter mais touchs proativos e os menores uma jornada mais automatizada. Há várias formas de segmentar: por produto, por touch (low, mid, high), por MRR etc.

**Criar o campo customizado**:
1. Vá em Configurações > Clientes > **Campo customizado** > **Novo campo**.
2. Preencha:
   - **Título do campo**: indique a segmentação.
   - **Identidade do campo**.
   - **Origem** do preenchimento.
   - **Tipo do campo**.
   - **Máscara** (opcional).
   - **Condição**.
3. Clique em **Salvar**.

**Criar as regras de preenchimento**:
1. Crie uma pasta para a segmentação (**Criar pasta**) e coloque nela todas as regras dessa segmentação.
2. Em cada regra, defina as condições daquele segmento e use a ação **Atualização**: tabela de origem > o campo customizado > **Valor** igual ao nome do segmento.
3. Repita para os outros segmentos, ajustando Nome, Condições e Valor. Duplicar as regras agiliza.
- Cada segmento deve ter regras específicas, para que os clientes de um mesmo segmento tenham todas as características em comum.
- Sugestão do guia: além do campo, crie uma Jornada da Carteira baseada nos segmentos.
- Veja o Exemplo 4.

### 15. Tickets e SLA
Mesmo não sendo o responsável por resolver os chamados, o CS precisa acompanhar os abertos, os resolvidos e principalmente os que estouraram o prazo.

**Regra**: condição pelo total de chamados acima do SLA; ações de alerta ao CS ou de e-mail para a equipe de suporte. Veja o Exemplo 9.

**Quando o CS recebe o alerta**, o guia sugere:
- verificar se algum chamado já pode ser finalizado;
- se nenhum puder, avisar o cliente de que está acompanhando e fazendo o possível para encerrá-los logo;
- se necessário, escalar internamente para que os times responsáveis priorizem.

**Visualizar** (Minha carteira > Tabelas):
- **Clientes**: campo **"Chamados acima do SLA"**, com o filtro "Maior que 0".
- **Suporte**: campo **"Situação SLA"**.
  - Chamado em aberto (sem data de conclusão) com SLA posterior à data de hoje: dentro do prazo.
  - Chamado em aberto com SLA anterior à data de hoje: atrasado.
  - Chamado com data de conclusão: não tem situação SLA e aparece como "---".

**Cards na Visão 360**:
1. Vá em Configurações > Clientes > **Cards Visão 360** > **Adicionar card** e escolha o indicador (ex.: Tickets em aberto).
2. Clique no card, escolha os gráficos e clique em **Salvar**.
3. Na Visão 360 do cliente (Tabelas > Clientes > busca), os cards aparecem. "Ver detalhes" abre os gráficos.

### 16. Planos de ação NPS
Tão importante quanto receber as respostas de NPS é dar uma devolutiva e tratar cada uma. O guia cita dois dados: um cliente infeliz conta a experiência negativa para 9 a 15 pessoas (White House Office of Consumer Affairs), e um cliente fiel é 10 vezes mais rentável que um cliente de primeira compra (Institute of Customer).

- **Promotores e neutros**: e-mail de agradecimento disparado por regra depois da resposta. O template de exemplo se chama "NPS promotora ou neutra com feedback" e tem saudação com o marcador do cliente, agradecimento pelo feedback e a assinatura do remetente.
- **Detratores**: uma regra aciona o CS da conta para contatar o cliente e entender o que está acontecendo, mostrando que o feedback está sendo tratado. Dá para limitar a ação aos detratores estratégicos (ex.: MRR acima de 5 mil). Veja o Exemplo 8.
- **Atinja Contatos, não Clientes**: numa empresa com 10 colaboradores em que 9 deram nota promotora e 1 deu nota detratora, a ação deve atingir só o contato detrator. Uma regra que atinge o cliente inteiro torna muito mais trabalhoso separar promotores de detratores.
- **Detratores de MRR menor**: use outra estratégia, também com uma regra que atinge contatos: outro tipo de comunicado, ou uma pesquisa **CSAT** para entender melhor os motivos da nota.

### 17. Campos customizados (campo)
O guia mostra o campo customizado só na segmentação (seção 14). Na prática, ele é o que permite regras sobre qualquer coisa que o produto não tem nativamente. Detalhes e especificação modelo em `references/campos-customizados.md`.
- **Onde**: Configurações > Clientes > Campo customizado > Novo campo (para clientes); há campos customizados também em contatos.
- **Nome interno**: minúsculas, `_` entre palavras (`cs_feeling`, `dias_sem_atualizacao_cs`). Em colisão de nome, a plataforma pode sufixar (`cs_feeling_2`): **confira o nome interno gerado**. API, integrações e SQL usam o nome interno, nunca o rótulo. Use `scripts/nome_interno.py`.
- **Tipos** vistos: texto, número (inteiro), data, lista de seleção única, lista de seleção múltipla, lista de usuários.
- **Quem preenche**: pessoa, regra (ação Atualização), integração (SenseConnect) ou rotina via API. Campo derivado deve ser **não editável** na tela; senão alguém sobrescreve e a automação reverte no dia seguinte.
- **Obrigatoriedade**: evite em campos subjetivos (preenchimento defensivo: todo mundo marca o valor do meio para conseguir salvar).
- **Listas**: poucos valores, com a grafia exata que as regras vão comparar. Para valores lidos por automação, use `minusculo_com_underline` (`alerta_90`), igual ao código; "Alerta 90" × "alerta_90" é um bug que não dá erro em lugar nenhum.
- **Lista de usuários** só aceita um usuário da plataforma. Texto com o nome da pessoa não serve; é preciso resolver para o usuário.
- **Vazio** é um estado: regras que usam o campo precisam de uma decisão para quando ele estiver vazio (excluir, ou tratar como valor padrão).

### 18. Padrões avançados de regras (campo)
Resumo; o detalhe está em `references/regras-avancadas.md`.
1. **A condição roda todo dia.** Com "Executar: Todos os dias" e "Atingir novamente: Sempre", uma condição como "dias sem atualização ≥ 90" fica verdadeira do dia 90 em diante e dispara **todo dia**. Com "= 90", dispara uma vez, mas se o cálculo falhar no dia 90 (o campo pula de 89 para 91) o alerta nunca acontece. Soluções, da mais simples à mais robusta:
   - "Atingir novamente o mesmo cliente: Nunca" ou "A cada intervalo de N dias";
   - uma janela ("≥ 90 e < 97") com intervalo de reenvio compatível;
   - **campo de nível** calculado fora (ex.: `nivel_alerta_inatividade` = `nenhum`/`alerta_90`/`escalonamento_105`/`critico_120`), que volta para `nenhum` depois de disparar. A regra só compara texto. É idempotente e tolera falhas.
2. **Guardas.** Toda régua de comunicação precisa excluir quem não deve receber: responsável vazio, cliente em onboarding (contrato recente), em cancelamento/churn, contas técnicas, campo usado no e-mail vazio.
3. **Ordem.** A regra precisa rodar **depois** da carga ou rotina que alimenta o campo que ela lê, com folga para uma nova tentativa (ex.: rotina às 06:00, regra às 09:00). Regra antes da carga lê o valor do dia anterior.
4. **Rollout.** Nunca ative direto uma régua nova sobre a base inteira. Crie a regra **inativa**, confira a amostra, meça o volume do primeiro disparo, teste com uma condição extra que só atinja você (ex.: "CS responsável = eu"), confira o e-mail que chega e só então ative. Se o primeiro disparo for grande (ex.: > 10% da base), use carência ou limite diário na rotina que calcula o campo.
5. **Escalonamento.** Liderança em cópia de 100% dos alertas vira filtro de e-mail. Prefira degraus: D+X para o CS (e-mail + atividade + alerta), D+X+15 com líder em cópia, D+X+30 para o líder. Cópia **dinâmica** para o líder de cada CS exige um campo com o e-mail do líder e que a ação de e-mail aceite campo customizado como destinatário/cópia (confirme no tenant); senão, lista fixa ou digest semanal.
6. **Atividade > e-mail.** Para cobrar uma ação interna, a atividade é o que resolve (fica na fila e em relatório); o e-mail lembra; o alerta (sino) pega quem está com a plataforma aberta. Playbook só quando a resposta é um processo de várias etapas.
7. **Uma regra, uma decisão.** Não misture populações que pedem ações diferentes numa regra só; duplique a regra e ajuste.

### 19. Remetente, destinatários e marcadores (campo)
- **Remetente dinâmico** (ex.: "CS da Conta", "Implementador da Conta" ou um campo customizado do tipo lista de usuários, como "Comercial da Conta"): o valor é lido **por cliente, no momento do disparo**. Se o campo estiver vazio, a plataforma usa o remetente padrão (na prática, o CS da conta). Sintoma: "o e-mail saiu em nome da pessoa errada". Correções: alimentar o campo (seção 20) e pôr uma **condição de guarda** na regra (campo "não vazio"), ou aceitar o fallback de forma consciente.
- **Destinatários**: Sponsor, contatos por tipo, usuários (CS da conta). "Ver amostra de destinatários" antes de ativar. "Remover e-mails duplicados entre clientes" evita que o mesmo contato receba N cópias quando atende várias contas.
- **Marcadores**: insira sempre pelo botão **Mesclar Marcadores**. Marcador digitado à mão (ex.: `{{nome_cliente}}`) chega literal no e-mail se a sintaxe do tenant for outra. Campos customizados aparecem no menu pelo nome.
- **Saudação vazia** ("Olá , tudo bem?"): o marcador de nome do contato está vazio (ou o nome cadastrado é o login do e-mail). É cadastro de contato, não defeito da regra. Use saudação neutra ou garanta o nome no cadastro.
- **Link do cliente**: se o objetivo do e-mail é fazer alguém atualizar um registro, o link direto para o cliente é o elemento mais importante do template.
- **Horário**: "Enviar email às" + "Não enviar mensagem após o horário" evitam e-mail de madrugada quando a carga atrasa.
- **Email transacional**: marque em comunicações operacionais (ex.: pedido de cancelamento), conforme a política do tenant.

### 20. Atualização em massa: Manutenção via CSV e API (campo)
Além da edição em massa pela tabela (seção 4), há dois caminhos. Detalhes em `references/manutencao-csv.md` e `references/api-v2.md`.
- **Manutenção via CSV** — Configurações > Clientes > Manutenção via CSV (há também para contatos). Ação **Atualização**. Aceita CSV ou TSV.
  - Clientes: identifica por ID Original ou ID Sensedata.
  - Contatos: obrigatórios Cliente (ID Original ou ID Sensedata) + Telefone 1/Telefone 2 e/ou E-mail. Casa por (cliente, e-mail), **não** pelo ID do contato.
  - Grava só as colunas presentes no arquivo: mande só a chave e o que muda.
  - A tela avisa que campos customizados "somente serão atualizados se forem do tipo data, número ou texto": listas (inclusive lista de usuários) podem não ser gravadas. Teste com uma linha.
  - Suba um piloto pequeno, confira na Visão 360, depois o resto em lotes.
- **API v2** — `https://api.sensedata.io/v2` (documentação ReDoc em `/v2/redoc`). Autenticação por API key num header cujo nome varia por contrato (confira); paginação `page`/`per_page`; respeite 429 (`Retry-After`) com backoff. Grave custom fields pelo **nome interno**. Útil para rotinas diárias (ex.: preencher um campo a partir de outro, calcular dias sem atualização).
- Em qualquer caminho: idempotente (só grava se o valor mudou), **nunca limpa** valor existente sem decisão explícita, e o que não resolver vira lista de pendências.

### 21. Acompanhar se a regra funciona (campo)
- Antes de ativar: "Ver amostra de clientes/contatos" e "Ver amostra de destinatários"; "Enviar Teste" no template.
- Depois de ativar: crie relatórios sobre regras no SenseAnalytics: disparos por semana e, principalmente, **taxa de conversão** (ex.: % de clientes que saíram da condição dentro do prazo da atividade). Conversão baixa indica problema de processo, não de regra.
- Alerta serve para interromper alguém; relatório serve para acompanhar um problema em aberto. Reincidente crônico sai do alerta e vai para uma visão ordenada (ex.: por "dias sem atualização").

### 22. Diagnóstico de problemas comuns
| Sintoma | Causa provável | O que fazer |
|---|---|---|
| A regra não roda | Status Inativo; regras ativas só rodam na próxima atualização de dados | Ative e aguarde a atualização |
| A regra atinge clientes errados | Condição mal definida; texto diferencia maiúsculas e minúsculas | Confira em "Ver amostra de clientes" e revise a grafia do Valor |
| Deveria atingir "A **ou** B", mas não atinge ninguém | As condições estão no mesmo grupo, que combina com E | Separe em grupos e use **OU** (como no Exemplo 4) |
| Cliente atingido várias vezes, ou nunca mais | Configuração de "Atingir novamente o mesmo cliente" | Ajuste para Nunca, Sempre ou A cada intervalo de N dias |
| A regra parou de rodar | "Parar execução" com data ou número de ocorrências | Revise o Passo 3 |
| Uma regra depende do resultado de outra | Ordem de execução | Arraste para reordenar regras e pastas |
| O playbook não dispara | Playbook inativo ou sem regra associada | Ative e associe a uma regra, ou inclua manualmente |
| A Jornada da carteira não aparece | A tela não está habilitada no perfil | Habilite "Telas Jornada da carteira" no perfil |
| Não é possível automatizar a jornada | A ação "Regras" não está habilitada no perfil | Em "Definir ações", selecione "Jornada da carteira" e "Regras" |
| Não dá para criar mais fases | Limite de 20 fases | Revise a estrutura da jornada |
| Depois da carteirização por regra, as atividades ficaram com o CS antigo | A transferência não foi marcada | Marque a transferência de atividades em aberto na ação Atualização |
| Cliente inativado por regra ficou sem data e motivo | A regra altera só o status | Preencha data e motivo à mão na Visão 360 |
| Todos os contatos do cliente receberam a ação de detrator | A regra atinge Clientes | Configure "Atingir: Contatos" |
| Não encontro o alerta | Local de exibição | Sino (canto superior direito) do destinatário, ou a Visão 360 |
| A renovação não pega os clientes certos | Cadastro de contratos inconsistente | Revise a tabela Contratos |
| O e-mail saiu com erro | Faltou teste | Use "Enviar Teste" antes de ativar a regra |
| **(campo)** O mesmo e-mail chega todo dia para o mesmo cliente | Condição "≥ X" + Todos os dias + Atingir novamente Sempre | Nunca/intervalo, janela, ou campo de nível (seção 18) |
| **(campo)** A régua nova nunca disparou, sem erro | O campo lido está vazio (rotina não rodou, nome interno errado, valor com grafia diferente) | Confira o nome interno, a grafia exata e se a rotina/carga roda antes da regra |
| **(campo)** O alerta chegou com 1 dia de atraso ou foi perdido | Regra roda antes da carga que alimenta o campo | Agende a regra depois da carga, com folga |
| **(campo)** No primeiro dia, centenas de pessoas receberam alerta | Régua ativada sobre base antiga sem carência | Rollout: regra inativa, amostra, teste só para você, carência/limite (seção 18) |
| **(campo)** O e-mail saiu em nome do CS, não da pessoa configurada no remetente | O campo do remetente está vazio naquele cliente; a plataforma usa o padrão | Alimente o campo e ponha guarda "não vazio" (seção 19) |
| **(campo)** O marcador chegou literal (`{{nome}}`) | Marcador digitado à mão com a sintaxe errada | Insira pelo "Mesclar Marcadores" |
| **(campo)** "Olá , tudo bem?" | Contato sem nome cadastrado | Saudação neutra ou corrigir cadastro |
| **(campo)** A regra não enxerga um campo customizado novo | Campo criado, mas ainda sem valores; ou procurado pelo rótulo errado | Confira a tabela do campo (cliente × contato) e se já há valores |
| **(campo)** A Manutenção via CSV não gravou um campo | Tipo lista (seleção ou usuários) não é atualizado por CSV; ou coluna com nome diferente | Teste com uma linha; use a API para listas |
| **(campo)** A Manutenção via CSV de contatos criou/ativou contato duplicado | A manutenção casa por (cliente, e-mail) e a dupla acha mais de um contato | Separe lotes sem ambiguidade; piloto antes (Exemplo 15) |
| **(campo)** O valor que o CS editou voltou sozinho | Uma integração ou rotina é dona do campo e sobrescreve | Defina a fonte da verdade; campo derivado não editável |
| **(campo)** Painéis de volumetria contam contas "técnicas" | Contas criadas para automação (ex.: conta matriz) entram nas contagens | Exclua por um campo `tipo_conta` nos painéis e segmentações |

## Examples

### Exemplo 1 — Caso de uso "Envio de formulário NPS" (do pedido às regras)
Pedido: "O cliente recebe o NPS 3 meses após o fim do Onboarding. Se não responder em 7 dias, reenviar. Nota promotora (9 e 10): e-mail de agradecimento. Nota detratora (0 a 6): disparar para o CS o playbook 'Análise de clientes detratores'."

| Situação | Ação |
|---|---|
| Cliente finalizou o Onboarding há 3 meses | Enviar o formulário de NPS |
| Cliente não respondeu em 7 dias | Reenviar o formulário |
| Cliente deu resposta promotora | Disparar e-mail de agradecimento |
| Cliente deu resposta detratora | Disparar o playbook de análise de clientes detratores |

Configuração sugerida — uma regra por linha da tabela:
- **Envio e reenvio**: ação **Formulário**. No reenvio, ajuste "Atingir novamente o mesmo cliente".
- **Promotores**: ação **Email**.
- **Detratores**: ação **Playbook**, de preferência numa regra que atinge **Contatos** (veja o Exemplo 8).
- O guia não mostra quais campos representam "3 meses após o Onboarding" e "sem resposta em 7 dias". Confirme na tela quais campos existem. **(campo)** Se não existirem, eles podem virar campos customizados alimentados por regra (ex.: gravar a data de fim do onboarding na ação que troca a fase) e então ser usados com "Há 'X' ou menos dias".
- Insumos que precisam existir antes: o template de NPS, o template de agradecimento e o playbook de detratores.

### Exemplo 2 — E-mail de boas-vindas no onboarding
```
Regra: Boas-vindas Onboarding
2. Condições — Grupo A:
   Cliente | Fase | Igual a | Onboarding
   E Cliente | Data de Registro | Há 'X' ou menos dias | 5
4. Ações — Email:
   Criar email a partir de: template de boas-vindas (no guia: "Bem-vindo(a) | SenseData")
   Remover e-mails duplicados entre clientes: marcado
   Enviar email às: 08:00
   Remetente: Implementador da Conta | Responder-para: endereço de retorno desejado
   CC/CCO: se necessário
```
**(campo)** Com "Há 5 ou menos dias" e execução diária, o mesmo cliente está na condição por vários dias: use "Atingir novamente o mesmo cliente: Nunca".

### Exemplo 3 — Carteirização por regra e distribuição automática
Caso do guia: todos os clientes com MRR acima de 5.000 vão para a carteira do CS "X".
```
Regra: Carteira CS X (nome de exemplo)
2. Condições — Cliente | MRR | Maior que | 5000
3. Recorrência — Executar regra: Somente uma vez | Parar: Nunca | Atingir novamente: Nunca
4. Ações — Atualização:
   Atualizar atributo para: Cliente | Campo: CS | Valor: <usuário do CS X>
   [x] Transferir todas as atividades em aberto atreladas ao antigo responsável
   [ ] Transferir todas as atividades em aberto independente do responsável
```
**Distribuição automática**: a estrutura é a mesma, mas com a ação Distribuição automática entre os CSs escolhidos. No exemplo do guia, os clientes são divididos entre dois CSs em partes iguais. O limite de clientes por carteira é opcional.

### Exemplo 4 — Segmentação por Tier (MRR)
```
Pasta: UPDATE | Portes do cliente → regras Tier 1, Tier 2 e Tier 3
Regra: Tier 1
2. Condições —
   Grupo A: Cliente | MRR | Maior que | 8999  E  Cliente | Status | Igual a | Ativo
   OU
   Grupo B: Cliente | MRR | Maior que | 8999  E  Cliente | Status | Igual a | Suspenso
4. Ações — Atualização: Cliente | Porte | Tier 1
```
- **Tier 2**: MRR menor que 8.999 e maior que 4.999,99.
- **Tier 3**: MRR menor que 4.999,99.
- Todos os tiers valem para clientes com status Ativo ou Suspenso, usando dois grupos ligados por OU.
- Para criar Tier 2 e Tier 3, duplique a regra Tier 1 e ajuste nome, condições e valor.
- **(campo)** Confira as bordas: com "Maior que 8999" e "Menor que 8.999", um MRR de exatamente 8.999 não entra em nenhum tier. Ajuste um dos limites.

### Exemplo 5 — Alerta de inadimplência
```
2. Condições — Cliente | Status | Igual a | Ativo
               E KPIs Padrões | Títulos em atraso | Maior que | 1
4. Ações — Alerta: "Cliente inadimplente!" | Destinatário: CS
           (opcional) Email ao cliente avisando sobre a inadimplência
```
Atenção ao valor: "Maior que 1" só atinge clientes com 2 ou mais títulos em atraso. Para "qualquer título em atraso", use "Maior que 0".

### Exemplo 6 — Renovação (60 dias)
**Alerta**:
```
2. Condições — Cliente | Status | Contém | ativo
               E Contrato | Fim vigência | Em 'X' ou menos dias | 60
3. Recorrência — definir a frequência de atualização
4. Ações — Alerta: mensagem avisando que há clientes com contrato a 60 dias ou menos da renovação | Destinatário: CS
```

**E-mail**:
1. Crie o template.
2. Crie a regra com as condições: cliente **Ativo** e o prazo de **Fim de vigência**.
3. Use a ação **Email** com o template, escolha para quem vai o envio e o remetente.
4. Clique em **Criar regra**.

**Playbook "Playbook Renovação"** (sugestão do guia):
- Status Ativo, Responsável CS.
- "Permitir editar playbooks em andamento": marcado. "Considerar somente dias úteis": desmarcado.

| # | Tarefa | Tipo | Prioridade | Dias |
|---|---|---|---|---|
| 1 | Confirmar se info contrato está correta | Tarefa | Normal | 0 |
| 2 | Contato com cliente para alinhar estratégia de renovação | Ligação | Normal | 10 |
| 3 | Alinhar estratégia com comercial | Tarefa | Normal | 5 |
| 4 | Registrar no Sense os próximos passos acordados | Milestone | Alta | 15 |

**(campo)** "Contém | ativo" também casa "Inativo", porque "Inativo" contém a sequência "ativo". Prefira "Igual a | Ativo" com a grafia confirmada.

### Exemplo 7 — Fluxo de churn ("Churn pt.1")
```
Regra: Churn pt.1 | Status: Ativo | Localização: Fora das pastas | Atingir: Cliente
2. Condições — Grupo A:
   Cliente | Status | Igual a | Ativo
   E Atividades | Conclusão playbook há X ou menos… | Igual a | 3
   E Atividades | Concluiu playbook com título | Igual a | Playbook Crise
   E Atividades | Categoria | Igual a | Não revertido
3. Recorrência — Executar regra: Segundas às sextas | Parar: Nunca | Atingir novamente: Sempre
4. Ações —
   Playbook: "Churn financeiro manutenção/Setup" | Responsável: Manter padrão template
   Email: template "Disparo de pedido de cancelamento" | Enviar para: Sponsor
          Remover e-mails duplicados: marcado | Remetente: CS da Conta | Email transacional: marcado
```
O guia sugere completar o fluxo com um e-mail ao financeiro e a **Atualização** do status para "Em cancelamento". No fim do fluxo, inative o cliente (seção 13). **(campo)** Com "Atingir novamente: Sempre" e a condição válida por 3 dias, o cliente pode receber o playbook e o e-mail mais de uma vez; a Atualização do status para "Em cancelamento" na mesma regra tira o cliente da condição "Status Igual a Ativo" e evita a repetição.

### Exemplo 8 — Detratores com MRR acima de 5 mil
```
Regra: NPS - RESPOSTA DETRATORA | ACIMA DE 5K | Ativo | Fora das pastas | Atingir: Contato
2. Condições — Cliente | Status | Igual a | Ativo
               E Cliente | MRR | Maior que | 5000
               E NPS | Avaliação NPS | Menor que | 7
3. Recorrência — Todos os dias | Parar: Nunca | Atingir novamente: A cada intervalo de 1 dia
4. Ações — Email (template para detratores)
           Criar tarefa de email: marcado | Remover e-mails duplicados: marcado | Enviar às 10:00
```

**Playbook de retorno para detratores** (no guia, parametrizado como "detratores com MRR maior que 5k"): Status Ativo, Responsável CS.

| # | Tarefa | Tipo | Prioridade | Responsável | Dias |
|---|---|---|---|---|---|
| 1 | Feedback negativo recebido | Contato | Normal | CS | 2 |
| 2 | Apuração do feedback | Tarefa | Normal | CS | 4 |
| 4 | Verificar e acompanhar o plano de ação realizado | Acompanhamento | Normal | CS | 14 |

A tarefa 3 não aparece nas capturas do guia. O corte de 5 mil é só um exemplo: use o que a sua empresa considera cliente estratégico. Para detratores abaixo do corte, crie uma regra parecida, também atingindo Contatos, com outro comunicado ou uma pesquisa CSAT. **(campo)** Com "A cada intervalo de 1 dia", o mesmo detrator pode receber o e-mail todo dia enquanto a última nota continuar < 7; confirme se a condição olha só respostas recentes ou use um intervalo maior.

### Exemplo 9 — Chamados acima do SLA
```
Regra: Chamados acima do SLA | Ativo | Localização: Gatilhos de proteção | Atingir: Cliente
2. Condições — Suporte - Chamados | Total de chamados acima do SLA | Maior que | 2
4. Ações — Alerta: "Chamado acima do SLA" | Destinatário: CS
           (opcional) Email, por exemplo para a equipe de suporte
```

### Exemplo 10 — Automação de fase: Onboarding → Adoção
```
2. Condições — Atividades | Concluiu playbook com título | Igual a | Onboarding
4. Ações — Atualização: Cliente | Fase | Adoção
           (opcional) Playbook: "Adoção"
```

### Exemplo 11 — Atividade por regra: cliente novo, conferir contatos
Caso do guia: sempre que entra um cliente novo, o CS deve verificar os contatos cadastrados.
```
Regra: Cliente novo - conferir contatos | Ativo | Atingir: Cliente
2. Condições — Cliente | Data de Inserção no SD | Há 'X' ou menos dias | 3
               E Cliente | Status | Igual a | Ativo
3. Recorrência — Todos os dias | Parar: Nunca | Atingir novamente: Nunca
4. Ações — Atividade:
   Título: Conferir contatos cadastrados | Tipo: Tarefa | Categoria: <categoria de onboarding>
   Instruções/checklist: sponsor cadastrado; e-mails válidos; decisor e usuário-chave identificados
   Prazo: 5 dias | [x] Notificar o responsável quando a atividade for criada
```

### Exemplo 12 — Régua de inatividade do CS (90 / 105 / 120 dias) (campo)
Pedido: "Se o CS ficar 90 dias sem atualizar as anotações **e** o CS Feeling de um cliente, avisar o CS; se não agir, escalar para a liderança."

Por que não dá para fazer só com regra: anotação é conteúdo de timeline, não campo filtrável. A inatividade precisa virar campo.

1. **Campos** (Configurações > Campos customizados; detalhes em `references/campos-customizados.md`):
   | Exibição | Nome interno | Tipo | Quem preenche |
   |---|---|---|---|
   | CS Feeling | `cs_feeling` | Lista (Verde/Amarelo/Vermelho) | CS |
   | Data última atualização do CS Feeling | `dt_ultima_atualizacao_cs_feeling` | Data, não editável | rotina |
   | Data da última anotação do CS | `dt_ultima_anotacao_cs` | Data, não editável | rotina |
   | Dias sem atualização do CS | `dias_sem_atualizacao_cs` | Inteiro, não editável | rotina |
   | Nível de alerta de inatividade | `nivel_alerta_inatividade` | Lista (`nenhum`, `alerta_90`, `escalonamento_105`, `critico_120`), não editável | rotina |
   | E-mail do líder de CS | `email_lider_cs` | Texto, não editável | integração |
2. **Rotina diária** (API ou integração), antes das regras: calcula `dias = MIN(dias desde a última anotação do time de CS, dias desde a última mudança do feeling)` (MIN porque a condição é "os dois parados"; MAX dispararia para quem anotou ontem), ignora anotações automáticas (integrações, bots), decide o nível com estado próprio (dispara uma vez por nível e ciclo) e grava os campos.
3. **Regras** (duplique a primeira e ajuste):
   ```
   Regra: [CS Ops] Inatividade 90d — CS Feeling e Anotações | Atingir: Cliente
   2. Condições — Cliente | Status | Igual a | Ativo
                  E Cliente | CS | <operação "não vazio" do tenant>
                  E Contrato | Início | <há mais de 90 dias>   (exclui onboarding; confira a operação disponível)
                  E Cliente | nivel_alerta_inatividade | Igual a | alerta_90
   3. Recorrência — Segundas às sextas, 09:00 (depois da rotina) | Atingir novamente: a cada 30 dias
   4. Ações — Atividade: "Atualizar CS Feeling e anotações", responsável CS, prazo 7 dias, tipo Acompanhamento
              Email: template D+90 para o CS | Criar tarefa de email: marcado
              Alerta: CS
   Regra: [CS Ops] Inatividade 105d — escalonamento | nível = escalonamento_105
     Ação: Email para o CS com o líder em cópia (sem nova atividade)
   Regra: [CS Ops] Inatividade 120d — crítico | nível = critico_120
     Ação: Email para o líder com o CS em cópia + Alerta para os dois
   ```
4. **Rollout**: rotina em dry-run por 3 dias; medir o volume do dia 1; carência (ex.: 30 dias sem disparo para o time preencher o feeling) e/ou limite diário; regra inativa com filtro "CS = eu" para testar; ativar.
5. **Acompanhar**: conversão de `alerta_90` para `nenhum` em 7 dias. Abaixo de ~50%, o problema é o processo.
Templates em `references/templates-email.md`; caso completo em `references/casos-reais.md`.

### Exemplo 13 — Remetente = comercial da conta (campo)
Pedido: "A régua de comunicação deveria sair em nome do comercial da conta, mas sai em nome do CS."
1. Confira a régua: se o **Remetente** já aponta para o campo "Comercial da Conta", a régua está certa.
2. Confira o campo nos clientes: se estiver vazio, a plataforma usa o remetente padrão (o CS). Esse é o defeito.
3. O campo é do tipo **lista de usuários**: só aceita um usuário da plataforma. Se o nome do comercial está num campo texto, é preciso resolver nome → usuário (por e-mail, ou nome normalizado sem acento/caixa) e gravar. Por CSV pode não funcionar (lista não é atualizada pela Manutenção via CSV); pela API, teste o formato aceito (e-mail, nome ou id) com **um** cliente.
4. Rotina diária idempotente depois da carga e antes da janela das réguas; nunca limpa valor existente; nomes sem usuário correspondente, inativos ou ambíguos viram pendência (criar usuário ou corrigir o cadastro).
5. Guarda na régua: `Comercial da Conta` não vazio (ou aceitar o fallback conscientemente).
6. Saudação: se sair "Olá ,", é nome de contato vazio; corrija o cadastro ou use saudação neutra.

### Exemplo 14 — Dado da conta matriz nas lojas do grupo (campo)
Pedido: "O CS registra o CS Feeling e as anotações uma única vez na conta matriz do grupo econômico e quer ver isso em todas as lojas (CNPJs)."
- A propagação é uma **integração** (SenseConnect, fonte PostgreSQL lendo a base espelho), não uma regra. Veja a skill sense-connect, Exemplo 6.
- Do lado da configuração:
  - crie os campos de destino nas lojas (`cs_feeling_grupo`, `anotacoes_grupo`, `conta_matriz_nome`, `grupo_atualizado_em`) e um campo `tipo_conta` para marcar a matriz;
  - mostre esses campos na Visão 360 da loja;
  - exclua `tipo_conta = matriz` de painéis de volumetria, health score médio e segmentações;
  - restrinja quem edita a matriz (a edição vale para o grupo todo);
  - defina uma convenção de escrita para o campo Grupo (grafias diferentes viram grupos diferentes);
  - **não replique atividades** para as lojas (multiplica registros e não se editam em conjunto): mantenha o histórico na matriz e o nome da matriz na loja.
- Alinhe a expectativa de "tempo real": a integração roda em horários agendados (ex.: a cada 30–60 min) mais execução manual quando necessário.

### Exemplo 15 — Reativar contatos com Manutenção via CSV (campo)
Pedido: "Uma carga inativou contatos que deveriam estar ativos. Quero reativá-los pela Manutenção via CSV."
1. **Pause** a carga que inativou (senão a próxima execução desfaz a reativação).
2. Monte o arquivo só com as colunas necessárias: `Cliente (ID Original)` (ou ID Sensedata), `E-mail` e a coluna de ativo. A manutenção grava só o que está no arquivo, então não há risco de apagar outros campos.
3. A manutenção casa por (cliente, e-mail). Separe:
   - **Lote A**: a dupla identifica um contato só → sobe primeiro;
   - **Lote B**: a dupla acha mais de um contato (mesmo e-mail duplicado na conta) → piloto com poucas linhas antes, para ver se a manutenção respeita maiúsculas/minúsculas ou ativa todos;
   - fora: quem já tem outro contato ativo na mesma conta (senão fica com dois ativos).
4. Confira depois: ninguém do alvo continua sem contato ativo; dados manuais (marcações) estão no registro ativo.
Queries de apoio na skill sense-connect (`references/sql-base-espelho.md`, seção 8).

## Notes
- O guia recomenda testar as configurações antes de colocá-las em produção. Em caso de dúvida, procure os IS, CS ou CX responsáveis pelo projeto.
- Os nomes de campos, categorias, templates, pastas e valores dos exemplos vêm das telas do guia e podem variar por ambiente.
- Antes de ativar regras que disparam comunicação para clientes, confira "Ver amostra de clientes/contatos" e "Ver amostra de destinatários".
- O guia mostra o status tanto como "Igual a | Ativo" quanto como "Contém | ativo". Como campos de texto diferenciam maiúsculas e minúsculas, confirme a grafia usada no seu ambiente.
- Itens marcados **(campo)** vêm de implantações reais e precisam de confirmação no tenant, principalmente: CC/destinatário por campo customizado na ação de e-mail, opção de não repetir disparo por N dias, disponibilidade da ação Atividade no plano, nome do header da API e endpoints liberados no contrato.
- Nunca inclua dados reais de clientes (e-mails, nomes, valores) em exemplos genéricos.
