# Biblioteca de templates de e-mail

Onde criar: Configurações > Comunicação > Templates de email > Criar template.

**Marcadores.** Nos textos abaixo, `«Nome do cliente»` indica um marcador. Insira sempre pelo botão **Mesclar Marcadores** do editor; não digite a sintaxe à mão (`{{...}}` digitado com a grafia errada chega literal no e-mail). Os nomes são conceitos: o marcador real do seu tenant pode ter outro nome.

## 0. Boas práticas
- **Título do template** diz o objetivo sem abrir (ex.: "Email de boas-vindas ao Onboarding", "[Interno] Inatividade D+90").
- **Assunto** com o nome do cliente e o fato concreto; assunto genérico parece disparo em massa e não é aberto.
- **Um objetivo por e-mail** e um botão/link principal. Se o objetivo é fazer alguém atualizar algo, o link direto para o cliente é o elemento mais importante.
- **Saudação resistente a vazio**: "Olá, tudo bem?" funciona com ou sem nome; "Olá «Nome do contato»," vira "Olá ," se o nome estiver vazio.
- **Enviar Teste** para você antes de ligar a regra: marcadores resolvidos, links, imagens, fontes, erros de digitação.
- **Rodapé interno** em e-mails automáticos para o time: "Mensagem automática | Regra: <nome> | <área>". Ajuda a achar a regra que disparou.
- Templates com **formulário integrado** (NPS/CSAT) facilitam a resposta e seguem a identidade visual.
- E-mail operacional (cancelamento, cobrança): marque "Email transacional" na ação, conforme a política do tenant.

---

## 1. Boas-vindas ao onboarding (cliente)
**Título:** Email de boas-vindas ao Onboarding · **Remetente:** Implementador da Conta
**Assunto:** Bem-vindo(a) à «Nome da sua empresa», «Nome do cliente»!
```
Olá, tudo bem?

É um prazer ter a «Nome do cliente» com a gente. Eu sou «Nome do remetente» e vou
acompanhar vocês na implantação.

Nos próximos dias:
1. Reunião de kick-off para alinhar objetivos e cronograma;
2. Configuração do ambiente;
3. Treinamento do time.

[Botão: Agendar o kick-off]

Qualquer dúvida, é só responder este e-mail.

«Assinatura do remetente»
```

## 2. NPS promotor ou neutro com feedback (contato)
**Título:** NPS promotora ou neutra com feedback · **Regra:** Atingir Contatos, nota ≥ 7
**Assunto:** Obrigado pelo seu feedback, «Nome do contato»
```
Olá, «Nome do contato», tudo bem?

Obrigado por responder nossa pesquisa. Seu feedback ajuda a «Nome da sua empresa» a
melhorar a cada dia, e ficamos felizes em saber como tem sido a experiência da
«Nome do cliente».

Se quiser contar mais alguma coisa, é só responder este e-mail.

«Assinatura do remetente»
```

## 3. NPS detrator — retorno do CS (contato)
**Regra:** Atingir Contatos, nota < 7 (e corte de MRR, se houver) · **Remetente:** CS da Conta · "Criar tarefa de email" marcado
**Assunto:** Queremos entender sua avaliação, «Nome do contato»
```
Olá, «Nome do contato», tudo bem?

Recebemos sua resposta na nossa pesquisa e ela é importante para nós. Quero entender
melhor o que motivou a sua nota e o que podemos fazer para melhorar.

Você teria 20 minutos esta semana? [Botão: Escolher um horário]

«Assinatura do remetente»
```
Para detratores abaixo do corte estratégico: troque o convite por uma pesquisa CSAT curta.

## 4. Renovação — 60 dias (cliente)
**Regra:** cliente Ativo + fim de vigência em 60 ou menos dias · **Remetente:** CS da Conta
**Assunto:** «Nome do cliente»: vamos planejar a renovação?
```
Olá, tudo bem?

O contrato da «Nome do cliente» vence em «Data de fim de vigência». Quero aproveitar
para revisar com vocês os resultados do período e os próximos objetivos, e alinhar a
renovação com antecedência.

[Botão: Agendar conversa]

«Assinatura do remetente»
```

## 5. Inadimplência (cliente)
**Regra:** cliente Ativo + títulos em atraso > 0 · **Remetente:** Financeiro ou CS da Conta · transacional
**Assunto:** «Nome do cliente»: identificamos um pagamento em aberto
```
Olá, tudo bem?

Identificamos «Quantidade de títulos vencidos» título(s) em aberto da «Nome do cliente».
Se o pagamento já foi feito, por favor desconsidere esta mensagem.

Caso precise da segunda via ou queira combinar outra data, responda este e-mail ou fale
com «Contato do financeiro».

«Assinatura do remetente»
```
Tom neutro: o objetivo é resolver de forma amigável.

