# Padrões avançados de regras (campo)

Padrões observados em réguas implantadas. O guia oficial ensina a montar uma regra; este arquivo trata do que acontece quando ela roda todo dia, por meses, sobre uma base real.

## 1. Uma regra é avaliada a cada execução
Com "Executar regra: Todos os dias", a condição é reavaliada diariamente. O que decide se o mesmo cliente recebe a ação de novo é **"Atingir novamente o mesmo cliente"**.

| Condição | Atingir novamente | Resultado |
|---|---|---|
| `dias ≥ 90` | Sempre | Dispara **todo dia** a partir do dia 90 (spam; a régua morre em duas semanas) |
| `dias ≥ 90` | Nunca | Dispara uma vez **para sempre**: quando o cliente voltar a ficar 90 dias parado num novo ciclo, não dispara |
| `dias ≥ 90` | A cada N dias | Lembrete periódico a cada N dias enquanto a condição vale |
| `dias = 90` | qualquer | Dispara uma vez por ciclo, **mas** se o cálculo falhar no dia 90 (89 → 91) o alerta é perdido em silêncio |
| `nivel = alerta_90` (campo de nível) | A cada N dias (trava extra) | Dispara uma vez por ciclo e tolera falha: quem decide é a rotina que calcula o nível |

### 1.1 Campo de nível
Uma rotina externa (API/integração) calcula e grava um campo lista com o **nível a disparar hoje** e o devolve para `nenhum` no dia seguinte. A rotina guarda estado (ex.: `(cliente, nível, data do marco)`), então:
- dispara uma vez por nível e ciclo;
- um novo ciclo (o CS atualizou e parou de novo) gera novo alerta;
- se a rotina falhar um dia, no dia seguinte ela ainda sabe que precisa alertar;
- acima do último nível, silencia (reenviar para sempre treina o time a ignorar).
A regra só compara texto (`Igual a | alerta_90`). Use valores `minusculo_com_underline` idênticos aos do código.

### 1.2 Janela
Sem rotina externa: `dias ≥ 90 E dias < 97` + "A cada 7 dias". Dispara uma vez por ciclo e tolera uma falha de até 6 dias.

## 2. Guardas (quem não deve receber)
| Guarda | Por quê |
|---|---|
| Responsável (CS) não vazio | Sem destinatário, o envio falha e polui a medição |
| Contrato/cliente com mais de X dias | Cliente em onboarding não teve tempo de "ficar inativo" |
| Status diferente de Em cancelamento/Churn/Inativo | Não cobre ação de conta que está saindo |
| `tipo_conta` diferente de conta técnica (ex.: matriz) | Conta criada para automação não é cliente |
| Campo usado no e-mail/remetente não vazio | Evita "Olá ," e remetente padrão |
| Contato com e-mail válido / sem opt-out | Entregabilidade e LGPD |

## 3. Ordem: carga → rotinas → regras
- Regras leem o que está na base no momento em que rodam.
- Carga (SenseConnect) e rotinas via API que gravam campos precisam terminar **antes**.
- Deixe folga para uma nova tentativa (ex.: rotina 06:00, regras 09:00).
- Dentro do SenseData, a ordem da lista de regras também importa quando uma regra grava um campo que outra lê.

## 4. Rollout de uma régua nova
1. Calcule os campos por alguns dias sem disparar nada (dry-run da rotina ou regra inativa).
2. Meça o volume do primeiro disparo com "Ver amostra". Se passar de ~10% da base, use:
   - **carência**: os campos são calculados, mas o nível só sai de `nenhum` depois de N dias da ativação (janela para o time pôr a casa em ordem);
   - **limite diário**: no máximo K alertas por dia, dos mais críticos para os menos.
3. Crie a regra **inativa**, com uma condição extra que só atinja você (ex.: CS responsável = você). Dispare, confira o e-mail: marcadores resolvidos, link funcionando, remetente certo.
4. Remova a condição de teste e ative.
5. Monitore disparos/semana e conversão (seção 7).

## 5. Escalonamento para a liderança
Duas leituras de "liderança em cópia":
- **A — cópia em todos os alertas**: transparente, mas o líder recebe 100% dos alertas, inclusive os que o CS resolve no dia seguinte. Vira filtro de e-mail.
- **B — degraus (recomendado)**:

| Nível | Quem recebe | Ações |
|---|---|---|
| D+90 | CS | E-mail + atividade (prazo 7 dias) + alerta |
| D+105 | CS, líder em cópia | E-mail (sem nova atividade: a de D+90 ainda está aberta) |
| D+120 | Líder, CS em cópia | E-mail + alerta |

Endereçar "o líder do CS" (a plataforma sabe quem é o CS do cliente, não o chefe do CS), em ordem de preferência:
1. campo customizado `email_lider_cs` preenchido por integração, usado como CC — única opção dinâmica; **confirme se a ação de e-mail aceita campo customizado como destinatário/CC**;
2. lista de distribuição fixa como CC;
3. digest semanal para a liderança (uma regra semanal com nível ≠ nenhum), se o plano suportar e-mail agregado; senão, gerar fora.

Texto do e-mail com líder em cópia: diga por que o líder está em cópia ("para dar suporte, não para cobrar"), senão o CS preenche qualquer coisa para o alerta sumir e o dado perde valor. No crítico, descreva ausência de **registro**, não de **trabalho**.

## 6. Qual ação usar
| Objetivo | Ação |
|---|---|
| Fazer alguém executar algo | **Atividade** (fica na fila, aparece em pendências) |
| Lembrar | **Email** (com "Criar tarefa de email" para ficar na timeline do cliente) |
| Chamar atenção agora | **Alerta** (sino) |
| Processo de várias etapas | **Playbook** |
| Mudar dado/segmento/fase | **Atualização** / **Atualização da Jornada** |
| Equilibrar carteiras | **Distribuição automática** |
| Falar com o cliente | **Email**, **Formulário**, SMS, WhatsApp |

## 7. Medir
- Disparos por semana, por regra (relatório de regras no SenseAnalytics).
- **Conversão**: % de clientes que saíram da condição dentro do prazo da atividade. Abaixo de ~50%, a régua virou ruído ou o processo não está claro.
- Reincidentes: ordene por "dias sem X" numa visão salva; não use alerta como relatório.

## 8. Anti-padrões
| Anti-padrão | Consequência | Faça |
|---|---|---|
| Duas condições no mesmo campo com valores diferentes, no mesmo grupo (`Status = Ativo E Status = Suspenso`) | Nunca atinge ninguém | Grupos separados com OU |
| "Maior que 1" para "tem algum" | Ignora quem tem exatamente 1 | "Maior que 0" |
| "Contém ativo" | Casa "Inativo" | "Igual a Ativo" |
| Limites de faixa que não se tocam (`> 8999` e `< 8999`) | Valor na borda fica sem faixa | Um limite inclusivo |
| Atingir Clientes em ação por resposta de NPS | Todos os contatos recebem | Atingir Contatos |
| Carteirização sem transferir atividades | Atividades ficam com o CS antigo | Marcar a transferência |
| Inativar por regra e esquecer motivo/data | Relatórios de churn incompletos | Preencher à mão, ou processo de fechamento |
| Remetente dinâmico sem guarda | E-mail sai pelo remetente padrão | Condição "campo não vazio" |
| Regra lendo campo de integração sem ordem definida | Alerta atrasado ou perdido | Regra depois da carga |
| Playbook para um toque único | Ruído, playbooks abertos para sempre | Atividade |
| Obrigatoriedade em campo subjetivo | Preenchimento defensivo | Campo opcional + régua de cobrança |
