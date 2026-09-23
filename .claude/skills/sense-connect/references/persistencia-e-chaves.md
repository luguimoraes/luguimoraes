# Persistência, chaves e idempotência

A parte da integração que mais causa incidente não é a extração: é decidir **como o dado fica** no SenseData depois de várias execuções. Este arquivo junta o que o manual diz (sem marcação) com o que foi aprendido em campo **(campo)**.

## 1. As duas chaves do carregamento

| Chave | Tela | Para que serve | Exemplo |
|---|---|---|---|
| Chave com o cliente | "Chave cliente no SenseData" ↔ "Chave cliente no arquivo" | Dizer **de qual cliente** é a linha | CNPJ ↔ CNPJ; id_legacy ↔ id_legacy |
| Chave da importação | "Chave no arquivo" (ou "Não possui chave no arquivo") | Dizer **qual registro** da tabela de destino a linha representa | `id_legacy` criado por concatenação |

- Sem chave da importação, não há como atualizar: cada execução só pode inserir (ou apagar e inserir, com limpeza).
- **(campo)** Em tabelas nativas, a chave da importação é gravada em `id_legacy` do registro. É por ela que a próxima execução encontra o registro.

## 2. Escolhendo a chave da importação (campo)

Boa chave:
- **identifica** um registro de negócio (um diagnóstico, um contato numa conta, um contrato);
- é **estável**: o mesmo registro produz a mesma chave em todas as execuções;
- é **única** no resultado da fonte (senão, deduplique antes);
- é **normalizada** (minúsculas, sem espaços nas pontas, sem máscara) antes de concatenar.

Má chave:
| Chave | Problema |
|---|---|
| Inclui um atributo que muda (produto, status, farol, data de atualização) | O registro "vira outro" quando o atributo muda; o antigo fica órfão |
| Não distingue registros (ex.: só o código da conta para contatos) | Cada linha sobrescreve a anterior; sobra um registro por conta |
| Muda de composição entre versões da integração | Nenhum registro existente casa; a base inteira é recriada |
| Usa um campo "emprestado" (ex.: produto guardado no campo Skype) | Formato imprevisível; mistura semânticas |
| Texto não normalizado ("Fulano@X.com " × "fulano@x.com") | Match falha de forma intermitente |

**Regra permanente:** mudar a composição da chave exige, **antes** da próxima execução, reescrever a chave dos registros já gravados para o formato novo. Sem isso, os registros antigos nunca mais casam: só podem ser desativados, nunca atualizados.

Modelo de identidade para contatos (recomendado): um registro por **(pessoa, conta)**; produto como atributo. Alternativa: (pessoa, conta, produto), com produto vindo de campo próprio e validado.

## 3. Tipo de integração (campo)

| Tipo | Linha nova | Linha que casa | Linha que sumiu da origem |
|---|---|---|---|
| `update` | ignorada | atualizada | **não tocada** (valor congela) |
| `upsert` / "Criação e Atualização" | criada | atualizada | **não tocada** |
| Qualquer um + limpeza Completa | — | — | apagada (a tabela é esvaziada a cada execução) |
| Qualquer um + limpeza Parcial | — | — | apagada se estiver no período limpo |

Consequências:
- Nenhum tipo "limpa sozinho" o que saiu da origem, exceto com limpeza. Decida o que fazer com órfãos.
- Limpeza Completa em tabela que também recebe dados de outra fonte ou edição manual apaga esses dados. Use só em tabelas que a integração possui por inteiro (típico: custom data com snapshot completo).
- Limpeza Parcial precisa de um campo de data confiável; combine com carga incremental pela mesma janela.

## 4. Opções do mapeamento (campo)
- **Sobrescrever** grava sempre, inclusive vazio. Uma fonte que devolve vazio **apaga**.
- **Ignorar** não grava.
- Campo editado à mão + Sobrescrever = a edição é revertida na próxima carga. Defina a fonte da verdade:
  - integração é dona do campo → Sobrescrever e deixe o campo não editável na tela;
  - pessoa é dona do campo → Ignorar (ou não mapeie);
  - os dois → use dois campos (ex.: `cs_feeling` da loja e `cs_feeling_grupo` vindo da integração).

