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
| Tickets e SLA; cards e gráficos na Visão 360 | Seção 15, Exemplo 9 |
| Promotores e detratores | Seção 16, Exemplo 8 |
| Criar ou especificar campo customizado | Seções 14 (tela) e 17, `references/campos-customizados.md` |
| Editar muitos clientes pela tabela (Edição em Massa) | Seção 4 |
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
| `references/guia-telas.md` | O que cada tela do guia mostra, página a página: campos, opções, botões, exemplos e divergências entre texto e captura |
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
- A tela tem os botões **Criar Regra** e **Criar Pasta**, a caixa "Expandir todas as pastas", os filtros **Atingir**, **Criado por**, **Status** e **Ação**, e a busca. A lista mostra ID, Nome, Criado por, Ações, Status e **Última execução**.
- **Ordem de execução**: as regras rodam na ordem da lista. Arraste e solte para reordenar. Pastas e as regras dentro delas também seguem essa ordem.
- A tela de criação se chama **Configurações da Regra** e tem quatro blocos numerados: 1 Informações, 2 Condições, 3 Agendamento e recorrência, 4 Ações.

**Passo 1 — Informações**
- **Nome**: campo livre. Prefira nomes claros e objetivos (ex.: "Chamados acima do SLA", "NPS - RESPOSTA DETRATORA | ACIMA DE 5K"). **(campo)** Um prefixo de área ajuda a achar e medir depois (ex.: "[CS Ops] Inatividade 90d").
- **Status**: *Ativo* roda na próxima atualização de dados do ambiente; *Inativo* não roda até voltar a Ativo.
- **Localização**: a pasta da regra, ou "Fora das pastas". Crie pastas para organizar; para mover a regra de pasta, altere este campo.
- **Atingir**: **Clientes** ou **Contatos** (no seletor aparecem como "Cliente" e "Contato").

**Passo 2 — Condições** (os gatilhos: as condições em que o cliente ou contato precisa se encaixar para receber a ação)
- Cada condição tem quatro campos: **Categoria**, **Campo**, **Operação** e **Valor**.
  - **Categoria** é a origem do dado (a tabela onde a informação é buscada). Exemplos vistos no guia: Cliente, Contrato, KPIs Padrões, Atividades, NPS e uma categoria de suporte cujo nome aparece cortado na captura ("Suporte - Cha…", onde fica o campo "Total de chamados acima do SLA"). O texto do guia também cita Contatos. Campos customizados aparecem junto da tabela a que pertencem.
  - **Operação** varia conforme o tipo do campo (texto, número ou data). Operações vistas no guia: "Igual a", "Contém", "Maior que", "Menor que", "Há 'X' ou menos dias" e "Em 'X' ou menos dias".
  - **Valor**: o valor a comparar. Em campos de **texto**, maiúsculas e minúsculas fazem diferença. Alguns campos trazem o valor numa lista (ex.: "Concluiu playbook com título" lista os playbooks). Números aparecem sem separador de milhar (ex.: 8999, 5000).
- Dentro de um grupo, cada condição pode ser duplicada (⧉), adicionada (⊕) ou removida (⊖). As condições de um mesmo grupo são combinadas com **E**.
- "Adicionar Grupo", "Duplicar Grupo" e "Excluir Grupo" gerenciam os grupos (Grupo A, Grupo B…). Entre dois grupos aparece o seletor **E / OU**: E para união de critérios, OU para alternativas (no Exemplo 4, "ou").
- Ao lado do título, a tela mostra o total de condições e quantos serão atingidos, com o link "Ver amostra de clientes" ou "Ver amostra de contatos" (ex.: "3 condições afetando 126 Contatos").
- Exemplo do guia — clientes inseridos há 3 dias ou menos e com status ativo:
  - Cliente | Data de Inserção no SD | Há 'X' ou menos dias | 3
  - **E** Cliente | Status | Igual a | Ativo

**Passo 3 — Agendamento e recorrência**
- **Data de início**: a regra roda a partir dela, incluindo o próprio dia. (Numa captura mais antiga, o rótulo é "Início de execução".)
- **Executar regra**: a periodicidade. Opções vistas: Todos os dias, Somente uma vez, Segundas as sextas (grafia da tela). O guia também cita uma vez por mês, a cada 15 dias e uma vez por semana.
- **Parar execução**: Nunca, Em <data>, ou Após <N> ocorrências.
- **Atingir novamente o mesmo cliente**: define se o cliente pode ser atingido mais de uma vez num período, desde que continue dentro das condições. Opções vistas: Nunca, Sempre, "A cada intervalo de" <N> dias.

**Passo 4 — Ações**
- Clique em **Adicionar Ação** e escolha na lista **Ação**. Não há limite: uma regra pode executar várias ações. Cada ação abre o bloco "Configurações da Ação"; o **X** ao lado da ação a remove.
- Ações da lista: Alerta, Atualização, Playbook, Atividade, Distribuição automática, Email, SMS, Webhook, Formulário, Relatório, Atualização da Jornada e WhatsApp.
- Clique em **Criar Regra** para salvar.

### 3. Configuração das ações
- **Alerta**
  - Texto do **Alerta** e **Destinatário** (ex.: CS).
  - O alerta interno aparece para o destinatário no ícone de **sino**, no canto superior direito, com um contador. O painel **Notificações** lista cada alerta como "<cliente> - <texto do alerta>", com a data, e tem o link "Limpar Notificações". Todos os usuários também veem os alertas na Visão 360 do cliente.
- **Atualização**
  - **Atualizar atributo para** (ex.: Cliente), **Campo** (ex.: CS, Fase, Porte, Status ou um campo customizado) e **Valor**. O Valor é texto livre (ex.: "Tier 1", "Adoção") ou uma lista, conforme o campo (ex.: Status > Inativo; CS > usuário).
  - Ao atualizar o responsável (CS), há duas caixas: "Transferir todas as atividades em aberto atreladas ao antigo responsável" e "Transferir todas as atividades em aberto independente do responsável".
- **Distribuição automática**
  - **Pelo critério** (na captura, "Quantidade de Clientes"), **Status do cliente na carteira** (seleção de vários status, ex.: Ativo, Inativo, Suspenso) e **Preenchendo o campo** (o campo do responsável, ex.: CS).
  - Caixa **Limitar quantidade de clientes na carteira**, que abre **Quantidade clientes por carteira** (ex.: 10).
  - As mesmas duas caixas de transferência de atividades da ação Atualização.
  - **Selecione os usuários para distribuição**: duas listas, com os botões » › ‹ « para passar usuários de uma para a outra.
  - A plataforma divide os clientes atingidos entre os usuários escolhidos em quantidades iguais, ou o mais perto disso possível.
- **Playbook**
  - **Playbook associado**, **Responsável** e **Categoria** (padrão: Nenhum).
  - Em Responsável, "Manter padrão template" usa o responsável configurado no próprio playbook; também dá para escolher outro (ex.: CS).
  - A categoria serve para classificar o playbook.
- **Atividade**
  - **Descrição** (o título), com os links "Editar instruções" e "Editar Checklist".
  - **Tipo de atividade**, **Categoria**, **Prioridade**, **Hora de início** e **Hora de fim**.
  - **Conclusão**: "Dias para conclusão" e o número de dias.
  - **Responsável**, **Horas utilizadas** e **Anotações** (editor de texto).
  - Caixa **Enviar alerta para o responsável**: o responsável recebe uma notificação quando a atividade é criada.
- **Atualização da Jornada**: **Atualizar jornada para**, **Atualizar fase para** e a caixa "Excluir da jornada e/ou fase clientes atingidos pelo passo 2 condições".
- **Formulário**
  - **Tipo do formulário** (ex.: Formulário NPS), **Disparar por** (ex.: Email) e **Selecionar template do formulário** (criado antes).
  - **Enviar para**: um ou mais grupos de destinatários ("Adicionar Grupo"); ao lado de cada grupo, a caixa "Criar tarefa de formulário".
  - "Remover emails duplicados entre clientes" e **Não enviar para** ("Adicionar Grupo").
  - **Enviar email às** (hora), com a caixa "Não enviar mensagem após o horário".
  - **Remetente** (ex.: CS da Conta) e **Responder para**.
