# Régua de inatividade de CS — SenseData

Configuração das ações **4 (Disparo de Regras de Inatividade — alerta de 90 dias)** e
**5 (Lembretes e Acompanhamento da Liderança)**.

**Objetivo:** quando um CS fica 90 dias sem atualizar as anotações **e** o CS Feeling
de um grupo econômico, o SenseData avisa o CS; se ele não agir, o assunto escala para
a liderança.

## Por onde começar

| # | Arquivo | O que é |
|---|---|---|
| 1 | [`campos-customizados.md`](campos-customizados.md) | Os 6 campos a criar no SenseData |
| 2 | [`automacao/`](automacao/) | Pipeline que calcula a inatividade e alimenta os campos |
| 3 | [`runbook-inatividade-90d.md`](runbook-inatividade-90d.md) | Configuração das 3 regras, passo a passo |
| 4 | [`templates-email.md`](templates-email.md) | Corpo dos e-mails de D+90, D+105 e D+120 |

Nessa ordem: os campos precisam existir antes de o pipeline gravar neles, e o pipeline
precisa estar rodando antes de as regras lerem o campo — regra apontando para campo
vazio nunca dispara e não dá erro em lugar nenhum.

## A parte que não é óbvia

Regras no SenseData filtram clientes por **campos da tabela de clientes**. Elas não
conseguem responder "faz quantos dias que o CS escreveu a última anotação?" — anotação
é conteúdo de timeline, não campo filtrável.

Então a inatividade precisa **virar um campo** antes de virar regra. É isso que o
pipeline em `automacao/` faz, e é por isso que ele é pré-requisito e não acessório.

## A escada

| Quando | Quem recebe | O quê |
|---|---|---|
| D+90 | CS responsável | E-mail + tarefa com prazo de 7 dias + alerta in-app |
| D+105 | CS responsável, líder em cópia | E-mail |
| D+120 | Líder, CS em cópia | E-mail + alerta in-app |

O escalonamento é uma recomendação, não o que estava escrito na ata — o texto original
levanta "a possibilidade de configurar a regra para incluir a liderança em cópia". As
duas leituras estão comparadas na seção 4 do runbook. Em resumo: liderança em cópia de
100% dos alertas vira filtro de e-mail em duas semanas, que é o oposto de "acompanhar
de perto".

## Estado

O pipeline está implementado e testado (13 testes de unidade em
`automacao/test_watchdog.py` e um teste ponta a ponta em
`automacao/test_integracao.py`, todos passando). A configuração dentro do SenseData é manual e depende de seis confirmações no
tenant — a lista está na seção 6 do runbook. A mais provável de travar a configuração é
se a ação de e-mail aceita **campo customizado como cópia**, que é o que permite copiar
dinamicamente o líder de cada CS.
