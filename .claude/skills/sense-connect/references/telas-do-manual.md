# Inventário de telas do SenseConnect (Manual SenseConnect)

Rótulos exatamente como aparecem nas capturas do manual. Rótulos em MAIÚSCULAS na tela estão escritos aqui com a primeira letra maiúscula. Versões do produto podem ter pequenas diferenças: quando o usuário descrever outra tela, prefira o que ele vê.

Índice do manual: Introdução · Conexão (Criar Conexão, Google OAuth, Google Service Account, AWS S3, Zendesk) · Integração (Fonte - Outras APIs, Transformações: Agregação, Concatenação, Condicional, Criar novo campo, Deduplicação, Filtro de Dados, Separação, Truncar, União ou interseção; Fonte Avançada) · Workflow · Agendador · Casos de uso (Pipo, Outras APIs/API SenseData, Filtro incremental, Tecnofit, Pet2Pet).

---

## 1. Conexões

**Listagem** — Configurações > SenseConnect > Conexões
- Ações: Criar Conexão, Criar Pasta, Duplicar, Mover, Inativar, Apagar.
- Filtro: Mostrar somente conexões ativas.

**Configuração de conexão** (criar/editar)
| Campo | Obrigatório | Observação |
|---|---|---|
| Nome da conexão | * | É o nome exibido em "Nome da conexão" nas fontes |
| Origem | * | Google OAuth, Google Service Account, AWS S3, Zendesk, … |
| Campos da origem | * | Variam por origem (tabela abaixo) |

Botões: **Cancelar**, **Testar**, **Atualizar** (na edição; fica desabilitado até haver mudança).

| Origem | Campos |
|---|---|
| Google OAuth | Client ID, Client Secret, Refresh Token |
| Google Service Account | Client EMail, Token URI, Private Key (com as quebras de linha) |
| AWS S3 | Region, Access Key, Secret Access Key |
| Zendesk | Prefixo (compõe `https://{PREFIXO}.zendesk.com/`), Token (API Key) |

Conexões que já vêm cadastradas: "Google Sheets - Sensedata", "Google Service Account - Sensedata" (numa captura aparece grafado "Google Service Acount - Sensedata"), "AWS S3".

---

## 2. Editor de integração (canvas)

- Cabeçalho: "Senseconnect" e o nome da integração com lápis (ex.: `S3_Clientes ✎`).
- Painel **Adicionar elementos** (ⓘ, fechar ×), campo **Pesquisar**, grupos:
  - **Fonte de Dados (13)**: Google Analytics, Google BigQuery, Google Sheets, Hubspot, S3 Amazon, Omie, Outras APIs, Pipedrive, PostgreSQL, Salesforce, Sensedata, SQL Server, Zendesk. (Captura antiga: "Fonte de Dados (10)".)
  - **Transformações de Dados (10)**: começa por "Agregação de Dados", "Concatenação"… (a captura corta a lista; o manual documenta 9).
- Caixas: Início (▶, azul), Fim (bandeira, verde), fontes ("Fonte de Dados"), transformações ("Transformação"), carregamento ("Carregamento de Dados").
- Cada caixa tem conector de entrada (esquerda) e de saída (direita). A ligação tem um × no meio.
- Caixa selecionada: lápis (editar) e lixeira (remover). Caixa sem configuração: ⚠ laranja.

---

## 3. Fontes de dados

### 3.1 Editar Fonte de Dados — Google Sheets (assistente de 2 passos)
**Passo 1 — Editar Fonte de Dados**
| Campo | Estado |
|---|---|
| Nome | livre (ex.: "Google Sheets", "Google Sheets: sortimento prioritário") |
| Tipo de carga | travado em "Completo" |
| Origem | travado em "Google Sheets" |
| Nome da conexão | lista (ex.: "Google Sheets - Sensedata") |
| Link do Sheets | URL da planilha |
| Aba do Sheets | desabilitado até processar ("Selecione") |

Aviso amarelo: "Antes de selecionar a aba da planilha é necessário processar o arquivo, clicando no botão "Processar" abaixo."
Botões: **Cancelar**, **Processar**, **Continuar** (desabilitado até processar).

