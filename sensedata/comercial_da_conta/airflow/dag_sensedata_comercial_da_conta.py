"""DAG diária que mantém o CF ``comercial_da_conta`` sincronizado no SenseData.

Roda depois da carga do SenseData (madrugada) e antes da janela de disparo das
réguas — em especial a regra 304, que usa esse campo como remetente.

Variáveis do Airflow esperadas:
  * ``sensedata_api_key``      – chave da API v2 (obrigatória);
  * ``sensedata_base_url``     – opcional, default https://api.sensedata.io/v2;
  * ``sensedata_cf_value_mode``– opcional: email | name | id.
"""

from __future__ import annotations

import os
import sys

import pendulum
from airflow.decorators import dag, task
from airflow.models import Variable

ROUTINE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
REPORT_DIR = os.getenv("SENSEDATA_REPORT_DIR", "/tmp/sensedata")
SAO_PAULO = pendulum.timezone("America/Sao_Paulo")


@dag(
    dag_id="sensedata_comercial_da_conta",
    description="Atualiza o campo customizado comercial_da_conta na tabela de clientes do SenseData",
    schedule="0 7 * * *",  # 07h America/Sao_Paulo, após a carga e antes das réguas
    start_date=pendulum.datetime(2026, 9, 1, tz=SAO_PAULO),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 2, "retry_delay": pendulum.duration(minutes=10)},
    tags=["sensedata", "thomson-reuters", "customer-success"],
)
def sensedata_comercial_da_conta():
    @task
    def sync_field(ds: str = "") -> dict:
        sys.path.insert(0, os.path.abspath(ROUTINE_DIR))
        import sync  # import tardio: o worker só resolve o path dentro da task

        os.makedirs(REPORT_DIR, exist_ok=True)
        pending_csv = os.path.join(REPORT_DIR, f"pendencias_comercial_da_conta_{ds or 'run'}.csv")

        exit_code = sync.main(
            [
                "--mode", "apply",
                "--api-key", Variable.get("sensedata_api_key"),
                "--base-url", Variable.get("sensedata_base_url", default_var="https://api.sensedata.io/v2"),
                "--value-mode", Variable.get("sensedata_cf_value_mode", default_var="email"),
                "--pending-csv", pending_csv,
            ]
        )
        if exit_code != 0:
            raise RuntimeError(f"Rotina comercial_da_conta terminou com código {exit_code}")
        return {"pending_csv": pending_csv}

    @task
    def report_pending(result: dict) -> int:
        """Loga quantos clientes seguem sem comercial resolvido (tratamento do CS)."""
        import csv
        import logging

        path = result["pending_csv"]
        if not os.path.exists(path):
            return 0
        with open(path, encoding="utf-8") as handle:
            rows = list(csv.DictReader(handle))
        for row in rows[:50]:
            logging.warning("Sem comercial: %s (%s) - %s", row["cliente"], row["id_original"], row["motivo"])
        logging.info("Total de pendências: %d (arquivo: %s)", len(rows), path)
        return len(rows)

    report_pending(sync_field())


dag = sensedata_comercial_da_conta()
