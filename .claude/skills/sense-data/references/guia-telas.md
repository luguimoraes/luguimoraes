# O que cada tela do Guia de Configurações mostra

Inventário das telas e anotações do "Guia de Configurações e Casos de Uso" (SenseData, 108 páginas), na ordem do guia, conferido página a página com o texto e as capturas de tela. Os números entre parênteses são as páginas do PDF. Use para responder "onde fica" e "o que aparece" sem supor.

As capturas vêm de versões diferentes do produto (ex.: "Início de execução" × "Data de início"). Quando o usuário descrever outra tela, prefira o que ele vê.

Nomes de pessoas e de clientes que aparecem nas capturas foram omitidos.

## Índice do guia (3–4)
- O que é um caso de uso.
- Regras.
- Carteirização: manual, por critério, distribuição automática.
- Playbooks: criar Playbook, criar Onboarding Playbook, associar Onboarding manualmente, associar Playbook manualmente, associar Playbook automaticamente.
- Atividades: criação manual, criação automática.
- Jornada da carteira: configurar, adicionar clientes manualmente, adicionar automaticamente.
- Automação de fases.
- Pesquisas (NPS, CSAT): criação do formulário, disparo automático, disparo manual.
- Disparos de e-mails (boas-vindas, newsletter): criar template, enviar automaticamente.
- Acompanhamento de inadimplência: tabela de clientes, tabela Financeiro, alerta.
- Renovação: alerta, e-mail, playbook.
- Churn: fluxo, inativar o cliente.
- Segmentação por produto/plano/serviço: campo customizado, regra de preenchimento.
- Acompanhamento de tickets: automático, clientes acima do SLA, Visão 360.
- Planos de ação NPS: promotores, detratores.
- Conclusão.

## Boas-vindas e caso de uso (2, 5–6)
- O guia é base para jornadas, playbooks e regras; replique ou adapte à sua operação; dúvidas com IS, CS ou CX do projeto.
- Caso de uso "Envio de formulário NPS":
  - NPS 3 meses após o fim do Onboarding;
  - reenvio se não houver resposta em 7 dias;
  - nota promotora (10 e 9) → e-mail de agradecimento;
  - nota detratora (0 a 6) → playbook "Análise de clientes detratores" para o CS.
  - O guia traduz isso numa tabela Situação × Ação com quatro linhas.

## Regras (7–12)
**Caminho** (8): tela principal > ícone Configurações > Regras > **Criar Regra**.
- Menu lateral de Configurações (varia com a versão): Apps, Atividades, Clientes, Contas, CS Ops, Dados de Consumo, Comunicação, Indicadores, Logs, Lab, Regras, SenseConnect, Sense Lab.
- Submenu Regras (17): Regras Gerais, Regras Individuais, Regras de Terceiros, Arquivos Exportados.
- Tela de lista:
  - aviso: "Ordene as regras pela ordem que deseja executar arrastando e soltando na posição desejada, inclusive as pastas e regras dentro delas obedecem esta ordem de execução";
  - botões Criar Regra e Criar Pasta, caixa "Expandir todas as pastas";
  - filtros Atingir, Criado por, Status e Ação, e busca;
  - colunas ID, Nome, Criado por, Ações, Status, Última execução.
- Tela de criação: "Configurações da Regra", com os blocos 1 Informações, 2 Condições, 3 Agendamento e recorrência, 4 Ações.

**Passo 1 — Informações** (9)
- Nome: livre, "claros e objetivos". Exemplo: "Revisar Contatos".
- Status: Ativo roda na próxima atualização de dados do ambiente; Inativo não roda.
- Localização: a pasta, ou "Fora das pastas". "Crie pastas para organizar suas regras."
- Atingir: Cliente ou Contato.

**Passo 2 — Condições** (10) — anotações da captura:
- "Indique a origem do dado (Clientes, Contatos, Contratos, KPIs, etc.)" → Categoria.
- "Selecione a Operação desejada de acordo com o campo escolhido. Existem várias opções, que variam de acordo com o tipo de dado do campo (texto, número ou data)."
- "Descreva o Valor a ser comparado… Em caso de campos do tipo texto, letras maiúsculas e minúsculas são diferenciadas."
- "Duplique, adicione ou remova condições" → ícones ⧉ ⊕ ⊖ por linha.
- "Adicione mais grupos de condições/situações e crie lógicas de união (E) ou exclusão (OU)" → links Adicionar Grupo, Duplicar Grupo, Excluir Grupo; caixas Grupo A, Grupo B…; seletor "E / OU" entre grupos.
- "Veja uma amostra de Clientes ou Contatos que serão atingidos" → "N condições [afetando N Clientes] Ver amostra de clientes".
- Exemplo: Cliente | Data de Inserção no SD | Há 'X' ou menos dias | 3 e Cliente | Status | Igual a | Ativo.

**Passo 3 — Agendamento e recorrência** (11)
- Data de início: a regra executa a partir dela, incluindo o dia.
- Executar regra: periodicidade (todos os dias; ou períodos como uma vez por mês, a cada 15 dias, uma vez por semana). Valores vistos nas capturas: Todos os dias, Somente uma vez, Segundas as sextas.
- Parar execução: (o) Nunca, (o) Em <data>, (o) Após <N> ocorrências.
- Atingir novamente o mesmo cliente (desde que continue nas condições): Nunca, Sempre, "A cada intervalo de" <N> dias.

