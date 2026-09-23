---
name: sense-connect
description: "Guia do SenseConnect, o ETL do SenseData (Zenvia): conexões, integrações (fontes, transformações, carregamento), workflow, agendador e o JSON de export/import das integrações. Cobre Google Sheets, S3, API (caminho de resposta, paginação, carga incremental), fonte SenseData, PostgreSQL/base espelho com SQL em Base64, Fonte Avançada em Python, chave do cliente e da importação, update vs upsert, limpeza, idempotência, guardrails e diagnóstico de cargas que duplicam, inativam ou apagam dados. Use quando o usuário pedir para criar ou revisar uma integração ou conexão, subir custom data, integrar API ou planilha, montar workflow ou agendamento, escrever a query SQL de uma integração, decodificar ou gerar o Base64 do JSON da integração, investigar carga que recriou contatos ou não trouxe linhas, ou planejar a virada de homologação para produção."
---

# SenseConnect — Integrações de Dados (guia completo)

## Overview
O SenseConnect é a ferramenta do SenseData para extrair (E), tratar (T) e carregar (L) dados de clientes sem precisar de um desenvolvedor dedicado, tanto no onboarding quanto em manutenções e ajustes do dia a dia. O objetivo é que os times de negócio e operação tragam para o SenseData dados comuns ou de baixa complexidade, liberando o time técnico. Ele não substitui o time técnico: casos específicos continuam exigindo rotina personalizada ou Fonte Avançada.

Esta skill junta duas fontes:
- **Manual SenseConnect** (oficial): telas, campos, regras e os casos Pipo, Tecnofit e Pet2Pet. Tudo o que vem dele aparece sem marcação.
- **Experiência de campo** (integrações reais exportadas, incidentes e correções): formato do JSON de export, fonte PostgreSQL com SQL em Base64, tipos `update` e `upsert`, chaves instáveis, inativação em massa, delta, guardrails. Esses pontos aparecem marcados como **(campo)**. São padrões observados, não documentação oficial: confirme no ambiente antes de afirmar como regra do produto.

## Como usar esta skill

### Triagem do pedido
| Pedido | Onde olhar |
|---|---|
| Criar ou revisar uma conexão | Seção 2 |
| Montar uma integração nova | Seções 3 a 6 e Examples |
| Integrar uma API (paginação, carga incremental, caminho de resposta) | Seção 4.4, Exemplos 2 e 3, `scripts/validar_caminho_resposta.py` |
| Trazer custom data pela API do SenseData | Exemplo 2 |
| Cruzar fontes ou replicar um dado para todos os clientes | Seção 5.9 e Exemplo 5 |
| Ler a própria base do SenseData com SQL (base espelho) | Seção 4.6, Exemplo 6, `references/sql-base-espelho.md` |
| Escolher tipo de integração, chave e limpeza | Seções 6 e 10, `references/persistencia-e-chaves.md` |
| Ler, corrigir ou gerar o JSON exportado de uma integração | Seção 11, Exemplo 8, `references/json-integracao.md`, `scripts/integracao_json.py` |
| Ordenar integrações e agendar | Seções 7 e 8 |
| Criar uma Fonte Avançada em Python | Seção 4.5 |
| Subir para produção ou operar | Seção 12, `references/checklist-go-live.md` |
| Algo deu errado (duplicou, inativou, não trouxe linhas, apagou) | Seção 13 e `references/incidentes-reais.md` |
| Saber exatamente o que aparece numa tela | `references/telas-do-manual.md` |

### O que levantar antes de desenhar uma integração
O manual destaca que a integração é a parte mais importante da ferramenta: exige conhecer os dados, as regras de negócio, o relacionamento entre os dados e a lógica de persistência. Antes de propor uma configuração, confirme os itens abaixo e pergunte só o que faltar:
1. **Origem**:
   - Google Sheets: link e aba.
   - S3: bucket ou pasta, arquivo, encoding e delimitador; se o nome do arquivo é fixo ou datado **(campo)**.
   - API: endpoint, método, headers, queries, paginação e formato da resposta.
   - SenseData: tipo de dado.
   - Base do próprio SenseData via SQL: tabelas e colunas envolvidas **(campo)**.
   - Plataforma não suportada: Fonte Avançada.
2. **Acesso**: qual conexão usar, uma pré-cadastrada da SenseData ou uma criada com as credenciais do cliente; e se é a conexão de **homologação ou de produção** **(campo)**.
3. **Destino**: tabela de destino e tipo de integração.
4. **Chaves**: o campo que liga cada linha ao cliente no SenseData (ex.: CNPJ, id_legacy) e a chave única do registro (chave da importação). A chave precisa ser **estável** entre execuções **(campo)**.
5. **Custom data**, se for o caso: nome do dado customizado e campo de data de referência.
6. **Persistência**: carga completa ou incremental (período e parâmetros de data), o tipo de limpeza e **o que deve acontecer com um registro que deixa de vir na origem** (manter, limpar, inativar) **(campo)**.
7. **Regras de negócio**: filtros, condições, deduplicação, junções.
8. **Campos manuais**: se algum campo de destino também é editado à mão no SenseData. Com "Sobrescrever", a carga apaga a edição na próxima execução **(campo)**.
9. **Dependências e agenda**: de quais integrações esta depende, frequência, horário, se o calc roda depois e se há regras do SenseData que leem o dado (a regra precisa rodar depois da carga).
10. **Volume esperado**: quantas linhas por execução. É o que permite montar guardrails e reconhecer uma carga anormal **(campo)**.

### Formato de resposta recomendado
Ao propor uma integração, entregue:
1. **Fluxo** numa linha: `Início → Fonte → Transformação(ões) → Carregamento → Fim`.
2. **Conexão**: qual usar ou quais campos preencher.
3. **Cada etapa** numa tabela `Campo | Valor`, usando os nomes de campo que aparecem na tela (veja `references/telas-do-manual.md`).
4. **Carregamento** completo: as 5 seções e o mapeamento.
5. **Workflow e agendamento**, quando fizer sentido.
6. **Persistência**: o que acontece com linha nova, linha alterada, linha igual e linha que sumiu da origem.
7. **Teste de aceite**: o que conferir depois da primeira execução e na segunda execução sem mudanças na origem.
8. **Pontos de atenção**: as validações da seção 9, os riscos das seções 10 e 13.
9. **Pendências**: só as informações que ainda faltam.

Quando o manual não especifica um valor (por exemplo, outras tabelas de destino além de Dados Customizados, outros tipos de integração ou outros tipos de paginação), não suponha: peça ao usuário para confirmar o que aparece na tela dele.

### Arquivos de apoio
| Arquivo | Quando abrir |
|---|---|
| `references/telas-do-manual.md` | Inventário tela a tela do manual: rótulos, passos do assistente, botões, avisos |
| `references/json-integracao.md` | Estrutura do JSON exportado: `connections`, `integrations`, `steps`, `steps_dependency`, `args` por tipo de etapa |
| `references/sql-base-espelho.md` | Modelo de dados observado (`public.customer`, `public.customer_contact`), leitura de `custom_fields`, queries de descoberta, qualidade e delta |
| `references/persistencia-e-chaves.md` | Chave do cliente, chave da importação, `update` × `upsert`, limpeza, órfãos, idempotência, inativação seletiva, guardrails |
| `references/incidentes-reais.md` | Casos reais anonimizados: contatos recriados a cada carga, Base64 quebrado, matriz duplicada, grafia divergente |
| `references/checklist-go-live.md` | Checklists de desenho, homologação, virada para produção e operação |
| `scripts/integracao_json.py` | `resumo`, `decode`, `build`, `validar` e `redigir` o JSON de uma integração |
| `scripts/validar_caminho_resposta.py` | Testa um caminho de resposta (`$.a.b[0]`) contra um JSON de exemplo |
| `scripts/normalizar_coluna.py` | Converte nomes de coluna para o padrão do SenseData (`a-z`, `0-9`, `_`) |

## Instructions

