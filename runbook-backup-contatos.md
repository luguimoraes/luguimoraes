# Runbook — Inativação de contatos TR: comprovação, backup e ajuste

Documento operacional. Pode ser executado sem o Luis (planning de segunda).

---

## Parte A — Por que os contatos foram inativados

A inativação não é um bug isolado: é o desenho da rotina. Duas integrações rodam em sequência.

### A.1 — A cadeia de execução

**1º · `Pré-processing_Inativa_Contatos` (integração 2012)**

| Step | Tipo | O que faz |
|---|---|---|
| 2131 | data_source | Lê **toda** a `customer_contact` (`load_type: total`) |
| 2132 | filter | Remove `Zendesk`, `GSI_GTM`, `GSI_LEGAL` → sobra só `Integração Sistema` |
| 2134 | create_column | Grava `is_active = "False"` em **todas** as linhas, sem condição |
| 2133 | load_data | `update` em `customer_contact`, chave `id_legacy` |

Resultado: **100% dos contatos de origem `Integração Sistema` são desativados.**

**2º · `Contatos_S3_V4` (integração 2036)**

| Step | Tipo | O que faz |
|---|---|---|
| 2568 | data_source | Lê o CSV do S3 — `sc_upload/sensedata_tr_contatos.csv` |
| 2567 | data_source | Lê clientes do SenseData |
| — | concat/join | Monta `chaveamento` e `chave_upsert_segura` |
| — | create_column | Grava `status = "Sim"` → mapeia para `is_active` |
| — | load_data | `upsert` em `customer_contact`, chave `chave_upsert_segura` |

Resultado: **só quem está no arquivo volta a ficar ativo.**

### A.2 — A conclusão que justifica a inativação

> Quem não estiver no arquivo do S3 no momento da execução **permanece inativo**.
> Não há verificação de que o arquivo seja recente, completo ou sequer novo.

Se o arquivo vier parcial, vier vazio, ou for o mesmo da semana passada, a rotina desativa a base
inteira e reativa apenas o que o arquivo contiver. Sem aviso e sem abortar.

### A.3 — Evidência de que foi isso que aconteceu

Volume trazido por execução (contatos criados por data de inserção):

| Data | Registros | Pessoas | Contas | Contatos por conta |
|---|---|---|---|---|
| 2025-07-10 | 6.853 | 5.757 | 1.731 | ~3,3 |
| 2026-08-13 | 6.214 | 5.823 | 1.802 | ~3,4 |
| 2026-08-14 | 10.807 | 8.223 | 2.055 | ~4,0 |
| **2026-08-20** | **2.102** | **2.008** | **2.053** | **~1,0** |

A execução de 20/08 trouxe cerca de **um contato por conta**, contra três a quatro do padrão
histórico. Ativos de origem `Integração Sistema` caíram de **6.257 (13/08)** para **2.053 (20/08)**.

O volume da origem oscilou de 5.823 → 8.223 → 2.008 pessoas em uma semana.

### A.4 — A onda de 21/08 e o que ela provou

Em 21/08, entre 18h12 e 18h25, **7.100 contatos** de origem `Integração Sistema` foram tocados —
**7.096 terminaram inativos**. É a quarta onda (13/08, 14/08, 20/08, 21/08).

O recorte é quase todo da carga original: 6.993 registros nascidos em julho/2025, 1.761 contas.

O achado decisivo está na chave gravada em `id_legacy` — **três formatos convivendo**:

| Formato | Registros | Deixado pela carga de |
|---|---|---|
| Numérico (`13779`, `28513`) | 7.079 | julho/2025 |
| `email : cnpj : produto` | 17 | 13–14/08/2026 |
| Código da conta (`135226-TAX`) | 4 | 20/08/2026 |

Cada troca de formato zera o match do upsert e a base inteira vira "registro novo". E os 7.079
registros com chave numérica **não podem mais ser casados por nenhuma execução da carga atual** —
só podem ser desativados, nunca reativados. Por isso reaparecem em toda onda.

Isso desloca o eixo do problema: não basta restaurar backup ou corrigir o arquivo do S3. Sem
reescrever as chaves órfãs (CR-1b no card), a recriação continua.

### A.5 — A quinta onda: 24/08 13h13 (a carga não foi pausada)