**Passo 4 — Ações** (12)
- Link "Adicionar Ação", lista **Ação** ("Selecione"): Alerta, Atualização, Playbook, Atividade, Distribuição automática, Email, SMS, Webhook, Formulário, Relatório, Atualização da Jornada, WhatsApp.
- Sem limite de ações por regra.
- Cada ação abre "Configurações da Ação" e tem um X para remover.

## Carteirização (13–19)
Três formas (14): manual (sem critério específico, ou para migrar clientes entre CSs); por critério (MRR, segmento etc.); distribuição automática pela plataforma.

**Manual** (15–16)
- Tabelas > Clientes.
  - Barra superior: Minha carteira, Atividades, Tabelas, Calendário, Onboarding, Performance da Equipe, Jornada da Carteira.
  - Cartões no topo da tabela: Sense Score, Clientes, MRR, Renovam (90 D).
  - Botões Adicionar cliente, Editar e Excluir; seletores Clientes, Minha Carteira e Opções.
- Buscar > marcar a caixa no início da linha ("1 cliente selecionado. Limpar seleção.") > **Editar**.
- Janela **Edição em Massa**:
  - "Selecione quais dados deseja editar:", com busca, "Selecionar todas as opções" e caixas por campo (ex.: Cidade, Estado, Porte, Fase, Segmento, Status, CSM, CS, Comercial e campos customizados);
  - na tela seguinte, um seletor por campo marcado;
  - Cancelar / **Próximo** > confirmar > "Sucesso! N clientes editados com sucesso!".

**Por regra** (17–18)
- Texto: "o critério é o porte dos clientes"; exemplo "MRR acima de 5.000 → carteira do CS 'X'".
- Captura (17): regra com nome "Tier 1", Ativo, numa pasta de segmentação, Atingir Cliente, condição Cliente | MRR | Maior que | 5000, Todos os dias, Parar Nunca.
- Captura (18): rótulo antigo "Início de execução"; Executar regra "Somente uma vez"; Parar Nunca; Atingir novamente Nunca.
- Ação Atualização (18): Atualizar atributo para Cliente | Campo CS | Valor <usuário>.
  - [x] Transferir todas as atividades em aberto atreladas ao antigo responsável.
  - [ ] Transferir todas as atividades em aberto independente do responsável.
  - Depois, Criar Regra.
- Pastas de exemplo na lista de regras (17, 58): Jornadas da Carteira, Regras Desativadas, Engajamento - Uso Produto, NPS / CSAT, Caso de Uso, Upsell/Crossell.

**Distribuição automática** (19) — ação "Distribuição automática", Configurações da Ação:
- **Pelo critério**: Quantidade de Clientes.
- **Status do cliente na carteira**: seleção múltipla (ex.: Ativo, Inativo, Suspenso…).
- **Preenchendo o campo**: CS.
- [x] **Limitar quantidade de clientes na carteira** → **Quantidade clientes por carteira** (10).
- [ ] Transferir … antigo responsável; [ ] Transferir … independente do responsável.
- **Selecione os usuários para distribuição**: duas listas com os botões » › ‹ «.
- Exemplo: dois CSs, quantidade igual ou o mais próxima possível. Agendamento Todos os dias, Parar Nunca; condições em branco na captura.

## Playbooks (20–35)
**Conceito** (21–22): conjunto de atividades que transforma a estratégia em tarefas. Dois tipos: Onboarding Playbook e Playbook.
- Exemplo: "Playbook de Execução de Cancelamento", com as tarefas extração do feedback do cliente, envio do e-mail do financeiro e desligar o ambiente. Independentes, em sequência ou não.
- A captura mostra a Visão 360 > Atividades:
  - contadores Todos, Vencem hoje, A vencer, Atrasadas, Em pausa;
  - botões Adicionar Atividade e Adicionar Playbook, filtro de responsável;
  - colunas Tipo/Descrição, Responsável, Cliente, Categoria, Data ("Atrasada há N dias", "Conclusão em N dias").

**Lista** (23): Configurações > Atividades > Playbooks.
- Submenu Atividades: Categorias, Onboarding Playbooks, Playbooks, Tipos de Atividades, Geolocalização.
- Aviso: ordem de execução por arrastar e soltar (inclusive pastas); "Playbooks normais não aparecem na visão Kanban dos Playbooks de Onboarding."
- Botões Criar Playbook, Criar Pasta, Duplicar, Mover, Inativar, Apagar, Restaurar; filtro "Mostrar ativos"; busca.
- Colunas: Nome, Id, Data de Criação, Criado por, Total de Atividades, Status (chave), Aplicados, Clientes Impactados, Concluídos.

**Criar Playbook** (24–27)
- Dados: Nome (ex.: "Retenção"), Status, Responsável (perfil ou usuário; ex.: CS).
- Caixas: "Permitir editar playbooks em andamento." e "Considerar somente dias úteis ao calcular previsão de conclusão".
- OBS. do guia: ativo + associado a regra → dispara quando a carga roda; sem regra → só manualmente.
- **Tarefas do playbook** — cada tarefa é um bloco recolhível "N. <descrição>" com alça de arrastar. Campos:
  - Tipo ("caso precise de uma nova opção é possível criá-la em Tipos de Atividades");
  - Prioridade;
  - Descrição (título);
  - Responsável (pode ser outro perfil ou usuário);
  - Categoria ("associe ou não a atividade a alguma categoria para gerar gatilhos"; padrão Nenhuma);
  - Dias ("após quantos dias de atribuição o prazo para a primeira tarefa do playbook começa a contar");
  - Hora De Início, Hora De Fim e Horas Utilizadas (em algumas capturas, "Valor").
