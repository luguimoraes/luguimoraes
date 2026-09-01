# Templates de e-mail — regras de inatividade

**Configurações → Templates de E-mail → Criar template**

## Variáveis (Mesclar Marcadores)

As variáveis são inseridas pelo botão **"Mesclar Marcadores"** no corpo do template —
não digite os marcadores à mão. Os nomes abaixo são os *conceitos*; o marcador literal
do seu tenant pode diferir (`{{customer.name}}`, `{{nome_cliente}}`, etc.). Pegue
sempre pelo menu, senão o marcador chega literal no e-mail do CS.

| Conceito | Onde pegar |
|---|---|
| Nome do grupo econômico | Marcadores → Cliente → Nome |
| Nome do CS responsável | Marcadores → Cliente → CS responsável |
| Dias sem atualização | Marcadores → Campos customizados → `dias_sem_atualizacao_cs` |
| Data da última anotação | Marcadores → Campos customizados → `dt_ultima_anotacao_cs` |
| CS Feeling atual | Marcadores → Campos customizados → `cs_feeling` |
| Link do cliente | Marcadores → Cliente → URL |

O **link do cliente é o elemento mais importante do e-mail**. O objetivo não é
informar, é fazer o CS atualizar o registro — e cada clique a mais entre o e-mail e o
campo editável derruba a taxa de conclusão. Se o seu tenant não expõe URL do cliente
como marcador, peça ao CSM; vale mais que o resto do template junto.

---

## D+90 — lembrete ao CS

**Assunto:** `Seu CS Feeling de {{nome_cliente}} está há {{dias_sem_atualizacao_cs}} dias sem atualização`

Assunto com o nome do cliente e o número. "Lembrete de atualização de CS Feeling"
genérico é indistinguível de e-mail automático em massa e não é aberto.

```
Oi, {{nome_cs}},

O grupo econômico {{nome_cliente}} está há {{dias_sem_atualizacao_cs}} dias sem
atualização de anotações e de CS Feeling.

Última anotação: {{dt_ultima_anotacao_cs}}
CS Feeling registrado: {{cs_feeling}}

Uma tarefa foi criada na sua fila com prazo de 7 dias. Atualizar leva uns 2 minutos:

{{url_cliente}}

Se a conta está saudável e simplesmente não houve novidade, registre isso mesmo —
"sem alteração, cliente estável" é uma anotação válida e mantém o histórico vivo.

--
Mensagem automática | Regra: Inatividade 90d | CS Ops
```

O último parágrafo evita o modo de falha mais comum deste tipo de régua: o CS que não
atualiza porque acha que só deve escrever quando tem novidade relevante. Deixar
explícito que "nada mudou" é resposta aceitável eleva bastante a taxa de resposta.

---

## D+105 — escalonamento, líder em cópia

**Assunto:** `[Escalonamento] {{nome_cliente}} — {{dias_sem_atualizacao_cs}} dias sem atualização de CS`

**Para:** CS responsável · **Cópia:** líder de CS

```
Oi, {{nome_cs}},

O grupo econômico {{nome_cliente}} continua sem atualização de anotações e CS Feeling
há {{dias_sem_atualizacao_cs}} dias. O lembrete anterior foi enviado há 15 dias.

Última anotação: {{dt_ultima_anotacao_cs}}
CS Feeling registrado: {{cs_feeling}}

{{url_cliente}}

Se houver algum impedimento para atualizar — conta em transição, cliente sem contato
aberto, carteira em remanejamento — responda a este e-mail. A liderança está em cópia
para dar suporte, não para cobrar.

--
Mensagem automática | Regra: Inatividade 105d | CS Ops
```

A última frase não é enfeite. A partir do momento em que o líder aparece em cópia, o
CS lê o e-mail como sinal de problema com ele, não com a conta — e a reação a isso é
preencher qualquer coisa para o alerta sumir, o que destrói o dado que a régua existe
para produzir. Nomear o motivo da cópia reduz esse efeito.

---

## D+120 — crítico, para a liderança

**Assunto:** `[Crítico] {{nome_cliente}} — {{dias_sem_atualizacao_cs}} dias sem acompanhamento registrado`

**Para:** líder de CS · **Cópia:** CS responsável

```
Olá,

O grupo econômico {{nome_cliente}}, sob responsabilidade de {{nome_cs}}, está há
{{dias_sem_atualizacao_cs}} dias sem nenhum registro de acompanhamento — nem anotação,
nem atualização de CS Feeling.

Última anotação: {{dt_ultima_anotacao_cs}}
CS Feeling registrado: {{cs_feeling}}

Dois lembretes automáticos já foram enviados (D+90 e D+105) sem retorno.

{{url_cliente}}

--
Mensagem automática | Regra: Inatividade 120d | CS Ops
```

Aqui o texto descreve a ausência de *registro*, não a ausência de *trabalho* — são
coisas diferentes e o e-mail não tem como saber qual das duas está acontecendo. O CS
pode estar em contato semanal com o cliente e simplesmente não registrar. Um e-mail
para a liderança afirmando "cliente sem acompanhamento" quando o caso é "cliente sem
registro" cria uma conversa desnecessária e desgasta a régua.

---

## Digest semanal para a liderança (opcional)

Alternativa à cópia individual, se a liderança preferir volume baixo (Opção B/saída 3
da seção 4.3 do runbook). Regra semanal, segunda-feira 08:00, filtro
`nivel_alerta_inatividade ≠ nenhum`, destinatário: líder.

**Assunto:** `Carteira sem acompanhamento registrado — semana de {{data_hoje}}`

Depende de o seu tenant suportar **e-mail agregado** (uma mensagem com a lista de
clientes) em vez de um e-mail por cliente. Nem todo plano suporta. Se não suportar, o
caminho é montar o digest fora do SenseData — o pipeline já tem os dados, e um envio
via SMTP a partir do próprio DAG resolve em poucas linhas.