Conferência direta no banco em 24/08 mostrou `updated_at = 2026-08-24 13:13:09` em registros de
`Integração Sistema`, com a reativação do sobrevivente às 13h15. **A rotina continua rodando.**

Duas coisas a mais que essa conferência mostrou:

1. **A chave de 20/08 é o código da conta** (`132626-TAX`), não o contato. Como todas as linhas da
   mesma conta calculam a mesma chave, cada uma sobrescreve a anterior e **só um contato por conta
   sobrevive**. É o mecanismo por trás do ~1,0 contato por conta da tabela em A.3.
2. **A chave numérica não é só da carga de 2025.** Há registros criados em 29 e 31/07/2026 com
   chave numérica (34.9xx, 35.0xx). A numeração é contínua até 31/07/2026 e para em 13/08.

> Enquanto a carga não for pausada, qualquer conferência mede uma base que muda debaixo da consulta,
> e qualquer recuperação é desfeita na execução seguinte. Pausar é pré-requisito de tudo.

---

## Parte B — Verificar o arquivo no S3 (30 min, confirma ou derruba a causa secundária)

O nome do arquivo é fixo: **`sc_upload/sensedata_tr_contatos.csv`**. Não há data no nome, então
a integração não distingue arquivo novo de arquivo antigo.

### Passo a passo

1. **Listar o histórico de versões do objeto** no bucket (se o versionamento estiver ativo):

   ```
   aws s3api list-object-versions \
     --bucket <bucket> \
     --prefix sc_upload/sensedata_tr_contatos.csv
   ```

   Anotar de cada versão: `LastModified`, `Size`, `VersionId`.

2. **Comparar `LastModified` com os horários de execução da carga:**

   ```
   13/08 22:43   ·   14/08 14:09   ·   20/08 22:49   ·   21/08 18:12   ·   24/08 13:13
   ```

3. **Contar linhas de cada versão:**

   ```
   aws s3api get-object --bucket <bucket> \
     --key sc_upload/sensedata_tr_contatos.csv \
     --version-id <id> arquivo.csv
   wc -l arquivo.csv
   ```

### Como interpretar

| Achado | Significado |
|---|---|
| `LastModified` **não mudou** entre execuções | A TR não enviou arquivo novo e a rotina reprocessou o antigo |
| Arquivo de 20/08 com ~2.000 linhas | Arquivo chegou parcial — agrava, mas não é a causa principal |
| Arquivo de 20/08 com ~6.000 linhas | O arquivo estava certo e o problema é só a chave |
| Sem versionamento no bucket | Não dá para reconstruir o histórico; ativar versionamento agora |

> Com os três formatos de chave já comprovados (A.4), a chave instável é causa suficiente para a
> recriação. Este teste serve para saber se o arquivo de origem **também** está inconsistente —
> os dois problemas podem coexistir e precisam ser tratados separadamente.

---

## Parte C — Restaurar o backup (ordem obrigatória)

> **A ordem importa.** Restaurar sem pausar significa que a próxima carga desfaz tudo.
> A recriação rodou em 13/08, 14/08, 20/08, 21/08 e 24/08 — não é evento único, e segue ativa.

### C.1 — Antes de restaurar

1. **Pausar as duas integrações:**
   - `Pré-processing_Inativa_Contatos` (2012)
   - `Contatos_S3_V4` (2036)

2. **Confirmar que nenhuma rotina de expurgo de contatos inativos vai rodar.**
   As 448 marcações de Benchmarking estão nos registros inativos. Expurgo = perda definitiva.
   Este é o único cenário irreversível.

3. **Exportar o estado atual antes de mexer** (snapshot de segurança do que existe hoje).
   O recorte de 21/08 com as 452 marcações já serve como esse snapshot para o Benchmarking.

### C.2 — O que o backup resolve e o que não resolve

| | Está no backup | Está vivo no banco hoje |
|---|---|---|
| Valores de Benchmarking / Data Benchmark | sim | **sim — 452 registros** |
| `id_legacy` original (chave anterior) | sim | **sim — as chaves numéricas seguem gravadas** |
| Quais contatos estavam ativos antes | **sim — só ali** | não |

