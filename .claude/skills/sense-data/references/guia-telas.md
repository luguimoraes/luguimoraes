# O que cada tela do Guia de Configurações mostra

Inventário das telas e anotações do "Guia de Configurações e Casos de Uso" (SenseData), na ordem do índice do guia. Use para responder "onde fica" e "o que aparece" sem supor. Versões do produto podem ter diferenças: quando o usuário descrever outra tela, prefira o que ele vê.

## Índice do guia
O que é um caso de uso · Regras · Carteirização (manual, por critério, distribuição automática) · Playbooks (criar Playbook, criar Onboarding Playbook, associar Onboarding manualmente, associar Playbook manualmente, associar Playbook automaticamente) · Atividades (manual, automática) · Jornada da carteira (configurar, adicionar clientes manualmente, adicionar automaticamente) · Automação de fases · Pesquisas NPS/CSAT (criar formulário, disparo automático, disparo manual) · Disparos de e-mails, boas-vindas e newsletter (criar template, enviar automaticamente) · Inadimplência (tabela Clientes, tabela Financeiro, alerta) · Renovação (alerta, e-mail, playbook) · Churn (fluxo, inativar) · Segmentação por produto/plano/serviço (campo customizado, regra de preenchimento) · Acompanhamento de tickets (automático, clientes acima do SLA, Visão 360) · Planos de ação NPS (promotores, detratores) · Conclusão.

## Regras — Configurações > Regras > Criar Regra
**Passo 1**: Nome (livre, "claros e objetivos") · Status (Ativo = roda na próxima atualização de dados; Inativo = não roda) · Localização (pasta; "Crie pastas para organizar suas regras") · Atingir (Clientes ou Contatos).

**Passo 2 — Condições** (anotações da captura):
- "Indique a origem do dado (Clientes, Contatos, Contratos, KPIs, etc.)" → campo Categoria.
- "Selecione a Operação desejada de acordo com o campo escolhido. Existem várias opções, que variam de acordo com o tipo de dado do campo (texto, número ou data)."
- "Descreva o Valor a ser comparado… Em caso de campos do tipo texto, letras maiúsculas e minúsculas são diferenciadas."
- "Duplique, adicione ou remova condições."
- "Adicione mais grupos de condições/situações e crie lógicas de união (E) ou exclusão (OU)."
- "Veja uma amostra de Clientes ou Contatos que serão atingidos."
- Exemplo: clientes inseridos há 3 ou menos dias e com status ativo.

**Passo 3 — Agendamento e recorrência**: data de início (inclusive) · periodicidade (todos os dias, uma vez por mês, a cada 15 dias, uma vez por semana…) · parada (nunca, data, após N ocorrências) · atingir o mesmo cliente mais de uma vez num período.

**Passo 4 — Ações**: escolha na lista; sem limite de quantidade.

## Carteirização
- Manual: Tabelas > Clientes > buscar > marcar caixa no início da tabela > Editar > selecionar campos > escolher usuário > Próximo > confirmar > "Sucesso!".
- Por regra: condições com o critério (a captura usa o porte dos clientes) > agendamento > ação Atualização (campo e novo valor) > Criar Regra.
- Distribuição automática: condições > agendamento > ação "Distribuição automática" com os CSs e, opcionalmente, o limite de clientes por carteira > Criar Regra.

## Playbooks — Configurações > Atividades > Playbook | Onboarding Playbook > Criar playbook
- Dados: nome, status, responsável (perfil ou usuário); marcações opcionais (editar em andamento; só dias úteis na previsão).
- Por tarefa: tipo ("caso precise de uma nova opção é possível criá-la em Tipos de Atividades"), título, responsável (pode ser outro), dias após a atribuição, categoria ("para gerar gatilhos"), hora de início e fim, horas utilizadas, instruções, checklist, notas; duplicar/adicionar/excluir atividades.
- Onboarding: também a fase da atividade e o prazo final em dias.
- "Crie pastas para organizar seus playbooks." Botão final: "Salvar playbook". Mensagem: "Playbook criado e disponível para uso."
- OBS. do guia: ativo + associado a regra → dispara quando a carga roda; sem regra → só manualmente.
- Associar Onboarding: barra superior > Onboarding > Adicionar Playbook (Cliente, Playbook, Responsável).
- Associar Playbook: Tabelas > Clientes > cliente > Atividades > Adicionar Playbook.
- Por regra: ação Playbook > Playbook associado; "Se manter o mesmo Responsável será utilizado o que foi configurado no playbook"; "É possível adicionar categorias para ter classificações do playbook."