- **Email**
  - **Criar email a partir de**: o template criado antes, com os links "Configurar Email" e "Visualizar Template".
  - **Enviar para**: um ou mais grupos (ex.: Sponsor, CS), cada um com a caixa "Criar tarefa de email" e um X para remover; "Adicionar Grupo" inclui outro.
  - **CC** e **CCO** (cópia e cópia oculta), cada um com "Adicionar Grupo".
  - "Remover e-mails duplicados entre clientes", "Destinatários atingidos (amostra)" com o link "Ver amostra de destinatários", e **Não enviar para**.
  - **Enviar email às** (o horário do disparo), com a caixa "Não enviar mensagem após o horário".
  - **Remetente**: o endereço usado como remetente. Valores vistos: CS da Conta, CSM da Conta, Implementador da Conta.
  - **Responder-para**: o destino das respostas. É um campo de texto ("Digite aqui"); nos exemplos do guia aparece preenchido com "cs da conta" ou "is da conta", ou vazio.
  - Caixa **Email transacional**.
- **SMS, Webhook, Relatório e WhatsApp** aparecem na lista de ações, mas o guia não detalha como configurá-los. Configurações > Comunicação tem "Templates de WhatsApp", mas o guia não o usa.

### 4. Carteirização
Carteirizar é colocar o cliente numa carteira, o grupo de clientes atendido por um CS ou CSM. Há três formas.

**Manual** — quando não há um critério específico, ou para migrar clientes de um CS para outro:
1. Vá em Tabelas > Clientes.
2. Busque os clientes e marque a caixa de seleção no início da tabela (a tela mostra "N cliente selecionado. Limpar seleção.").
3. Clique em **Editar**. Na janela **Edição em Massa**, em "Selecione quais dados deseja editar", marque os campos (ex.: CS, CSM; a lista traz campos nativos e customizados do ambiente, com "Selecionar todas as opções" e busca).
4. Na tela seguinte, escolha o novo valor de cada campo marcado (para CS/CSM, o usuário responsável).
5. Clique em **Próximo** e confirme. Aparece "Sucesso! N clientes editados com sucesso!".
- A mesma Edição em Massa serve para outros campos (Porte, Fase, Segmento, Status…), não só o responsável.

**Por regra** — por um critério (MRR, segmento, região, porte…): coloque o critério nas condições, defina o agendamento e use a ação **Atualização** no campo do responsável com o novo valor. Veja o Exemplo 3.

**Distribuição automática** — equilibra as carteiras, com um limite opcional por CS: condições, recorrência e ação **Distribuição automática** (configuração na seção 3). No exemplo do guia, os clientes atingidos são divididos entre dois CSs em quantidades iguais ou o mais próximas possível.

### 5. Playbooks
Um playbook é um conjunto de atividades que o usuário deve realizar: ele transforma a estratégia da operação em tarefas com um objetivo. Serve para criar, compartilhar e descrever esse conjunto. Há dois tipos: **Playbook** e **Onboarding Playbook**.
- Exemplo do guia, o Playbook de Execução de Cancelamento: extrair o feedback do cliente, enviar o e-mail do financeiro e desligar o ambiente. As atividades são independentes e podem ser feitas em sequência ou não.

**Criar** — Configurações > Atividades > **Playbooks** (ou **Onboarding Playbooks**) > **Criar Playbook**. O menu Atividades de Configurações tem: Categorias, Onboarding Playbooks, Playbooks, Tipos de Atividades e Geolocalização.
- A tela de lista também edita playbooks existentes. Botões: Criar Playbook, Criar Pasta, Duplicar, Mover, Inativar, Apagar e Restaurar; filtro "Mostrar ativos" e busca.
- Colunas: Nome, Id, Data de Criação, Criado por, Total de Atividades, Status (chave liga/desliga), Aplicados, Clientes Impactados e Concluídos.
- Aviso da tela: a ordem da lista (arrastar e soltar, inclusive pastas) é a ordem de execução, e playbooks normais não aparecem na visão Kanban dos Playbooks de Onboarding.

1. **Dados gerais**:
   - **Nome**: de acordo com a ação.
   - **Status**: Ativo (disponível para uso) ou Inativo (criado, mas indisponível). Dá para mudar a qualquer momento.
   - **Responsável**: um perfil ou um usuário.
2. **Marcações opcionais**: "Permitir editar playbooks em andamento" e "Considerar somente dias úteis ao calcular previsão de conclusão".
3. **Tarefas do playbook** — cada tarefa é um bloco recolhível com o título "N. <descrição>" e uma alça para arrastar. Campos:
   - **Tipo**: novos tipos são criados em "Tipos de Atividades". Tipos vistos no guia: Tarefa, Ligação, Contato, Acompanhamento, Milestone, Reunião.
   - **Prioridade** (ex.: Normal, Alta) e **Descrição** (o título que descreve a atividade).
   - **Responsável**: não precisa ser o mesmo do playbook; pode ser outro perfil ou usuário. Nos exemplos do guia aparece às vezes em branco ("Selecione").
   - **Categoria**: opcional (padrão: Nenhuma); serve para gerar gatilhos em outras regras.
   - **Dias**: após quantos dias da atribuição o prazo começa a contar.
   - **Hora De Início**, **Hora De Fim** e **Horas Utilizadas**. Em algumas capturas, o último campo aparece como **Valor**.
   - **Adicionar instruções** (como conduzir; editor de texto com o botão VAR), **Adicionar checklist** (janela "Checklist da Atividade", com "+ Adicionar item") e **Adicionar notas** (janela "Adicionar anotações"). Depois de preenchidos, os links viram "Editar instruções", "Editar checklist" e "Editar notas".
   - Os ícones ⧉ ⊕ ⊖ duplicam, adicionam e excluem tarefas.
4. Clique em **Salvar playbook** (ou Cancelar). O playbook aparece na lista, "criado e disponível para uso". **Criar Pasta** ajuda a organizar.
- **Importante:** um playbook ativo e associado a uma regra é disparado quando a carga roda. Sem regra associada, ele só pode ser incluído manualmente.
- Exemplo das capturas, um playbook de retenção: tarefa 1 "Entrar em contato com o cliente" (Ligação, Normal, Dias 1); tarefa 3 "Formalizar ao grupo de churn o que foi feito para a retenção" (Tarefa, Normal, Dias 3). A tarefa 3 tem instruções em 5 passos (formalizar no grupo de churn; detalhar o que levou ao pedido de cancelamento; descrever tratativas e prazos; informar como será o acompanhamento; retornar com o resultado final), um checklist (informar no grupo; listar as reclamações do cliente; criar um cronograma de acompanhamento semanal) e uma nota (acionar o líder direto para nova reunião, se necessário).

**Onboarding Playbook**
- As ações são divididas em **fases**, totalmente customizáveis (ex.: Kick-off, Formação, Acompanhamento, Encerramento). O cliente avança de fase conforme as atividades são concluídas.
- Diferenciais: quadro Kanban mostrando onde cada cliente está, prazo de cada atividade em dias e barra de progresso com o percentual concluído.
- Na criação:
  - os dados gerais têm também o campo **Categoria**;
  - cada tarefa tem **Grupo** (a fase a que pertence, ex.: Planejamento, Handoff), Tipo, Descrição, Responsável, Categoria, **Dias**, **Duração (Dias)** (o prazo final em dias para conclusão), Hora De Início, Hora De Fim e Horas Utilizadas;
  - a captura não mostra Prioridade.
- Exemplos de tarefas nas capturas: "Alinhamento e Kickoff" (Grupo Planejamento, Ligação, Dias 0, Duração 4); "Reunião de Handoff com cliente" (Grupo Handoff, Reunião, Dias 84, Duração 4).
- Tela **Onboarding** ("Visão Geral do Onboarding"):
  - filtros Playbook, Responsável, Cliente e Categoria;
  - contadores Todos, Atrasadas, Vencem hoje, A vencer, Concluídas e Em pausa;
  - botão Adicionar Playbook e visões **Lista**, **Quadro** e **Tabela**;
  - no Quadro, uma coluna por fase mais "Concluídos 30 dias", e cada card mostra tarefas concluídas/total e a barra de progresso.
