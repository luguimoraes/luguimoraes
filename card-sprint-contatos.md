# Integração de Contatos TR — recriação da base a cada carga (chave de upsert instável)

**Tipo:** Bug / Incidente em curso
**Prioridade:** Crítica — o problema se agrava a cada execução da carga
**Integrações:** `Contatos_S3_V4` (id 2036), `Pré-processing_Inativa_Contatos` (id 2012)
**Tabela:** `customer_contact`
**Última apuração:** export de 21/08/2026 (recorte Origem = "Integração Sistema", 7.100 linhas)

---

## 1. Resumo

A cada execução da carga de contatos, os registros existentes não são reconhecidos. O resultado é
que toda a base de origem `Integração Sistema` é desativada e recriada, gerando uma nova geração
de duplicados e abandonando os campos preenchidos manualmente.

**Não é um incidente pontual.** Já são quatro ondas: 13/08, 14/08, 20/08 e **21/08**.

Distribuição em 9.562 pessoas-conta distintas (origem `Integração Sistema`, apuração de 20/08):

| Registros por pessoa-conta | Qtd |
|---|---|
| 1 (correto) | 452 |
| 2 | 2.321 |
| 3 | 4.355 |
| 4 | 1.492 |
| 5 ou mais | 888 |

## 2. Impacto medido

| | 13/08 | 20/08 | 21/08 |
|---|---|---|---|
| Contatos na base | 22.783 | 35.539 | — |
| Ativos `Integração Sistema` | 6.257 | 2.053 | ver §2.1 |
| Benchmarking ativos | 3 | 3 | 4 |
| Benchmarking em registros inativos | 437 | 448 | 448 |

A base ativa caiu para um terço em uma semana. A tela 360 mostra hoje uma fração dos contatos.

Impacto no cliente (Thomson Reuters): **452 marcações de Benchmarking** — 448 delas em registros
desativados — construídas ao longo de meses pelo time de CS. O time Comercial usa essa marcação
para consultar clientes de referência.

### 2.1 — A onda de 21/08

7.100 contatos de origem `Integração Sistema` foram tocados em 21/08 entre 18h12 e 18h25;
**7.096 terminaram inativos**, 4 seguem ativos.

| Momento | Registros |
|---|---|
| 21/08 18:12 | 7.073 |
| 21/08 18:16 | 4 |
| 21/08 18:24 | 19 |
| 21/08 18:25 | 4 |

Composição do recorte: 6.993 registros nascidos na carga original de **julho/2025** (6.853 só em
10/07), 1.761 contas, brands TAX 4.295 · GTM 1.950 · LEGAL 855.

**A capacidade de recuperação cai a cada carga:**

```
contatos recuperáveis por correspondência direta:
   13/08: 280
   20/08: 120
```

Os 120 contatos-destino apurados em 20/08 **não aparecem** no recorte de 21/08 — não foram tocados
nesta onda, então a recuperação direta segue viável. Já os 412 registros inativos que carregavam
Benchmarking foram todos re-carimbados hoje, e outros 40 se somaram a eles (412 → 452).

## 3. Causa raiz — confirmada

A chave de upsert é gravada em `customer_contact.id_legacy`. Na carga seguinte a string é remontada
e usada para localizar o registro. Quando o valor calculado difere do gravado, o upsert insere em
vez de atualizar.

**O export de 21/08 fecha o diagnóstico: há três formatos de chave convivendo na mesma coluna**,
cada um deixado por uma execução diferente.

| Formato gravado em `id_legacy` | Registros | Geração | Exemplo |
|---|---|---|---|
| Numérico | 7.079 | julho/2025 | `13779`, `28513` |
| `email : cnpj : produto` | 17 | 13–14/08/2026 | `nome@empresa.com:00.000.000/0001-00:ONESOURCE DFe` |
| Código da conta | 4 | 20/08/2026 | `135226-TAX` |

Os valores numéricos são 7.079 inteiros distintos entre 155 e 34.840, sem correlação com o
`id_contato` (r = 0,07) — não é identificador do SenseData, é a chave da carga original.

Isso responde ao ponto que estava em aberto no card anterior: a recriação continuou em 14/08, 20/08
e 21/08 **sem nova alteração de configuração** porque a chave calculada muda entre execuções.
A alteração de 13/08 foi só a primeira ocorrência:

| Versão | Horário | Composição |
|---|---|---|
| V3_3 | 13/08 19:06 | `EMAIL : CNPJ` |
| V4 | 13/08 20:48 | `EMAIL : CNPJ : SKYPE` |

```
13/08 20:48   chave passa a incluir SKYPE
13/08 22:43   carga executa
              → Pré-processing marca is_active=False em 100% da base Integração Sistema
              → upsert calcula EMAIL:CNPJ:SKYPE; registros gravados têm chave numérica ou EMAIL:CNPJ
              → nenhum match → 6.271 registros inseridos como novos
              → base anterior permanece desativada
```

**Consequência permanente:** os 7.079 registros com chave numérica não podem mais ser casados por
nenhuma execução da carga atual. Eles só podem ser desativados, nunca reativados. É por isso que
reaparecem em toda onda de inativação.

Dois fatores se somam:

1. **Chave composta por campo volátil e de formato mutável.** `SKYPE` não é campo de skype —
   carrega produto. E a composição já mudou três vezes.
2. **Inativação em massa.** O `Pré-processing` desativa 100% da base antes de cada carga e depende
   do fluxo principal para reativar. Match falhou = nada é reativado.

## 3.1 — Único ponto ainda em aberto

