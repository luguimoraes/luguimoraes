# Análise — Inativação em massa de contatos na integração S3

Documento de trabalho da auditoria. Números vindos do export SenseData de 13/08/2026
(recorte Origem = "Integração Sistema": 2.048 contas, 16.945 linhas).

## O ponto que a Jaqueline levantou

O que ela confirma como correto: inativar contatos que não constam no relatório.

O que ela aponta como errado: **toda a base foi inativada e recriada como contatos
novos, em mais de uma ocasião** — e os registros novos nascem sem os campos que
haviam sido preenchidos manualmente.

Essa distinção é a questão central. Não é o mesmo problema que o descrito antes.

## Diferença entre os dois comportamentos

Comportamento acordado (inativação seletiva):

    para cada conta:
        inativar os contatos que NÃO estão no arquivo TR
        manter/reativar os que estão, preservando o registro existente

Comportamento observado (recriação):

    inativar a base
    inserir os contatos do arquivo TR como registros novos
    → o registro antigo fica inativo e o campo manual fica no registro antigo

A consequência é que o dado manual não é apagado: ele fica preso no registro
desativado. Isso é relevante para a recuperação — é migração de campo entre
registros, não restauração de backup.

## Evidência na base auditada

A aba `Contatos` do `Auditoria_Contatos_360.xlsx` já classifica esse padrão:

- "Registro fantasma: clone antigo da mesma chave, desativado" — registros que
  existem em duplicidade, sendo o antigo o que carrega o histórico.
- 6.257 linhas com o produto gravado no campo `Skype` em vez do campo `Produto`.
- 10.688 linhas em que o produto do contato não bate com o produto da conta.

A existência de clones desativados da mesma chave é consistente com o relato de
recriação, e não com inativação seletiva.

## Benchmarking — o que ainda não sabemos

Segundo o Erimar, a marcação de Benchmarking vinha historicamente vinculada a um
**tipo de atividade específico** que ligava ao contato. Durante a passagem anterior
houve mudança nos tipos de atividade e nos campos customizados, e ele não sabe como
o processo está hoje.

Isso deixa duas hipóteses abertas, com tratamentos diferentes:

1. **Benchmarking é campo no registro do contato.** Então os valores estão nos
   registros desativados e a recuperação é migrar o campo do registro antigo para
   o novo, casando pela chave e-mail + CNPJ.
2. **Benchmarking vem de vínculo com atividade.** Então o vínculo pode ter sido
   quebrado na mudança de tipos de atividade, e o problema é anterior e
   independente da recriação.

Os números citados pela Jaqueline (300+ antes, 15-20 agora) não distinguem entre as
duas. Precisamos de exemplos nomeados de contatos que tinham a marcação para
decidir qual hipótese vale.

## O que precisa ser levantado antes de dar prazo

- [ ] Onde no fluxo ocorre a inativação — se é update em massa ou por conta.
- [ ] Se os registros novos são insert ou upsert sobre a chave existente.
- [ ] Se Benchmarking é coluna do contato ou relacionamento com atividade.
- [ ] Quantas cargas rodaram com o comportamento de recriação (13/08 e 14/08
      confirmadas; validar se houve outras antes).
- [ ] Se os registros desativados ainda carregam o valor de Benchmarking — isso
      define se a recuperação é viável sem backup.

O último item é o que decide o prazo da recuperação. Sem ele, qualquer estimativa
para a Fase 2 é chute.

## Ordem de trabalho proposta

**Fase 1 — parar a recriação.** Trocar a inativação em massa por inativação
seletiva por conta, e garantir que a gravação seja upsert sobre o registro
existente em vez de insert. Escopo fechado, é correção de lógica.

**Fase 2 — recuperar Benchmarking.** Depende inteiramente do resultado do
levantamento acima. Se hipótese 1, é um script de migração de campo entre registros
pareados. Se hipótese 2, é reconstruir o vínculo com atividade, e aí o Erimar e a
Jaqueline precisam definir qual é o tipo de atividade válido hoje.

**Fase 3 — documentar.** Como Benchmarking é marcado, e qual validação roda antes
de cada carga para detectar recriação em massa (ex.: abortar se a carga inativaria
mais de X% da base).

## Caso de validação

Usar 132626-TAX (BRFERTIL S.A, CNPJ 12.759.673/0001-09), que já foi conferido
registro a registro nesta auditoria e tem resultado esperado conhecido: 7 acessos
na conta TAX. A conta 132626-GTM do mesmo CNPJ está sem contato ativo e serve de
segundo caso.