- Na visão Lista: "Selecione um playbook para ver os clientes por etapa"; filtros Playbook, Status (ex.: "Playbooks Não Concluídos"), Resp. Playbook, Resp. Atividades, Cliente e Categoria.

**Associar um playbook a um cliente**
- *Onboarding Playbook, manual*:
  1. Na barra superior, clique em **Onboarding** > **Adicionar Playbook**.
  2. Na janela, preencha **Cliente**, **Playbook** e **Responsável** ("Manter o padrão do template" ou outro). Há também a caixa "Marcar como concluído".
  3. Clique em **Adicionar Playbook**.
  - Para só visualizar, procure o cliente no quadro.
- *Playbook, manual*:
  1. Vá em Tabelas > Clientes e abra o cliente.
  2. Na aba **Atividades**, clique em **Adicionar Playbook**.
  3. Preencha Playbook e Responsável ("Manter padrão template" ou outro); o Cliente já vem preenchido. Há a caixa "Marcar como concluído".
  4. Clique em **Adicionar Playbook**.
  - Para só visualizar, procure o playbook na lista.
- *Por regra*: em Configurações > Regras > Criar Regra, defina o público nas condições e escolha a ação **Playbook** > Playbook associado (e, se quiser, Responsável e Categoria). Para incluir um playbook numa regra que já existe, basta editá-la.

### 6. Atividades
Atividades registram todas as ações feitas com os clientes, para uma visão completa das interações. Quando várias ações seguem um padrão e uma sequência, prefira um playbook.

**Criação manual**:
- Onde criar: tela **Atividades** (barra superior) > **Adicionar atividade**, ou **Visão 360** do cliente > aba **Atividades** > **Adicionar atividade**. As duas telas também têm **Adicionar Playbook**.
- O formulário tem as abas **Detalhes** e **Checklist e instruções**. Campos obrigatórios (*): **Cliente** (a quem a atividade é atribuída), **Tipo de atividade**, **Descrição** (o título), **Data de início**, **Prev. de conclusão** e **Responsável** (o usuário que executa).
- Campos opcionais: **Contato no cliente** (o receptor da atividade), Hora de início, Hora de fim, Valor, Prioridade (ex.: Normal), Categoria, Anotações (campo livre do usuário) e **Arquivos** ("Adicionar do Computador" ou "Adicionar do Google Drive").
- No rodapé: a caixa "Marcar como concluída", **Adicionar atividade** e "Marcar como favorito".
- Os tipos ficam em **Configurações > Atividades > Tipos de Atividades**; as categorias, em **Configurações > Atividades > Categorias**.

**Concluir uma atividade**: a janela **Confirmar Conclusão** mostra Cliente e Atividade e pede **Data conclusão**, **Valor**, **Categoria** e **Anotações**; o botão é **Concluir tarefa**. É aqui que se aplica uma categoria na conclusão (ex.: "Não revertido", seção 13).

**Por regra**: quando uma ação pontual precisa acontecer num momento conhecido (ex.: sempre que entra um cliente novo, o CS verifica os contatos cadastrados), use a ação **Atividade** (seção 3). Veja o Exemplo 11.

**Visão 360**:
- Abas: Visão 360, Atividades, Arquivos, Contratos, Histórico, Lista de contatos, Notas e Formulários.
- Na aba Atividades, os contadores são: Todos, Vencem hoje, A vencer, Atrasadas e Em pausa; há filtro por responsável. A lista mostra Tipo/Descrição, Responsável, Cliente, Categoria e Data (ex.: "Atrasada há N dias", "Conclusão em N dias").

**(campo)** Atividade × anotação: anotação (nota da timeline) não é um campo filtrável em regras. Se uma regra precisa de "dias desde a última anotação", esse número precisa ser calculado fora e gravado num campo customizado (Exemplo 12). O campo nativo **Última interação** (data da última atividade concluída) é global: qualquer atividade concluída zera o contador.

### 7. Jornada da Carteira
A Jornada da Carteira organiza as fases do relacionamento com o cliente, em vários tipos de produto, e melhora a visualização da base. Com ela você acompanha o ciclo de vida de cada cliente, as etapas da jornada e os indicadores.

**Habilitar no perfil**:
1. Vá em Configurações > Contas > Perfis (tela "Perfis de Usuário", com Adicionar Perfil e as colunas Nome, Papel, Usuários, Menus, Ações, Data de criação e Criado por) e clique no ícone **Editar** do perfil desejado.
2. No bloco **Definir menu** ("escolha os itens de menu que o perfil pode acessar"), selecione **Telas - Jornada da carteira** e clique na seta para a direita. O grupo "Telas" também tem Atividades, Calendário e Onboarding.
3. No bloco **Definir ações** ("escolha quais ações o perfil irá poder realizar"), selecione **Jornada da carteira** e **Regras** (esta última permite automatizar a jornada) e clique na seta. O grupo Jornada da Carteira tem as ações Atualizar fase, Adicionar clientes, Remover clientes e Editar Filtros da Jornada.
4. Clique em **Salvar perfil**.

**Criar**:
1. Vá em Configurações > Clientes > Jornada da carteira > **Criar Jornada**. A lista tem também Criar Pasta, Duplicar, Mover, Inativar e Apagar, com as colunas Nome e Perfil.
2. Na janela **Criar Jornada**, preencha **Nome da Jornada** e **Perfis com acesso**.
3. Para cada fase, defina **Nome Fase**, **Tempo estimado na fase (dias)** e **Cor da fase** (os três obrigatórios). O ⊕ à direita adiciona fases, o ⊖ remove, e a alça reordena.
4. Clique em **Salvar**.
- Avisos da janela: sem nenhum perfil com acesso, só os perfis Administrador e Sensedata veem a jornada; nomes e cores das fases não podem se repetir.
- O tempo estimado precisa ser realista, porque serve de indicador de atraso.
- O limite é de 20 fases, ligado à quantidade de cores disponíveis.

**Visualizar**:
- Na barra superior, clique em **Jornada da carteira** e escolha a jornada em "Selecionar Jornada" (as jornadas podem estar em pastas).
- Formas de ver: visão geral, com uma aba "Geral (N)" e uma aba por fase com a contagem de clientes e cada fase expandindo pela seta à direita; ou em Kanban (ícone à direita). A visão geral tem um gráfico de rosca com o total.
- A tela tem Adicionar cliente, Exportar, Pesquisar cliente, Ordenar por, Minha carteira e Filtros.
- Exemplo das capturas: a jornada "Renovação", com as fases Renovação 60D+, Renovação 60D, Renovação 30D e Renovação 15D.
- **Card do cliente na jornada**: abas **Detalhes** e **Anotações**. Em Detalhes aparecem a etiqueta da fase (editável pelo lápis), Tempo na fase, Tempo de vida, Última atualização e os principais indicadores. Exemplos de indicadores nas capturas: Countdown etapa, Progresso funil (%), Qtd de touchs (15 dias), Dias sem touch. Em Anotações dá para registrar notas do cliente.

**Adicionar clientes**:
- *Manual*: clique em **Adicionar cliente**; na janela (Jornada já preenchida), escolha a **Fase** e o **Cliente** e salve.
- *Por regra*:
  1. Defina nas condições as situações que levam o cliente à jornada ou fase.
  2. Use a ação **Atualização da jornada**, preenchendo "Atualizar jornada para" e "Atualizar fase para". A ação tem também a caixa "Excluir da jornada e/ou fase clientes atingidos pelo passo 2 condições".
  3. Salve e execute, confira de novo os clientes selecionados e clique em **Disparar regra**.