**Importante:** nem os valores de Benchmarking nem as chaves antigas dependem do backup — estão
vivos no banco. O backup é necessário apenas para saber **quem estava ativo** antes da primeira onda.

**Prazo:** retenção de 7 dias. A primeira onda foi 13/08 22h43. Verificar hoje se o snapshot
anterior a essa data ainda existe — provavelmente já expirou. Não montar o plano em cima dele.

### C.3 — Depois de restaurar

4. Validar em uma amostra: contatos ativos, Benchmarking preenchido, contagem por conta.
5. **Não religar as integrações** até a Parte D estar implementada.

---

## Parte D — Ajustes na integração

### D.0 — Reescrever as chaves órfãs

Os 7.079 registros com `id_legacy` numérico precisam receber a chave no formato definitivo antes de
qualquer nova execução. Sem isso, mesmo com a carga corrigida eles seguem invisíveis para o upsert
e continuam sendo desativados a cada rodada.

### D.1 — Não rodar quando o arquivo não for novo (resolve o ponto da Jaque)

Antes de executar, comparar o `LastModified` do objeto no S3 com o horário da última execução
bem-sucedida. Se o arquivo não for mais recente, **abortar sem processar**.

Isso implementa exatamente o comportamento que a TR diz esperar: se eles não enviam o arquivo,
a integração não roda. Independe de haver registro do alinhamento — é o comportamento correto.

### D.2 — Guardrail de volume

Abortar e alertar quando:

- o número de linhas do arquivo divergir mais que 20% da última execução;
- a rotina for desativar mais que 10% da base;
- as inserções ultrapassarem 10% da base;
- a taxa de match ficar abaixo de 90% dos ativos existentes.

Registrar por execução: linhas lidas, casadas, inseridas, atualizadas, desativadas.

> Com este guardrail, a execução de 20/08 (2.008 pessoas contra 5.823 da anterior) teria abortado
> antes de gravar. A de 21/08, com match zero contra 7.079 registros, também.

### D.3 — Inativação seletiva

Substituir o `create_column` que grava `is_active = False` em todas as linhas (step 2134) por
anti-join: desativar **apenas** contatos ausentes do arquivo recebido.

Com isso, mesmo que o arquivo venha parcial, a base não é zerada.

### D.4 — Chave de upsert estável

A `chave_upsert_segura` inclui `SKYPE`, que carrega produto. Campo volátil na chave torna a
identidade instável entre execuções — e a composição já mudou três vezes (numérica → `email:cnpj`
→ `email:cnpj:produto` → código da conta).

**Regra permanente:** alterar a composição da chave exige migração que reescreva o `id_legacy`
dos registros existentes **antes** da carga rodar.

### D.5 — Nome de arquivo com data

Passar de `sensedata_tr_contatos.csv` para `sensedata_tr_contatos_AAAAMMDD.csv`. Torna impossível
reprocessar arquivo antigo por engano e cria rastro de auditoria.

---

## Parte E — Ordem de execução

```
1. Pausar as duas integrações                          ← hoje
2. Bloquear expurgo de inativos                        ← hoje
3. Exportar as 452 marcações de Benchmarking           ← hoje (snapshot fora do banco)
4. Verificar versões do arquivo no S3 (Parte B)        ← 30 min, causa secundária
5. Verificar se o backup pré-13/08 ainda existe        ← hoje (prazo de 7 dias)
6. Recuperar Benchmarking dos que têm match direto     ← independe do resto
7. Implementar D.1 + D.2 (aborta carga ruim)           ← impede reincidência
8. Implementar D.3 + D.4 (corrige o desenho)
9. Rodar D.0 (reescrever as 7.079 chaves órfãs)
10. Restaurar backup / reativar contatos
11. Religar as integrações
12. Validar: duas execuções seguidas → 0 inserções e 0 desativações na segunda
```

---

## Validação final

1. Duas execuções seguidas sem alteração na origem → 0 inserções, 0 desativações na segunda.
2. Um único formato de chave em `id_legacy` para a origem `Integração Sistema` (query 1.1).
3. Carga com arquivo antigo → aborta sem processar.
4. Carga com arquivo 20% menor → aborta e alerta.
5. `132626-TAX` exibindo os 7 contatos corretos.
6. Contagem de ativos por conta estável entre execuções.
