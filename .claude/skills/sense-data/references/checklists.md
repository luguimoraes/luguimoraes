# Checklists

## 1. Antes de ativar uma regra
- [ ] Nome claro, com prefixo de área; pasta correta.
- [ ] Atingir: Clientes ou Contatos (NPS por resposta → Contatos).
- [ ] Condições revisadas: grafia exata dos valores de texto; nada de duas condições incompatíveis no mesmo grupo; OU entre grupos para alternativas; limites de faixa que se tocam.
- [ ] Guardas: responsável não vazio, fora de onboarding, fora de cancelamento/churn, sem contas técnicas, campos usados no e-mail não vazios.
- [ ] "Ver amostra de clientes/contatos": quantidade e alguns nomes conferidos.
- [ ] Recorrência coerente com a condição: se a condição vale por vários dias, "Atingir novamente" = Nunca ou intervalo.
- [ ] "Parar execução" correto (Nunca, salvo campanha com data).
- [ ] Ordem: roda depois da carga/rotina que alimenta os campos que lê.
- [ ] Insumos existem e estão ativos (template, formulário, playbook, categoria, tipo de atividade, campo).
- [ ] Ação Atualização de responsável com a transferência de atividades definida.
- [ ] `python3 scripts/ficha_regra.py regra.json` sem alertas não justificados.

## 2. Antes de disparar comunicação para cliente
- [ ] Template com "Enviar Teste" para você: marcadores resolvidos, links, imagens, erros.
- [ ] Marcadores inseridos pelo "Mesclar Marcadores".
- [ ] Saudação resistente a nome vazio.
- [ ] "Ver amostra de destinatários"; "Remover e-mails duplicados entre clientes"; "Não enviar para" quando necessário.
- [ ] Remetente: se dinâmico, o campo está preenchido na base (ou a regra tem guarda); "Responder para" definido.
- [ ] Horário de envio e "Não enviar mensagem após o horário".
- [ ] "Criar tarefa de email/formulário" marcado quando a comunicação precisa ficar na timeline.
- [ ] Transacional marcado quando for comunicação operacional.
- [ ] Teste com a regra inativa e uma condição que só atinja você.
- [ ] Volume do primeiro disparo aceitável (senão carência/limite/lotes).

## 3. Régua nova (rollout)
- [ ] Campos criados e nomes internos conferidos.
- [ ] Rotina/integração que alimenta os campos rodando e conferida por alguns dias.
- [ ] Volume do dia 1 medido.
- [ ] Carência e/ou limite diário, se o volume for alto.
- [ ] Teste ponta a ponta com você como destinatário.
- [ ] Métrica de conversão definida e relatório no SenseAnalytics.

## 4. Auditoria periódica (mensal)
- [ ] Regras ativas sem disparo há 30+ dias (campo vazio? condição impossível?).
- [ ] Regras com disparo repetido para o mesmo cliente.
- [ ] Conversão das réguas de cobrança interna.
- [ ] Playbooks inativos ainda associados a regras.
- [ ] Campos customizados sem uso ou com valores fora da lista esperada.
- [ ] Contas técnicas fora dos painéis.
- [ ] Remetentes dinâmicos vazios na base.
- [ ] Clientes inativados por regra sem motivo/data.
