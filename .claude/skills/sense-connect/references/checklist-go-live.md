# Checklists de integração

## 1. Desenho (antes de abrir o canvas)
- [ ] Objetivo em uma frase: que dado, para qual tabela, com que frequência.
- [ ] Origem, acesso e conexão definidos; ambiente da conexão explícito no nome.
- [ ] Tabela de destino e tipo de integração escolhidos.
- [ ] Chave com o cliente definida e com cobertura conferida (quantas linhas da origem casam com clientes).
- [ ] Chave da importação: identifica, é estável, é única, é normalizada.
- [ ] Decisão sobre órfãos: manter, limpar, inativar ou apagar.
- [ ] Campos com dono humano ficam em Ignorar (ou em campo separado).
- [ ] Nenhum campo em Sobrescrever pode receber vazio sem querer.
- [ ] Volume esperado por execução anotado (base para guardrail).
- [ ] Dependências no workflow e posição no agendamento (antes das regras que leem o dado).
- [ ] Uma integração por informação.

## 2. Construção
- [ ] Todas as caixas ligadas do Início ao Fim; nenhuma com ⚠.
- [ ] Sheets/S3: "Processar" antes de escolher aba/arquivo.
- [ ] API: caminho de resposta validado (`scripts/validar_caminho_resposta.py`) e paginação configurada.
- [ ] Filtro "Não é vazio" nos campos obrigatórios do layout.
- [ ] Deduplicação pela chave da importação, com desempate.
- [ ] Nomes de coluna no mapeamento em `a-z0-9_` (`scripts/normalizar_coluna.py`).
- [ ] SQL: aliases explícitos, uma linha por chave, junções normalizadas, delta, sintaxe validada.
- [ ] Base64 gerado por script com round-trip (nunca à mão).
- [ ] `scripts/integracao_json.py validar` sem erros no export.

## 3. Homologação
- [ ] Dry-run: quantas linhas cada execução tocaria (antes de carregar).
- [ ] Primeira execução com o número esperado de linhas.
- [ ] Amostra conferida no SenseData (Visão 360 / tabela), inclusive um caso que **não** deveria ser tocado.
- [ ] Segunda execução sem mudança na origem: 0 inserções, 0 desativações (e 0 linhas com delta).
- [ ] Mudança na origem propaga; segunda mudança também propaga.
- [ ] Registro que sai do escopo recebe o tratamento combinado.
- [ ] Cliente validou o roteiro de aceite, quando for o caso.

## 4. Virada para produção
- [ ] Export da versão atual guardado (rollback).
- [ ] Conexão de produção na(s) fonte(s); nenhum `connection_params` de outro ambiente.
- [ ] Workflow salvo e **sincronizado**; dependências conferidas.
- [ ] "Em caso de quebras na carga parar a execução" marcado onde faz sentido.
- [ ] Agendamento criado; calc após a carga, se necessário.
- [ ] Regras do SenseData que dependem do dado agendadas depois da carga, com folga.
- [ ] Painéis/segmentações ajustados se a integração cria registros "técnicos" (ex.: contas matriz).
- [ ] Comunicação ao time: quem é a fonte da verdade de cada campo.

## 5. Operação
- [ ] Contagem de linhas por execução acompanhada (lidas, inseridas, atualizadas, desativadas).
- [ ] Alerta para "0 linhas por N dias" e para volume anômalo.
- [ ] Arquivos com data no nome e bucket versionado.
- [ ] Queries de qualidade rodando mensalmente (chaves duplicadas, grafia divergente, órfãos).
- [ ] Mudança de chave só com migração prévia das chaves gravadas.
- [ ] Em incidente: pausar, bloquear expurgo, snapshot, investigar (veja `persistencia-e-chaves.md`, seção 9).