**Passo 2 — Editar tipo de campo**
| Coluna no Arquivo | Tipo de Campo |
|---|---|
| lista das colunas | Texto / Data / Número (lápis para editar) |
- ⊕/⊖ por linha; link "Carregar todos os campos" (ⓘ).
- Botões: **Voltar**, **Salvar**.

### 3.2 Editar Fonte de Dados — Amazon S3 (2 passos)
| Campo | Estado |
|---|---|
| Nome | livre (ex.: "Amazon S3") |
| Tipo de carga | travado em "Completo" |
| Origem | travado em "Amazon S3" |
| Nome da conexão | lista (ex.: "AWS S3 Tecnofit") |
| URL | nome da pasta/bucket (ex.: `tecnofit-ds-sensedata`) |
| Arquivo | desabilitado até processar; depois lista os arquivos (ex.: clientes.csv, contatos.csv, contratos.csv, financeiro.csv) |
| Encoding | ex.: UTF-8 |
| Delimitador | vírgula, ponto e vírgula, pipe, espaço |

Aviso: "Antes de selecionar o arquivo é necessário processar a URL, clicando no botão "Processar" abaixo."
Botões: **Cancelar**, **Processar**, **Continuar**. Passo 2 = Editar tipo de campo.

### 3.3 Editar Fonte de Dados — Sensedata (2 passos)
| Campo | Estado |
|---|---|
| Nome | ex.: "Sensedata: clientes" |
| Tipo de carga | travado em "Completo" |
| Origem | travado em "Sensedata" |
| Tipo de dado | lista (ex.: "Cliente") |
Passo 2: Editar tipo de campo (ex.: só `id_legacy`, Texto).

### 3.4 Outras APIs (assistente de 5 passos: 1—2—3—4—5)
**1. Editar Fonte de Dados**: Nome (ex.: "Extração de API", "API Sensedata"), Tipo de carga (Completo/Incremental), Origem (travado "Outras APIs"), Nome da conexão ("Selecione"). Botões: Cancelar, Continuar.

**2. Filtros período incremental** (só com Incremental)
- *1. Definição do intervalo*: Data de referência (ex.: "Data de hoje", com lápis), Tipo de intervalo (ex.: "Dia"), Número de dias (ex.: 60).
- *2. Mapeamento dos parâmetros de filtros*: Referência data início (ex.: `dt_inicio`) + Formato (ex.: `MM/DD/YYYY`); Referência data fim (ex.: `dt_fim`) + Formato.
- Botões: Voltar, Continuar.

**3. Gerenciar Parâmetros**
- Método (GET/POST) e URL (ex.: `https://api.onb.sensedata.io/v2/custom_data`).
- Liga/desliga: **Query**, **Header**, **Caminho de resposta**.
- Seção "header parâmetros (1)": Chave | Valor, ⊕/⊖ (ex.: `Authorization` | `Bearer <token>`).
- Seção "Caminho da resposta": Caminho (ⓘ) (ex.: `$.custom_data`).
- Botões: Voltar, Continuar.

**4. Gerenciar paginação**
- Tipo de paginação: "Offset e Limit".
- Chave | Campos: "Posição inicial: Offset" → `page`; "Posição limite: Limit" → `per_page`.
- Caminho para as variáveis | Valor inicial: "Posição inicial: Offset" → `1`; "Posição limite: Limit" → `100`.
- Botões: Voltar, Continuar.

**5. Editar tipo de campo**
- Coluna no Arquivo | Tipo de Campo (ex.: `type`, `id_customer`, `data` → Texto), ⊕/⊖, "Carregar todos os campos".
- Botões: Voltar, Salvar.

### 3.5 Fonte de Dados Avançada
| Campo | Observação |
|---|---|
| Nome da fonte de dados customizada | livre (ex.: "Fonte Avançada") |
| Nome da conexão | lista |
| Nome Airflow | lista com o valor da constante `__NAME__` |

---

## 4. Transformações

### 4.1 Concatenação de Campos
- Nome da concatenação · Etapa anterior
- Bloco "Campos a concatenar 1" (recolhível): Campos (lista, ⊕/⊖), Tipo de separador (ex.: "Dois pontos (:)") + campo "Digite o separador", Nome do novo campo concatenado (ex.: `id_legacy`).
- Link "Adicionar campo concatenado" (grafado "Adcionar" na tela).

