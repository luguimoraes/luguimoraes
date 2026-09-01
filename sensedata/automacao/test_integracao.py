"""Teste ponta a ponta de `executar()` com uma API falsa.

Verifica o payload que seria gravado no SenseData, incluindo o comportamento do
primeiro run (baseline) e a deduplicação entre execuções.

    python test_integracao.py
"""

from __future__ import annotations

import os
import sys
import tempfile
from datetime import date, timedelta

HOJE = date(2026, 9, 1)

_tmp = tempfile.TemporaryDirectory()
os.environ.update(
    {
        "SENSEDATA_API_KEY": "fake",
        "BANCO_CONTROLE": f"{_tmp.name}/controle.sqlite",
        "LIDER_POR_CS": '{"ana.silva":"lider@suaempresa.com.br"}',
        "AUTORES_IGNORADOS": "bot-zendesk",
    }
)

import watchdog_cs_feeling  # noqa: E402

GRAVADOS: list[dict] = []


class ClienteFalso:
    """Duas contas: Alfa parada desde abril, Beta com anotação recente."""

    @classmethod
    def from_env(cls):
        return cls()

    def listar_clientes(self, **kwargs):
        return [
            {"id_cliente": "1", "name": "Grupo Alfa", "cs": "ana.silva",
             "start_date": "2024-01-01", "custom_fields": {"cs_feeling": "Verde"}},
            {"id_cliente": "2", "name": "Grupo Beta", "cs": "joao.souza",
             "start_date": "2025-01-01", "custom_fields": {"cs_feeling": "Vermelho"}},
        ]

    def listar_anotacoes(self, desde=None):
        return [
            {"id_cliente": "1", "user": "bot-zendesk", "date": "2026-08-30T10:00:00Z"},
            {"id_cliente": "1", "user": "ana.silva", "date": "2026-04-01T10:00:00Z"},
            {"id_cliente": "2", "user": "joao.souza", "date": "2026-08-25T10:00:00Z"},
        ]

    def atualizar_campos_em_lote(self, registros, tamanho_lote=100):
        GRAVADOS.extend(registros)
        return len(registros)


def _rodar(hoje: date) -> dict[str, dict]:
    GRAVADOS.clear()
    watchdog_cs_feeling.executar(dry_run=False, limite_diario=None, hoje=hoje)
    return {r["id_cliente"]: r["custom_fields"] for r in GRAVADOS}


def main() -> int:
    watchdog_cs_feeling.SenseDataClient = ClienteFalso

    # --- Run 1: primeiro dia -------------------------------------------------
    campos = _rodar(HOJE)
    alfa, beta = campos["1"], campos["2"]

    # A anotação de robô (bot-zendesk, 30/08) é descartada; vale a humana de 01/04.
    assert alfa["dt_ultima_anotacao_cs"] == "2026-04-01", alfa
    # Baseline do feeling não afirma data de atualização, então o cálculo cai
    # para a anotação — e o alerta sai já no primeiro run, não 90 dias depois.
    assert "dt_ultima_atualizacao_cs_feeling" not in alfa, alfa
    assert alfa["dias_sem_atualizacao_cs"] == 153, alfa
    assert alfa["nivel_alerta_inatividade"] == "critico_120", alfa
    assert alfa["email_lider_cs"] == "lider@suaempresa.com.br", alfa

    assert beta["dias_sem_atualizacao_cs"] == 7, beta
    assert beta["nivel_alerta_inatividade"] == "nenhum", beta
    assert "email_lider_cs" not in beta, beta  # joao.souza sem líder mapeado

    # --- Run 2: 200 dias depois, ninguém mexeu em nada -----------------------
    campos = _rodar(HOJE + timedelta(days=200))
    # Alfa já foi alertada em critico_120 neste mesmo ciclo: silêncio.
    assert campos["1"]["dias_sem_atualizacao_cs"] == 353, campos["1"]
    assert campos["1"]["nivel_alerta_inatividade"] == "nenhum", campos["1"]
    # Beta cruza 120 agora, primeira vez: alerta.
    assert campos["2"]["nivel_alerta_inatividade"] == "critico_120", campos["2"]

    # --- Run 3: dia seguinte, nada novo --------------------------------------
    campos = _rodar(HOJE + timedelta(days=201))
    assert campos["1"]["nivel_alerta_inatividade"] == "nenhum", campos["1"]
    assert campos["2"]["nivel_alerta_inatividade"] == "nenhum", campos["2"]

    print("integração ok")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    finally:
        _tmp.cleanup()
