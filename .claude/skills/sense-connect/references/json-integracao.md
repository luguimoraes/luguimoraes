# O JSON de export/import de uma integração (campo)

Estrutura observada em integrações reais exportadas do SenseConnect. Não é documentação oficial: campos novos podem aparecer e nomes podem mudar entre versões. Leia o export do próprio ambiente antes de afirmar algo.

## 1. Visão geral

```json
{
  "connections":      { "<connection_id>":  { ... } },
  "integrations":     { "<integration_id>": { ... } },
  "steps":            { "<step_id>":        { ... } },
  "steps_dependency": [ { ... }, ... ]
}
```
Os ids são números, mas aparecem como **strings** nas chaves dos objetos (`"122"`) e como **inteiros** dentro dos valores (`"connection_id": 6`, `"item_id": 119`).

## 2. `connections`
```json
"6": {
  "_deleted": false,
  "connection_params": "<blob criptografado>",
  "created_at": "2025-10-02T21:12:06.294781",
  "created_by": 1,
  "default_connection": false,
  "is_active": true,
  "name": "SENSEDATA_HOM",
  "source": "postgres",
  "status": true,
  "updated_at": null,
  "updated_by": null
}
```
- `connection_params` carrega a credencial (criptografada, mas sensível). **Redija** antes de versionar ou mandar para alguém: `scripts/integracao_json.py redigir`.
- `source` é o tipo da conexão (`postgres` observado). O nome deve deixar claro o ambiente.
- Ao importar em outro ambiente, reaproveite a conexão existente de lá e confira se o `connection_id` usado pelas etapas existe e é do ambiente certo.

## 3. `integrations`
```json
"20": {
  "_deleted": false,
  "created_at": "...", "created_by": 1,
  "folder_id": null,
  "name": "Grupos_Economicos",
  "status": true,
  "updated_at": "...", "updated_by": 1
}
```

## 4. `steps`
Campos comuns a todas as etapas:

| Campo | Significado |
|---|---|
| `item_type` | Tipo da caixa (ver abaixo) |
| `name` | Nome exibido na caixa |
| `integration_id` | Integração dona da etapa |
| `args` | Configuração da etapa (depende do tipo) |
| `output_schema` | Colunas que saem da etapa (fontes e transformações) ou o mapeamento (carregamento) |
| `position` | `{x, y}` da caixa no canvas |
| `is_wiped` | Observado sempre `false` |
| `execution_fn` | Observado `null` |
| `created_at/by`, `updated_at/by` | Auditoria |

### 4.1 `item_type` observados
| `item_type` | Caixa | Observação |
|---|---|---|
| `start` | Início | `args: {}` |
| `end` | Fim | `args: {}` |
| `data_source` | Fonte de dados | `args.integration_params` + `args.load_type` |
| `filter` | Filtro de Dados | Ex.: etapa "Filtro_Type" que remove origens |
| `create_column` | Criar novo campo | Ex.: etapa que grava um valor constante |
| `load_data` | Carregamento | `args.destiny_table`, `integ_type`, `keys`, `customer_key` |

Concatenação, deduplicação, separação, união, condicional, agregação e truncar têm `item_type` próprios que não foram registrados aqui. Leia no export.

### 4.2 `data_source` com SQL (PostgreSQL)
```json
"122": {
  "item_type": "data_source",
  "name": "PostgreSQL",
  "args": {
    "integration_params": {
      "connection_id": 6,
      "query": "V0lUSCBtYXRyaXogQVMg...",
      "source": "postgres"
    },
    "load_type": "total"
  },
  "output_schema": {
    "fields": {
      "customer_id_legacy": {
        "type": "text",
        "treatment": "keep_original",
        "remove_dots_and_dash": false,
        "remove_special_char": false,
        "remove_whitespaces": false,
        "remove_zero_left": false
      }
    }
  }
}
```
- `query` é o SQL em **Base64 (UTF-8)**. Decodifique para ler (`scripts/integracao_json.py decode`) e gere com round-trip para gravar (`build`). **Nunca monte o Base64 à mão**: numa entrega real, o Base64 do documento de implantação tinha uma vírgula a mais que o SQL revisado e a integração quebraria na primeira execução.
- `output_schema.fields` tem uma entrada por coluna do `SELECT` final (o alias). Se a query ganhar ou perder colunas, o schema precisa acompanhar.
- Flags de tratamento por coluna: `remove_dots_and_dash`, `remove_special_char`, `remove_whitespaces`, `remove_zero_left` e `treatment` (`keep_original` observado). Provavelmente são as opções do lápis de "Tipo de Campo". Úteis para chaves: CNPJ com e sem máscara, códigos com zero à esquerda.