- Links Adicionar instruções, Adicionar checklist e Adicionar notas:
  - janela de instruções: editor de texto com botão VAR;
  - "Checklist da Atividade": itens com caixa, "+ Adicionar item", Excluir;
  - "Adicionar anotações": editor de texto.
  - Depois de preenchidos, os links viram "Editar …".
- Ícones duplicar, adicionar e excluir tarefa.
- Botões Cancelar / **Salvar playbook**. "Playbook criado e disponível para uso." "Crie pastas para organizar seus playbooks."
- Exemplo de conteúdo (26), playbook de retenção:
  - tarefa 1 "Entrar em contato com o cliente" (Ligação, Normal, Dias 1);
  - tarefa 3 "Formalizar ao grupo de churn o que foi feito para a retenção e informar a quantidade de horas" (Tarefa, Normal, Dias 3);
  - instruções em 5 passos: formalizar a retenção; detalhar o que levou ao pedido de cancelamento; descrever tratativas e prazos; informar como será o acompanhamento; retornar com o resultado final;
  - checklist: informar no grupo; listar as reclamações do cliente; criar um cronograma de acompanhamento semanal;
  - nota: acionar o líder direto para nova reunião, se necessário.

**Onboarding Playbook** (28–32)
- Conceito (28): ações divididas em fases; progressão conforme a conclusão das atividades. Diferenciais: quadro Kanban e prazo de cada atividade em dias; barra de progresso com o percentual.
- Tela Onboarding, "Visão Geral do Onboarding":
  - filtros Playbook, Responsável, Cliente, Categoria;
  - contadores Todos, Atrasadas, Vencem hoje, A vencer, Concluídas, Em pausa;
  - Adicionar Playbook; visões Lista, Quadro, Tabela;
  - "Visão Quadro - (N Clientes)" com as colunas Kick-off, Formação, Acompanhamento, Encerramento e "Concluídos 30 dias". "As fases são totalmente customizadas."
- Lista (29): Configurações > Atividades > Onboarding Playbooks. Mesmos botões da lista de Playbooks.
- Criar (30–32):
  - Nome (ex.: "Onboarding"), Status, Responsável (ex.: perfil IS) e **Categoria**; as mesmas duas caixas.
  - Por tarefa: **Grupo** ("a fase que pertence a atividade"; ex.: Planejamento, Handoff), Tipo, Descrição, Responsável, Categoria, Dias, **Duração (Dias)** ("informe o prazo final em dias para conclusão da atividade"), Hora De Início, Hora De Fim, Horas Utilizadas.
  - Tarefas de exemplo: "Alinhamento e Kickoff" (Ligação, IS, Dias 0, Duração 4); "Reunião de Handoff com cliente" (Reunião, IS, Dias 84, Duração 4).
  - Salvar playbook.

**Associar** (33–35)
- Onboarding manual (33): barra superior > Onboarding > Adicionar Playbook.
  - Janela: Cliente ("Selecione um Cliente"), Playbook, Responsável ("Manter o padrão do template"), [ ] Marcar como concluído.
  - Cancelar / Adicionar Playbook. Para só ver, procure no quadro.
- Playbook manual (34): Tabelas > Clientes > cliente > Atividades > Adicionar Playbook.
  - Janela "Adicionar Playbook": Cliente (preenchido), Playbook, Responsável ("Manter padrão template"), [ ] Marcar como concluído. Para só ver, procure na lista.
- Por regra (35): ação Playbook > Configurações da Ação: **Playbook associado**, **Responsável** (ex.: CS) e **Categoria** (Nenhum).
  - "Se manter o mesmo Responsável será utilizado o que foi configurado no playbook."
  - "É possível adicionar categorias para ter classificações do playbook."
  - Para uma regra existente, basta editá-la.

## Atividades (36–42)
- Conceito (37): registro de todas as ações com o cliente; manual ou "disparando por padrão em determinadas situações"; padrão e sequência → Playbook.
- Onde criar (38–40): opção 1, tela Atividades; opção 2, Visão 360 > Atividades.
  - Barra superior: Minha carteira, Atividades, Tabelas, Calendário, Onboarding, Performance da Equipe, Jornada da Carteira, Sense Analytics.
  - Minha carteira: Principais Indicadores, SenseScore por cliente (Bom/Neutro/Ruim).
- Tela Atividades (39): Adicionar Atividade, Adicionar Playbook, "Selecionar todas as 50 atividades da página".
- Formulário **Adicionar atividade** (39), abas **Detalhes** e **Checklist e instruções**:
  - Cliente* ("selecione um cliente para a atividade ser atribuída");
  - Tipo de atividade* (personalizável em Configurações > Atividades > Tipos de Atividades);
  - Contato no cliente ("indique quem será o receptor"), com ícones de e-mail, WhatsApp e telefone;
  - Descrição* (título);
  - Data de início*, Hora de início, Prev. de conclusão*, Hora de fim;
  - Valor, Prioridade (Normal), Categoria (personalizável em Configurações > Atividades > Categorias);
  - Responsável* (o usuário que executa);
  - Anotações ("campo destinado ao usuário que queira anotar algo relevante");
  - Arquivos ("anexe arquivos importantes": Adicionar do Computador, Adicionar do Google Drive);
  - checklist e textos de instruções (aba própria);
  - rodapé: [ ] Marcar como concluída, Cancelar, Adicionar atividade, ☆ Marcar como favorito;
  - "*Campos obrigatórios".