### 1. Estrutura e navegação
Acesso: **Configurações > SenseConnect**, no menu lateral. São 5 partes:
- **Conexão**: a configuração que as integrações usam para se autenticar e extrair dados das fontes.
- **Integração**: os processos que levam o dado de onde o cliente o disponibilizou até o SenseData. Cada etapa (caixa) faz parte de uma rotina de E[T]L.
- **Workflow**: a sequência de integrações necessárias para trazer os dados.
- **Agendador**: os horários em que um workflow roda. Também dá para agendar só a execução de um calc.
- **Logging**: registro das execuções. O manual não detalha esta parte.

**O editor de integração (canvas)**:
- À esquerda fica o painel **Adicionar elementos** (ⓘ), com um campo **Pesquisar** e dois grupos recolhíveis: **Fonte de Dados (N)** e **Transformações de Dados (N)**. Cada item tem uma alça (⠿) para arrastar ao canvas.
- No topo aparece o nome da integração com um lápis para renomear (ex.: `S3_Clientes ✎`).
- Toda integração nova começa com **Início** (círculo azul ▶) e **Fim** (círculo verde com bandeira).
- Cada caixa tem um conector de entrada à esquerda e um de saída à direita. A ligação entre duas caixas mostra um **×** no meio, que remove a ligação.
- Ao selecionar uma caixa aparecem o **lápis** (editar) e a **lixeira** (remover). Uma caixa ainda sem configuração mostra um **ícone de alerta laranja** (⚠).
- Uma fonte pode ter várias saídas (ramos), e várias caixas podem convergir numa mesma transformação (ex.: União).

### 2. Conexões
As conexões são usadas só dentro das integrações. Cada fonte de dados tem seu tipo de conexão.
1. Vá em **Configurações > SenseConnect > Conexões**. A listagem oferece Criar Conexão, Criar Pasta, Duplicar, Mover, Inativar, Apagar e o filtro "Mostrar somente conexões ativas".
2. Clique em **Criar Conexão**. A tela se chama **Configuração de conexão**.
3. Preencha **Nome da conexão*** (é assim que ela aparece na integração), escolha a **Origem*** e preencha os campos que aparecerem. Os campos com * são obrigatórios.
4. Salve e valide com **Testar**. Os botões da tela são **Cancelar**, **Testar** e **Atualizar** (ao editar uma conexão existente).

| Origem | Uso | Campos | Conexão pré-cadastrada |
|---|---|---|---|
| Google OAuth | Google Sheets | Client ID, Client Secret, Refresh Token | "Google Sheets - Sensedata", se o cliente deu acesso à chave do SenseData |
| Google Service Account | Google Sheets via service account, BigQuery | Client EMail, Token URI, Private Key (com as quebras de linha) | "Google Service Account - Sensedata", se o cliente deu acesso à service account do SenseData |
| AWS S3 | Storage da AWS | Region do bucket (us-west-1, sa-east-1 etc.), Access Key, Secret Access Key | "AWS S3", quando o bucket é fornecido pela SenseData |
| Zendesk | API do Zendesk | Prefixo do serviço do cliente (forma `https://{PREFIXO}.zendesk.com/`), Token (API Key) | — |
| PostgreSQL **(campo)** | Ler uma base Postgres, inclusive a base espelho do próprio SenseData | Não documentado no manual; confira na tela | Costuma existir uma por ambiente (ex.: uma de homologação e uma de produção) |

- Quando o cliente tem um data lake próprio num S3, ele informa Region, Access Key e Secret Access Key, e a conexão é criada com esses dados. Veja o Exemplo 4.
- **(campo)** Dê nomes que deixem o ambiente explícito (ex.: `POSTGRES_SENSEDATA_HOM`, `POSTGRES_SENSEDATA_PROD`). Subir para produção uma integração que ainda aponta para a conexão de homologação é o erro clássico de virada.
- **(campo)** O JSON exportado de uma integração leva o campo `connection_params` com a credencial da conexão (criptografada, mas ainda sensível). Trate o export como artefato com segredo: redija antes de versionar ou compartilhar (`scripts/integracao_json.py redigir`).

### 3. Integração — princípios
- Uma integração é o conjunto de etapas que extrai (E), trata (T) e carrega (L) o dado. Em alguns casos o tratamento é dispensável.
- Toda integração nova começa com **Início** e **Fim**. Fontes, transformações e carregamentos entram conforme a necessidade: você arrasta cada elemento do painel "Adicionar elementos" para o canvas.
- Cada etapa precisa estar ligada às outras para formar a sequência de execução e a integração ser válida. A saída de uma caixa (à direita) liga na entrada da próxima (à esquerda).
- **Fonte de dados**: obrigatória. Pode haver várias, de tipos diferentes, na mesma integração.
- **Transformações**: opcionais. É onde entram a sanitização, o tratamento e as regras de negócio.
- **Carregamento**: obrigatório e sempre o último passo. Define o tipo de dado inserido e como os dados serão mantidos (sem limpeza, limpeza parcial ou limpeza total).
- **Uma integração por informação**, mesmo que isso repita a extração de uma fonte. A complexidade fica menor e a integração pode ser reaproveitada em mais de um workflow.
- Defina a lógica de persistência: carga completa diária, carga incremental, carga incremental por data etc. A seção 10 detalha as consequências de cada escolha.

### 4. Fontes de dados
O painel "Fonte de Dados" lista, numa versão recente do manual, 13 fontes: Google Analytics, Google BigQuery, Google Sheets, Hubspot, S3 Amazon, Omie, Outras APIs, Pipedrive, PostgreSQL, Salesforce, Sensedata, SQL Server e Zendesk. Numa captura mais antiga aparecem 10. A lista varia por versão e ambiente. O manual detalha as fontes abaixo.

Toda fonte abre o assistente **Editar Fonte de Dados**, com os campos **Nome**, **Tipo de carga**, **Origem** (fixa, preenchida pelo tipo da caixa) e **Nome da conexão** (ou **Tipo de dado**, na fonte SenseData). Nas fontes de arquivo (Sheets, S3) o assistente tem 2 passos; em Outras APIs, até 5.

#### 4.1 Google Sheets
1. **Nome** (ex.: "Google Sheets: sortimento prioritário"). **Tipo de carga**: Completo (o campo vem travado).
2. **Nome da conexão**: "Google Sheets - Sensedata" (OAuth), "Google Service Account - Sensedata" ou a conexão do próprio cliente.
3. **Link do Sheets**: cole a URL da planilha.
4. Clique em **Processar**. Sem isso, o campo **Aba do Sheets** fica desabilitado, e a tela avisa: "Antes de selecionar a aba da planilha é necessário processar o arquivo, clicando no botão 'Processar' abaixo." O botão **Continuar** também fica desabilitado até o processamento.
5. Selecione a aba e clique em **Continuar**.
6. **Editar tipo de campo** (passo 2): para cada **Coluna no Arquivo**, escolha o **Tipo de Campo** (Texto, Data, Número…; o lápis abre as opções do tipo). "Carregar todos os campos" (ⓘ) traz todas as colunas de uma vez; ⊕/⊖ adicionam ou removem linhas.
7. Clique em **Salvar**.

#### 4.2 Amazon S3
1. **Nome** (ex.: "Amazon S3"). **Tipo de carga**: Completo.
2. **Nome da conexão**: "AWS S3" (bucket da SenseData) ou a conexão criada com as credenciais do cliente. Uma conexão recém-criada já aparece nessa lista.
3. **URL**: o nome da pasta ou bucket a acessar (ex.: `tecnofit-ds-sensedata`).
4. **Encoding**: a codificação esperada dos arquivos (ex.: UTF-8).
5. **Delimitador**: vírgula, ponto e vírgula, pipe ou espaço.
6. Clique em **Processar** para listar os arquivos a que você tem acesso. A tela avisa: "Antes de selecionar o arquivo é necessário processar a URL, clicando no botão 'Processar' abaixo."
7. Em **Arquivo**, escolha o arquivo (ex.: `clientes.csv`), clique em **Continuar**, defina os tipos de campo e clique em **Salvar**.
- **(campo)** O bucket fornecido pela SenseData costuma receber arquivos num prefixo de upload (ex.: `sc_upload/<arquivo>.csv`).
- **(campo)** A fonte lê o arquivo que estiver lá na hora da execução. Com **nome fixo** (`contatos.csv`), a integração não distingue arquivo novo de arquivo antigo, parcial ou vazio. Veja a seção 10.6.