### 4.2 Deduplicação
- Nome da deduplicação · Etapa anterior
- Deduplicar em (lista, ⊕/⊖)
- Filtrar por | Tipo (automático, desabilitado) | Condição (ex.: "Mais recente"), ⊕/⊖

### 4.3 Filtro de Dados
- Nome do filtro (numa captura: "Nome da separação") · Etapa anterior
- Grupo A: Coluna no arquivo | Operação | Valor, ⊕/⊖ por linha
- Operações vistas: "Igual a", "Não é vazio" (esta desabilita o Valor: "Insira o valor")
- Link "Adicionar grupo" (grafado "Adcionar grupo")
- Botões: Cancelar, Salvar

### 4.4 Separação
- Blocos "Separação 1", "Separação 2"… (recolhíveis)
- Por bloco: Tipo de separação (ex.: "Json"), Campo origem (ex.: `data`), Atributo (ex.: `id_contratacao`), Nome do novo campo, Tipo do dado (lápis)
- Link "Remover separação"
- Botões: Cancelar, Salvar

### 4.5 Criar novo campo
- Nome da transformação (ex.: "Novo Campo: clientes-id") · Etapa anterior
- Nome do novo campo | É igual a (lápis) | Tipo do dado (lápis), ⊕/⊖

### 4.6 Adicionar ou Subtrair Registros (União ou interseção) — 4 passos
- Passo 1: Nome, Tipo de fusão (ex.: "Adição de linhas dos arquivos"), Fonte 1 | Campo chave fonte 1, Fonte 2 | Campo chave fonte 2.
- Passos seguintes: seleção dos campos das fontes; salvar.

### 4.7 Agregação, Condicional, Truncar
O manual descreve, sem captura:
- Agregação: chave + condição (Média; menor/maior data em campos de data).
- Condicional: Simples, Composta, Com cálculo.
- Truncar: operador Apagar ou Manter, com a quantidade de caracteres e o lado.

---

## 5. Carregamento (2 passos)

**Passo 1 — Carregamento de dados**
- Etapa anterior (ex.: "Deduplicação")
- *1. Definição de destino dos dados*: Tabela de destino (ex.: "Dados Customizados") | Tipo de integração (ex.: "Criação e Atualização")
- *2. Definição da chave com o cliente*: Chave cliente no Sensedata (ex.: CNPJ) | Chave cliente no arquivo (ex.: CNPJ)
- *3. Definição da chave da importação de dados*: Chave no arquivo (ex.: `id_legacy`, ⊕/⊖) · caixa "Não possui chave no arquivo"
- *4. Definição de Custom Data*: Nome do dado customizado (ex.: `mapa_de_calor`) | Data de referência (ex.: "Data do diagnóstico")
- *5. Limpeza de dados da tabela*: Tipo de limpeza (Completa/Parcial; desabilitado quando "Não limpar" está marcado) · caixa "Não limpar"
- Botões: Cancelar, Continuar

**Passo 2 — Mapeamento dos dados**
- Aviso: "As colunas no Sensedata devem ser escritas sem espaço ou com underline para separar as palavras. É aceito somente letras minúsculas e números. Exemplo: nome, data_de_nascimento, telefone_01."
- Colunas: Coluna no Arquivo | Coluna na Sensedata (placeholder "Insira o nome da coluna no Sensedata") | Tipo de Campo (desabilitado, herdado) | Opções (Ignorar/Sobrescrever)

---

## 6. Workflow
- Título com lápis (ex.: "Carga full ✎"); "Última execução: -"; "Proxima execução agendada: -".
- Bloco "Ordem execução": por linha, Integração N (lista) | Dependência de processamento (lista; a primeira é "Início", travada), ⊖ (e ⊕ na última), caixa "Em caso de quebras na carga parar a execução".
- Botões: Cancelar, Sincronizar, Executar agora (desabilitado até salvar/sincronizar), Salvar.

## 7. Agendador
- "← Voltar"
- *Informações do agendamento*: Nome | Tipo (ex.: "Carga") | Workflow | Status (ex.: "Ativo") · caixa "Executar a rotina de calc após a execução da carga"
- *Agendamento e recorrência*: Data de execução (calendário) | Executar (ex.: "Todos os dias") | Hora de execução (relógio)
- Botões: Cancelar, Salvar