- Visão 360 (40): cabeçalho do cliente com logo, cards de campos e as abas.
- Por regra (41–42): exemplo "sempre que um novo cliente entrar, o CS deve verificar os contatos cadastrados". Ação Atividade:
  - Descrição ("Verificar contados cadastrados", sic), com os links Editar instruções e Editar Checklist;
  - Tipo de atividade (Tarefa), Categoria (Selecione), Prioridade (Alta);
  - Hora de início, Hora de fim;
  - Conclusão: "Dias para conclusão" + 3;
  - Responsável (CS), Horas utilizadas (0), Anotações (editor com VAR);
  - [x] **Enviar alerta para o responsável** ("para que o responsável receba uma notificação quando a atividade for criada");
  - "Ao finalizar a configuração, clique em Criar Regra."
- Conclusão de atividade (80): janela **Confirmar Conclusão** com Cliente, Atividade, Data conclusão, Valor, Categoria (lista), Anotações; Cancelar / Concluir tarefa.

## Jornada da carteira (43–52)
- Conceito (44): fases do relacionamento em vários tipos de produto; ciclo de vida, etapas e indicadores.
  - Minha carteira mostra: SenseScore por MRR, MRR, Variação do MRR, MRR em risco, MRR para expansão, Clientes ativos, Novos clientes, Clientes em risco, Clientes para expansão, e Atividades - 60 dias.
- **Perfil** (45): Configurações > Contas > Perfis.
  - Tela "Perfis de Usuário": Adicionar Perfil; colunas Nome, Papel, Usuários, Menus, Ações, Data de criação, Criado por; ícone Editar.
  - Bloco "Definir menu" ("escolha os itens de menu que o perfil pode acessar"): "Telas - Jornada da carteira" > seta para a direita ("transfira os itens selecionados para o menu da direita").
  - Bloco "Definir ações" ("escolha quais ações o perfil irá poder realizar"): Jornada da carteira e Regras > seta.
    - Ações do grupo Jornada da Carteira: Atualizar fase, Adicionar clientes, Remover clientes, Editar Filtros da Jornada.
    - Outros grupos vistos: Disparar Formulário, Mapa de Contatos, NPS, Playbooks.
  - Salvar perfil.
- **Criar** (46): Configurações > Clientes > Jornada da carteira > Criar Jornada.
  - Lista com Criar Jornada, Criar Pasta, Duplicar, Mover, Inativar, Apagar; colunas Nome, Perfil.
  - Janela "Criar Jornada", aviso: "Caso a Jornada não seja compartilhada com nenhum perfil, apenas os perfis de administrador e Sensedata terão acesso. Nomes e cores das fases da jornada não podem ser iguais."
  - Campos: Nome da Jornada, Perfis com acesso, e por fase: Nome Fase*, Tempo estimado na fase (dias)*, Cor da fase*; ⊕/⊖ e alça de ordenar; Cancelar / Salvar.
  - Obs.: tempo estimado realista (indicador de atraso); limite de 20 fases (quantidade de cores).
- **Visualizar** (47): barra superior > Jornada da carteira > "Selecionar Jornada" (jornadas em pastas).
  - Adicionar cliente, Exportar, Pesquisar cliente, ícones lista/Kanban, "Ordenar por: Padrão", Minha carteira, Filtros.
  - Abas "Geral (N)" e uma por fase; gráfico de rosca; cada fase expande pela seta. Kanban pelo ícone à direita.
  - Exemplo: jornada "Renovação" com Renovação 60D+, 60D, 30D, 15D.
- **Adicionar manual** (48): Adicionar cliente > janela com Jornada, Fase, Cliente > salvar.
- **Adicionar por regra** (49): ação "Atualização da Jornada":
  - Atualizar jornada para (ex.: Renovação), Atualizar fase para (ex.: Renovação 60D);
  - [ ] "Excluir da jornada e/ou fase clientes atingidos pelo passo 2 condições";
  - depois: salvar e executar > conferir os clientes > "Disparar regra".
- **Card do cliente** (50): abas Detalhes e Anotações.
  - Detalhes: jornada e etiqueta da fase com lápis; Tempo na fase, Tempo de vida, Última atualização.
  - Principais indicadores, ex.: Countdown etapa, Progresso funil (%), Qtd de touchs (15 dias), Dias sem touch.
  - Anotações: "Digite a sua anotação aqui". Botão Fechar.
- **Exemplos de uso** (51): "Carteira Onboarding" (uma aba por pessoa do time) e "CS Felling" (sic), com as abas Geral, Sem mapeamento, Em cancelamento, Integração Instável, Baixo Engajamento, Troca de Sponsor, Insatisfação Produto.
- **Jornada × Onboarding Playbook** (52):
  - a jornada metrifica a etapa, definida manualmente ou por regra;
  - o onboarding avalia pelas atividades (concluídas, a vencer hoje, atrasadas, todas), em lista, quadro ou tabela;
  - na visão Lista: "Selecione um playbook para ver os clientes por etapa"; filtros Playbook, Status ("Playbooks Não Concluídos"), Resp. Playbook, Resp. Atividades, Cliente, Categoria.

## Automação de fases (53–54)
- Condição: Atividades | Concluiu playbook com título | Igual a | Onboarding.
- Ação Atualização: Cliente | Fase | Adoção.
- Mais ações, ex.: disparar o playbook "Adoção".
- Captura em versão antiga da tela ("0 condições afetando 0 clientes Ver clientes", "3 Ações").