### 4.3 `load_data`
```json
"123": {
  "item_type": "load_data",
  "name": "Carregamento",
  "args": {
    "customer_key": {},
    "destiny_table": "customer",
    "integ_type": "update",
    "keys": ["customer_id_legacy"]
  },
  "output_schema": {
    "fields": {
      "cs_feeling_grupo":   {"field_destiny": "cs_feeling_grupo", "options": "overwrite", "type": "text"},
      "customer_id_legacy": {"field_destiny": "",                 "options": "ignore",    "type": "text"}
    }
  }
}
```
| Campo | Valores observados | Significado |
|---|---|---|
| `destiny_table` | `customer`, `customer_contact` | Tabela de destino |
| `integ_type` | `update`, `upsert` | `update` só altera o que casa pela chave; `upsert` altera ou cria |
| `keys` | ex.: `["customer_id_legacy"]`, `["chave_upsert_segura"]` | Coluna(s) da fonte usadas para localizar o registro |
| `customer_key` | `{}` quando o destino é o próprio cliente | Chave cliente (SenseData ↔ arquivo) quando o destino é outra tabela |
| `options` por campo | `overwrite`, `ignore` | Sobrescrever / Ignorar da tela |
| `field_destiny` | nome interno do campo ou `""` | Coluna na Sensedata; vazio quando ignorado |

- Numa integração que atualiza clientes, a coluna de chave (`customer_id_legacy`) é casada com o `id_legacy` do cliente.
- Campo customizado de destino: `field_destiny` é o **nome interno** (minúsculas, `_`), não o rótulo de exibição. Se houver colisão de nomes, a plataforma pode sufixar (`cs_feeling_2`); confira em Configurações.

## 5. `steps_dependency`
```json
[
  {"item_id": 119, "dependency_id": 122, "direction": {"from_direction": "right", "to_direction": "left"}},
  {"item_id": 122, "dependency_id": 123, "direction": {"from_direction": "right", "to_direction": "left"}},
  {"item_id": 123, "dependency_id": 120, "direction": {"from_direction": "right", "to_direction": "left"}}
]
```
Cada item é uma seta: da saída (direita) de `item_id` para a entrada (esquerda) de `dependency_id`. O exemplo acima é `Início(119) → PostgreSQL(122) → Carregamento(123) → Fim(120)`.

Validação mínima (o `scripts/integracao_json.py validar` faz):
- existe exatamente um `start` e um `end`;
- todo passo é alcançável a partir do `start` e alcança o `end`;
- toda seta aponta para ids que existem em `steps`;
- há pelo menos um `data_source` e um `load_data`;
- as `keys` do `load_data` existem no `output_schema` da etapa anterior (quando ela é uma fonte com schema);
- todo campo `overwrite` tem `field_destiny` preenchido;
- nenhum `connection_params` real está presente.

## 6. Receitas

**Ler o SQL de todas as fontes**
```bash
python3 scripts/integracao_json.py decode integracao.json
```

**Trocar o SQL de uma fonte e atualizar o mapeamento**
```bash
python3 scripts/integracao_json.py build \
  --base integracao.json --sql nova_query.sql --step 122 \
  --campos cs_feeling_grupo,anotacoes_grupo \
  --out integracao_v2.json
```
- `--step`: id da etapa `data_source` (se omitido e só houver uma fonte SQL, ela é usada).
- `--campos`: colunas gravadas (Sobrescrever). As demais colunas da query viram Ignorar. Sem `--campos`, o mapeamento atual é mantido para colunas que continuam existindo.
- O script confere que a chave do carregamento continua no `SELECT` e faz round-trip do Base64.

**Compartilhar com segurança**
```bash
python3 scripts/integracao_json.py redigir integracao.json --out integracao_redigida.json
```

## 7. Cuidados ao importar
- Importar sobre uma integração existente substitui etapas: exporte a versão atual antes (é o seu rollback).
- Confira `connection_id` e o ambiente.
- Depois de importar, abra a integração no canvas, confira se nenhuma caixa mostra ⚠ e rode primeiro em homologação.
