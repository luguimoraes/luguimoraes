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

**Não é um incidente pontual.** Já são cinco ondas: 13/08, 14/08, 20/08, 21/08 e **24/08**.

> **A carga não está pausada.** A onda de 24/08 rodou às 13h13, depois do card ter sido
> aberto com CR-0 (pausar) como ação imediata. Enquanto a carga roda, o estrago cresce e a
> janela de recuperação encolhe.

Distribuição em 9.562 pessoas-conta distintas (origem `Integração Sistema`, apuração de 20/08):

| Registros por pessoa-conta | Qtd |
|---|---|
| 1 (correto) | 452 |
| 2 | 2.321 |
| 3 | 4.355 |
| 4 | 1.492 |
| 5 ou mais | 888 |

## 2. Impacto medido

| | 13/08 | 20/08 | 21/08 | 24/08 |
|---|---|---|---|---|
| Contatos na base | 22.783 | 35.539 | — | 35.543 |
| Ativos `Integração Sistema` | 6.257 | 2.053 | ver §2.1 | 2.052 |
| Benchmarking ativos | 3 | 3 | 4 | 7 |
| Benchmarking em registros inativos | 437 | 448 | 448 | 448 |

### 2.0 — O número que mede o estrago

Cruzamento do snapshot de 13/08 (16.945 linhas, com `Ativo` medido) contra o export completo de
24/08 (35.543 registros), casando por `ID Contato` — número **medido**, não inferido:

| Estado em 13/08 | Ativo hoje | Inativo hoje | Sumiu da base |
|---|---|---|---|
| **Ativo (6.257)** | **0** | 6.203 | 54 |
| Inativo (10.688) | 0 | 10.542 | 146 |

**Nenhum contato ativo em 13/08 continua ativo.** E o snapshot de 13/08 já é posterior à primeira
onda (22h43), então esse número **subestima** o estado de 10/08.

> **200 registros sumiram da base** entre 13/08 e 24/08 — 54 deles estavam ativos —, concentrados
> em 24 contas. Não é desativação: é ausência do registro. Investigar antes de reativar; pode
> haver exclusão de conta envolvida. É o cenário irreversível descrito no runbook (C.1).

Sobre o estado de 10/08 especificamente: a onda de 24/08 sobrescreveu `updated_at` em toda a base,
o que destruiu a única evidência que permitia reconstruí-lo por inferência. A reconstrução hoje
devolve 10.495 registros, mas isso **superestima** — inclui registros que já estavam inativos antes
de 10/08 e foram recarimbados. O número real exige a listagem do dia 10 (seção D das queries).

Os 2.052 ativos de hoje são todos registros **novos**: 2.051 criados em 20/08 e 1 em 22/08.
Nenhum contato que o cliente via em 10/08 sobreviveu.

Contatos `Zendesk` (5.576), `GSI_GTM` (164) e `GSI_LEGAL` (81) têm **zero** inativos — o
`Filtro_Type` os protege, e é por isso que só 11 das 2.124 contas ficaram sem nenhum contato ativo.

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
| Numérico | 7.079 | jul/2025 **a 31/07/2026** | `13779`, `28513`, `35024` |
| `email : cnpj` | — | 13/08/2026 22:45 | `nome@empresa.com:00.000.000/0001-00` |
| `email : cnpj : produto` | 17 | 14/08/2026 14:09 | `nome@empresa.com:00.000.000/0001-00:ONESOURCE DFe` |
| **Código da conta** | 4 | 20/08/2026 22:49 | `132626-TAX` |

Os valores numéricos são 7.079 inteiros distintos entre 155 e 34.840, sem correlação com o
`id_contato` (r = 0,07) — não é identificador do SenseData, é a chave da carga original.
A conferência de 24/08 mostrou que esse formato **seguiu em uso até 31/07/2026** (chaves 34.9xx
e 35.0xx), e não só na carga de 2025 — a numeração é contínua e simplesmente para em 13/08.

### 3.2 — Por que a carga de 20/08 trouxe ~1 contato por conta

A chave gravada em 20/08 é **o código da conta**, não o contato: `132626-TAX`. Não há nada no valor
que distinga uma pessoa da outra dentro da mesma conta.

Consequência direta: **só um contato por conta sobrevive ao upsert.** Cada linha seguinte do arquivo
recalcula a mesma chave e sobrescreve o mesmo registro. Isso explica com mecanismo — e não por
correlação — o número que já estava na tabela de volumes: 2.102 registros para 2.053 contas (~1,0).

Em uma conta conferida registro a registro, os 7 contatos corretos (4 pessoas × produto) foram
recriados certos em 14/08 e colapsaram para **1 único ativo** depois de 20/08.

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

## 3.1 — Cada onda pega um recorte diferente

O recorte de 21/08 (7.100 linhas) **não é a base inteira**: nenhuma chave numérica acima de 34.840
aparece nele, e apenas 3 registros criados em jul/2026. A conferência de 24/08 encontrou registros
de 29 e 31/07/2026 que não foram tocados em 21/08 — e foram tocados hoje.

Ou seja, a onda de 24/08 alcançou **mais** registros que a de 21/08. O conjunto varia entre
execuções, o que é mais um sintoma do arquivo de origem instável (Parte B do runbook) e não muda
nenhuma das ações abaixo.

---

## 4. Ação imediata

### CR-0 — Pausar a carga de contatos · **NÃO EXECUTADO**

Cada execução desativa mais registros, cria mais duplicados e reduz o que ainda pode ser
recuperado (280 → 120 em uma semana). Pausar até a correção.

**Status em 24/08: a carga rodou de novo às 13h13.** Pausar `Pré-processing_Inativa_Contatos`
(2012) e `Contatos_S3_V4` (2036) é pré-requisito de todo o resto — inclusive de qualquer
conferência, porque a base muda debaixo da consulta.

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

### 6.1 — Por que "restabelecer nos contatos ativos" não funciona como pedido

Das 419 pessoas-conta com marcação, apenas **138 têm contato ativo hoje** para receber o dado.
As outras **281 (67%) não têm destino algum** — não existe contato ativo daquela pessoa naquela conta.

Migrar campo entre registros só resolve 1/3 do problema. **A reativação resolve os 100%**, porque
431 das 455 marcações estão nos próprios registros que estavam ativos em 10/08: reativar traz o
Benchmarking junto, sem carga de migração de campo.

Ordem correta: reativar primeiro, migrar campo depois (e só nos poucos casos que sobrarem).

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