## Pesquisas (55–60)
- Configurações > Comunicação: SPF, Autorização de Envio, Listas de Envio, Templates de Email, Templates de WhatsApp, Templates de Formulário.
- Tela **Formulários** (56):
  - Criar Formulário, Criar Pasta, Duplicar, Mover, Inativar, Apagar; [x] "Mostrar somente formulários ativos";
  - colunas Nome, Tipo (NPS ou Livre), Assunto (padrão "Convite para responder formulário"), ID, Data de Criação, Criado Por, Status, Estatísticas;
  - o formulário de CSAT da lista tem o tipo "Livre".
- Criar (56–57): "Bem vindo ao construtor de formulários! … Selecione o template que deseja:" → **Net Promoter Score (NPS)** ou **Formulário Livre**.
  - Texto: "Nesta tela você pode criar templates de pesquisa como NPS, CSAT ou outros formulários livres."
  - Construtor de Formulário: nome editável, Enviar Teste, Salvar, Salvar e sair.
  - Blocos do NPS: Resposta, Escala NPS, Texto, Título.
  - Canvas: "+ Adicionar logo", título, descrição, texto, escala 0–10 "Pouco provável"–"Muito provável".
  - "Para criar outro tipo de pesquisa ou ter mais possibilidade de personalização, crie um Formulário livre."
- Por regra (58): ação Formulário:
  - Tipo do formulário (Formulário NPS), Disparar por (Email), Selecionar template do formulário;
  - Enviar para (grupo, ex.: IS) com [ ] Criar tarefa de formulário e X; Adicionar Grupo;
  - [ ] Remover emails duplicados entre clientes; Não enviar para (Adicionar Grupo);
  - Enviar email às + [ ] Não enviar mensagem após o horário;
  - Remetente (CS da Conta), Responder para.
- Manual (59–60): Visão 360 > Formulários > Adicionar Formulário.
  - A aba tem filtros Tipo de formulário, Tipo de envio, Meio de envio, Enviado por, Data do disparo, e as colunas Nome, Tipo de formulário, Tipo de envio, Meio de envio, Enviado por, Data do disparo, Total de respostas, Última resposta, Respostas.
  - Janela "Selecionar formulário": Tipo de formulário, Formulário, "Enviar link do formulário via e-mail" ou "via sms", Enviar para (contato), [x] Criar tarefa de formulário, Prosseguir.
- Visão 360 (59): abas Visão 360, Atividades, Arquivos, Contratos, Histórico, Lista de contatos, Notas, Formulários.
  - Cabeçalho com as jornadas do cliente e o link "Gerenciar".
  - Cards de campos, botão "Ver mais informações", "Principais Indicadores".

## E-mails (61–67)
- Conceito (62): padronizar e escalar a comunicação; templates com formulários integrados, na identidade visual da empresa.
- Lista (63): Configurações > Comunicação > Templates de Email.
  - Aviso de ordenação por arrastar e soltar.
  - Criar Template, Criar Pasta, Duplicar, Mover, Inativar, Apagar; "Mostrar ativos".
  - Colunas Nome, Assunto, ID, Data de Criação, Criado Por, Status.
- Editor (64–65):
  - Barra superior: "Nome do Template*" + Editar, Enviar Teste, Salvar, Salvar e Sair.
  - Painel direito com as abas Conteúdo, Blocos, Corpo, Imagens. Blocos: Colunas, Título, Texto, Imagem, Botão, Divisor, HTML, Menu, Social.
  - Barra de texto: fonte, tamanho, estilos, alinhamento, listas, cores, link, **Mesclar Marcadores**, **Texto Inteligente**.
  - Rodapé: desfazer/refazer, pré-visualizar, desktop/celular.
  - Anotações da captura: texto (fonte, cor, alinhamento, espaçamento); redes sociais; imagens; colunas; HTML; divisões para assuntos diferentes no mesmo envio; botões de CTA para links externos ("ótimos para aumentar a taxa de cliques"); "Mesclar Marcadores" (variáveis, campos customizados e KPIs); blocos duplicáveis e deletáveis.
  - Dicas: título claro (ex.: "Email de boas-vindas ao Onboarding"); assunto que estimule a abertura; arrastar blocos da coluna da direita; teste para o seu e-mail antes (links, imagens, fontes, digitação).
- Template de boas-vindas (65), com marcadores como etiquetas:
  - "Olá, «Contato Primeiro Nome». Tudo bem?"; "Meu nome é «IS», … conduzir o onboarding em conjunto com o time «Cliente»";
  - kick-off remoto de cerca de 1 hora; pauta: alinhamento das expectativas, overview da jornada completa, detalhamento das etapas do onboarding;
  - o que é preciso: time de negócios responsável pelo onboarding e responsável técnico de integrações;
  - link de agenda.
- Regra de e-mail (66) — anotações da captura: tabela onde a informação é buscada; condição específica; operação; valor; ação "envio de e-mail"; template criado antes; CC/CCO; horário do disparo; endereço do remetente; destino das respostas.
  - Condições: "7 condições" no contador, duas visíveis: Cliente | Fase | Igual a | Onboarding e Cliente | Data de Registro | Há 'X' ou menos dias | 5.
  - Ação Email:
    - Criar email a partir de "Bem-vindo(a) | SenseData" + Configurar Email | Visualizar Template;
    - [ ] Criar tarefa de email; CC e CCO (Adicionar Grupo);
    - [x] Remover e-mails duplicados entre clientes;
    - Enviar email às 08:00 + [ ] Não enviar após o horário;
    - Remetente "Implementador da Conta"; Responder-para "is da conta";
    - [ ] Email transacional; Adicionar Ação.
