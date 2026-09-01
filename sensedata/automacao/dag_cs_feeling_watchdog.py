"""DAG Airflow — inatividade de CS Feeling / anotações no SenseData.

Alimenta os campos customizados que as regras de 90/105/120 dias leem.

Ordem importa: este DAG tem que terminar **antes** do horário agendado das
regras no SenseData. Com o DAG às 06:00 e as regras às 09:00 sobram três horas
para retry. Se as regras rodarem antes, leem o campo do dia anterior — o que no
dia da virada significa alerta atrasado ou perdido.
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta

import pendulum
from airflow.decorators import dag, task
from airflow.models import Variable

TZ = pendulum.timezone("America/Sao_Paulo")

ARGS_PADRAO = {
    "owner": "cs-ops",
    "retries": 3,
    "retry_delay": timedelta(minutes=10),
    "email_on_failure": True,
    "email": ["cs-ops@suaempresa.com.br"],
}


@dag(
    dag_id="sensedata_cs_feeling_watchdog",
    description="Calcula inatividade de CS Feeling/anotações e grava nos campos do SenseData",
    schedule="0 6 * * 1-5",  # dias úteis, 06:00 America/Sao_Paulo
    start_date=datetime(2026, 9, 1, tzinfo=TZ),
    catchup=False,
    max_active_runs=1,  # duas execuções simultâneas corromperiam o banco de controle
    default_args=ARGS_PADRAO,
    tags=["sensedata", "cs-ops", "inatividade"],
)
def sensedata_cs_feeling_watchdog():
    @task
    def carregar_config() -> dict:
        """Segredos vêm de Variables/Connections do Airflow, nunca do código."""
        os.environ["SENSEDATA_API_KEY"] = Variable.get("sensedata_api_key")
        os.environ["SENSEDATA_BASE_URL"] = Variable.get(
            "sensedata_base_url", default_var="https://api.sensedata.io/v2"
        )
        os.environ["SENSEDATA_HEADER_AUTH"] = Variable.get(
            "sensedata_header_auth", default_var="api_key"
        )
        os.environ["LIDER_POR_CS"] = Variable.get("sensedata_lider_por_cs", default_var="{}")
        os.environ["AUTORES_IGNORADOS"] = Variable.get(
            "sensedata_autores_ignorados", default_var=""
        )
        os.environ["BANCO_CONTROLE"] = Variable.get(
            "sensedata_banco_controle", default_var="/opt/airflow/data/controle_inatividade.sqlite"
        )
        return {"ok": True}

    @task
    def rodar(_: dict) -> int:
        from watchdog_cs_feeling import executar

        # limite_diario: mantenha um teto durante o rollout inicial e remova
        # (None) depois que a base estabilizar. Ver runbook, seção 5.
        limite = Variable.get("sensedata_limite_diario", default_var=None)
        return executar(dry_run=False, limite_diario=int(limite) if limite else None)

    rodar(carregar_config())


dag_inatividade = sensedata_cs_feeling_watchdog()