O recorte de 21/08 tem 7.100 linhas, contra ~35 mil contatos na base. Falta confirmar se o
pré-processing leu a base inteira (e o export é que foi filtrado) ou se leu apenas um subconjunto.
Query 2.2 do `queries-contatos-tr.sql` resolve. Se for subconjunto, o filtro do step 2132 também
precisa ser revisto.

Não muda a conclusão nem as ações abaixo.

---

## 4. Ação imediata

### CR-0 — Pausar a carga de contatos

Cada execução desativa mais registros, cria mais duplicados e reduz o que ainda pode ser
recuperado (280 → 120 em uma semana). Pausar até a correção.

### BLOQUEIO — expurgo de inativos

Nenhuma rotina de limpeza de contatos inativos pode rodar. Os 448 registros desativados são a
única fonte das marcações de Benchmarking. Excluí-los torna a perda definitiva.

---

## 5. Correção

### CR-1 — Estabilizar a chave de upsert

A chave não pode conter campo volátil ou derivado. Definir e documentar o modelo de identidade:

- **(a)** um registro por *(pessoa, conta)* — produto vira atributo. **Recomendado.**
- **(b)** um registro por *(pessoa, conta, produto)* — produto na chave, vindo de campo próprio e
  validado, nunca de `SKYPE`.

**Regra permanente:** alterar a composição da chave exige migração que reescreva o `id_legacy` dos
registros existentes **antes** da carga rodar.

**Aceite:** duas execuções seguidas sem alteração na origem → 0 inserções e 0 desativações na segunda.

### CR-1b — Migrar as chaves órfãs

Os 7.079 registros com `id_legacy` numérico precisam ter a chave reescrita no formato escolhido em
CR-1, senão continuam invisíveis para a carga mesmo depois da correção. Fazer **antes** de religar
as integrações.

### CR-2 — Inativação seletiva

Substituir a desativação em massa (`Campo_is_active` grava `False` para todas as linhas, sem
condição) por anti-join: desativar apenas contatos ausentes do arquivo recebido.

**Aceite:** carga com o mesmo conjunto de contatos não desativa nenhum registro.

### CR-3 — Produto no campo correto

6.061 dos 6.271 registros de 13/08 têm produto em `SKYPE`, com `Produto` vazio. Mapear para
`Produto`; `SKYPE` volta a ser skype. Corrigir os registros já gravados.

Origem SD: `custom_fields` → `$.produto.value` (step `Separação`). Origem S3: coluna `SKYPE`. Unificar.

### CR-4 — Guardrails

Abortar a carga e alertar quando:

- taxa de match < 90% dos ativos existentes;
- desativação > 10% da base;
- inserções > 10% da base.

Logar por execução: lidos, casados, inseridos, atualizados, desativados.

**Aceite:** simular alteração de chave em teste; a carga aborta antes de gravar.

### CR-5 — Deduplicar

Após CR-1 e CR-2, consolidar as gerações duplicadas (9.110 pessoas-conta com 2+ registros),
preservando o registro que carrega os campos preenchidos manualmente.

---

## 6. Recuperação do Benchmarking (frente separada — não depende dos devs)

Situação em 21/08: **452 registros com marcação real**, em 416 pessoas-conta e 353 contas.
415 têm `Data Benchmark` preenchida (de 02/12/2024 a 30/04/2026); 5 estão com opt-out.

Distribuição por produto de referência (top): Onesource Tax One 141 · Legal One 70 ·
Onesource Global Trade 60 · Onesource DFe 50 · Onesource Tax Analyser 14. Por brand:
TAX 248 · GTM 126 · LEGAL 78.

Sobre o mapeamento de 20/08 (412 pessoas-conta):

| Situação | Qtd | Ação |
|---|---|---|
| 1 contato ativo na mesma conta | 120 | Copiar `Benchmarking` + `Data Benchmark` — automático |
| Ambíguo / ativo em outra conta | 16 linhas | Conferência manual |
| Sem contato ativo | 277 | Decisão do cliente: reativar ou manter |

Os 40 registros que entraram depois de 20/08 precisam passar pelo mesmo pareamento (query 3.2).

**Atenção ao formato do campo.** `Benchmarking` fica em `customer_contact.custom_fields` (jsonb) e o
valor é um **array**: `["Legal One"]`, `["OSGT -  Import", "Onesource Global Trade"]`, e às vezes
`{"value": null}`. Ou seja, `custom_fields->'benchmarking'->>'value'` devolve a string `["N/A"]`,
não `N/A` — filtrar por `NOT IN ('','N/A')` deixa passar a base inteira. O
`queries-contatos-tr.sql` já trata isso.

**Ponto aberto antes de executar:** confirmar se a carga faz **merge** ou **replace** no jsonb — se
for replace, gravar Benchmarking apaga os demais custom fields. Validar com 10 registros,
comparando o `custom_fields` completo antes e depois.

Carga de recuperação: `integ_type = update` (nunca upsert), chave pelo identificador do próprio
registro, gravando apenas os dois campos.

---

## 7. Validação final

1. Duas execuções seguidas → 0 inserções, 0 desativações na segunda (idempotência).
2. Um único formato de chave em `id_legacy` para a origem `Integração Sistema`.
3. Contagem de ativos por conta estável entre execuções.
4. `132626-TAX` exibindo os 7 contatos corretos.
5. Nenhum registro novo com produto em `SKYPE`.
6. Amostra dos 120 recuperados com `Benchmarking` e `Data Benchmark` preenchidos.

---

## 8. Fora de escopo

Contatos `Zendesk` e `GSI` vinculados a contas de outra brand. Vinculam por e-mail sem preencher
`Brand`; são anteriores ao incidente (2022 e jun/2026) e o `Filtro_Type` do pré-processing os exclui
da recriação. Demanda separada.