- Manual pela Visão 360 (67): Lista de Contatos.
  - Tela: visões Lista e Mapa; Novo Contato, Editar, Excluir; [ ] Somente Sponsor, [x] Somente Ativos; busca.
  - Colunas: Nome, Apelido, Cargo, Tipo de Contato, Email, Telefone, Celular, Sponsor. Ícones por contato: favoritar, visualizar, e-mail, WhatsApp, telefone.
  - Janela "Nova mensagem": De (preenchido), Para (+ CC, CCO), Responder para, Assunto, Adicionar template; Cancelar / Enviar.
  - Aviso: "Para incluir imagens em seu e-mail, clique no ícone de imagem e adicione a URL da imagem … apenas imagens hospedadas online podem ser incluídas desta forma."

## Inadimplência (68–73)
- Conceito (69): impacto na saúde financeira; acompanhar atrasos, padrões e medidas preventivas; alertas para ações ágeis e resolução amigável.
- Tabela Clientes (70): coluna "Títulos Vencidos" (quantidade) com filtro. Outras colunas: Engagement Score, NPS.
- Tabela Financeiro (71): colunas Cliente, Valor, Documento, ID Original, Status Financeiro (Pago, Vencido, Em aberto; calculado pela data de pagamento) + filtros.
- Alerta (72):
  - "2 condições": Cliente | Status | Igual a | Ativo e KPIs Padrões | Titulos em atraso | Maior que | 1.
  - Ação Alerta: "Cliente inadimplente!" | Destinatário CS.
  - Também é possível enviar e-mail ao cliente.
- Ver alertas (73): sino no topo com contador > painel "Notificações N" com "Limpar Notificações"; item "<cliente> - Cliente inadimplente!" + data. Todos também veem pela Visão 360.

## Renovação (74–78)
- Conceito (75): contratos próximos da expiração; dados da tabela Contratos; upsell/cross-sell; exemplos com 60 dias; cadastro consistente de contratos.
  - Menu Tabelas: Clientes, Contratos, Financeiro, Suporte, Lista de Contatos, NPS.
- Alerta (76):
  - Condições: Cliente | Status | Contém | ativo e Contrato | Fim vigência | Em 'X' ou menos dias | 60.
  - Recorrência (etapa 3).
  - Ação Alerta: "Você possui clientes com contratos com menos de 60 dias ou menos de renovação" | Destinatário CS.
- E-mail (77): mesmas condições. Ação Email:
  - Criar email a partir de "Template";
  - Enviar para **CS** + [ ] Criar tarefa de email; Adicionar Grupo; CC; CCO;
  - [x] Remover e-mails duplicados; "Destinatários atingidos (amostra)" > Ver amostra de destinatários; Não enviar para;
  - Enviar email às (vazio); Remetente **CSM da Conta**; Responder-para (vazio).
- Playbook (78), "Sugestão de Formatação": "Playbook Renovação", Ativo, Responsável CS; [x] Permitir editar; [ ] dias úteis. Tarefas (responsável "Selecione", categoria Nenhuma):
  1. Confirmar se info contrato está correta — Tarefa, Normal, 0.
  2. Contato com cliente para alinhar estratégia de renovação — Ligação, Normal, 10.
  3. Alinhar estratégia com comercial — Tarefa, Normal, 5.
  4. Registrar no Sense os próximos passos acordados — Milestone, Alta, 15.

## Churn (79–85)
- Fluxo (80): a partir do playbook de crise; a última atividade indica se houve reversão; categoria "Não revertido" aplicada na conclusão (janela Confirmar Conclusão; lista de categorias com "Não revertido"); a categoria é criada em Atividades > Categoria.
- Regra (81–82): "Churn pt.1", Ativo, Fora das pastas, Cliente.
  - "4 condições afetando 1 Cliente":
    - Cliente | Status | Igual a | Ativo;
    - Atividades | "Conclusão playbook há X ou menos…" (cortado) | Igual a | 3;
    - Atividades | Concluiu playbook com título | Igual a | Playbook Crise (lista);
    - Atividades | Categoria | Igual a | Não revertido.
  - Segundas as sextas; Parar Nunca; Atingir novamente Sempre.
  - Ações:
    - Playbook "Churn financeiro manutenção/Setup", Responsável "Manter padrão template";
    - Email "Disparo de pedido de cancelamento" > Enviar para Sponsor ([ ] tarefa), [x] remover duplicados, Enviar às (vazio), Remetente CS da Conta, Responder-para "cs da conta", [x] Email transacional.
  - Texto: e-mail de cancelamento com as etapas; e-mail ao financeiro; playbook para CS/CSM; atualização do Status para "Em cancelamento".
- Inativar manual (83–84): Visão 360 > card Status > lápis > painel "Alterar status do cliente".
  - Alterar status para (lista do ambiente, ex.: Ativo, Inativo, Demonstração) e Data da Alteração.
  - Com Inativo: Motivo (ex.: "Problemas no Onboarding") e Comentários.
  - Atualizar status; "X Fechar".
  - Status em Configurações > Status dos Clientes; motivos em Configurações > Motivos de Cancelamento.
- Inativar por regra (85): ação Atualização > Cliente | Status | Inativo. Só o status muda; data e motivo à mão.

