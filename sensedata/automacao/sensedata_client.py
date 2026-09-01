"""Cliente HTTP para a API SenseData v2 (SenseConnect).

Referência: https://api.sensedata.io/v2/redoc

Os caminhos dos endpoints e o nome do header de autenticação são configuráveis
porque variam entre contratos. Confira o ReDoc do seu tenant e ajuste no .env
antes do primeiro run.
"""

from __future__ import annotations

import logging
import os
import time
from typing import Any, Iterator

import requests

log = logging.getLogger(__name__)

TRANSIENTES = {429, 500, 502, 503, 504}


class SenseDataError(RuntimeError):
    pass


class SenseDataClient:
    def __init__(
        self,
        api_key: str,
        base_url: str = "https://api.sensedata.io/v2",
        header_auth: str = "api_key",
        timeout: int = 30,
        max_retries: int = 4,
    ) -> None:
        if not api_key:
            raise SenseDataError("API key vazia. Defina SENSEDATA_API_KEY.")
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.max_retries = max_retries
        self.session = requests.Session()
        self.session.headers.update(
            {
                header_auth: api_key,
                "Content-Type": "application/json",
                "Accept": "application/json",
            }
        )

    @classmethod
    def from_env(cls) -> "SenseDataClient":
        return cls(
            api_key=os.environ.get("SENSEDATA_API_KEY", ""),
            base_url=os.environ.get("SENSEDATA_BASE_URL", "https://api.sensedata.io/v2"),
            header_auth=os.environ.get("SENSEDATA_HEADER_AUTH", "api_key"),
        )

    # ------------------------------------------------------------------ HTTP

    def _request(self, method: str, path: str, **kwargs: Any) -> Any:
        url = f"{self.base_url}/{path.lstrip('/')}"
        espera = 2.0

        for tentativa in range(1, self.max_retries + 1):
            try:
                resp = self.session.request(method, url, timeout=self.timeout, **kwargs)
            except requests.RequestException as exc:
                if tentativa == self.max_retries:
                    raise SenseDataError(f"{method} {url} falhou: {exc}") from exc
                log.warning("%s %s erro de rede (%s), retry %s", method, url, exc, tentativa)
            else:
                if resp.status_code not in TRANSIENTES:
                    if resp.status_code >= 400:
                        raise SenseDataError(
                            f"{method} {url} -> {resp.status_code}: {resp.text[:500]}"
                        )
                    return resp.json() if resp.content else None

                # 429 traz o tempo de espera; respeitar evita entrar em ciclo de bloqueio
                if resp.status_code == 429 and resp.headers.get("Retry-After"):
                    espera = float(resp.headers["Retry-After"])
                log.warning("%s %s -> %s, retry %s", method, url, resp.status_code, tentativa)

            if tentativa < self.max_retries:
                time.sleep(espera)
                espera *= 2

        raise SenseDataError(f"{method} {url}: esgotadas {self.max_retries} tentativas")

    def _paginar(self, path: str, params: dict[str, Any] | None = None) -> Iterator[dict]:
        params = dict(params or {})
        params.setdefault("per_page", 200)
        pagina = 1

        while True:
            params["page"] = pagina
            corpo = self._request("GET", path, params=params)

            # O envelope varia entre endpoints: ora lista pura, ora {"data": [...]}
            if isinstance(corpo, list):
                itens = corpo
            elif isinstance(corpo, dict):
                itens = corpo.get("data") or corpo.get("results") or corpo.get("items") or []
            else:
                itens = []

            if not itens:
                return

            yield from itens

            if len(itens) < params["per_page"]:
                return
            pagina += 1

    # ------------------------------------------------------------- Clientes

    def listar_clientes(self, **filtros: Any) -> list[dict]:
        """Clientes ativos. Filtros extras são repassados como query string."""
        return list(self._paginar("/customers", filtros))

    def atualizar_campos_customizados(self, id_externo: str, campos: dict[str, Any]) -> None:
        """Grava campos customizados de um cliente.

        `campos` deve usar o **nome interno** do campo no SenseData
        (minúsculo, com underline, e possivelmente sufixado: `cs_feeling_2`).
        """
        payload = {"customers": [{"id_cliente": id_externo, "custom_fields": campos}]}
        self._request("POST", "/customers", json=payload)

    def atualizar_campos_em_lote(self, registros: list[dict[str, Any]], tamanho_lote: int = 100) -> int:
        """Mesma coisa, em lotes. Devolve quantos clientes foram enviados.

        Lote grande demais estoura o limite de payload do endpoint e devolve 413;
        100 é conservador e cabe em qualquer contrato.
        """
        enviados = 0
        for inicio in range(0, len(registros), tamanho_lote):
            lote = registros[inicio : inicio + tamanho_lote]
            self._request("POST", "/customers", json={"customers": lote})
            enviados += len(lote)
            log.info("lote gravado: %s clientes (%s/%s)", len(lote), enviados, len(registros))
        return enviados

    # ------------------------------------------------------------ Anotações

    def listar_anotacoes(self, desde: str | None = None) -> list[dict]:
        """Anotações da base.

        Se o endpoint de anotações não estiver liberado no seu contrato, esta
        chamada devolve 404 — nesse caso use a fonte de dados do DW
        (ver README.md, seção "Fonte de dados alternativa").
        """
        params = {"start_date": desde} if desde else {}
        return list(self._paginar("/notes", params))
