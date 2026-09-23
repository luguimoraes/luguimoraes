# API SenseData v2 (campo)

O que foi observado em rotinas reais. Os caminhos, o nome do header de autenticação e os endpoints liberados **variam por contrato**: confirme no ReDoc do tenant antes de escrever código.

## 1. Base e documentação
- Base: `https://api.sensedata.io/v2`
- Documentação: `https://api.sensedata.io/v2/redoc`
- No Manual SenseConnect, o exemplo de custom data usa `https://api.onb.sensedata.io/v2/custom_data` com `Authorization: Bearer <token>`. O host pode variar por ambiente.

## 2. Autenticação
API key (gerada na plataforma) enviada num header. Variantes vistas em código de campo:
| Variante | Onde apareceu |
|---|---|
| `Authorization: Bearer <token>` | Manual SenseConnect (fonte Outras APIs → API SenseData) |
| `api_key: <token>` | Rotina de inatividade (configurável por variável de ambiente) |
| `apikey: <token>` | Rotina de preenchimento de campo |
Deixe o nome do header configurável e teste com um GET simples. Guarde a key em variável de ambiente ou no cofre do orquestrador (ex.: Airflow Variables), nunca no código ou em arquivo versionado.

## 3. Paginação
- Parâmetros `page` (começa em 1) e `per_page` (ex.: 100–200).
- O corpo da resposta varia entre endpoints: lista pura ou envelope (`{"data": [...]}`, `results`, `items`, `records`, `customers`, `contacts`, `users`, `custom_data`…). Trate os dois casos.
- Pare quando a página vier vazia ou com menos itens que `per_page`. Tenha um teto de páginas como proteção.

## 4. Erros e retry
- Retry com backoff exponencial (2s, 4s, 8s, 16s) em **429** e **5xx** (500, 502, 503, 504) e em erro de rede.
- Em 429, respeite `Retry-After` quando vier.
- 4xx diferente de 429: não repita; registre o corpo da resposta (até ~500 caracteres).
- 413 (payload grande): diminua o lote (100 registros por chamada é conservador).
- 404 num endpoint de listagem pode significar "não liberado no seu contrato" (ex.: anotações).

## 5. Endpoints observados
| Recurso | Uso observado | Observação |
|---|---|---|
| `GET /customers` | Listar clientes (filtros por query string) | Paginado |
| `POST /customers` com `{"customers": [{"id_cliente": "<id>", "custom_fields": {"<nome_interno>": <valor>}}]}` | Gravar custom fields em lote | Formato visto numa rotina; confirme no ReDoc |
| `PUT /customers/{id}` com `{"custom_fields": [{"name": "<nome_interno>", "value": <valor>}]}` | Gravar um custom field de um cliente | Variante com `"id": <id do campo>` em vez de `name`, conforme a criação do campo |
| `GET /contacts` | Listar contatos | Paginado |
| `GET /users` | Listar usuários (para resolver nome/e-mail → usuário) | Paginado |
| `GET /notes?start_date=...` | Listar anotações | Pode não estar liberado (404) |
| `GET /custom_data` | Listar dados customizados | Campos, exceto `id_legacy`, `id_customer` e `ref_date`, vêm dentro de `data`; filtre por `type` |

## 6. Gravação de custom fields
- Use o **nome interno** (`comercial_da_conta`), nunca o rótulo ("Comercial "). Se o campo foi sufixado por colisão (`_2`), use o sufixado.
- **Lista de usuários**: o valor aceito pode ser e-mail, nome ou id do usuário. Teste com **um** cliente e confira na Visão 360; troque o formato até o campo aceitar.
- **Merge × replace**: confirme se gravar um campo preserva os demais `custom_fields` do registro. Teste com poucos registros comparando antes/depois.
- **Idempotência**: leia o valor atual e só grave se mudou. Rotina diária que reescreve tudo polui histórico e "data de atualização".
- **Nunca limpe** um valor existente por falta de dado na origem; registre como pendência (motivos: sem origem, usuário não encontrado, usuário inativo, homônimo ambíguo).

## 7. Esqueleto de cliente (Python, só biblioteca padrão)
```python
import json, time, urllib.error, urllib.parse, urllib.request

class SenseData:
    def __init__(self, api_key, base_url="https://api.sensedata.io/v2", header="Authorization",
                 bearer=True, per_page=200, max_retries=4):
        self.base, self.per_page, self.max_retries = base_url.rstrip("/"), per_page, max_retries
        valor = f"Bearer {api_key}" if bearer else api_key
        self.headers = {header: valor, "accept": "application/json"}

    def _req(self, method, path, params=None, payload=None):
        url = f"{self.base}/{path.lstrip('/')}"
        if params:
            url += "?" + urllib.parse.urlencode(params)
        body = json.dumps(payload).encode() if payload is not None else None
        headers = dict(self.headers, **({"content-type": "application/json"} if body else {}))
        for tentativa in range(self.max_retries + 1):
            try:
                with urllib.request.urlopen(urllib.request.Request(url, body, headers, method=method), timeout=60) as r:
                    return json.loads(r.read() or b"{}")
            except urllib.error.HTTPError as e:
                if e.code not in (429, 500, 502, 503, 504) or tentativa == self.max_retries:
                    raise RuntimeError(f"{method} {url} -> {e.code}: {e.read()[:500]!r}") from e
                espera = float(e.headers.get("Retry-After") or 2 ** (tentativa + 1))
            except urllib.error.URLError:
                if tentativa == self.max_retries:
                    raise
                espera = 2 ** (tentativa + 1)
            time.sleep(espera)

    def paginar(self, path, **filtros):
        for pagina in range(1, 501):
            corpo = self._req("GET", path, dict(filtros, page=pagina, per_page=self.per_page))
            itens = corpo if isinstance(corpo, list) else next(
                (v for v in (corpo or {}).values() if isinstance(v, list)), [])
            yield from itens
            if len(itens) < self.per_page:
                return
```
Ajuste `header`/`bearer` ao que o ReDoc do tenant pede.

## 8. Operação de rotinas
- Agende depois da carga diária e antes das regras que leem o campo (ex.: 06:00–07:00, regras às 09:00).
- Uma execução por vez (`max_active_runs=1` no Airflow): duas execuções simultâneas corrompem estado.
- Estado (histórico de valores, deduplicação de alertas) é dado, não cache: volume persistente e backup.
- Modos `dry-run` (calcula e mostra, não grava), `--only-customer <id>` (valida um caso) e `apply`.
- Se já existe extração do SenseData no DW, ler de lá é mais rápido, não consome rate limit e pode trazer histórico.