**Exemplos de organização**:
- *Por colaborador*: ex.: a jornada "Carteira Onboarding", com uma aba por pessoa do time. O líder vê a perspectiva de cada liderado sobre seus clientes.
- *Por comportamento da base*: ex.: a jornada "CS Felling" (grafia do guia), com as fases Sem mapeamento, Em cancelamento, Integração Instável, Baixo Engajamento, Troca de Sponsor e Insatisfação Produto. Dá visibilidade a quem é responsável pelas ações com esses clientes.
- *Por segmento*: o guia sugere uma jornada baseada nos segmentos da seção 14.

**Jornada × Onboarding Playbook**: a Jornada mede em que etapa o cliente está, definida manualmente ou por regra; o foco são os indicadores do momento do cliente. O Onboarding Playbook avalia o cliente pelas atividades em andamento ou concluídas; o foco são as tarefas que o time interno precisa executar.

### 8. Automação de fases
Troca a fase do cliente a partir de marcos, como a conclusão de atividades ou playbooks:
1. **Condições**: o marco (ex.: conclusão do playbook de Onboarding).
2. **Ação**: **Atualização** do Cliente para a nova fase (ex.: "Adoção").
3. Outras ações, se precisar (ex.: disparar o playbook de "Adoção").

Veja o Exemplo 10.

### 9. Pesquisas (NPS, CSAT, formulário livre)
**Criar o formulário**:
1. Vá em Configurações > Comunicação > **Templates de formulário**. O menu Comunicação tem: SPF, Autorização de Envio, Listas de Envio, Templates de Email, Templates de WhatsApp e Templates de Formulário.
2. Na tela **Formulários**, clique em **Criar formulário**. A tela também tem Criar Pasta, Duplicar, Mover, Inativar e Apagar, a caixa "Mostrar somente formulários ativos" e as colunas Nome, Tipo, Assunto, ID, Data de Criação, Criado Por, Status e Estatísticas.
3. Em "Selecionar template", escolha **Net Promoter Score (NPS)** ou **Formulário Livre** (as duas opções da captura).
4. No **Construtor de Formulário**, defina o nome (lápis ao lado do nome) e edite. O modelo NPS traz os blocos Resposta, Escala NPS, Texto e Título; o formulário tem logo, título, descrição, texto e a escala de 0 a 10 ("Pouco provável" a "Muito provável").
5. Use **Enviar Teste**, **Salvar** ou **Salvar e sair**.
- **CSAT** e outros tipos de pesquisa, ou mais personalização, são feitos com o **Formulário Livre**. Na lista do guia, o formulário de CSAT aparece com o tipo "Livre".
- O assunto padrão do convite, visto na lista, é "Convite para responder formulário".

**Disparo por regra**: em Configurações > Regras > Criar Regra, defina as condições, o agendamento e a recorrência, use a ação **Formulário** (tipo, forma de disparo e template; para quem enviar, horário e remetente; seção 3) e clique em **Criar Regra**.

**Disparo manual pela Visão 360**:
1. Na Visão 360 do cliente, vá em **Formulários** > **Adicionar formulário**. A aba lista os formulários enviados, com filtros (tipo de formulário, tipo de envio, meio de envio, enviado por, data do disparo) e as colunas Total de respostas, Última resposta e Respostas.
2. Na janela **Selecionar formulário**, escolha o tipo (NPS ou livre) e o formulário.
3. Escolha o meio: "Enviar link do formulário via e-mail" ou "Enviar link do formulário via sms".
4. Em **Enviar para**, escolha o contato.
5. Se quiser que o disparo fique registrado como atividade concluída, ative a flag "Criar tarefa de formulário".
6. Clique em **Prosseguir**.

### 10. E-mails
O SenseData tem funções de customização e disparo de e-mails para padronizar a comunicação e reduzir tarefas manuais (boas-vindas, newsletter, avisos). Os templates podem ter **formulários integrados**, que facilitam o acesso às pesquisas e seguem a identidade visual da empresa.

**Criar o template**: Configurações > Comunicação > **Templates de email** > **Criar template**.
- A lista tem Criar Template, Criar Pasta, Duplicar, Mover, Inativar e Apagar, o filtro "Mostrar ativos" e as colunas Nome, Assunto, ID, Data de Criação, Criado Por e Status. A ordem da lista se ajusta arrastando e soltando, inclusive pastas.
- **Editor**:
  - Na barra superior ficam o nome do template (obrigatório, com o link "Editar") e os botões Enviar Teste, Salvar e Salvar e Sair.
  - O painel da direita tem as abas Conteúdo, Blocos, Corpo e Imagens.
  - Arraste os blocos de Conteúdo para o corpo do e-mail: Colunas (organizar e dividir o conteúdo), Título, Texto, Imagem, Botão (CTA para links externos, bom para a taxa de cliques), Divisor (separar assuntos no mesmo envio), HTML, Menu e Social (redes da empresa). Com o corpo vazio, a tela diz "Nenhum conteúdo aqui. Arraste o conteúdo da direita."
  - Todo bloco pode ser duplicado ou apagado a qualquer momento.
  - O texto aceita fonte, tamanho, cor, alinhamento e espaçamento, listas e links. O e-mail também pode ser editado direto em HTML.
  - O rodapé do editor tem desfazer/refazer, pré-visualizar e as visões desktop e celular.
- **Mesclar Marcadores** (na barra de texto) insere variáveis, campos customizados e KPIs. Ao lado há o botão **Texto Inteligente**. No corpo do e-mail, o marcador aparece como uma etiqueta. Marcadores vistos nos templates do guia: Contato Primeiro Nome, Cliente, Descrição Cliente, IS, Assinatura do Remetente e Link formulário (este insere o link de um formulário no e-mail, o "formulário integrado").
- Dicas do guia:
  - Use um título claro e descritivo, que diga o objetivo sem abrir a configuração (ex.: "Email de boas-vindas ao Onboarding").
  - Escreva um assunto que estimule a abertura.
  - Antes de enviar a clientes, faça um teste para o seu próprio e-mail e confira links, imagens, fontes e erros de digitação.
- Template de boas-vindas das capturas:
  - "Olá, «Contato Primeiro Nome». Tudo bem?" e apresentação de quem conduz o onboarding («IS»), junto com o time do «Cliente»;
  - a primeira etapa é agendar a reunião de kick-off (remota, cerca de 1 hora), com a pauta: alinhamento das expectativas, overview da jornada completa e detalhamento das etapas do onboarding;
  - o que é preciso para a reunião: o time de negócios responsável pelo onboarding e o responsável técnico das integrações;
  - um link de agenda para o cliente escolher o horário.

**Disparo por regra**: ação **Email** (seção 3). Veja o Exemplo 2 e a seção 19 (remetente e marcadores).

**Envio manual pela Visão 360**:
1. Na Visão 360, vá em **Lista de Contatos**. A tela tem as visões Lista e Mapa, os botões Novo Contato, Editar e Excluir, as caixas "Somente Sponsor" e "Somente Ativos", busca e as colunas Nome, Apelido, Cargo, Tipo de Contato, Email, Telefone, Celular e Sponsor. Cada contato tem ícones de favoritar, visualizar, e-mail, WhatsApp e telefone.
2. Clique no ícone de e-mail do contato. Abre a janela **Nova mensagem**, com De e Para já preenchidos (e CC/CCO).
3. Preencha **Responder para** e o **Assunto**.
4. Em **Adicionar template**, escolha um template e ajuste, ou escreva e formate o texto.
5. Clique em **Enviar**.
- Aviso da janela: imagens só entram pelo ícone de imagem, com a URL de uma imagem hospedada online.

### 11. Inadimplência
Acompanhe os pagamentos em atraso, identifique padrões e aja cedo; os alertas permitem resolver de forma amigável e evitar prejuízos maiores.
- O menu **Tabelas** tem: Clientes, Contratos, Financeiro, Suporte, Lista de Contatos e NPS.
- **Tabela Clientes**: Tabelas > Clientes > coluna **"Títulos Vencidos"** (a quantidade de títulos). Aplique o filtro da coluna para ver quem tem títulos em atraso.
- **Tabela Financeiro**: Tabelas > Financeiro > coluna **"Status Financeiro"**. A plataforma preenche essa coluna a partir da data de pagamento: **Pago**, **Vencido** ou **Em aberto**. Filtre pelos títulos vencidos. Outras colunas vistas: Cliente, Valor, Documento (ex.: número da nota fiscal) e ID Original.
- **Alerta**: uma regra avisa o CS quando o cliente fica inadimplente e, se quiser, também manda um e-mail ao cliente. Veja o Exemplo 5. O alerta aparece no sino (painel Notificações) do destinatário e na Visão 360 (seção 3).