## Segmentação (86–90)
- Conceito (87): estratégias por perfil; clareza, foco e objetividade.
  - Por MRR: réguas distintas; maiores com mais interação e touchs proativos; menores com jornada mais automatizada.
  - Sugestão: jornada da carteira baseada nos segmentos.
  - Captura: pasta de regras "UPDATE | Portes do cliente" com as regras Tier 1, Tier 3 e Tier 2 (uma ação cada, ativas).
- **Campo customizado** (88): Configurações > Clientes > Campo customizado > "Novo campo" → janela **Criar campo customizado**:
  - Título do campo; link **Visualizador de nome interno**; aviso "Lembre-se que não é possível inserir queries no texto da descrição do campo."; Descrição do campo.
  - **Identidade do campo**: Cliente, Contato.
  - **Origem**: Manual, Custom Data, Integração, Outros.
  - **Tipo do Campo**: Text, Date, Number, Checklist, Select, Lista de Usuários.
  - **Máscara**: lista "Selecione" (não obrigatória).
  - **Condição**: Campo Alterável, Ativo, Campo Obrigatório, Edição Restrita ao Perfil, Ocultar Campo na Tabela, Sobrescrito na Integração. Marcadas na captura: Campo Alterável, Ativo, Sobrescrito na Integração.
  - Cancelar / Salvar.
  - No submenu Clientes de Configurações (96), o item se chama "Campos Customizados".
- **Regras** (89–90):
  - Passo 1: Criar pasta de segmentação e colocar nela as regras.
  - Passo 2: em cada regra, as condições do segmento; ação Atualização; tabela de origem; campo customizado; Valor = o segmento.
  - Passo 3: repetir ajustando Nome, Condições e Valor; duplicar as regras.
  - Captura Tier 1:
    - "5 condições" no contador, quatro visíveis;
    - Grupo A: Cliente | MRR | Maior que | 8999 e Cliente | Status | Igual a | Ativo;
    - E / OU = "ou";
    - Grupo B: Cliente | MRR | Maior que | 8999 e Cliente | Status | Igual a | Suspenso;
    - ação Atualização: Cliente | **Porte** | Tier 1.
  - Importante (90): regras específicas por nicho; pastas; cada segmento separado; opções: por produto ou por touch (low, mid, high).
  - Tier 01: MRR > 8.999, ativo ou suspenso. Tier 02: MRR < 8.999 e > 4999,99. Tier 03: MRR < 4999,99.

## Tickets (91–97)
- Conceito (92): o CS acompanha abertos, resolvidos e os que estouraram o prazo; regra que indica ao CS/CSM os clientes com tickets em aberto acima do SLA.
  - "Assim que a Regra disparar um alerta ou uma atividade", sugestões: analisar e finalizar o que der; avisar o cliente; escalar internamente.
- Regra (93): "Chamados acima do SLA", Ativo, Localização "Gatilhos de proteção", Cliente.
  - "1 condição": "Suporte - Cha…" (cortado) | Total de chamados acima do SLA | Maior que | 2.
  - Todos os dias; Parar Nunca; Atingir novamente **Sempre**.
  - Ações:
    - Email: template de exemplo; Enviar para **Sponsor** ([ ] tarefa); CC; CCO; [ ] remover duplicados; Ver amostra de destinatários; Não enviar para; Enviar às (vazio); Remetente CS da Conta; Responder-para "CS da Conta"; [ ] transacional;
    - Alerta "Chamado acima do SLA" | CS.
  - Texto: alertas ao CS ou e-mails para a equipe de suporte.
- Visualizar (94): Minha carteira > Tabelas > Clientes ou Suporte.
  - Minha carteira tem também a "Visão Consolidada" (cards Chamados, Sense Score, Usuários ativos (mês), Utilização de licenças).
  - Clientes: coluna "Chamados acima do SLA" com filtro "Maior que 0". Outras colunas: Sponsor, E-mail Sponsor, Telefone Sponsor, Licenças, Data Renovação, Dias para Renovar, Engagement Score, NPS, Títulos Vencidos, Usuários Ativos.
  - Suporte: Chamado, Cliente, Aberto por, Tipo (problem, task, question, incident), Categoria, Grupo, Encerramento, SLA, **Situação SLA** ("Atrasado"), Descrição, Grupo Econômico; Limpar filtros; Exportar; 50 itens por página.
  - Lógica: em aberto e SLA depois de hoje = no prazo; em aberto e SLA antes de hoje = atrasado; com data de conclusão = "---".