#### 4.3 SenseData
1. **Nome** (ex.: "Sensedata: clientes"). **Tipo de carga**: Completo. **Origem**: Sensedata.
2. **Tipo de dado**: ex.: "Cliente".
3. **Editar tipo de campo**: escolha os campos (ex.: só `id_legacy`, como Texto).

#### 4.4 Outras APIs (Fonte Genérica)
Serve para acessar APIs REST (HTTP) externas, de forma parecida com o Postman ou o Insomnia. Você define URL, parâmetros e cabeçalhos, além do período (para carga incremental) e da paginação (para trazer todas as linhas). As informações de conexão vêm da documentação de cada API.

Para criar: arraste **Outras APIs** para o canvas, ligue o **Início** à esquerda da fonte e clique em editar (lápis). O assistente tem até 5 passos (1 — Editar Fonte de Dados, 2 — Filtros período incremental, 3 — Gerenciar Parâmetros, 4 — Gerenciar paginação, 5 — Editar tipo de campo). Os botões são **Cancelar/Continuar** no passo 1, **Voltar/Continuar** nos intermediários e **Voltar/Salvar** no último.

**Passo 1 — Editar Fonte de Dados**
- **Nome**: algo fácil de identificar depois (ex.: "Extração de API", "API Sensedata").
- **Tipo de carga**: Completo ou Incremental.
- **Origem**: Outras APIs (campo fixo).
- **Nome da conexão**: selecione uma, se houver.
- Clique em **Continuar**.

**Passo 2 — Filtros período incremental** (só aparece na carga Incremental)
- **1. Definição do intervalo**:
  - **Data de referência**: dinâmica, como "Data de hoje", ou uma data fixa (o lápis edita).
  - **Tipo de intervalo**: ex.: Dia.
  - **Número de dias** (a quantidade): ex.: 60.
- **2. Mapeamento dos parâmetros de filtros**:
  - **Referência data início**: o nome do parâmetro que a API espera (ex.: `dt_inicio`), com o **Formato** da data (ex.: `MM/DD/YYYY`).
  - **Referência data fim**: ex.: `dt_fim`, também com o **Formato**.
- Clique em **Continuar**.

