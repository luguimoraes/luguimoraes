"""Cliente HTTP mínimo para a API v2 do SenseData.

Usa apenas a biblioteca padrão (urllib) para que a rotina possa rodar em
qualquer worker (Airflow, container, cron) sem instalação de dependências.

Trata as duas situações que mais quebram carga em produção:
  * paginação (a API devolve tanto lista pura quanto envelope ``{"data": [...]}``);
  * throttling / instabilidade (429 e 5xx viram retry com backoff exponencial).
"""

from __future__ import annotations

import json
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Iterator

DEFAULT_BASE_URL = "https://api.sensedata.io/v2"
DEFAULT_PAGE_SIZE = 200

# Chaves usadas pela API para embrulhar a lista de registros.
_ENVELOPE_KEYS = ("data", "items", "results", "records", "customers", "contacts", "users")


class SenseDataError(RuntimeError):
    """Erro de comunicação com a API do SenseData."""


class SenseDataClient:
    def __init__(
        self,
        api_key: str,
        base_url: str = DEFAULT_BASE_URL,
        timeout: int = 60,
        max_retries: int = 4,
        page_size: int = DEFAULT_PAGE_SIZE,
        max_pages: int = 500,
        opener: Any = None,
        sleeper: Any = time.sleep,
    ) -> None:
        if not api_key:
            raise SenseDataError("API key do SenseData não informada (SENSEDATA_API_KEY).")
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.max_retries = max_retries
        self.page_size = page_size
        self.max_pages = max_pages
        self._opener = opener or urllib.request.build_opener()
        self._sleep = sleeper

    # ------------------------------------------------------------------ HTTP
    def _request(self, method: str, path: str, params: dict | None = None, payload: Any = None) -> Any:
        url = f"{self.base_url}/{path.lstrip('/')}"
        if params:
            url = f"{url}?{urllib.parse.urlencode(params)}"

        body = json.dumps(payload).encode("utf-8") if payload is not None else None
        headers = {
            "accept": "application/json",
            "apikey": self.api_key,
            "user-agent": "sensedata-comercial-da-conta/1.0",
        }
        if body is not None:
            headers["content-type"] = "application/json"

        last_error: Exception | None = None
        for attempt in range(self.max_retries + 1):
            request = urllib.request.Request(url, data=body, headers=headers, method=method)
            try:
                with self._opener.open(request, timeout=self.timeout) as response:
                    raw = response.read().decode("utf-8") or "{}"
                return json.loads(raw)
            except urllib.error.HTTPError as exc:  # noqa: PERF203 - retry precisa do try por tentativa
                detail = exc.read().decode("utf-8", errors="replace")[:500]
                if exc.code not in (429, 500, 502, 503, 504) or attempt == self.max_retries:
                    raise SenseDataError(f"{method} {url} -> HTTP {exc.code}: {detail}") from exc
                last_error = exc
            except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
                if attempt == self.max_retries:
                    raise SenseDataError(f"{method} {url} falhou: {exc}") from exc
                last_error = exc
            self._sleep(2 ** (attempt + 1))  # 2s, 4s, 8s, 16s

        raise SenseDataError(f"{method} {url} falhou após {self.max_retries} tentativas: {last_error}")

    @staticmethod
    def _unwrap(response: Any) -> list[dict]:
        if isinstance(response, list):
            return response
        if isinstance(response, dict):
            for key in _ENVELOPE_KEYS:
                value = response.get(key)
                if isinstance(value, list):
                    return value
        return []

    def paginate(self, path: str, params: dict | None = None) -> Iterator[dict]:
        """Percorre todas as páginas de um endpoint de listagem."""
        page = 1
        while page <= self.max_pages:
            query = dict(params or {})
            query.update({"page": page, "per_page": self.page_size})
            rows = self._unwrap(self._request("GET", path, params=query))
            yield from rows
            if len(rows) < self.page_size:
                return
            page += 1

    # -------------------------------------------------------------- Recursos
    def list_users(self) -> list[dict]:
        return list(self.paginate("users"))

    def list_customers(self, params: dict | None = None) -> list[dict]:
        return list(self.paginate("customers", params=params))

    def list_contacts(self, params: dict | None = None) -> list[dict]:
        return list(self.paginate("contacts", params=params))

    def update_customer_custom_field(self, customer_id: Any, field_key: str, field_value: Any, key_mode: str = "name") -> Any:
        """Atualiza um único campo customizado do cliente.

        ``key_mode`` define se o campo é identificado por ``name`` (rótulo/alias do
        CF) ou por ``id`` — depende de como o CF foi criado na instância.
        """
        field = {"value": field_value}
        field["id" if key_mode == "id" else "name"] = field_key
        return self._request("PUT", f"customers/{customer_id}", payload={"custom_fields": [field]})