### 12. Renovação
Acompanhe os contratos perto de expirar usando os dados da tabela **Contratos** (Tabelas > Contratos). Isso dá tempo para criar pontos de contato que favoreçam a renovação e para mapear upsell e cross-sell.
- Os exemplos do guia usam 60 dias antes do fim do contrato, mas o ideal é ajustar para o momento em que as ações funcionam melhor com seus clientes.
- Tudo depende de um cadastro de contratos consistente.
- Alerta, e-mail e playbook de renovação: veja o Exemplo 6. No exemplo de e-mail do guia, o envio vai para o **CS** (interno), com remetente "CSM da Conta".
- Na parte de Jornada da Carteira, o guia mostra uma jornada "Renovação" com as fases Renovação 60D+, 60D, 30D e 15D (seção 7).

### 13. Churn e inativação
**Fluxo de churn**
- Pode começar a partir de um playbook de cliente em crise, que reúne as ações feitas quando se percebe que o cliente pode pedir, ou já pediu, o cancelamento.
- A última atividade desse playbook indica se houve reversão. Se não houve, esse é o gatilho do churn.
- Para marcar isso, aplique a **categoria "Não revertido"** ao concluir a atividade, no campo Categoria da janela **Confirmar Conclusão** (seção 6). A categoria é criada em Configurações > Atividades > Categorias.
- Ações sugeridas pelo guia:
  - e-mail de cancelamento, explicando as etapas pelas quais a empresa vai passar;
  - e-mail comunicando o financeiro;
  - playbook para o CS/CSM com as ações necessárias para o cancelamento;
  - atualização do status para "Em cancelamento".
- Veja o Exemplo 7.

**Inativar o cliente** (registrar a inativação, a data e o motivo do cancelamento):
- *Manual*:
  1. Na Visão 360, clique no ícone de edição (lápis) do card **Status**. Abre o painel **Alterar status do cliente**.
  2. Em **Alterar status para**, escolha "Inativo". A lista traz os status do ambiente (ex.: Ativo, Inativo, Demonstração).
  3. Escolha o **Motivo** do cancelamento (ex.: "Problemas no Onboarding") e detalhe em **Comentários** o que for importante.
  4. Se o cancelamento aconteceu em outro dia, ajuste a **Data da Alteração**.
  5. Clique em **Atualizar status**.
- *Por regra*: ação **Atualização** > Atualizar atributo para **Cliente** > campo **Status** > Valor **Inativo** (ou outro status). A regra altera **só o status**; a data e o motivo do cancelamento precisam ser preenchidos à mão.
- Os status são configurados em **Configurações > Status dos Clientes**, e os motivos em **Configurações > Motivos de Cancelamento**.

### 14. Segmentação por produto, plano ou serviço
Segmentar permite estratégias personalizadas por perfil de cliente, com mais clareza, foco e objetividade no atendimento. Por exemplo, segmentando pelo MRR, dá para criar réguas de comunicação distintas: os clientes maiores têm mais interação e touchs proativos, e os menores participam de uma jornada mais automatizada. Há várias formas de segmentar: por produto, por touch (low, mid, high), por MRR etc. O caminho do guia é criar um campo customizado e preenchê-lo por regras.

**Criar o campo customizado**:
1. Vá em Configurações > Clientes > **Campo customizado** (no menu, "Campos Customizados") > **Novo campo**.
2. Na janela **Criar campo customizado**, preencha:
   - **Título do campo**: indique a segmentação. Logo abaixo fica o link **Visualizador de nome interno**.
   - **Descrição do campo** (opcional). Aviso da tela: não é possível inserir queries no texto da descrição.
   - **Identidade do campo**: Cliente ou Contato.
   - **Origem** do preenchimento: Manual, Custom Data, Integração ou Outros.
   - **Tipo do Campo**: Text, Date, Number, Checklist, Select ou Lista de Usuários.
   - **Máscara**: uma lista; não obrigatória.
   - **Condição** (caixas): Campo Alterável, Ativo, Campo Obrigatório, Edição Restrita ao Perfil, Ocultar Campo na Tabela e Sobrescrito na Integração. Na captura, vêm marcadas Campo Alterável, Ativo e Sobrescrito na Integração.
3. Clique em **Salvar** (ou Cancelar).

**Criar as regras de preenchimento**:
1. Em Configurações > Regras, crie uma pasta para a segmentação (**Criar pasta**) e coloque nela todas as regras dessa segmentação. No guia, a pasta se chama "UPDATE | Portes do cliente" e tem as regras Tier 1, Tier 2 e Tier 3, cada uma com uma ação.
2. Em cada regra, defina as condições daquele segmento e use a ação **Atualização**: selecione a tabela de origem (Atualizar atributo para: Cliente), o campo customizado criado e, em **Valor**, o nome do segmento que as condições representam.
3. Repita para os outros segmentos, ajustando Nome, Condições e Valor. Duplicar as regras agiliza.
- Cada segmento deve ter regras específicas, para que os clientes de um mesmo segmento tenham todas as características em comum. Para manter a organização, crie as regras numa pasta e cada segmento separado.
- A segmentação dá mais eficiência às comunicações e aos processos, com ações mais assertivas e personalizadas.
- Sugestão do guia: além do campo nas tabelas, crie uma Jornada da Carteira baseada nos segmentos (seção 7).
- Veja o Exemplo 4. Na captura do exemplo, a ação atualiza o campo **Porte** com o valor "Tier 1". O guia não mostra se, naquele ambiente, "Porte" é o campo customizado criado no passo anterior.

### 15. Tickets e SLA
Mesmo não sendo o responsável por resolver os chamados, o CS precisa acompanhar os abertos, os resolvidos e principalmente os que estouraram o prazo de resolução. Para escalar essa análise, o guia indica uma regra que mostre ao CS ou CSM quais clientes têm tickets em aberto que já estouraram o SLA.

**Regra** (Configurações > Regras > Criar Regra):
1. Em Condições, defina o valor do **total de chamados acima do SLA** que ativa a ação.
2. Defina o agendamento e a recorrência.
3. Em Ações, configure por exemplo um alerta ao CS responsável pelo cliente, ou e-mails para a equipe de suporte.
- Na captura do guia, a regra tem duas ações: um **Email** (Enviar para: Sponsor; Remetente: CS da Conta) e um **Alerta** ("Chamado acima do SLA", para o CS). Veja o Exemplo 9.

**Quando a regra dispara um alerta ou uma atividade para o CS**, o guia sugere ações para reduzir o impacto no cliente:
- analisar quais chamados estão abertos e ver se algum já pode ser finalizado;
- se nenhum puder, avisar o cliente de que está acompanhando os chamados e fazendo o possível para encerrá-los o quanto antes;
- se necessário, escalar os chamados internamente para que os times responsáveis priorizem.

**Visualizar** (Minha carteira > Tabelas > Clientes ou Suporte):
- **Clientes**: campo **"Chamados acima do SLA"** (a quantidade), com o filtro "Maior que 0".
- **Suporte**: campo **"Situação SLA"**. Outras colunas vistas: Chamado, Cliente, Aberto por, Tipo (ex.: problem, task, question, incident), Categoria, Grupo, Encerramento, SLA (data), Descrição e Grupo Econômico. A tabela tem "Limpar filtros" e "Exportar".
  - Chamado em aberto (sem data de conclusão) com SLA posterior à data de hoje: dentro do prazo.
  - Chamado em aberto com SLA anterior à data de hoje: atrasado (na tabela, "Atrasado").
  - Chamado com data de conclusão: não tem situação SLA e aparece como "---".

