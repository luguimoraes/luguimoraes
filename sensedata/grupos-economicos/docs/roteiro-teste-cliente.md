# Roteiro de validação — Conta Matriz (Grupos Econômicos)

**Ticket:** 477940 · **Ambiente:** homologação · **Tempo estimado:** 20 minutos

Roteiro para o cliente validar a Conta Matriz em homologação. Todos os passos são feitos pela
tela do SenseData — nenhum acesso técnico é necessário.

---

## Antes de começar

A integração já está configurada em homologação. Ela roda a propagação da Conta Matriz para as
lojas do grupo.

Para o teste, sugerimos o grupo **TIAGO ZANETTE (OTACILIO COSTA)**: tem 9 lojas, sendo 6 ativas e
3 canceladas. Ele foi escolhido de propósito — a mistura de lojas ativas e canceladas permite
validar, na mesma rodada, o filtro de lojas ativas alinhado na reunião de 30/07.

Se preferirem outro grupo, basta que ele tenha pelo menos duas lojas ativas e uma cancelada.

---

## Passo 1 — Criar a Conta Matriz

Criar uma conta nova com:

| Campo | Valor |
|---|---|
| Nome | `MATRIZ - TIAGO ZANETTE (OTACILIO COSTA)` |
| CNPJ | **deixar em branco** |
| Grupo | exatamente igual ao das lojas: `TIAGO ZANETTE (OTACILIO COSTA)` |

**Por que sem CNPJ:** é isso que identifica a conta como matriz e evita que ela seja contada como
mais uma loja.

**Atenção ao campo Grupo:** ele precisa estar escrito exatamente igual ao das lojas, incluindo
espaços e parênteses. Uma diferença de escrita faz a matriz não encontrar as lojas.

> **Comportamento esperado:** a conta é criada normalmente e aparece na listagem, sem CNPJ.

---

## Passo 2 — Registrar as informações na matriz

Na Conta Matriz recém-criada, preencher:

- **CS Feeling** — escolher uma das opções, por exemplo `Engajado e satisfeito`
- **Anotações Grupo** — escrever algo identificável, por exemplo
  `Teste de validação - reunião estratégica de 13/08`

> **Comportamento esperado:** os campos salvam normalmente. Nenhuma loja muda ainda — a
> propagação acontece na execução da integração.

---

## Passo 3 — Executar a integração

Acionar a execução da integração de Grupos Econômicos (ou aguardar a próxima execução
programada).

> **Comportamento esperado:** a execução conclui com sucesso e reporta **6 contas processadas** —
> uma para cada loja ativa do grupo.

---

## Passo 4 — Conferir uma loja ATIVA

Abrir qualquer uma das 6 lojas ativas do grupo.

> **Comportamento esperado:**
> - **CS Feeling** = `Engajado e satisfeito` (o mesmo registrado na matriz)
> - **Anotações Grupo** = o texto que vocês escreveram na matriz
> - **Conta Matriz** = `MATRIZ - TIAGO ZANETTE (OTACILIO COSTA)`
> - **Grupo Atualizado Em** = data e hora de agora

Os dois últimos campos são a rastreabilidade: qualquer consultor que abrir essa loja vê de onde
veio a informação e quando foi registrada. É o ponto levantado no ticket sobre passagem de bastão.

---

## Passo 5 — Conferir uma loja CANCELADA

Abrir uma das 3 lojas canceladas do mesmo grupo.

> **Comportamento esperado:** ela **não** foi alterada. Os campos de grupo continuam vazios ou com
> o conteúdo anterior.

Este é o ajuste alinhado na reunião de 30/07: apenas lojas ativas recebem a informação do grupo.

---

## Passo 6 — Editar de novo na matriz

Voltar à Conta Matriz e **alterar** o CS Feeling para outra opção, por exemplo
`Engajado, mas com riscos`. Executar a integração novamente.

> **Comportamento esperado:** as 6 lojas ativas passam a mostrar o novo valor, e o campo
> **Grupo Atualizado Em** é atualizado.

**Este é o passo mais importante do roteiro.** A tentativa anterior de estruturar a Conta Matriz
foi abandonada porque o registro não podia ser editado depois de criado. Aqui a segunda edição
propaga exatamente como a primeira, e a terceira também.

---

## Passo 7 — Executar sem alterar nada

Executar a integração mais uma vez, sem mexer em nada.

> **Comportamento esperado:** **0 contas processadas.**

A integração só grava o que realmente mudou. Isso evita poluir o histórico das contas com
atualizações que não representam nenhuma mudança real e evita interferir nas regras de ciclo e
alerta de CS Feeling.

---

## O que esta versão ainda não faz

Vale deixar explícito para que a validação seja justa:

| Item | Situação |
|---|---|
| **Atualização em tempo real** | A propagação acontece na execução da integração, não no instante da digitação. A frequência precisa ser definida com vocês. |
| **Resumo de atividades** | Não é propagado. Replicar a mesma atividade em vários CNPJs recriaria o problema de edição que encerrou a tentativa anterior. Nossa recomendação é manter o registro único na matriz. |
| **Visões estratégicas** | Fora do escopo desta entrega. Precisamos definir juntos o que entra. |
| **CS Feeling individual por loja** | Passa a ser do grupo. Se alguém editar direto na loja, a próxima execução restaura o valor da matriz. |

---

## O que precisamos que vocês definam

| # | Decisão | Nossa sugestão |
|---|---|---|
| 1 | Frequência de atualização | A cada 30 a 60 minutos, com execução manual após reuniões estratégicas |
| 2 | CS Feeling individual por loja deixa de existir | Matriz como fonte única da verdade, comunicado ao time de CS |
| 3 | Conta Matriz nos indicadores de volumetria | Excluir dos painéis. São 524 grupos na base, então o impacto é relevante |
| 4 | O que é "loja inativa" | Confirmar se é apenas loja cancelada ou se há outros estados |
| 5 | Loja que sai do grupo | Hoje o CS Feeling congela no último valor e a rastreabilidade é limpa |
| 6 | Quem pode editar a Conta Matriz | Restringir a quem responde pela conta, já que a edição altera o grupo inteiro |
| 7 | Padrão de escrita do campo Grupo | Definir convenção, para evitar que grafias diferentes virem grupos diferentes |
| 8 | Escopo da próxima fase | Definir quais visões estratégicas entram |

---

## Se algo sair diferente do esperado

Anotem qual passo e o que aconteceu, e nos avisem pelo ticket 477940. Estamos em homologação
justamente para isso — nada aqui afeta o ambiente de produção.