## 5. Órfãos: o que fazer com quem saiu da origem (campo)
| Estratégia | Como | Quando |
|---|---|---|
| Manter | Não fazer nada | Histórico que vale mesmo depois que a origem esquece |
| Limpar | Emitir a linha com valor `''` para quem deixou de ser elegível | Dado derivado que só vale enquanto a condição vale (ex.: dado do grupo numa loja que saiu do grupo) |
| Inativar | Emitir `is_active = false` só para quem existe no destino e não veio (anti-join) | Contatos, produtos, usuários |
| Apagar | Limpeza Completa/Parcial | Snapshot que a integração possui por inteiro |

### 5.1 Inativação seletiva × inativação em massa
Em massa (evitar):
```
1) integração A: is_active = false para TODOS da origem X
2) integração B: is_active = true para quem veio no arquivo (upsert por chave)
```
Falha se o arquivo vier parcial, vazio ou antigo, se B quebrar, ou se a chave não casar: a base inteira fica inativa ou é recriada.

Seletiva (recomendado):
```
contatos_no_arquivo  = chaves do arquivo (normalizadas)
contatos_no_destino  = chaves ativas da origem X no SenseData
a_inativar           = contatos_no_destino − contatos_no_arquivo   (anti-join)
a_criar_ou_atualizar = contatos_no_arquivo
```
Na mesma execução, e protegido por guardrails (seção 7).

## 6. Delta e idempotência (campo)
- Carga `total` reenviando tudo, todo dia, gera: histórico poluído, "data de atualização" sempre nova (o que engana regras e relatórios), carga desnecessária.
- Delta: devolva só o que mudou (numa fonte SQL, `IS DISTINCT FROM` entre valor atual e novo).
- **Teste de idempotência** (aceite de toda integração): duas execuções seguidas, sem mudança na origem. A segunda deve ter 0 inserções, 0 desativações e, com delta, 0 linhas.

## 7. Guardrails (campo)
Aborte **antes de gravar** e alerte quando:
| Sinal | Limite sugerido |
|---|---|
| Linhas da origem × última execução | variação > 20% |
| Registros a desativar | > 10% da base ativa |
| Registros a inserir | > 10% da base |
| Taxa de match com existentes | < 90% |
| Arquivo não é mais novo que a última execução bem-sucedida | abortar sem processar |

Registre por execução: lidas, casadas, inseridas, atualizadas, desativadas, ignoradas. "0 linhas por vários dias" precisa ser distinguível de "quebrou".

Se o SenseConnect não oferecer esses controles no seu ambiente, coloque-os:
- na origem (quem gera o arquivo não publica arquivo incompleto; nome com data);
- numa etapa anterior (fonte SQL que já devolve vazio quando o volume é anômalo);
- ou numa rotina externa que decide se dispara o workflow ("Executar agora" por API/orquestrador).

## 8. Arquivos (S3) (campo)
- Nome fixo (`contatos.csv`) não distingue arquivo novo de antigo. Prefira `contatos_AAAAMMDD.csv` ou confira `LastModified`.
- Ative o **versionamento** do bucket: é o que permite saber, depois, o que foi processado em cada execução.
  ```
  aws s3api list-object-versions --bucket <bucket> --prefix <pasta>/<arquivo>.csv
  aws s3api get-object --bucket <bucket> --key <pasta>/<arquivo>.csv --version-id <id> arq.csv
  ```
- Compare `LastModified` de cada versão com os horários das execuções: se não mudou, a carga reprocessou o arquivo antigo.

## 9. Recuperação depois de um estrago (campo)
Ordem que funciona:
1. **Pausar** as integrações envolvidas (senão a próxima execução desfaz a recuperação e a base muda debaixo da consulta).
2. **Bloquear expurgo** de registros inativos (é o único cenário irreversível; os dados manuais costumam estar nos registros antigos, agora inativos).
3. Exportar um snapshot do estado atual (fora do banco).
4. Descobrir a causa (formatos de chave, ondas de `updated_at`/`created_at`, versões do arquivo).
5. Corrigir o desenho (chave estável, inativação seletiva, guardrails).
6. Migrar as chaves antigas para o formato novo.
7. Recuperar dados manuais: migrar campo do registro antigo para o novo, pareando por uma chave de negócio (ex.: conta + e-mail). Carga de recuperação com `update` (nunca `upsert`), chave pelo identificador do registro, gravando só os campos recuperados.
8. Reativar quem deveria estar ativo (ex.: via Manutenção via CSV, em lotes, começando pelos casos sem ambiguidade).
9. Religar e rodar o teste de idempotência.

Backups com retenção curta (ex.: 7 dias) costumam expirar antes de alguém perceber o problema. Não monte o plano em cima deles sem confirmar que o snapshot certo ainda existe.