**Cards na Visão 360** — a Visão 360 pode mostrar os dados de suporte com indicadores e gráficos que já existem no produto:
1. O texto do guia diz "Configurações > Clientes > Cards Visão 360". Na captura, o caminho é Configurações > Clientes > **Visão 360**, e "Cards Visão 360" é o nome de uma das visões da lista.
   - A tela Visão 360 tem Criar Visão 360, Criar Pasta, Duplicar, Mover, Inativar e Apagar, e a caixa "Mostrar somente Visões 360 ativas".
   - Colunas: Nome, Data de Criação, Criado Por e Status. A ordem das visões (arrastar e soltar) é a ordem de execução.
2. Abra a visão. No bloco **Cards**, clique em **Adicionar card** e escolha o indicador na janela "Adicionar Card" (lista com busca, ex.: Tickets em aberto).
   - A lista mostra o nome e o identificador do indicador, ex.: Usuários Ativos (mês) (active_users), Utilização de Licenças (license_usage), Tempo de Uso Total (usage_time), MRR (mrr), Usuários Contratados (contracted_users).
   - Os cards podem ser reordenados arrastando, e a lixeira remove o card.
3. Clique no card para abrir **Gráficos por card** > **Adicionar gráfico**. Cada gráfico é de "Página inteira" ou "Meia página", com lápis para editar e lixeira para remover. Arraste para ordenar.
   - Aviso da tela: ao ordenar, preste atenção ao modelo da página; não é indicado usar só um gráfico de meia página seguido de um de página inteira.
   - Gráficos de exemplo do card "Chamados acima do SLA" (nomes cortados na captura): Chamados por criti…, Chamados por cate…, Distribuição de cha…, Chamados aberto ú… e Suporte detalhado (tabela).
4. Clique em **Salvar**.
5. Na Visão 360 do cliente (Tabelas > Clientes, ou a busca do topo com o filtro Clientes), os cards aparecem em **Principais Indicadores**. "Ver detalhes" no card abre os gráficos associados.
- Cards de exemplo no guia: Qtd. de admissões, Engagement Score, NPS, Títulos em atraso, Qtd chamados em aberto, Chamados acima do SLA, Valor títulos vencidos, Dias em onb, Usuários ativos (mês).

### 16. Planos de ação NPS
Tão importante quanto receber as respostas de NPS é dar uma devolutiva ou montar um plano de ação para tratar cada uma. O guia cita dois dados: um cliente infeliz conta a experiência negativa para 9 a 15 pessoas (White House Office of Consumer Affairs), e um cliente fiel é 10 vezes mais rentável que um cliente de primeira compra (Institute of Customer). Com templates de e-mail disparados por regra, dá para retornar a promotores, neutros e detratores depois que respondem ao formulário de NPS.

- **Promotores e neutros**: e-mail de agradecimento disparado por regra depois da resposta. O guia mostra só o template, não as condições e ações dessa regra. O template de exemplo se chama "NPS promotora ou neutra com feedback":
  - logo da empresa e o título "Sua opinião é importante!";
  - "Olá «Cliente»!";
  - agradecimento pelo tempo dedicado a responder à pesquisa;
  - o feedback ajuda a aprimorar os serviços, e a empresa fica feliz com a experiência positiva;
  - agradecimento pela parceria;
  - "Abraços," e o marcador «Assinatura do Remetente».
- **Detratores**: uma regra aciona o CS da conta para contatar o cliente e entender o que está acontecendo, mostrando que o feedback está sendo tratado pelo time. Dá para limitar a ação aos detratores com MRR maior. O corte do exemplo, "detratores com MRR maior que 5k", deve seguir o que a sua empresa considera cliente estratégico.
  - **Playbook de retorno para detratores**: crie o playbook com as atividades da ação (seção 5). Veja a tabela no Exemplo 8.
  - **Regra**: na captura, atinge **Contatos**, com três condições (cliente ativo, MRR maior que 5000, Avaliação NPS menor que 7), e a ação é um **e-mail para os contatos detratores**. Veja o Exemplo 8.
  - O guia apresenta o playbook e a regra separadamente e não mostra a ação Playbook nessa regra. Para que a regra entregue as tarefas ao CS, adicione a ação **Playbook** com o playbook de retorno (seção 3).
- **Atinja Contatos, não Clientes**: numa empresa com 10 colaboradores em que 9 deram nota promotora e 1 deu nota detratora, a ação de contato (que informa sobre a análise da nota e do comentário) deve atingir só o contato detrator. Uma regra que atinge o cliente inteiro torna muito mais trabalhoso separar promotores de detratores.
- **Detratores de MRR menor** (abaixo de R$ 5.000,00 no exemplo): use outra estratégia, também com uma regra que atinge contatos: outro tipo de comunicado, ou uma pesquisa **CSAT** para entender melhor os motivos da nota (seção 9). O template de exemplo, "NPS detratores com mrr <5k":
  - "Sua opinião é importante!" e "Olá «Descrição Cliente»!";
  - agradecimento pelo tempo;
  - o feedback ajuda a avaliar o que a empresa faz bem e onde pode melhorar;
  - pergunta qual a sugestão de melhoria ou o ponto específico que levou à nota;
  - "Segue «Link formulário» para melhor esclarecer seus pontos de melhorias.";
  - "Agradeço sua paciência e compreensão."

### 17. Campos customizados (campo)
O guia mostra o campo customizado só na segmentação (seção 14), onde estão a tela e as opções. Na prática, ele é o que permite regras sobre qualquer coisa que o produto não tem nativamente. Detalhes e especificação modelo em `references/campos-customizados.md`.
- **Onde**: Configurações > Clientes > Campos Customizados > Novo campo. A "Identidade do campo" escolhe Cliente ou Contato.
- **Nome interno**: minúsculas, `_` entre palavras (`cs_feeling`, `dias_sem_atualizacao_cs`). Em colisão de nome, a plataforma pode sufixar (`cs_feeling_2`): **confira o nome interno gerado** (a janela tem o link "Visualizador de nome interno"). API, integrações e SQL usam o nome interno, nunca o rótulo. Use `scripts/nome_interno.py`.
- **Tipos** da tela: Text, Date, Number, Checklist, Select e Lista de Usuários. Na prática, Select funciona como lista de seleção única e Checklist como seleção múltipla; confirme no tenant.
- **Quem preenche**: pessoa, regra (ação Atualização), integração (SenseConnect) ou rotina via API. A tela tem "Origem" (Manual, Custom Data, Integração, Outros) e as caixas de Condição. Campo derivado deve ser **não editável** na tela (desmarque "Campo Alterável", ou use "Edição Restrita ao Perfil"); senão alguém sobrescreve e a automação reverte no dia seguinte. "Sobrescrito na Integração" define se a carga pode sobrescrever o valor: decida quem é o dono do campo.
- **Obrigatoriedade** (caixa "Campo Obrigatório"): evite em campos subjetivos (preenchimento defensivo: todo mundo marca o valor do meio para conseguir salvar).
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
- **Remetente dinâmico** (ex.: "CS da Conta", "CSM da Conta", "Implementador da Conta" ou um campo customizado do tipo lista de usuários, como "Comercial da Conta"): o valor é lido **por cliente, no momento do disparo**. Se o campo estiver vazio, a plataforma usa o remetente padrão (na prática, o CS da conta). Sintoma: "o e-mail saiu em nome da pessoa errada". Correções: alimentar o campo (seção 20) e pôr uma **condição de guarda** na regra (campo "não vazio"), ou aceitar o fallback de forma consciente.
- **Destinatários**: Sponsor, contatos por tipo, usuários (CS da conta). "Ver amostra de destinatários" antes de ativar. "Remover e-mails duplicados entre clientes" evita que o mesmo contato receba N cópias quando atende várias contas.
- **Marcadores**: insira sempre pelo botão **Mesclar Marcadores**; no editor, o marcador vira uma etiqueta (nos templates do guia: Contato Primeiro Nome, Cliente, Descrição Cliente, IS, Assinatura do Remetente, Link formulário). Marcador digitado à mão (ex.: `{{nome_cliente}}`) chega literal no e-mail se a sintaxe do tenant for outra. Campos customizados aparecem no menu pelo nome.
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
- Nas telas do guia: a lista de regras tem a coluna **Última execução** e o filtro por Status; a lista de playbooks tem **Aplicados**, **Clientes Impactados** e **Concluídos**; a lista de formulários tem **Estatísticas**. São o primeiro lugar para ver se algo está rodando.
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
| A Jornada da carteira não aparece | A tela não está habilitada no perfil | Habilite "Telas - Jornada da carteira" no perfil |
| Uma jornada específica não aparece para um perfil | A jornada não foi compartilhada com esse perfil; sem perfis com acesso, só Administrador e Sensedata a veem | Inclua o perfil em "Perfis com acesso" |
| Não é possível automatizar a jornada | A ação "Regras" não está habilitada no perfil | Em "Definir ações", selecione "Jornada da carteira" e "Regras" |
| Não dá para criar mais fases | Limite de 20 fases | Revise a estrutura da jornada |
| A jornada não salva | Nomes ou cores de fase repetidos | Use nome e cor diferentes em cada fase |
| O playbook não aparece no Kanban do Onboarding | É um Playbook normal; o Kanban mostra só Onboarding Playbooks | Crie-o como Onboarding Playbook |
| A imagem não entrou no e-mail manual (Visão 360) | Só entram imagens hospedadas online | Use o ícone de imagem com a URL da imagem |
| Depois da carteirização por regra, as atividades ficaram com o CS antigo | A transferência não foi marcada | Marque a transferência de atividades em aberto na ação Atualização |
| Cliente inativado por regra ficou sem data e motivo | A regra altera só o status | Preencha data e motivo à mão na Visão 360 |
| Todos os contatos do cliente receberam a ação de detrator | A regra atinge Clientes | Configure "Atingir: Contatos" |
| A categoria "Não revertido" não dispara o fluxo de churn | A categoria não foi aplicada na conclusão, ou não existe | Crie em Configurações > Atividades > Categorias e aplique na janela "Confirmar Conclusão" |
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
| **(campo)** A regra não enxerga um campo customizado novo | Campo criado, mas ainda sem valores; ou procurado pelo rótulo errado; ou criado com a caixa "Ativo" desmarcada | Confira a identidade do campo (Cliente × Contato), a caixa Ativo e se já há valores |
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
   [ ] Criar tarefa de email
   CC / CCO: Adicionar Grupo, se necessário
   [x] Remover e-mails duplicados entre clientes
   Enviar email às: 08:00 | [ ] Não enviar mensagem após o horário
   Remetente: Implementador da Conta | Responder-para: "is da conta" (texto digitado no campo)
   [ ] Email transacional