- Visão 360 (95–97):
  - Texto: Configurações > Clientes > "Cards Visão 360".
  - Captura: Configurações > Clientes > **Visão 360**.
    - Submenu Clientes: Campos Customizados, Visão 360, Visão Minha Carteira, Status Financeiro, Status dos Clientes, Motivos de Cancelamento, Status dos Contratos, Tipos de Contatos, Manutenção via CSV, Apagar Clientes, Transferir Dados, Jornada da Carteira.
    - Tela "Visão 360": aviso de ordem de execução; Criar Visão 360, Criar Pasta, Duplicar, Mover, Inativar, Apagar; [x] "Mostrar somente Visões 360 ativas"; colunas Nome, Data de Criação, Criado Por, Status. Uma das visões se chama "Cards Visão 360".
  - Dentro da visão, bloco "Cards": **Adicionar card**; "Arraste os cards na ordem desejada de visualização e clique no card desejado para editá-lo"; lixeira por card.
  - Janela "Adicionar Card": lista com busca, nome e identificador, ex.: Usuários Ativos (mês) (active_users), Utilização de Licenças (license_usage), Tempo de Uso Total (usage_time), OTR (sales), MRR (mrr), Usuários Contratados (contracted_users).
  - Cards de exemplo: Qtd. de admissões, Engagement Score, NPS, Títulos em atraso, Qtd chamados em aberto, Chamados acima do SLA, Valor títulos vencidos, Dias em onb.
  - Clicar no card: **Gráficos por card** (<nome do card>) > **Adicionar gráfico**; "Arraste os gráficos na ordem desejada de visualização."
    - Aviso: "Ao configurar a ordem, prestar atenção no modelo de configuração da página, por exemplo, é indicado não utilizar somente um gráfico de meia página seguido de um gráfico de página inteira."
    - Cada gráfico: "Página inteira" ou "Meia página", lápis e lixeira.
    - Exemplos (cortados): Chamados por criti…, Chamados por cate…, Distribuição de cha…, Chamados aberto ú…, Suporte detalhado (tabela).
  - Salvar.
  - Ver (97): Tabelas > Clientes > busca, ou a busca do topo (filtros Atividades, Clientes, Contatos, Playbooks; "Exibir apenas ativos"; resultado com ID Original e ID Sensedata; "Fechar busca").
    - Na Visão 360, "Principais Indicadores" mostra os cards; "Ver detalhes" abre os gráficos.

## Planos de ação NPS (98–106)
- Conceito (99): devolutiva ou plano de ação; 9 a 15 pessoas (White House Office of Consumer Affairs); cliente fiel 10x mais rentável (Institute of Customer); templates por regra para promotores, neutros e detratores.
- Promotores/neutros (100): só o template "NPS promotora ou neutra com feedback" (o guia não mostra condições e ações dessa regra):
  - logo; "Sua opinião é importante!"; "Olá «Cliente»!";
  - agradece o tempo dedicado à pesquisa; o feedback ajuda a aprimorar os serviços; feliz com a experiência positiva; agradece a parceria;
  - "Abraços," «Assinatura do Remetente».
- Playbook de retorno (101–102):
  - texto: regra para o CS da conta contatar detratores; corte "Detratores com MRR maior que 5k", a definir pelo que a empresa considera estratégico;
  - captura: nome "Detratores com NPS maior que 5k", Ativo, Responsável CS; [ ] Permitir editar; [ ] dias úteis;
  - tarefas (Responsável CS, Categoria Nenhuma, Prioridade Normal):
    1. Feedback negativo recebido — Contato, 2.
    2. Apuração do feedback — Tarefa, 4.
    3. (não aparece)
    4. Verificar e acompanhar o plano de ação realizado — Acompanhamento, 14.
- Atingir Contatos (103): exemplo dos 10 colaboradores (9 promotores, 1 detrator).
- Regra (104–105): "NPS - RESPOSTA DETRATORA | ACIMA DE 5K", Ativo, Fora das pastas, **Contato** (destacado).
  - "3 condições afetando 126 Contatos", Ver amostra de contatos: Cliente | Status | Igual a | Ativo; Cliente | MRR | Maior que | 5000; NPS | Avaliação NPS | Menor que | 7.
  - Todos os dias; Parar Nunca; "A cada intervalo de" 01 dias.
  - Ação Email ("o disparo de um e-mail para os contatos detratores"): template de teste; [x] Criar tarefa de email; CC; CCO; [x] remover duplicados; 10:00; [ ] não enviar após; Remetente **CSM da Conta**; Responder-para vazio; [ ] transacional. A captura não mostra "Enviar para".
- MRR menor que R$ 5.000,00 (106): regra também atingindo contatos, outro comunicado ou CSAT. Template "NPS detratores com mrr <5k":
  - "Sua opinião é importante!"; "Olá «Descrição Cliente»!";
  - agradece o tempo; o feedback ajuda a avaliar o que fazem bem e onde melhorar;
  - pergunta a sugestão de melhoria ou o ponto específico que levou à nota;
  - "Segue «Link formulário» para melhor esclarecer seus pontos de melhorias."; "Agradeço sua paciência e compreensão."

## Conclusão (107)
- O material busca tornar as tarefas acessíveis e transparentes, com exemplos práticos e diretrizes claras.
- O time do projeto está disponível para dúvidas e suporte.
- O guia encoraja testes com as instruções: reforçam o conhecimento e constroem autonomia e confiança para explorar a plataforma.

## Divergências entre texto e captura
| Página | Texto do guia | Captura |
|---|---|---|
| 17 | Critério da carteirização por regra é o porte | Condição MRR > 5000 |
| 17 × 18 | — | Recorrência "Todos os dias" numa captura e "Somente uma vez" na outra |
| 56 | Criar templates "como NPS, CSAT ou outros formulários livres" | Seletor só com NPS e Formulário Livre; CSAT de exemplo é do tipo Livre |
| 66 | — | Contador "7 condições", duas visíveis |
| 89 | Atualizar "o campo customizado criado" | Ação atualiza o campo "Porte"; contador "5 condições", quatro visíveis |
| 93 | Alerta ao CS ou e-mail para a equipe de suporte | E-mail para Sponsor + alerta ao CS |
| 95–96 | Configurações > Clientes > "Cards Visão 360" | Configurações > Clientes > Visão 360 > visão "Cards Visão 360" |
| 101 | "Detratores com MRR maior que 5k" | Playbook "Detratores com NPS maior que 5k" |
| 102 | — | Tarefa 3 do playbook de detratores não aparece |
