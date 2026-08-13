# Mensagem para o Teams — pedido de validação

Versão curta e escaneável do roteiro de validação, para enviar por chat.
O e-mail detalhado continua sendo a referência completa.

---

Oi Gio, tudo bem?

Terminei os ajustes na integração de Grupos Econômicos e ela já está em homologação. Antes de
levar pra produção, preciso que você valide se está se comportando como vocês esperam.

Montei um passo a passo pra você testar direto na tela do SenseData. Não precisa de nada técnico
e leva uns 20 minutos.

**Grupo sugerido: TIAGO ZANETTE (OTACILIO COSTA)** — tem 9 lojas, sendo 6 ativas e 3 canceladas.
Escolhi de propósito: assim dá pra testar o filtro de lojas ativas que combinamos em 30/07 na
mesma rodada.

---

**1. Criar a Conta Matriz**
Nome: `MATRIZ - TIAGO ZANETTE (OTACILIO COSTA)`
CNPJ: deixar em branco
Grupo: `TIAGO ZANETTE (OTACILIO COSTA)` — exatamente igual ao das lojas, com os parênteses
→ *A conta é criada e aparece na listagem, sem CNPJ*

O CNPJ em branco é o que marca a conta como matriz. E se o Grupo tiver qualquer diferença de
escrita, a matriz não encontra as lojas.

**2. Preencher na matriz**
CS Feeling: escolher uma opção, ex. "Engajado e satisfeito"
Anotações Grupo: um texto que dê pra reconhecer depois
→ *Salva normal. Nenhuma loja muda ainda*

**3. Rodar a integração**
→ *Deve processar 6 contas — uma para cada loja ativa*

**4. Abrir uma loja ATIVA**
→ *CS Feeling igual ao da matriz*
→ *Anotações Grupo com o seu texto*
→ *Conta Matriz preenchido*
→ *Grupo Atualizado Em com a data e hora de agora*

**5. Abrir uma loja CANCELADA**
→ *Não pode ter mudado nada*

Esse é o ajuste que vocês pediram em 30/07.

**6. Voltar na matriz, trocar o CS Feeling e rodar de novo**
→ *As 6 lojas ativas passam a mostrar o valor novo*

Esse é o passo mais importante. Foi por não conseguir editar depois de criado que o projeto foi
abandonado da outra vez.

**7. Rodar mais uma vez sem mexer em nada**
→ *Deve processar 0 contas*

---

Se algum passo der diferente do esperado, me manda qual foi e o que aconteceu. Estamos em
homologação, então nada disso afeta produção.

Te mandei por e-mail a versão detalhada, com o que essa versão ainda não faz (tempo real e
propagação de atividades, principalmente) e as definições que preciso fechar com vocês antes da
virada.