**Passo 3 — Gerenciar Parâmetros**
- **Método**: GET ou POST.
- **URL**: https + domínio + caminho do endpoint (ex.: `https://api.onb.sensedata.io/v2/custom_data`).
- Três botões de liga/desliga, cada um abrindo uma seção recolhível:
  - **Query**: parâmetros de consulta.
  - **Header**: "header parâmetros (N)", em pares **Chave**/**Valor** com ⊕/⊖ (ex.: `Authorization` = `Bearer <token>`).
  - **Caminho de resposta**: "Caminho da resposta", campo **Caminho** (ⓘ).
- **Caminho de resposta** é o tratamento aplicado ao retorno da API para extrair os dados. Olhando o retorno (no Postman, por exemplo), o valor recuperado precisa ser uma **lista** (entre `[ ]`) de **objetos chave/valor** (entre `{ }`). As regras são:
  - sempre começa com `$`;
  - `.nome_da_chave` pega uma informação de dentro de um objeto (ex.: `$.resultado`);
  - `[posição]` pega um item de uma lista, começando em 0 (ex.: `[0]`).
- Clique em **Continuar**. Se tudo estiver correto, você vai para a paginação.

**Passo 4 — Gerenciar paginação**
Aqui você informa quantos registros são consultados em cada requisição.
- **Tipo de paginação**: ex.: "Offset e Limit".
- Bloco **Chave | Campos** (o nome do parâmetro na API):
  - Posição inicial: Offset → ex.: `page`.
  - Posição limite: Limit → ex.: `per_page`.
- Bloco **Caminho para as variáveis | Valor inicial**:
  - Posição inicial: Offset → `1`.
  - Posição limite: Limit → `100`.
- Detalhe: no exemplo da API do SenseData, mesmo com o tipo "Offset e Limit", as chaves usadas são `page` e `per_page`, ou seja, a paginação é por página e o valor inicial 1 é a primeira página.

**Passo 5 — Editar tipo de campo**
- Escolha as colunas que serão usadas e o tipo de cada uma (ex.: `type`, `id_customer` e `data`, todas como Texto).
- "Carregar todos os campos" traz todas as colunas.
- Clique em **Salvar**.

#### 4.5 Fonte Avançada
Serve para plataformas que a estrutura do SenseConnect não suporta. São rotinas em Python que aparecem no produto como uma fonte nova, e **precisam ser criadas pelo time de desenvolvimento**.
1. Crie um arquivo Python numa pasta com o nome do **tenant** do cliente, no repositório **sc_bin2**, no caminho `tasks/senseconnect/custom_data_sources/<tenant>/`.
2. O arquivo precisa definir duas constantes:
   - `__NAME__`: o nome da fonte que aparece no produto, no campo "Nome Airflow".
   - `__CLASSNAME__`: o nome da classe que representa a fonte.
3. Essa classe precisa estender `CustomDataSource`, do módulo `tasks.senseconnect.custom_data_sources.custom_data_source`, e sobrescrever dois métodos:
   - `apply`: todo o procedimento de busca na plataforma de origem. O retorno precisa ser um **gerador** que emite os registros linha a linha, cada um como **dicionário**.
   - `get_output_schema`: retorna um dicionário com a chave `"fields"`. O valor dela é outro dicionário, com um item por campo disponibilizado, cada um com seu tipo (e o formato, no caso de datas).
4. Para a fonte aparecer no produto, faça o **merge** no `sc_bin2`, na branch do ambiente em que ela deve ser implementada.
5. No SenseConnect, a tela "Fonte de Dados Avançada" pede três campos: **Nome da fonte de dados customizada**, **Nome da conexão** e **Nome Airflow** (uma lista onde aparece o valor de `__NAME__`).

Esqueleto de referência. O manual não documenta o construtor de `CustomDataSource` nem como as credenciais chegam à classe, então confirme isso no `sc_bin2`:
```python
from tasks.senseconnect.custom_data_sources.custom_data_source import CustomDataSource

__NAME__ = "Minha Fonte Avançada"      # aparece no produto (Nome Airflow)
__CLASSNAME__ = "MinhaFonteAvancada"   # nome da classe abaixo


class MinhaFonteAvancada(CustomDataSource):

    def apply(self):
        # Buscar os dados na plataforma de origem e emitir um dicionário por linha,
        # com as mesmas chaves declaradas em get_output_schema.
        registros = []  # TODO: implementar a busca
        for r in registros:
            yield {"campo1": r.get("campo1"), "campo2": r.get("campo2")}

    def get_output_schema(self):
        return {
            "fields": {
                "campo1": {"type": "text"},
                "campo2": {"type": "date", "format": "%Y-%m-%d"},
            }
        }
```

#### 4.6 PostgreSQL e a base espelho do SenseData (campo)
O manual não documenta esta fonte, mas ela aparece no painel e em integrações reais. O caso de uso mais comum é ler a **própria base do SenseData** (a base espelho do tenant) com SQL para derivar um dado e gravá-lo de volta, por exemplo propagar um campo de uma conta para outras (Exemplo 6).
- No JSON exportado, a etapa é `item_type: "data_source"` com `integration_params.source: "postgres"`, `connection_id` e `query`. **A query fica em Base64.** Veja a seção 11.
- O resultado da query vira as colunas da fonte (o `output_schema`). O nome de cada coluna é o **alias** do `SELECT` final, então dê aliases explícitos (`AS customer_id_legacy`).
- `load_type` observado: `total` (a query roda inteira a cada execução).
- Tabelas observadas: `public.customer` (clientes) e `public.customer_contact` (contatos). Campos customizados ficam em `custom_fields` (jsonb), com o valor em `->'<nome_interno>'->>'value'`. Detalhes, armadilhas e queries prontas em `references/sql-base-espelho.md`.
- Boas práticas:
  - devolva a chave de carga (ex.: `customer_id_legacy`) e filtre nulos e vazios dela;
  - normalize textos usados como chave de junção com `upper(btrim(...))`;
  - garanta uma linha por chave (`DISTINCT ON` com desempate determinístico);
  - devolva só o que mudou (filtro de delta com `IS DISTINCT FROM`, seção 10.4);
  - valide a sintaxe antes de colar e **nunca monte o Base64 à mão** (`scripts/integracao_json.py build`).

### 5. Transformações
São opcionais. Se o dado já vem da fonte do jeito que deve ser integrado, vá direto ao Carregamento. Toda transformação tem um **nome** e uma **etapa anterior** (a caixa ligada à esquerda dela, preenchida automaticamente). O manual documenta 9 transformações; o painel de uma versão recente mostra "Transformações de Dados (10)", então pode haver uma a mais no seu ambiente.

#### 5.1 Agregação
Junta vários registros em um só, por meio de uma chave e uma condição. No painel aparece como "Agregação de Dados".
- Exemplo: um cliente tem vários registros de NPS e você precisa da média. Agregue por `id_legacy` com a condição "Média".
- A condição disponível muda conforme o tipo do dado. Em campos de data, dá para escolher a menor ou a maior data.

#### 5.2 Concatenação
Cria uma coluna nova juntando duas ou mais colunas. A tela se chama **Concatenação de Campos**.
- Campos da tela:
  - **Nome da concatenação** e **Etapa anterior**.
  - Bloco recolhível **"Campos a concatenar 1"**, com a lista **Campos** (⊕/⊖ por linha).
  - **Tipo de separador**: ex.: "Dois pontos (:)". Ao lado há o campo "Digite o separador", para um separador personalizado.
  - **Nome do novo campo concatenado**.
- "Adicionar campo concatenado" cria outro bloco ("Campos a concatenar 2") na mesma etapa.
- Exemplos:
  - id do cliente = tipo de produto + número da base.
  - Caso real: `Data do diagnóstico` + `Farol Cliente` + `CNPJ`, com `:`, gerando `id_legacy`.

#### 5.3 Criar novo campo
Cria um campo e atribui a ele um valor: o de outro campo da etapa anterior ou um valor personalizado. A tela se chama **Criar novo campo**.
- Campos: **Nome da transformação**, **Etapa anterior**, **Nome do novo campo**, **É igual a** (o valor; o lápis alterna entre valor fixo e campo) e **Tipo do dado**. ⊕/⊖ adicionam mais campos na mesma etapa.
- Uso típico: uma chave auxiliar falsa (`aux` = `1`, Texto) para cruzar duas fontes. Veja o Exemplo 5.
- **(campo)** Cuidado ao usar esta transformação para gravar um valor constante numa coluna de status (ex.: `is_active = False` em todas as linhas). Veja a seção 10.5.

#### 5.4 Condicional
Tem três tipos:
- **Simples**: compara um campo com um valor e atualiza o próprio campo. Ex.: se `status` = 1, atribuir "ativo".
- **Composta**: faz a comparação e atualiza **outro** campo. Ex.: se o MRR for menor ou igual a 0, atualizar `status` para "Inativo".
- **Com cálculo**: atualiza o próprio campo da condição com um cálculo. Ex.: se `status` = "Ativo", o novo valor é o status + "Grupo".

#### 5.5 Deduplicação
Remove entradas duplicadas com base numa chave e numa condição.
- Campos da tela:
  - **Nome da deduplicação** e **Etapa anterior**.
  - **Deduplicar em**: a chave, com ⊕/⊖ (a chave pode ser composta).
  - **Filtrar por**: o campo de desempate.
  - **Tipo**: preenchido automaticamente de acordo com o tipo do campo (desabilitado).
  - **Condição**: ex.: "Mais recente". ⊕/⊖ adicionam critérios de desempate.
- Exemplo: registros com o mesmo `id_legacy` → manter o de data de registro mais recente.

#### 5.6 Filtro de dados
Define quais valores serão integrados.
- A tela tem **Nome do filtro** (numa captura o rótulo aparece como "Nome da separação"), **Etapa anterior** e grupos de condições ("Grupo A" e "Adicionar grupo"). Cada linha tem **Coluna no arquivo**, **Operação** e **Valor**, com ⊕/⊖. Condições e grupos são combinados com **E** e **OU**, como nas regras do SenseData.
- Operações que aparecem no manual: "Igual a" e "Não é vazio". Com "Não é vazio", o campo Valor fica desabilitado ("Insira o valor").
- Exemplos:
  - Só contratos cujo `modelo` seja MRR.
  - `type` Igual a `contratacoes`.
  - Campos obrigatórios com "Não é vazio" ("Filtro de Dados - Campos Obrigatorios").

#### 5.7 Separação
É o inverso da concatenação.
- **Por separador**: transforma um campo em dois ou mais. Ex.: Rua, Número e Bairro que vêm num só campo, separados por vírgula.
- **Json**: extrai um atributo de um campo JSON.
  - Cada bloco ("Separação 1", "Separação 2"…) tem **Tipo de separação** "Json", **Campo origem** (ex.: `data`), **Atributo** a extrair, **Nome do novo campo** e **Tipo do dado**.
  - É preciso uma separação por atributo. "Remover separação" apaga uma delas.
- **(campo)** Em integrações reais, uma etapa de Separação também é usada para tirar um atributo de dentro de `custom_fields` da fonte SenseData (ex.: `$.produto.value`).

#### 5.8 Truncar
Corta caracteres de um texto.
- Operador **Apagar** (ex.: apagar 5 dígitos à direita) ou **Manter** (ex.: manter 4 dígitos à esquerda).
- Uso: limitar o tamanho de strings, porque alguns campos do banco do SD têm quantidade máxima de caracteres.

#### 5.9 União ou interseção
Une ou intersecta duas ou mais fontes numa só, por meio de uma **chave única presente nas duas fontes**.
- A tela se chama **"Adicionar ou Subtrair Registros"** e tem 4 passos:
  - **Nome** e **Tipo de fusão**.
  - **Fonte 1** e **Campo chave fonte 1**; **Fonte 2** e **Campo chave fonte 2**.
  - Depois, selecione os campos das duas fontes e salve.
- Estratégias:
  - **Adição** ("Adição de linhas dos arquivos"): todas as linhas entram.
  - **Subtração**: segundo o manual, só entram as linhas que estão nas duas fontes.
- Exemplo: unir dados vindos de uma API com dados alimentados via Google Sheets.

### 6. Carregamento
É o último passo e é obrigatório. O assistente tem 2 passos: **Carregamento de dados** e **Mapeamento dos dados**. A Etapa anterior é a última transformação (ou a própria fonte).
1. **Definição de destino dos dados**:
   - **Tabela de destino**: ex.: Dados Customizados.
   - **Tipo de integração**: ex.: "Criação e Atualização". Se o dado não existe, é criado; se existe, é atualizado.
2. **Definição da chave com o cliente**: **Chave cliente no SenseData** e **Chave cliente no arquivo** (ex.: CNPJ ↔ CNPJ). É o que associa cada linha ao cliente no Sense.
3. **Definição da chave da importação de dados**: **Chave no arquivo**, a chave única do registro na tabela de destino (ex.: o `id_legacy` criado na concatenação), com ⊕/⊖ para chave composta. Se não houver, marque "Não possui chave no arquivo".
4. **Definição de Custom Data** (quando o destino é custom data): **Nome do dado customizado** (ex.: `mapa_de_calor`) e **Data de referência** (ex.: "Data do diagnóstico").
5. **Limpeza de dados da tabela**:
   - **Completa**: apaga a tabela inteira a cada execução.
   - **Parcial**: apaga um período definido, usando um campo de data como referência.
   - **Não limpar**: marque essa caixa para manter tudo (o seletor de tipo fica desabilitado).
6. Clique em **Continuar** para chegar ao **Mapeamento dos dados**. Cada linha tem **Coluna no arquivo**, **Coluna na Sensedata**, **Tipo de campo** e **Opções** (**Ignorar** ou **Sobrescrever**).
   - A tela avisa: "As colunas no Sensedata devem ser escritas sem espaço ou com underline para separar as palavras. É aceito somente letras minúsculas e números. Exemplo: nome, data_de_nascimento, telefone_01."
   - Nos casos do manual, campos usados só como chave (ex.: CNPJ, id_legacy) ficam como **Ignorar**, com a "Coluna na Sensedata" vazia.

#### 6.1 Tipos de integração e tabelas de destino (campo)
O manual só mostra "Criação e Atualização" e "Dados Customizados". Em exports reais aparecem:

| No JSON (`args`) | Comportamento observado | Risco principal |
|---|---|---|
| `integ_type: "update"` | Só atualiza registros que já existem, localizados pela chave. **Linha que não vem no resultado não é tocada.** | Dado órfão nunca é limpo (seção 10.3) |
| `integ_type: "upsert"` | Atualiza se a chave casar, cria se não casar. Provavelmente é o "Criação e Atualização" da tela; confirme. | Chave que muda de formato cria duplicados (seção 10.2) |
| `destiny_table: "customer"` | Tabela de clientes; o registro é localizado pela chave (`keys`) | — |
| `destiny_table: "customer_contact"` | Tabela de contatos | Chave instável recria a base de contatos |

Nomes exatos das opções na tela para `update`/`upsert` e outras tabelas de destino (contratos, financeiro, NPS etc.): confirme com o usuário.

#### 6.2 Ignorar × Sobrescrever (campo)
- **Sobrescrever** grava o valor da coluna no destino **inclusive quando ele é vazio ou nulo**. Uma fonte que devolve `NULL` apaga o que estava no SenseData.
- **Ignorar** não grava a coluna. Use para chaves e colunas de conferência.
- Um campo que o time também edita à mão, mapeado como Sobrescrever, é revertido pela próxima carga. Combine com o cliente quem é a fonte da verdade.

### 7. Workflow
É a sequência de integrações necessárias para o ambiente ter todos os dados, exibi-los e calcular as métricas do SenseData. Além de escolher as integrações, é preciso definir quais dependem de quais, porque alguns dados só podem ser integrados depois que outros já estão no SenseData.
1. Crie o workflow e dê um nome a ele (ex.: "Carga full"; o lápis renomeia). A tela mostra "Última execução" e "Próxima execução agendada".
2. Em **Ordem execução**, adicione cada integração (Integração 1, 2, …, com ⊕/⊖) e a **Dependência de processamento** dela. A primeira depende de "Início"; as outras dependem da integração cujos dados precisam já estar no SenseData.
3. Para cada integração, decida se marca **"Em caso de quebras na carga parar a execução"**.
4. Clique em **Salvar** e depois em **Sincronizar**. A tela também tem **Executar agora** (habilitado depois de salvo e sincronizado) e **Cancelar**.

Exemplo ("Carga full", com todas as integrações marcando "parar a execução"):
| # | Integração | Dependência de processamento |
|---|---|---|
| 1 | S3_Clientes | Início |
| 2 | S3_Contratos | S3_Clientes |
| 3 | S3_Contatos | S3_Clientes |
| 4 | S3_Financeiro | S3_Clientes |
| 5 | Gsheets_NPS | S3_Clientes |
| 6 | SenseData_Contatos | S3_Contatos |

**(campo)** Duas integrações encadeadas em que a primeira desfaz algo e a segunda refaz (ex.: "inativar tudo" e depois "reativar quem veio no arquivo") são frágeis: se a segunda falhar ou não casar, o estrago da primeira fica. Prefira uma integração só, com inativação seletiva (seção 10.5).

### 8. Agendador
1. O workflow só pode ser escolhido aqui depois de **salvo e sincronizado**.
2. **Informações do agendamento**:
   - Nome.
   - Tipo (ex.: Carga).
   - Workflow.
   - Status (ex.: Ativo).
   - A caixa **"Executar a rotina de calc após a execução da carga"**.
3. **Agendamento e recorrência**:
   - Data de execução.
   - Executar (ex.: Todos os dias; também semanal ou mensal).
   - Hora de execução.
4. Clique em **Salvar**. Não há limite de agendamentos: um workflow pode ter vários, em horários diferentes. Também é possível agendar só a execução de um calc.

Exemplo:
| Campo | Valor |
|---|---|
| Nome | Carga full + Calc_03h |
| Tipo | Carga |
| Workflow | Carga full |
| Status | Ativo |
| Calc após a carga | Marcado |
| Data de execução | 06/05/2022 |
| Executar | Todos os dias |
| Hora | 03:00 |

**(campo)** Ordem no dia:
- Carga (e calc) primeiro; regras do SenseData que leem o dado integrado, depois. Uma regra que roda antes da carga lê o valor do dia anterior.
- Rotinas externas que gravam campos no SenseData (via API) também precisam terminar antes das regras que leem esses campos.
- Deixe folga entre a carga e as regras, para uma nova tentativa caber.
- "Tempo real" não existe por esse caminho: a integração é batch. Se o cliente pede propagação imediata, alinhe a frequência (ex.: a cada 30–60 min, mais "Executar agora" quando necessário) e registre a necessidade como pedido de produto.

### 9. Validações antes de salvar

**Caminho de resposta (Outras APIs)** — use uma resposta de exemplo da API:
1. O caminho começa com `$`?
2. Percorra a resposta:
   - cada `.chave` precisa existir no objeto em que você está;
   - cada `[n]` precisa cair numa lista com pelo menos n+1 itens.
3. O ponto final precisa ser uma **lista** de **objetos**. Se cair num objeto único, num texto ou numa lista de valores soltos, as linhas não serão extraídas.
4. Liste as chaves dos objetos encontrados. Elas serão as colunas disponíveis em "Editar tipo de campo".
- Exemplo: para a resposta `{"custom_data": [{"type": "...", "id_customer": "...", "data": {...}}]}`, o caminho é `$.custom_data`.
- Se o usuário colar um JSON, rode `scripts/validar_caminho_resposta.py resposta.json '$.custom_data'`. Sem o caminho, o script sugere os caminhos válidos.

**Nomes de coluna no mapeamento**:
- Só são válidos com `a-z`, `0-9` e `_`.
- Para converter: tudo em minúsculas, sem acento, e espaços e símbolos viram `_`. Use `scripts/normalizar_coluna.py`.
- Exemplos do manual:
  - "Data do diagnóstico" → `data_do_diagnostico`
  - "Farol Cliente sem %" → `farol_cliente_sem`
  - "Mapa de Calor" → `mapa_de_calor`

**Checklist geral da integração**:
- Todas as caixas estão ligadas, do Início ao Fim, e nenhuma mostra o ícone de alerta.
- Há pelo menos uma fonte e um carregamento.
- A chave do cliente e a chave da importação estão definidas (ou "Não possui chave no arquivo" está marcado).
- A chave é estável: não depende de campo que muda entre execuções **(campo)**.
- O tipo de limpeza combina com a lógica de persistência.
- Quando fizer sentido, os campos obrigatórios do layout estão protegidos por um Filtro de dados com "Não é vazio".
- Nenhuma coluna mapeada como Sobrescrever pode chegar vazia sem querer **(campo)**.
- A conexão é a do ambiente certo (homologação × produção) **(campo)**.
- No JSON, `scripts/integracao_json.py validar` não aponta erro **(campo)**.

### 10. Persistência, chaves e idempotência (campo)
Resumo; o detalhe, com queries e exemplos, está em `references/persistencia-e-chaves.md`.

**10.1 Teste de idempotência.** Execute a integração duas vezes seguidas sem mudar a origem. A segunda execução deve processar **0 inserções, 0 desativações** e, se houver filtro de delta, **0 linhas**. É o teste de aceite mais barato e o que pega a maioria dos defeitos abaixo.

**10.2 A chave precisa ser estável.** A chave da importação (em tabelas nativas, gravada em `id_legacy`) é recalculada a cada carga e comparada com a gravada. Se a composição mudar (outro campo, outra ordem, outro separador, um campo volátil incluído), nenhum registro casa: o `upsert` cria tudo de novo e os registros antigos ficam órfãos, com o que foi preenchido à mão. Regras:
- nunca inclua na chave um campo que muda (produto, status, datas de atualização);
- uma chave precisa distinguir os registros (a chave de um contato não pode ser só o código da conta, senão só um contato por conta sobrevive);
- alterar a composição da chave exige, **antes** da próxima carga, uma migração que reescreva a chave dos registros existentes.

**10.3 Linha que some da origem.** Com `update`, a linha que deixa de vir no resultado não é tocada: o valor antigo fica congelado para sempre (loja que saiu do grupo, contato que saiu da empresa). Decida explicitamente: manter, limpar (emitir valor vazio para quem deixou de ser elegível) ou inativar (seção 10.5).

**10.4 Delta.** Em cargas `total`, devolva só o que mudou. Isso evita poluir o histórico do cliente, evita disparar regras que olham "data de atualização" e reduz a carga. Numa fonte SQL: compare o valor novo com o atual (`WHERE valor_atual IS DISTINCT FROM valor_novo`).

**10.5 Inativação seletiva, nunca em massa.** Um desenho comum e perigoso é "marcar todos como inativos e depois reativar quem veio no arquivo". Se o arquivo vier parcial, vazio ou antigo, ou se a chave não casar, a base inteira fica inativa ou é recriada. Faça anti-join: inative **só** quem existe no SenseData e não veio no arquivo, na mesma integração que atualiza os que vieram.

**10.6 Guardrails de volume.** Aborte e alerte, antes de gravar, quando:
- o número de linhas da origem variar mais de ~20% em relação à última execução;
- a execução for desativar mais de ~10% da base, ou inserir mais de ~10%;
- a taxa de match com os registros existentes ficar abaixo de ~90%.
Para arquivos: prefira nome com data (`contatos_AAAAMMDD.csv`) e só processe se o arquivo for mais novo que a última execução bem-sucedida. Ligue o versionamento do bucket para ter histórico. O SenseConnect pode não ter esses controles nativamente; quando não tiver, eles ficam na origem (quem gera o arquivo) ou numa etapa anterior. Registre por execução: lidas, casadas, inseridas, atualizadas, desativadas.

**10.7 Valor vazio apaga.** Com Sobrescrever, `NULL` ou `''` vindos da fonte apagam o destino. Se "vazio na origem" não significa "apagar", filtre essas linhas ou não as emita.

### 11. O JSON da integração (export/import) (campo)
Uma integração pode ser exportada e importada como JSON. A estrutura observada:
```
{
  "connections":  { "<id>": { "name", "source", "connection_params", "is_active", ... } },
  "integrations": { "<id>": { "name", "status", "folder_id", ... } },
  "steps":        { "<id>": { "item_type", "name", "args", "output_schema", "position", "integration_id", ... } },
  "steps_dependency": [ { "item_id": <origem>, "dependency_id": <destino>, "direction": {...} } ]
}
```
- `item_type` observados: `start`, `end`, `data_source`, `filter`, `create_column`, `load_data`. As outras transformações têm tipos próprios; leia no export.
- Em `steps_dependency`, cada item liga a saída de `item_id` à entrada de `dependency_id` (`from_direction: right` → `to_direction: left`).
- `data_source` com SQL: `args.integration_params = {connection_id, query (Base64), source: "postgres"}` e `args.load_type` (`total`).
- `output_schema.fields` de uma fonte: por coluna, `type` e flags de tratamento (`remove_dots_and_dash`, `remove_special_char`, `remove_whitespaces`, `remove_zero_left`, `treatment: "keep_original"`). Provavelmente correspondem às opções do lápis em "Tipo de Campo"; úteis para normalizar CNPJ e códigos com zero à esquerda.
- `load_data`: `args = {destiny_table, integ_type, keys: [...], customer_key: {...}}` e `output_schema.fields.<coluna> = {field_destiny, options: "overwrite" | "ignore", type}`.
- Use `scripts/integracao_json.py`:
  - `resumo arquivo.json`: etapas, ligações, chaves e mapeamento;
  - `decode arquivo.json`: mostra o SQL de cada fonte;
  - `build --base arquivo.json --sql nova.sql --step <id> --out novo.json`: grava o SQL em Base64 com round-trip e atualiza o schema;
  - `validar arquivo.json`: grafo do Início ao Fim, chave de carga presente na fonte, colunas gravadas, credenciais expostas;
  - `redigir arquivo.json --out seguro.json`: remove `connection_params`.
Referência completa: `references/json-integracao.md`.

### 12. Homologação → produção e operação (campo)
1. Descubra a modelagem real antes de escrever a query (nome e tipo da coluna de status, nome interno dos campos, integridade da chave). `references/sql-base-espelho.md` tem as queries.
2. Meça antes: rode um dry-run (a própria query, sem carregar) e guarde quantas linhas cada versão tocaria.
3. Publique em homologação e execute o roteiro de aceite: primeira execução com o número esperado de linhas; segunda execução sem mudança com 0; edição na origem propagando; registro que deixou de ser elegível tratado como combinado.
4. Na virada: troque a conexão para a de produção, confira o agendamento e a ordem com as regras, e confira se o JSON importado não trouxe credencial de outro ambiente.
5. Monitore a contagem de linhas por execução. "0 linhas por vários dias" pode ser "nada mudou" ou "quebrou"; tenha um jeito de distinguir.
6. Rode mensalmente as queries de qualidade (chave duplicada, grafia divergente, órfãos).
Checklists completos em `references/checklist-go-live.md`.

### 13. Diagnóstico de problemas comuns
| Sintoma | Causa provável | O que fazer |
|---|---|---|
| A aba do Sheets ou o arquivo do S3 não aparece | Faltou processar | Clique em **Processar** antes de escolher |
| A API responde, mas nenhuma linha chega | O caminho de resposta não aponta para uma lista de objetos | Refaça o caminho (seção 9) |
| Só parte dos registros da API chega | Paginação não configurada | Configure o Passo 4 |
| O custom data da API chega com tudo dentro de `data` | É o comportamento da API do SenseData (exceto `id_legacy`, `id_customer` e `ref_date`) | Uma Separação **Json** por atributo |
| Custom data de várias tabelas vem misturado | Falta filtrar | **Filtro de dados** por `type` |
| Coluna rejeitada no mapeamento | Nome fora do padrão | Use só minúsculas, números e `_` |
| Registros duplicados | Mais de uma linha com a mesma chave | **Deduplicação** com uma condição de desempate |
| Linhas sem um campo obrigatório estão subindo | Falta validação | **Filtro de dados** com "Não é vazio" |
| Texto maior que o campo de destino | Limite de caracteres do SD | **Truncar** |
| Dados antigos são apagados a cada carga | Limpeza **Completa** | Use Parcial ou Não limpar, se não era essa a intenção |
| Uma integração roda antes do dado de que depende | Dependência errada no workflow | Ajuste a **Dependência de processamento** |
| A carga quebrou e o workflow continuou | Caixa desmarcada | Marque "Em caso de quebras na carga parar a execução" |
| O workflow não aparece no agendador | Não foi salvo e sincronizado | Clique em **Salvar** e **Sincronizar** no workflow |
| O calc não rodou depois da carga | Opção desmarcada | Marque "Executar a rotina de calc após a execução da carga" |
| A conexão falha no **Testar** | Credencial ou campo incorreto | Revise a Region (S3), o prefixo (Zendesk) e a Private Key com as quebras de linha (Service Account) |
| A Fonte Avançada não aparece no produto | Falta o merge na branch do ambiente, ou faltam `__NAME__`/`__CLASSNAME__` | Revise o arquivo no `sc_bin2` e faça o merge |
| **(campo)** A cada carga, a base de contatos é recriada e os campos manuais "somem" | Chave da importação instável; os dados estão nos registros antigos, agora inativos | Pausar a carga; estabilizar a chave; migrar as chaves antigas; migrar os campos (seção 10.2 e `references/incidentes-reais.md`) |
| **(campo)** Só um contato por conta sobrevive | A chave não distingue as pessoas (ex.: é só o código da conta) | Chave por pessoa + conta |
| **(campo)** Base inteira ficou inativa depois de uma carga | Inativação em massa + arquivo parcial, vazio, antigo ou chave sem match | Inativação seletiva e guardrails (seções 10.5 e 10.6) |
| **(campo)** A integração quebra na primeira execução com erro de sintaxe | Base64 montado à mão, diferente do SQL revisado | Gere com `scripts/integracao_json.py build` (round-trip) |
| **(campo)** Mesma loja recebe valores diferentes a cada execução | A fonte devolve a mesma chave mais de uma vez (ex.: duas contas "origem" no mesmo grupo) | Uma linha por chave, com desempate determinístico |
| **(campo)** Parte dos registros nunca recebe o dado, sem erro | Junção por texto exato com grafia diferente ("Rede Alfa" × "REDE ALFA ") | Normalize com `upper(btrim(...))` nos dois lados |
| **(campo)** O valor do destino foi apagado | Fonte devolveu vazio e o campo está em Sobrescrever | Filtre vazios ou trate a limpeza como decisão explícita |
| **(campo)** O dado antigo continua no cliente que saiu do escopo | `update` não toca linha ausente | Emita valor vazio para quem deixou de ser elegível |
| **(campo)** `invalid input syntax for type integer` na query | Comparação de coluna numérica com texto (ex.: `status = 'active'` numa coluna inteira) | Descubra o tipo e os valores reais da coluna antes |
| **(campo)** Data exibida 3 horas errada | `timestamp without time zone` gravado em UTC | Converta com `AT TIME ZONE 'UTC' AT TIME ZONE 'America/Sao_Paulo'`, depois de confirmar o relógio do banco |
| **(campo)** Em produção, a integração lê dados de homologação | Conexão não foi trocada na virada | Aponte para a conexão de produção |
| **(campo)** Filtro por lista de seleção deixa passar tudo | O valor do custom field é um array jsonb (`["N/A"]`), não texto | Expanda com `jsonb_array_elements_text` (veja `references/sql-base-espelho.md`) |

## Examples

### Exemplo 1 — Cliente Pipo: custom data "Mapa de calor" via Google Sheets
Entrada: "Quero subir a aba 'Mapa de Calor' da planilha do cliente como custom data, uma linha por diagnóstico, associada pelo CNPJ."

Fluxo: `Início → Google Sheets → Concatenação → Deduplicação → Carregamento → Fim`

**Fonte**
1. Nome "Google Sheets", tipo de carga Completo, conexão "Google Sheets - Sensedata".
2. Cole o link, clique em **Processar**, escolha a aba "Mapa de Calor" e clique em **Continuar**.
3. Defina os tipos de campo:

| Coluna no arquivo | Tipo |
|---|---|
| CNPJ | Texto |
| Data do diagnóstico | Data |
| Farol Cliente | Número |
| Farol Cliente sem % | Texto |
| Mapa de Calor | Texto |

**Concatenação** ("Concatenação de Campos")
- Nome "Concatenação", etapa anterior "Google Sheets".
- Campos a concatenar 1: Data do diagnóstico, Farol Cliente, CNPJ.
- Tipo de separador: Dois pontos (:).
- Nome do novo campo concatenado: `id_legacy`.

**Deduplicação**
- Nome "Deduplicação", etapa anterior "Concatenação".
- Deduplicar em: `id_legacy`.
- Filtrar por: Data do diagnóstico (Tipo: Data).
- Condição: Mais recente.

**Carregamento**
| Seção | Valor |
|---|---|
| Etapa anterior | Deduplicação |
| Tabela de destino | Dados Customizados |
| Tipo de integração | Criação e Atualização |
| Chave cliente (SenseData ↔ arquivo) | CNPJ ↔ CNPJ |
| Chave da importação | id_legacy |
| Custom data | nome `mapa_de_calor`, data de referência "Data do diagnóstico" |
| Limpeza | Não limpar |

**Mapeamento**
| Coluna no arquivo | Coluna na Sensedata | Tipo | Opção |
|---|---|---|---|
| CNPJ | — | Texto | Ignorar |
| Data do diagnóstico | data_do_diagnostico | Data | Sobrescrever |
| Farol Cliente | farol_cliente | Número | Sobrescrever |
| Farol Cliente sem % | farol_cliente_sem | Texto | Sobrescrever |
| Mapa de Calor | mapa_de_calor | Texto | Sobrescrever |
| id_legacy | — | Texto | Ignorar |

**(campo)** Atenção: a chave inclui "Farol Cliente". Se o farol de um mesmo diagnóstico for corrigido na planilha, a chave muda e o registro vira outro (o antigo fica). Se um diagnóstico por data e CNPJ basta, `Data do diagnóstico : CNPJ` é mais estável.

### Exemplo 2 — Custom data pela API do SenseData
Entrada: "Preciso trazer o custom data 'contratacoes' via API."

Fluxo: `Início → Outras APIs → Filtro de Dados → Separação → Carregamento → Fim`
1. **Editar Fonte de Dados**: nome "API Sensedata", tipo de carga Completo (ou Incremental).
2. **Gerenciar Parâmetros**:
   - GET `https://api.onb.sensedata.io/v2/custom_data`
   - Header ligado: `Authorization` = `Bearer <token>`
   - Caminho de resposta ligado: `$.custom_data`
3. **Gerenciar paginação**:
   - Tipo: Offset e Limit.
   - Chaves: `page` (posição inicial) e `per_page` (posição limite).
   - Valores iniciais: 1 e 100.
4. **Editar tipo de campo**: `type`, `id_customer` e `data`, todas como Texto. Clique em **Salvar**.
5. **Filtro de Dados**: Grupo A, `type` Igual a `contratacoes`. Isso isola uma tabela customizada.
6. **Separação** (tipo Json, campo origem `data`, uma separação por atributo):
   - Separação 1: atributo `id_contratacao` → `id_contratacao` (Texto)
   - Separação 2: atributo `data_inicio_contrato` → `data_inicio_contrato` (Data)
7. Se não precisar de mais transformações, adicione o **Carregamento** e associe os campos.

Na API do SenseData, com exceção dos campos obrigatórios (`id_legacy`, `id_customer` e `ref_date`), todos os campos chegam agrupados dentro de `data`. O host (`api.onb.sensedata.io`) e o header podem variar por ambiente e contrato; confira na documentação da API do tenant.

### Exemplo 3 — Carga incremental dos últimos 60 dias
Entrada: "A API aceita os parâmetros dt_inicio e dt_fim no formato americano (mês/dia/ano). Quero trazer os dados de forma incremental."

Escolha **Incremental** em "Editar Fonte de Dados" e preencha "Filtros período incremental":
| Campo | Valor |
|---|---|
| Data de referência | Data de hoje |
| Tipo de intervalo | Dia |
| Número de dias | 60 |
| Referência data início | `dt_inicio`, formato `MM/DD/YYYY` |
| Referência data fim | `dt_fim`, formato `MM/DD/YYYY` |

Depois clique em **Continuar** e siga para Gerenciar Parâmetros. **(campo)** Numa carga incremental, a chave da importação precisa ser a do registro (não a data), para que um registro que reaparece na janela seguinte seja atualizado em vez de duplicado. Combine com limpeza Parcial pelo mesmo campo de data se a janela deve ser sempre substituída.

### Exemplo 4 — Cliente Tecnofit: S3 externo (data lake do cliente)
Entrada: "O cliente tem um bucket S3 próprio com clientes, contatos, contratos e financeiro."

**Conexão** ("Configuração de conexão")
1. Nome da conexão "AWS S3 Tecnofit", origem AWS S3.
2. Region, Access Key e Secret Access Key, informadas pelo cliente.
3. Clique em **Testar**.

**Integrações** (uma por arquivo: Clientes, Contatos, Contratos e Financeiro)
1. Adicione a fonte **Amazon S3**. A conexão recém-criada já aparece em "Nome da conexão".
2. Preencha URL `tecnofit-ds-sensedata`, Encoding UTF-8 e Delimitador Pipe.
3. Clique em **Processar**. A lista "Arquivo" mostra `clientes.csv`, `contatos.csv`, `contratos.csv` e `financeiro.csv`; escolha o arquivo da integração.
4. O fluxo usado foi `Amazon S3 → Condicional → Filtro de Dados → Carregamento`.
5. Boa prática: um "Filtro de Dados - Campos Obrigatorios" (etapa anterior: Condicional) com "Não é vazio" em `id_legacy`, `customer_name…` (nome truncado na captura), `dt_register` e `cs`. Assim, só sobe ao SenseData o que tem as informações obrigatórias do layout de integração.

**Workflow**: S3_Clientes primeiro; as outras dependem dela (veja a tabela da seção 7).

**(campo)** Arquivos com nome fixo: combine com o cliente que o arquivo só é substituído quando está completo, e acompanhe o volume por execução (seção 10.6).

### Exemplo 5 — Cliente Pet2Pet: replicar um dado para todos os clientes
Entrada: "A planilha de sortimento prioritário precisa aparecer em todos os clientes."
1. **Fonte SenseData**: nome "Sensedata: clientes", tipo de dado Cliente, único campo `id_legacy` (Texto).
2. **Fonte Google Sheets**: nome "Google Sheets: sortimento prioritário", conexão "Google Service Account - Sensedata". Cole o link, clique em **Processar**, escolha a aba, selecione todos os campos e salve.
3. **Criar novo campo** em cada ramo, com a mesma chave falsa:
   - "Novo Campo: sortimento prioritário-id" (etapa anterior: a fonte Sheets) → `aux` = `1`, Texto.
   - "Novo Campo: clientes-id" (etapa anterior: a fonte SenseData) → `aux` = `1`, Texto.
4. **União** ("Adicionar ou Subtrair Registros"):
   - Nome "União: sortimento prioritário-clientes".
   - Tipo de fusão "Adição de linhas dos arquivos".
   - Fonte 1: o Novo Campo do sortimento, campo chave `aux`. Fonte 2: o Novo Campo dos clientes, campo chave `aux`.
   - Selecione todos os campos das duas fontes e salve.
5. **Carregamento**: associe os campos necessários.

```
Início ─┬→ Google Sheets: sortimento → Novo Campo (aux=1) ─┐
        └→ Sensedata: clientes       → Novo Campo (aux=1) ─┴→ União → Carregamento → Fim
```

Resultado: o dado é replicado para todos os clientes, inclusive os que forem inseridos depois no SenseData. O volume é linhas da planilha × clientes; em bases grandes, confira o tamanho antes.

### Exemplo 6 — Propagar o dado de uma conta "matriz" para as contas do grupo (campo)
Entrada: "O CS registra o CS Feeling e as anotações só na conta matriz do grupo econômico. Quero que todas as lojas ativas do grupo recebam esses valores."

Fluxo: `Início → PostgreSQL (base espelho, SQL) → Carregamento (customer, update) → Fim`

Decisões de desenho:
- **Onde gravar**: em campos próprios da loja (`cs_feeling_grupo`, `anotacoes_grupo`, `conta_matriz_nome`, `grupo_atualizado_em`) em vez de sobrescrever o campo individual da loja. Preserva o dado por CNPJ e dá rastreabilidade (de qual matriz veio e quando).
- **Quem é matriz**: um campo explícito (`tipo_conta = 'matriz'`), com "sem CNPJ" apenas como fallback durante a migração.
- **Uma matriz por grupo**: `DISTINCT ON (company, grupo_normalizado)` com desempate por `updated_at DESC, id DESC`.
- **Junção normalizada**: `upper(btrim("group"))` nos dois lados.
- **Elegibilidade**: loja ativa (confirme a coluna e os valores reais de status; numa base observada, `status` era inteiro e o critério usado foi `dt_cancel IS NULL`).
- **Limpeza**: loja que deixou de ser elegível recebe `''`.
- **Delta**: só devolve a loja cujo valor atual difere do novo.

Carregamento: `destiny_table` customer, `integ_type` update, `keys` `["customer_id_legacy"]`; os 4 campos em Sobrescrever; `customer_id`, `customer_id_legacy`, `customer_name`, `customer_cnpj`, `customer_group` em Ignorar.

Teste de aceite em homologação: editar na matriz e executar (todas as lojas ativas recebem; nenhuma inativa é tocada); editar de novo (propaga de novo); executar sem mudar nada (0 linhas); tirar uma loja do grupo (campos limpos). A query completa está em `references/sql-base-espelho.md`, seção 6.

### Exemplo 7 — Carga de contatos por arquivo, com inativação seletiva (campo)
Entrada: "O cliente manda um CSV de contatos por produto. Quem não estiver no arquivo deve ficar inativo, mas não posso perder os campos que o CS preenche à mão."

Desenho recomendado:
1. **Identidade**: um registro por (pessoa, conta). Chave `email_normalizado : id_conta`. Produto vira atributo (campo próprio, não um campo emprestado como "Skype").
2. **Uma integração só**:
   - Fonte S3 (arquivo datado) → Filtro "Não é vazio" em e-mail e conta → normalização (e-mail em minúsculas, sem espaços) → Concatenação da chave → Deduplicação pela chave → Carregamento `upsert` em contatos, com `is_active = true` para quem veio.
   - Inativação seletiva: uma segunda fonte com os contatos atuais da mesma origem no SenseData; os que **não** estão no arquivo recebem `is_active = false`. Se o SenseConnect da sua versão não fizer o anti-join, gere a lista na origem ou numa rotina à parte.
3. **Nunca** "inativar todos e reativar os que vieram".
4. **Guardrails**: não processar arquivo que não seja mais novo que a última execução; abortar se o volume cair mais de 20% ou se for desativar mais de 10% da base.
5. **Campos manuais** (ex.: marcação de referência, opt-out) em Ignorar no mapeamento da carga.
6. **Aceite**: duas execuções seguidas → 0 inserções e 0 desativações na segunda; contagem de ativos por conta estável.

### Exemplo 8 — Corrigir o SQL de uma integração exportada (campo)
Entrada: "Recebi o JSON da integração e o documento traz um Base64 novo para colar na etapa da fonte."
1. `python3 scripts/integracao_json.py resumo integracao.json` — identifique o id da etapa `data_source` e a chave de carga.
2. `python3 scripts/integracao_json.py decode integracao.json` — leia o SQL atual.
3. Decodifique também o Base64 do documento e compare com o SQL que foi revisado. Numa entrega real, o Base64 do documento tinha uma vírgula a mais (`WHERE "group",  IS NOT NULL`) e quebraria a integração na primeira execução.
4. Salve o SQL revisado em `.sql` e gere o JSON novo: `python3 scripts/integracao_json.py build --base integracao.json --sql revisado.sql --step <id> --campos campo_a,campo_b --out integracao_v2.json`.
5. `python3 scripts/integracao_json.py validar integracao_v2.json` e `redigir` antes de compartilhar.

### Exemplo 9 — Validar o caminho de resposta de uma API
Entrada: o usuário cola a resposta `{"meta": {"page": 1}, "results": {"items": [{"id": 1, "nome": "A"}]}}` e pergunta qual caminho usar.
```
$ python3 scripts/validar_caminho_resposta.py resposta.json
Caminhos que terminam numa lista de objetos:
  $.results.items   (1 itens; chaves: id, nome)
$ python3 scripts/validar_caminho_resposta.py resposta.json '$.results'
ERRO: o caminho termina em um objeto, não em uma lista de objetos.
```
Resposta: use `$.results.items`; as colunas disponíveis em "Editar tipo de campo" serão `id` e `nome`.

## Notes
- O SenseConnect não substitui o time técnico: casos específicos podem precisar de uma rotina personalizada ou de uma Fonte Avançada.
- As conexões pré-cadastradas ("Google Sheets - Sensedata", "Google Service Account - Sensedata", "AWS S3") só servem quando o cliente deu acesso à chave ou à service account do SenseData, ou quando o bucket é da SenseData.
- A Private Key do Service Account precisa ser colada com as quebras de linha.
- No Sheets e no S3, é obrigatório clicar em **Processar** antes de escolher a aba ou o arquivo.
- Ambiguidades do manual:
  - Na União, a estratégia de subtração é descrita como "só as linhas presentes nas duas fontes", o que na prática é uma interseção. Teste antes de usar em produção.
  - No exemplo da concatenação, o texto diz "agregação", mas o contexto é de concatenação.
  - Na tela do Filtro de Dados, o rótulo do nome aparece como "Nome da separação" numa captura e "Nome do filtro" em outra.
- O manual não detalha o módulo Logging, a fonte PostgreSQL, os tipos de integração além de "Criação e Atualização" nem as tabelas de destino além de "Dados Customizados". O que esta skill diz sobre eles vem de campo **(campo)** e deve ser confirmado na tela.
- Nunca exponha tokens, chaves ou `connection_params` reais em exemplos ou respostas. Use `<token>`.
- Nunca inclua dados reais de clientes (nomes, e-mails, CNPJs) em exemplos genéricos.