## Atividades
- Manual, opção 1: tela Atividades > Adicionar atividade. Opção 2: Visão 360 > Atividades > Adicionar atividade.
- Campos anotados: cliente a quem a atividade é atribuída; receptor; título; tipo (personalizável em Configurações > Atividades > Tipos de Atividades); categoria (Configurações > Atividades > Categorias); responsável pela execução; checklist e instruções; notas; anexos; marcar como concluída. Campos obrigatórios marcados com *.
- Por regra: ação "Atividade" com título, tipo, instruções e checklist, categoria, prazo em dias e a caixa para notificar o responsável quando a atividade for criada.

## Jornada da carteira
- Perfil: Configurações > Contas > Perfis > Editar > "Definir menu": Telas - Jornada da carteira → seta; "Definir ações": Jornada da carteira e Regras → seta; Salvar perfil.
- Criar: Configurações > Clientes > Jornada da carteira > Criar jornada: nome, perfis com acesso, fases (nome, tempo estimado em dias, cor), ⊕ para mais fases, Salvar. Limite atual: 20 fases (quantidade de cores).
- Ver: barra superior > Jornada da carteira > jornada; geral (expande por fase) ou Kanban.
- Adicionar manual: Adicionar cliente > fase > cliente > salvar.
- Adicionar por regra: ação "Atualização da jornada" (Atualizar jornada para / Atualizar fase para) > salvar e executar > conferir clientes > "Disparar regra".
- "Exemplos de cards da Jornada da Carteira": por colaborador e por comportamento da base.

## Pesquisas
- Criar: Configurações > Comunicação > Templates de formulário > Criar formulário > escolher template (NPS, CSAT, livre) > nome > editar > salvar.
- Por regra: ação Formulário (tipo, forma de disparo, template; enviar para; horário; remetente).
- Manual: Visão 360 > Formulários > Adicionar formulário > tipo (NPS ou livre) > formulário > meio (SMS ou e-mail) > contato > flag "Criar tarefa de formulário" > Prosseguir.

## E-mails
- Criar template: Configurações > Comunicação > Templates de email > Criar template; pastas.
- Editor (anotações da captura): imagens; colunas; HTML; texto (fonte, cor, alinhamento, espaçamento); divisões; redes sociais; botões de CTA; "Mesclar Marcadores" (variáveis, campos customizados e KPIs); blocos duplicáveis e deletáveis; arrastar blocos da coluna da direita.
- Regra de e-mail (anotações da captura): tabela onde a informação é buscada; condição específica; operação; valor; ação "envio de e-mail"; template criado antes; CC/CCO; horário do disparo; endereço do remetente; destino das respostas. Exemplo: clientes em fase de onboarding com data de registro há 5 ou menos dias.
- Manual pela Visão 360: Lista de Contatos > ícone de e-mail > Responder para > Assunto > template ou texto livre > Enviar.

## Inadimplência
- Tabela Clientes: coluna "Títulos Vencidos" + filtros.
- Tabela Financeiro: coluna "Status Financeiro" (Pago, Vencido, Em aberto, calculado pela data de pagamento) + filtros.
- Alerta: regra com alerta ao CS; opcionalmente e-mail ao cliente.
- Onde ver alertas: sino no canto superior direito do destinatário; todos veem na Visão 360.

## Renovação
- Alerta: condições cliente Ativo + fim de vigência em 60 ou menos dias; recorrência; ação Alerta com a mensagem.
- E-mail: template > regra com cliente Ativo e prazo de fim de vigência > ação Email (template, destinatário, remetente) > Criar regra.
- Playbook: "Sugestão de Formatação" (tabela no SKILL.md, Exemplo 6).

## Churn
- Fluxo a partir do playbook de crise; última atividade indica reversão; categoria "Não revertido" (Atividades > Categoria).
- Inativar: Visão 360 > editar Status > Inativo > Motivo do Cancelamento > comentários > Data de Alteração, se necessário. Por regra, só o status.

## Segmentação
- Campo: Configurações > Clientes > Campo customizado > Novo campo: título, identidade, origem, tipo, máscara, condição > Salvar.
- Regras: uma pasta por segmentação; ação Atualização com o valor do segmento; duplicar para os outros segmentos.

## Tickets
- Regra: total de chamados acima do SLA > alerta ao CS ou e-mail ao suporte.
- Tabelas: Clientes ("Chamados acima do SLA" > 0); Suporte ("Situação SLA").
- Visão 360: Configurações > Clientes > Cards Visão 360 > Adicionar card > indicador > gráficos > Salvar; na Visão 360, "Ver detalhes".

## Planos de ação NPS
- Promotores/neutros: e-mail de agradecimento por regra.
- Detratores: regra atingindo Contatos, ação para o CS da conta; corte por MRR; CSAT para os demais.