```
- Na captura, o contador mostra "7 condições", mas só as duas acima aparecem. O guia também não mostra a recorrência nem o "Enviar para" dessa regra.
- O conteúdo do template de boas-vindas do guia está na seção 10.
- **(campo)** Com "Há 5 ou menos dias" e execução diária, o mesmo cliente está na condição por vários dias: use "Atingir novamente o mesmo cliente: Nunca".

### Exemplo 3 — Carteirização por regra e distribuição automática
Caso do guia: todos os clientes com MRR acima de 5.000 vão para a carteira do CS "X".
```
Regra: Carteira CS X (nome de exemplo) | Ativo | Atingir: Cliente
2. Condições — Cliente | MRR | Maior que | 5000
3. Recorrência — Executar regra: Somente uma vez | Parar: Nunca | Atingir novamente: Nunca
4. Ações — Atualização:
   Atualizar atributo para: Cliente | Campo: CS | Valor: <usuário do CS X>
   [x] Transferir todas as atividades em aberto atreladas ao antigo responsável
   [ ] Transferir todas as atividades em aberto independente do responsável
```
- O texto do guia diz que o critério da captura é o porte dos clientes, mas a condição mostrada é MRR maior que 5000. Na regra da captura, o nome aparece como "Tier 1".
- As duas capturas diferem na recorrência: uma mostra "Todos os dias", a outra "Somente uma vez".

**Distribuição automática** (mesma estrutura, outra ação):
```
4. Ações — Distribuição automática:
   Pelo critério: Quantidade de Clientes
   Status do cliente na carteira: <status considerados, ex.: Ativo, Suspenso…>
   Preenchendo o campo: CS
   [x] Limitar quantidade de clientes na carteira → Quantidade clientes por carteira: 10 (opcional)
   [ ] Transferir … atreladas ao antigo responsável   [ ] Transferir … independente do responsável
   Selecione os usuários para distribuição: <CS 1>, <CS 2>
```
No exemplo do guia, os clientes são divididos entre dois CSs em partes iguais, ou o mais perto disso possível. A captura mostra "Todos os dias" e "Parar: Nunca", com as condições em branco.

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
- Todos os tiers valem para clientes com status Ativo ou Suspenso, usando dois grupos ligados por OU (seletor "E / OU" = "ou").
- Para criar Tier 2 e Tier 3, duplique a regra Tier 1 e ajuste nome, condições e valor. O guia mostra só a regra Tier 1; as condições de Tier 2 e Tier 3 vêm do texto.
- Na captura, o contador da regra Tier 1 mostra "5 condições", mas só as quatro acima aparecem. O guia também não mostra a recorrência dessas regras.
- **(campo)** Confira as bordas: com "Maior que 8999" e "Menor que 8.999", um MRR de exatamente 8.999 não entra em nenhum tier; o mesmo vale para 4.999,99 entre Tier 2 e Tier 3. Ajuste um dos limites de cada borda.
- **(campo)** No Tier 2, cada grupo (Ativo e Suspenso) precisa ter as duas condições de MRR, porque o OU separa os grupos inteiros.

### Exemplo 5 — Alerta de inadimplência
```
2. Condições — Cliente | Status | Igual a | Ativo
               E KPIs Padrões | Títulos em atraso | Maior que | 1
4. Ações — Alerta: "Cliente inadimplente!" | Destinatário: CS
           (opcional) Email ao cliente avisando sobre a inadimplência
```
Atenção ao valor: "Maior que 1" só atinge clientes com 2 ou mais títulos em atraso. Para "qualquer título em atraso", use "Maior que 0". O guia não mostra a recorrência dessa regra. O alerta chega ao CS no sino como "<cliente> - Cliente inadimplente!".

### Exemplo 6 — Renovação (60 dias)
**Alerta**:
```
2. Condições — Cliente | Status | Contém | ativo
               E Contrato | Fim vigência | Em 'X' ou menos dias | 60
3. Recorrência — definir a frequência de atualização
4. Ações — Alerta: "Você possui clientes com contratos com menos de 60 dias ou menos de renovação" | Destinatário: CS
```

**E-mail**:
1. Crie o template.
2. Crie a regra com as condições: cliente **Ativo** e o prazo de **Fim de vigência** (as mesmas do alerta).
3. Use a ação **Email** com o template, escolha para quem vai o envio e o remetente.
4. Clique em **Criar regra**.
```
4. Ações — Email (como na captura do guia):
   Criar email a partir de: <template de renovação>
   Enviar para: CS | [ ] Criar tarefa de email
   CC / CCO: Adicionar Grupo
   [x] Remover e-mails duplicados entre clientes
   Destinatários atingidos (amostra): Ver amostra de destinatários
   Não enviar para: Adicionar Grupo
   Enviar email às: (em branco) | [ ] Não enviar mensagem após o horário
   Remetente: CSM da Conta | Responder-para: (em branco)
