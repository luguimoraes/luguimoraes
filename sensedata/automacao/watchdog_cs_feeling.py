"""Calcula a inatividade de CS Feeling / anotações e alimenta os campos que as
regras do SenseData leem.

Roda uma vez por dia, antes do horário das regras. Grava em cada grupo econômico:

    dt_ultima_anotacao_cs               data
    dt_ultima_atualizacao_cs_feeling    data
    dias_sem_atualizacao_cs             inteiro
    nivel_alerta_inatividade            nenhum | alerta_90 | escalonamento_105 | critico_120
    email_lider_cs                      texto (opcional)

O campo que dispara as regras é `nivel_alerta_inatividade`. Ele vale o nível do
alerta **apenas no dia em que o alerta deve sair** e volta para `nenhum` no dia
seguinte — é isso que garante disparo único sem depender de deduplicação dentro
do SenseData.

Uso:
    python watchdog_cs_feeling.py --dry-run
    python watchdog_cs_feeling.py --limite-diario 50
    python watchdog_cs_feeling.py
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import sqlite3
from contextlib import closing
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from pathlib import Path

from sensedata_client import SenseDataClient, SenseDataError

log = logging.getLogger("watchdog")

# Limiares da escada de escalonamento (runbook, seção 4.1).
NIVEIS: list[tuple[int, str]] = [
    (120, "critico_120"),
    (105, "escalonamento_105"),
    (90, "alerta_90"),
]
SEM_ALERTA = "nenhum"


# --------------------------------------------------------------------- config


@dataclass
class Config:
    campo_feeling: str = "cs_feeling"
    campo_dt_anotacao: str = "dt_ultima_anotacao_cs"
    campo_dt_feeling: str = "dt_ultima_atualizacao_cs_feeling"
    campo_dias: str = "dias_sem_atualizacao_cs"
    campo_nivel: str = "nivel_alerta_inatividade"
    campo_email_lider: str = "email_lider_cs"

    autores_ignorados: set[str] = field(default_factory=set)
    lider_por_cs: dict[str, str] = field(default_factory=dict)

    data_ativacao_regra: date | None = None
    carencia_inicial: int = 0
    banco_controle: Path = Path("controle_inatividade.sqlite")

    @classmethod
    def from_env(cls) -> "Config":
        def _data(chave: str) -> date | None:
            bruto = os.environ.get(chave, "").strip()
            return date.fromisoformat(bruto) if bruto else None

        def _json(chave: str, padrao):
            bruto = os.environ.get(chave, "").strip()
            return json.loads(bruto) if bruto else padrao

        return cls(
            campo_feeling=os.environ.get("CAMPO_FEELING", "cs_feeling"),
            campo_dt_anotacao=os.environ.get("CAMPO_DT_ANOTACAO", "dt_ultima_anotacao_cs"),
            campo_dt_feeling=os.environ.get("CAMPO_DT_FEELING", "dt_ultima_atualizacao_cs_feeling"),
            campo_dias=os.environ.get("CAMPO_DIAS", "dias_sem_atualizacao_cs"),
            campo_nivel=os.environ.get("CAMPO_NIVEL", "nivel_alerta_inatividade"),
            campo_email_lider=os.environ.get("CAMPO_EMAIL_LIDER", "email_lider_cs"),
            autores_ignorados={a.strip().lower() for a in os.environ.get("AUTORES_IGNORADOS", "").split(",") if a.strip()},
            lider_por_cs={k.lower(): v for k, v in _json("LIDER_POR_CS", {}).items()},
            data_ativacao_regra=_data("DATA_ATIVACAO_REGRA"),
            carencia_inicial=int(os.environ.get("CARENCIA_INICIAL", "0")),
            banco_controle=Path(os.environ.get("BANCO_CONTROLE", "controle_inatividade.sqlite")),
        )


@dataclass
class Cliente:
    id_cliente: str
    nome: str
    cs_responsavel: str | None
    dt_inicio_contrato: date | None
    cs_feeling: str | None
    dt_ultima_anotacao: date | None = None
    dt_ultima_feeling: date | None = None


# ------------------------------------------------------------------ controle


SCHEMA = """
CREATE TABLE IF NOT EXISTS historico_cs_feeling (
    id_cliente     TEXT NOT NULL,
    valor          TEXT,
    dt_observacao  TEXT NOT NULL,
    eh_baseline    INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (id_cliente, dt_observacao)
);
CREATE TABLE IF NOT EXISTS alertas_enviados (
    id_cliente  TEXT NOT NULL,
    nivel       TEXT NOT NULL,
    dt_marco    TEXT NOT NULL,
    dt_envio    TEXT NOT NULL,
    dias        INTEGER NOT NULL,
    PRIMARY KEY (id_cliente, nivel, dt_marco)
);
"""


class Controle:
    """Estado local do pipeline.

    Duas responsabilidades:

    1. Histórico do CS Feeling. A API v2 não expõe histórico de alteração de campo
       customizado, então o pipeline monta o seu: guarda um registro por cliente
       toda vez que o valor **muda**.

       O primeiro registro de cada cliente é marcado como `eh_baseline` e **não**
       conta como atualização. Sem essa distinção, o primeiro run gravaria
       "feeling atualizado hoje" para a base inteira — um fato que o pipeline não
       observou, ele só viu o valor atual pela primeira vez. O efeito seria zerar
       o contador de todo mundo e deixar a régua muda pelos 90 dias seguintes ao
       go-live. Enquanto só existe baseline, o cálculo cai para a anotação.

       Se o seu contrato expuser esse histórico nativamente, troque esta fonte —
       é mais confiável que reconstruir.

    2. Deduplicação de alertas. A chave inclui `dt_marco` (o dia em que o cliente
       foi tocado pela última vez), então um cliente que ficou inativo, foi
       alertado, voltou a ser atualizado e ficou inativo de novo é alertado de
       novo — ciclo novo, marco novo.
    """

    def __init__(self, caminho: Path) -> None:
        caminho.parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(caminho)
        self.conn.executescript(SCHEMA)
        self.conn.commit()

    def close(self) -> None:
        self.conn.close()

    def registrar_feeling(self, id_cliente: str, valor: str | None, hoje: date) -> None:
        cur = self.conn.execute(
            "SELECT valor FROM historico_cs_feeling WHERE id_cliente = ? "
            "ORDER BY dt_observacao DESC LIMIT 1",
            (id_cliente,),
        )
        linha = cur.fetchone()
        if linha is None:
            # Primeira vez que vemos este cliente: registra o valor atual como
            # marco zero, sem afirmar que houve atualização hoje.
            self.conn.execute(
                "INSERT OR REPLACE INTO historico_cs_feeling VALUES (?, ?, ?, 1)",
                (id_cliente, valor, hoje.isoformat()),
            )
            return
        if linha[0] == valor:
            return  # sem mudança: não é atualização, não move o marco
        self.conn.execute(
            "INSERT OR REPLACE INTO historico_cs_feeling VALUES (?, ?, ?, 0)",
            (id_cliente, valor, hoje.isoformat()),
        )

    def dt_ultima_mudanca_feeling(self, id_cliente: str) -> date | None:
        """Data da última mudança **observada**. `None` enquanto só há baseline."""
        cur = self.conn.execute(
            "SELECT MAX(dt_observacao) FROM historico_cs_feeling "
            "WHERE id_cliente = ? AND eh_baseline = 0",
            (id_cliente,),
        )
        valor = cur.fetchone()[0]
        return date.fromisoformat(valor) if valor else None

    def ja_alertado(self, id_cliente: str, nivel: str, dt_marco: date) -> bool:
        cur = self.conn.execute(
            "SELECT 1 FROM alertas_enviados WHERE id_cliente = ? AND nivel = ? AND dt_marco = ?",
            (id_cliente, nivel, dt_marco.isoformat()),
        )
        return cur.fetchone() is not None

    def marcar_alertado(self, id_cliente: str, nivel: str, dt_marco: date, hoje: date, dias: int) -> None:
        self.conn.execute(
            "INSERT OR REPLACE INTO alertas_enviados VALUES (?, ?, ?, ?, ?)",
            (id_cliente, nivel, dt_marco.isoformat(), hoje.isoformat(), dias),
        )

    def commit(self) -> None:
        self.conn.commit()


# --------------------------------------------------------------------- coleta


def _para_data(valor) -> date | None:
    if not valor:
        return None
    if isinstance(valor, date):
        return valor
    texto = str(valor).strip()

    # ISO com ou sem hora, com ou sem timezone — o caso comum da API.
    try:
        return datetime.fromisoformat(texto.replace("Z", "+00:00")).date()
    except ValueError:
        pass

    for formato in ("%Y-%m-%d", "%d/%m/%Y", "%Y-%m-%dT%H:%M:%S", "%Y/%m/%d"):
        try:
            return datetime.strptime(texto, formato).date()
        except ValueError:
            continue

    log.debug("data não reconhecida: %r", valor)
    return None


def coletar_clientes(client: SenseDataClient, cfg: Config) -> list[Cliente]:
    brutos = client.listar_clientes(status="active")
    log.info("clientes retornados pela API: %s", len(brutos))

    clientes = []
    for bruto in brutos:
        custom = bruto.get("custom_fields") or {}
        clientes.append(
            Cliente(
                id_cliente=str(bruto.get("id_cliente") or bruto.get("id") or ""),
                nome=bruto.get("name") or bruto.get("nome") or "",
                cs_responsavel=bruto.get("cs") or bruto.get("owner") or None,
                dt_inicio_contrato=_para_data(bruto.get("start_date") or bruto.get("dt_inicio")),
                cs_feeling=custom.get(cfg.campo_feeling),
            )
        )
    return [c for c in clientes if c.id_cliente]


def aplicar_anotacoes(clientes: list[Cliente], client: SenseDataClient, cfg: Config) -> None:
    """Preenche `dt_ultima_anotacao` a partir das anotações da base.

    Anotações de robô (integração de tickets, NPS, cobrança) não são
    acompanhamento de CS: se contarem, o contador nunca chega a 90 e a regra
    morre em silêncio. Por isso o filtro de autor.
    """
    try:
        anotacoes = client.listar_anotacoes()
    except SenseDataError as exc:
        log.warning(
            "endpoint de anotações indisponível (%s). "
            "dt_ultima_anotacao ficará vazia — ver README, 'Fonte de dados alternativa'.",
            exc,
        )
        return

    por_cliente: dict[str, date] = {}
    ignoradas = 0
    for anotacao in anotacoes:
        autor = str(anotacao.get("user") or anotacao.get("author") or "").lower()
        if autor in cfg.autores_ignorados:
            ignoradas += 1
            continue
        id_cliente = str(anotacao.get("id_cliente") or anotacao.get("customer_id") or "")
        dt = _para_data(anotacao.get("date") or anotacao.get("created_at"))
        if not id_cliente or dt is None:
            continue
        atual = por_cliente.get(id_cliente)
        if atual is None or dt > atual:
            por_cliente[id_cliente] = dt

    log.info("anotações: %s consideradas, %s ignoradas por autor", len(por_cliente), ignoradas)
    for cliente in clientes:
        cliente.dt_ultima_anotacao = por_cliente.get(cliente.id_cliente)


# ------------------------------------------------------------------- cálculo


def calcular(cliente: Cliente, hoje: date) -> tuple[date, int]:
    """Devolve (dt_marco, dias_sem_atualizacao).

    dias = MIN(dias desde a anotação, dias desde o feeling), que é o mesmo que
    contar a partir da **mais recente** das duas datas. MIN porque a regra do
    processo é "as duas coisas paradas" — ver runbook, seção 1.

    Sem nenhum dos dois, o marco é o início do contrato: dá um número finito e
    ordenável em vez de NULL, e o cliente entra na fila pela idade da conta.
    """
    candidatas = [d for d in (cliente.dt_ultima_anotacao, cliente.dt_ultima_feeling) if d]
    if candidatas:
        dt_marco = max(candidatas)
    else:
        dt_marco = cliente.dt_inicio_contrato or hoje

    return dt_marco, max((hoje - dt_marco).days, 0)


def nivel_para(dias: int) -> str:
    for limiar, nivel in NIVEIS:
        if dias >= limiar:
            return nivel
    return SEM_ALERTA


def decidir_alertas(
    clientes: list[Cliente],
    controle: Controle,
    cfg: Config,
    hoje: date,
    limite_diario: int | None,
) -> dict[str, tuple[str, date, int]]:
    """Decide, por cliente, o nível a gravar hoje.

    Devolve {id_cliente: (nivel, dt_marco, dias)}. O nível vem `nenhum` para todo
    cliente que já foi alertado naquele nível no ciclo atual.
    """
    if cfg.data_ativacao_regra and cfg.carencia_inicial:
        decorridos = (hoje - cfg.data_ativacao_regra).days
        if decorridos < cfg.carencia_inicial:
            log.warning(
                "carência ativa: %s de %s dias desde a ativação. "
                "Campos serão gravados, nenhum alerta será disparado.",
                decorridos,
                cfg.carencia_inicial,
            )
            return {c.id_cliente: (SEM_ALERTA, *calcular(c, hoje)) for c in clientes}

    pendentes: list[tuple[Cliente, str, date, int]] = []
    decisao: dict[str, tuple[str, date, int]] = {}

    for cliente in clientes:
        dt_marco, dias = calcular(cliente, hoje)
        candidato = nivel_para(dias)

        if candidato == SEM_ALERTA or controle.ja_alertado(cliente.id_cliente, candidato, dt_marco):
            decisao[cliente.id_cliente] = (SEM_ALERTA, dt_marco, dias)
        else:
            pendentes.append((cliente, candidato, dt_marco, dias))

    # Mais inativo primeiro: se houver corte diário, o pior caso sai antes.
    pendentes.sort(key=lambda item: item[3], reverse=True)

    if limite_diario is not None and len(pendentes) > limite_diario:
        log.warning(
            "%s alertas elegíveis, limite diário de %s. O excedente sai nos próximos runs.",
            len(pendentes),
            limite_diario,
        )
        adiados = pendentes[limite_diario:]
        pendentes = pendentes[:limite_diario]
        for cliente, _, dt_marco, dias in adiados:
            decisao[cliente.id_cliente] = (SEM_ALERTA, dt_marco, dias)

    for cliente, candidato, dt_marco, dias in pendentes:
        decisao[cliente.id_cliente] = (candidato, dt_marco, dias)

    return decisao


# --------------------------------------------------------------------- saída


def montar_payload(cliente: Cliente, nivel: str, dias: int, cfg: Config) -> dict:
    campos = {
        cfg.campo_dias: dias,
        cfg.campo_nivel: nivel,
    }
    if cliente.dt_ultima_anotacao:
        campos[cfg.campo_dt_anotacao] = cliente.dt_ultima_anotacao.isoformat()
    if cliente.dt_ultima_feeling:
        campos[cfg.campo_dt_feeling] = cliente.dt_ultima_feeling.isoformat()

    lider = cfg.lider_por_cs.get((cliente.cs_responsavel or "").lower())
    if lider:
        campos[cfg.campo_email_lider] = lider

    return {"id_cliente": cliente.id_cliente, "custom_fields": campos}


def executar(dry_run: bool, limite_diario: int | None, hoje: date | None = None) -> int:
    cfg = Config.from_env()
    hoje = hoje or date.today()
    client = SenseDataClient.from_env()

    clientes = coletar_clientes(client, cfg)
    aplicar_anotacoes(clientes, client, cfg)

    with closing(Controle(cfg.banco_controle)) as controle:
        for cliente in clientes:
            controle.registrar_feeling(cliente.id_cliente, cliente.cs_feeling, hoje)
        controle.commit()

        for cliente in clientes:
            cliente.dt_ultima_feeling = controle.dt_ultima_mudanca_feeling(cliente.id_cliente)

        decisao = decidir_alertas(clientes, controle, cfg, hoje, limite_diario)

        registros = []
        disparos: dict[str, int] = {}
        for cliente in clientes:
            nivel, dt_marco, dias = decisao[cliente.id_cliente]
            registros.append(montar_payload(cliente, nivel, dias, cfg))
            if nivel != SEM_ALERTA:
                disparos[nivel] = disparos.get(nivel, 0) + 1
                if not dry_run:
                    controle.marcar_alertado(cliente.id_cliente, nivel, dt_marco, hoje, dias)

        resumo = ", ".join(f"{n}={q}" for n, q in sorted(disparos.items())) or "nenhum"
        log.info("clientes avaliados: %s | alertas de hoje: %s", len(registros), resumo)

        if dry_run:
            log.info("--dry-run: nada gravado no SenseData nem no controle")
            for reg in registros[:10]:
                log.info("  %s", reg)
            return 0

        enviados = client.atualizar_campos_em_lote(registros)
        controle.commit()
        log.info("gravados %s clientes no SenseData", enviados)

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="calcula e loga, não grava em lugar nenhum")
    parser.add_argument("--limite-diario", type=int, default=None, help="teto de alertas por execução (rollout gradual)")
    parser.add_argument("--data", type=date.fromisoformat, default=None, help="data de referência (YYYY-MM-DD), para backfill")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
    return executar(args.dry_run, args.limite_diario, args.data)


if __name__ == "__main__":
    raise SystemExit(main())
