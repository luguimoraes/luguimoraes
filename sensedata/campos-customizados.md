# Campos customizados — especificação

**Configurações → Campos Customizados → Criar campo**

Convenção de nomenclatura do SenseData: nomes internos sempre em **minúsculas**, com
**underline** separando palavras. A API só aceita o nome interno — não o nome de
exibição. Quando há colisão de nome, a plataforma sufixa (`cs_feeling` → `cs_feeling_2`),
então **confira o nome interno gerado** e reflita em `automacao/.env`.

---

## 1. `cs_feeling` — preenchido pelo CS

| Propriedade | Valor |
|---|---|
| Exibição | `CS Feeling` |
| Tipo | Lista de seleção única |
| Opções | `Verde`, `Amarelo`, `Vermelho` |
| Nível | Cliente (grupo econômico) |
| Editável na tela do cliente | Sim |
| Obrigatório | Não |

O único campo desta lista que uma pessoa preenche. Os outros são todos derivados.

Deixe **não obrigatório**. Campo obrigatório em CRM de CS gera preenchimento
defensivo — o CS marca "Amarelo" em tudo para conseguir salvar a tela, e aí o dado
não vale nada. A regra de 90 dias já é o mecanismo de cobrança; obrigatoriedade em
cima disso é redundante e piora a qualidade do dado.

Três opções, não cinco. Escala de 5 pontos em avaliação subjetiva concentra tudo no
meio e a distinção entre "4" e "5" não é reproduzível entre dois CSs diferentes.

---

## 2. `dt_ultima_atualizacao_cs_feeling` — automação

| Propriedade | Valor |
|---|---|
| Exibição | `Data última atualização do CS Feeling` |
| Tipo | Data |
| Editável na tela do cliente | **Não** |

Data da última vez em que `cs_feeling` **mudou de valor**. Não é "última vez que
alguém abriu a tela" — reabrir o cliente e sair sem mexer não conta como atualização.

Deixe não editável. Campo derivado que uma pessoa pode sobrescrever à mão deixa de
ser confiável, e o pipeline vai sobrescrever de volta no dia seguinte de qualquer jeito.

---

## 3. `dt_ultima_anotacao_cs` — automação

| Propriedade | Valor |
|---|---|
| Exibição | `Data da última anotação do CS` |
| Tipo | Data |
| Editável na tela do cliente | **Não** |

Data da anotação mais recente feita **por um usuário do time de CS** no grupo econômico.

Filtrar por autor importa: anotação automática de integração (ticket sincronizado,
log de NPS, registro de cobrança) não é acompanhamento de CS. Se elas contarem, o
contador nunca chega a 90 e a regra nunca dispara — falha silenciosa, a pior
categoria, porque a tela mostra tudo verde e ninguém percebe que o alerta morreu.

O filtro de autor está em `AUTORES_IGNORADOS` no `.env`.

---

## 4. `dias_sem_atualizacao_cs` — automação

| Propriedade | Valor |
|---|---|
| Exibição | `Dias sem atualização do CS` |
| Tipo | Número inteiro |
| Editável na tela do cliente | **Não** |

```
MIN(hoje - dt_ultima_anotacao_cs, hoje - dt_ultima_atualizacao_cs_feeling)
```

`MIN` porque a condição do processo é "as duas coisas paradas" (ver seção 1 do
runbook). Quando nunca houve nem anotação nem feeling, o pipeline usa a data de início
do contrato como marco zero — em vez de `NULL` ou de um número gigante, que quebraria
ordenação na tabela de clientes.

Este campo não é usado como condição de regra; ele existe para leitura humana na
tabela de clientes, para ordenar a fila de trabalho e para o gráfico de distribuição
no SenseAnalytics.

---

## 5. `nivel_alerta_inatividade` — automação

| Propriedade | Valor |
|---|---|
| Exibição | `Nível de alerta de inatividade` |
| Tipo | Lista de seleção única |
| Opções | `nenhum`, `alerta_90`, `escalonamento_105`, `critico_120` |
| Editável na tela do cliente | **Não** |

**É este o campo que as três regras leem.** Ele carrega uma decisão já tomada pelo
pipeline: "hoje, para este cliente, dispare o alerta de nível X" — e volta para
`nenhum` no dia seguinte, o que garante disparo único sem depender de deduplicação
dentro do SenseData.

Valores em minúsculo com underline, iguais aos do código, para evitar divergência
entre a string do pipeline e a string da condição da regra. `Alerta 90` versus
`alerta_90` é um bug que não levanta erro em lugar nenhum: a regra simplesmente nunca
casa e ninguém recebe e-mail.

---

## 6. `email_lider_cs` — integração

| Propriedade | Valor |
|---|---|
| Exibição | `E-mail do líder de CS` |
| Tipo | Texto |
| Editável na tela do cliente | Não |

E-mail do líder do CS que atende aquele grupo econômico, para a cópia dinâmica das
regras de D+105 e D+120 (seção 4.3 do runbook).

Só crie este campo se o seu tenant aceitar campo customizado como destinatário/cópia
na ação de e-mail — item aberto no checklist do runbook. Se não aceitar, use lista de
distribuição fixa e pule este campo.

O mapeamento CS → líder vem de `LIDER_POR_CS` no `.env` (ou de uma tabela do seu DW,
se a estrutura do time já estiver modelada lá — preferível, porque não exige deploy
quando alguém troca de time).