```
No exemplo do guia, o e-mail vai para o CS (um aviso interno). Para avisar o cliente, troque "Enviar para" por um contato do cliente (ex.: Sponsor).

**Playbook "Playbook Renovação"** (sugestão de formatação do guia):
- Status Ativo, Responsável CS.
- "Permitir editar playbooks em andamento": marcado. "Considerar somente dias úteis": desmarcado.
- Nas quatro tarefas, o Responsável está em branco ("Selecione") e a Categoria é "Nenhuma".

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
2. Condições — Grupo A ("4 condições afetando 1 Cliente"):
   Cliente | Status | Igual a | Ativo
   E Atividades | Conclusão playbook há X ou menos… (nome cortado na captura) | Igual a | 3
   E Atividades | Concluiu playbook com título | Igual a | Playbook Crise (valor escolhido numa lista)
   E Atividades | Categoria | Igual a | Não revertido
3. Recorrência — Executar regra: Segundas as sextas | Parar: Nunca | Atingir novamente: Sempre
4. Ações —
   Playbook: "Churn financeiro manutenção/Setup" | Responsável: Manter padrão template
   Email: template "Disparo de pedido de cancelamento" | Enviar para: Sponsor ([ ] Criar tarefa de email)
          [x] Remover e-mails duplicados | Enviar email às: (em branco)
          Remetente: CS da Conta | Responder-para: "cs da conta" | [x] Email transacional
```
A categoria "Não revertido" é aplicada pelo CS ao concluir a última atividade do "Playbook Crise", na janela "Confirmar Conclusão".
O guia sugere completar o fluxo com um e-mail ao financeiro e a **Atualização** do status para "Em cancelamento". No fim do fluxo, inative o cliente (seção 13). **(campo)** Com "Atingir novamente: Sempre" e a condição válida por 3 dias, o cliente pode receber o playbook e o e-mail mais de uma vez; a Atualização do status para "Em cancelamento" na mesma regra tira o cliente da condição "Status Igual a Ativo" e evita a repetição.

### Exemplo 8 — Detratores com MRR acima de 5 mil
```
Regra: NPS - RESPOSTA DETRATORA | ACIMA DE 5K | Ativo | Fora das pastas | Atingir: Contato
2. Condições — Grupo A ("3 condições afetando 126 Contatos", Ver amostra de contatos):
               Cliente | Status | Igual a | Ativo
               E Cliente | MRR | Maior que | 5000
               E NPS | Avaliação NPS | Menor que | 7
3. Recorrência — Data de início | Todos os dias | Parar: Nunca | Atingir novamente: A cada intervalo de 01 dias
4. Ações — Email:
   Criar email a partir de: <template para detratores>
   [x] Criar tarefa de email
   CC / CCO: Adicionar Grupo
   [x] Remover e-mails duplicados entre clientes
   Enviar email às: 10:00 | [ ] Não enviar mensagem após o horário
   Remetente: CSM da Conta | Responder-para: (em branco)
   [ ] Email transacional
```
- Na captura, a ação Email dessa regra não mostra o campo "Enviar para"; o e-mail vai para os contatos detratores atingidos pela regra.
- Para que o CS receba as tarefas, adicione a ação **Playbook** com o playbook abaixo (o guia não mostra essa ação na regra; seção 16).

**Playbook de retorno para detratores** (o texto do guia o chama de "Detratores com MRR maior que 5k"; na captura, o nome é "Detratores com NPS maior que 5k"):
- Status Ativo, Responsável CS.
- "Permitir editar playbooks em andamento" e "Considerar somente dias úteis": desmarcados.

| # | Tarefa | Tipo | Prioridade | Responsável | Categoria | Dias |
|---|---|---|---|---|---|---|
| 1 | Feedback negativo recebido | Contato | Normal | CS | Nenhuma | 2 |
| 2 | Apuração do feedback | Tarefa | Normal | CS | Nenhuma | 4 |
| 4 | Verificar e acompanhar o plano de ação realizado | Acompanhamento | Normal | CS | Nenhuma | 14 |

A tarefa 3 não aparece nas capturas do guia. O corte de 5 mil é só um exemplo: use o que a sua empresa considera cliente estratégico. Para detratores abaixo do corte, crie uma regra parecida, também atingindo Contatos, com outro comunicado ou uma pesquisa CSAT (template "NPS detratores com mrr <5k", seção 16). **(campo)** Com "A cada intervalo de 1 dia", o mesmo detrator pode receber o e-mail todo dia enquanto a última nota continuar < 7; confirme se a condição olha só respostas recentes ou use um intervalo maior.

### Exemplo 9 — Chamados acima do SLA
```
Regra: Chamados acima do SLA | Ativo | Localização: Gatilhos de proteção | Atingir: Cliente
2. Condições — Suporte - Cha… (nome cortado) | Total de chamados acima do SLA | Maior que | 2
3. Recorrência — Data de início | Todos os dias | Parar: Nunca | Atingir novamente: Sempre
4. Ações —
   Email: Criar email a partir de: <template> | Enviar para: Sponsor ([ ] Criar tarefa de email)
          [ ] Remover e-mails duplicados | Enviar email às: (em branco)
          Remetente: CS da Conta | Responder-para: "CS da Conta" | [ ] Email transacional
   Alerta: "Chamado acima do SLA" | Destinatário: CS
```
- O texto do guia sugere alerta ao CS ou e-mail para a equipe de suporte; na captura, o e-mail vai para o Sponsor (o template da captura é um exemplo sem relação com SLA).
- "Maior que 2" só atinge clientes com 3 ou mais chamados acima do SLA; para "qualquer chamado", use "Maior que 0" (o filtro que o guia usa na tabela Clientes).
- **(campo)** Com "Todos os dias" e "Atingir novamente: Sempre", o alerta e o e-mail se repetem todo dia enquanto o cliente tiver chamados acima do SLA. Para não virar ruído, use "A cada intervalo de N dias".

### Exemplo 10 — Automação de fase: Onboarding → Adoção
```
2. Condições — Atividades | Concluiu playbook com título | Igual a | Onboarding
4. Ações — Atualização: Cliente | Fase | Adoção
           (opcional) Playbook: "Adoção"
```

### Exemplo 11 — Atividade por regra: cliente novo, conferir contatos
Caso do guia: sempre que entra um cliente novo, o CS deve verificar os contatos cadastrados. As capturas do passo a passo de regras (seção 2) mostram uma regra "Revisar Contatos" com essas condições e essa recorrência; as da ação Atividade mostram a tarefa.
```
Regra: Revisar Contatos | Ativo | Localização: Fora das pastas | Atingir: Cliente
2. Condições — Cliente | Data de Inserção no SD | Há 'X' ou menos dias | 3
               E Cliente | Status | Igual a | Ativo
3. Recorrência — Data de início | Todos os dias | Parar: Nunca | Atingir novamente: Nunca
4. Ações — Atividade:
   Descrição: Verificar contatos cadastrados | Tipo de atividade: Tarefa | Categoria: (em branco)
   Prioridade: Alta | Conclusão: Dias para conclusão = 3 | Responsável: CS | Horas utilizadas: 0
   Editar instruções / Editar Checklist / Anotações: conforme o processo
   [x] Enviar alerta para o responsável
```
**(campo)** Sugestão de checklist: sponsor cadastrado; e-mails válidos; decisor e usuário-chave identificados.

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
- Conclusão do guia: o material existe para facilitar a compreensão e a configuração de casos de uso, com exemplos práticos e diretrizes claras. O guia encoraja **testar** as instruções, o que reforça o conhecimento da plataforma e ajuda a construir autonomia para explorar as possibilidades. Em caso de dúvida ou necessidade de suporte, procure o time responsável pelo projeto (IS, CS ou CX). Replique as dicas ou adapte às necessidades da sua empresa e operação.
- Os nomes de campos, categorias, templates, pastas e valores dos exemplos vêm das telas do guia e podem variar por ambiente. As capturas do guia são de versões diferentes da tela (ex.: "Início de execução" × "Data de início"; condições e ações numa tela mais antiga com "3 Ações").
- Antes de ativar regras que disparam comunicação para clientes, confira "Ver amostra de clientes/contatos" e "Ver amostra de destinatários".
- O guia mostra o status tanto como "Igual a | Ativo" quanto como "Contém | ativo". Como campos de texto diferenciam maiúsculas e minúsculas, confirme a grafia usada no seu ambiente.
- Itens marcados **(campo)** vêm de implantações reais e precisam de confirmação no tenant, principalmente: CC/destinatário por campo customizado na ação de e-mail, opção de não repetir disparo por N dias, disponibilidade da ação Atividade no plano, nome do header da API e endpoints liberados no contrato.
- Nunca inclua dados reais de clientes (e-mails, nomes, valores) em exemplos genéricos.