## 6. Pedido de cancelamento (cliente)
**Título:** Disparo de pedido de cancelamento · **Regra:** Churn pt.1 · **Enviar para:** Sponsor · **Remetente:** CS da Conta · transacional
**Assunto:** «Nome do cliente»: próximos passos do cancelamento
```
Olá, tudo bem?

Registramos o pedido de cancelamento da «Nome do cliente». Os próximos passos são:
1. Confirmação da data de encerramento: «Data»;
2. Exportação dos dados, se necessário;
3. Comunicação do financeiro sobre valores finais.

Se quiser conversar antes de concluir, estou à disposição.

«Assinatura do remetente»
```

## 7. Comunicação ao financeiro (interno)
**Assunto:** [Cancelamento] «Nome do cliente» — «ID do cliente»
```
Cliente: «Nome do cliente» («ID do cliente»)
CS responsável: «CS da conta»
MRR: «MRR»
Fim de vigência: «Data de fim de vigência»
Motivo informado: «Motivo do cancelamento»

Mensagem automática | Regra: Churn pt.1 | CS Ops
```

## 8. Chamados acima do SLA (interno, suporte)
**Assunto:** [SLA] «Nome do cliente» com «Total de chamados acima do SLA» chamados fora do prazo
```
Cliente: «Nome do cliente» — CS: «CS da conta»
Chamados acima do SLA: «Total de chamados acima do SLA»

Por favor, verifiquem se algum pode ser finalizado ou priorizado.

Mensagem automática | Regra: Chamados acima do SLA | CS Ops
```

## 9. Régua de inatividade do CS (interno)

### 9.1 D+90 — lembrete ao CS
**Para:** CS responsável
**Assunto:** Seu CS Feeling de «Nome do cliente» está há «dias_sem_atualizacao_cs» dias sem atualização
```
Oi, «CS da conta»,

O cliente «Nome do cliente» está há «dias_sem_atualizacao_cs» dias sem atualização de
anotações e de CS Feeling.

Última anotação: «dt_ultima_anotacao_cs»
CS Feeling registrado: «cs_feeling»

Uma tarefa foi criada na sua fila com prazo de 7 dias. Atualizar leva uns 2 minutos:

«Link do cliente»

Se a conta está saudável e simplesmente não houve novidade, registre isso mesmo —
"sem alteração, cliente estável" é uma anotação válida e mantém o histórico vivo.

--
Mensagem automática | Regra: Inatividade 90d | CS Ops
```
O último parágrafo evita a falha mais comum: o CS que não atualiza porque acha que só deve escrever quando há novidade.

### 9.2 D+105 — escalonamento (líder em cópia)
**Para:** CS responsável · **CC:** líder
**Assunto:** [Escalonamento] «Nome do cliente» — «dias_sem_atualizacao_cs» dias sem atualização de CS
```
Oi, «CS da conta»,

O cliente «Nome do cliente» continua sem atualização de anotações e CS Feeling há
«dias_sem_atualizacao_cs» dias. O lembrete anterior foi enviado há 15 dias.

Última anotação: «dt_ultima_anotacao_cs»
CS Feeling registrado: «cs_feeling»

«Link do cliente»

Se houver algum impedimento para atualizar — conta em transição, cliente sem contato
aberto, carteira em remanejamento — responda a este e-mail. A liderança está em cópia
para dar suporte, não para cobrar.

--
Mensagem automática | Regra: Inatividade 105d | CS Ops
```

### 9.3 D+120 — crítico (para a liderança)
**Para:** líder · **CC:** CS responsável
**Assunto:** [Crítico] «Nome do cliente» — «dias_sem_atualizacao_cs» dias sem acompanhamento registrado
```
Olá,

O cliente «Nome do cliente», sob responsabilidade de «CS da conta», está há
«dias_sem_atualizacao_cs» dias sem nenhum registro de acompanhamento — nem anotação,
nem atualização de CS Feeling.

Última anotação: «dt_ultima_anotacao_cs»
CS Feeling registrado: «cs_feeling»

Dois lembretes automáticos já foram enviados (D+90 e D+105) sem retorno.

«Link do cliente»

--
Mensagem automática | Regra: Inatividade 120d | CS Ops
```
Descreva ausência de **registro**, não de **trabalho**: o CS pode estar em contato com o cliente e só não ter registrado.

### 9.4 Digest semanal (opcional)
**Regra:** semanal, segunda 08:00, `nivel_alerta_inatividade` diferente de `nenhum`, para o líder.
**Assunto:** Carteira sem acompanhamento registrado — semana de «Data de hoje»
Depende de o plano suportar e-mail agregado (uma mensagem com a lista). Se não suportar, gere o digest fora do SenseData (a rotina que calcula os campos já tem os dados).
