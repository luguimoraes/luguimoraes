"""Testes da lógica de inatividade.

    python -m pytest test_watchdog.py -q
    python test_watchdog.py          # sem pytest instalado
"""

from __future__ import annotations

import tempfile
from datetime import date, timedelta
from pathlib import Path

from watchdog_cs_feeling import (
    SEM_ALERTA,
    Cliente,
    Config,
    Controle,
    _para_data,
    calcular,
    decidir_alertas,
    nivel_para,
)

HOJE = date(2026, 9, 1)


def _cliente(id_cliente="c1", anotacao=None, feeling=None, inicio=None, cs="ana") -> Cliente:
    c = Cliente(
        id_cliente=id_cliente,
        nome=f"Grupo {id_cliente}",
        cs_responsavel=cs,
        dt_inicio_contrato=inicio or HOJE - timedelta(days=400),
        cs_feeling="Verde",
    )
    c.dt_ultima_anotacao = anotacao
    c.dt_ultima_feeling = feeling
    return c


def _controle() -> tuple[Controle, tempfile.TemporaryDirectory]:
    tmp = tempfile.TemporaryDirectory()
    return Controle(Path(tmp.name) / "controle.sqlite"), tmp


# ------------------------------------------------------------------ cálculo


def test_min_e_nao_max():
    """Anotação recente segura o alerta mesmo com feeling parado há meses.

    É a diferença entre MIN e MAX, e o erro aqui alertaria cliente ativo.
    """
    c = _cliente(anotacao=HOJE - timedelta(days=10), feeling=HOJE - timedelta(days=200))
    _, dias = calcular(c, HOJE)
    assert dias == 10, dias
    assert nivel_para(dias) == SEM_ALERTA


def test_ambos_parados_dispara():
    c = _cliente(anotacao=HOJE - timedelta(days=95), feeling=HOJE - timedelta(days=140))
    dt_marco, dias = calcular(c, HOJE)
    assert dias == 95
    assert dt_marco == HOJE - timedelta(days=95)
    assert nivel_para(dias) == "alerta_90"


def test_sem_historico_usa_inicio_de_contrato():
    c = _cliente(inicio=HOJE - timedelta(days=200))
    dt_marco, dias = calcular(c, HOJE)
    assert dt_marco == HOJE - timedelta(days=200)
    assert dias == 200


def test_escada_de_niveis():
    assert nivel_para(89) == SEM_ALERTA
    assert nivel_para(90) == "alerta_90"
    assert nivel_para(104) == "alerta_90"
    assert nivel_para(105) == "escalonamento_105"
    assert nivel_para(119) == "escalonamento_105"
    assert nivel_para(120) == "critico_120"
    assert nivel_para(500) == "critico_120"


# ------------------------------------------------------------- deduplicação


def test_dispara_uma_vez_so():
    """O mesmo cliente inativo não pode gerar e-mail todo dia."""
    controle, tmp = _controle()
    cfg = Config()
    try:
        c = _cliente(anotacao=HOJE - timedelta(days=90), feeling=HOJE - timedelta(days=90))

        d1 = decidir_alertas([c], controle, cfg, HOJE, None)
        assert d1["c1"][0] == "alerta_90"
        nivel, dt_marco, dias = d1["c1"]
        controle.marcar_alertado("c1", nivel, dt_marco, HOJE, dias)

        # Dia seguinte: 91 dias, mesmo marco, alerta já enviado.
        d2 = decidir_alertas([c], controle, cfg, HOJE + timedelta(days=1), None)
        assert d2["c1"][0] == SEM_ALERTA

        # E no dia 105 sobe de nível, porque é outro nível no mesmo marco.
        d3 = decidir_alertas([c], controle, cfg, HOJE + timedelta(days=15), None)
        assert d3["c1"][0] == "escalonamento_105"
    finally:
        controle.close()
        tmp.cleanup()


def test_ciclo_novo_alerta_de_novo():
    """CS atualiza, some de novo por 90 dias -> tem que alertar outra vez."""
    controle, tmp = _controle()
    cfg = Config()
    try:
        c = _cliente(anotacao=HOJE - timedelta(days=90), feeling=HOJE - timedelta(days=90))
        nivel, dt_marco, dias = decidir_alertas([c], controle, cfg, HOJE, None)["c1"]
        assert nivel == "alerta_90"
        controle.marcar_alertado("c1", nivel, dt_marco, HOJE, dias)

        # CS anota hoje; 90 dias depois o marco é outro.
        depois = HOJE + timedelta(days=90)
        c.dt_ultima_anotacao = HOJE
        assert decidir_alertas([c], controle, cfg, depois, None)["c1"][0] == "alerta_90"
    finally:
        controle.close()
        tmp.cleanup()


def test_job_que_falhou_nao_perde_o_alerta():
    """Pipeline fora do ar no dia 90: no dia 97 o alerta ainda tem que sair.

    É o motivo de a condição da regra não ser `dias = 90`.
    """
    controle, tmp = _controle()
    cfg = Config()
    try:
        c = _cliente(anotacao=HOJE - timedelta(days=97), feeling=HOJE - timedelta(days=97))
        assert decidir_alertas([c], controle, cfg, HOJE, None)["c1"][0] == "alerta_90"
    finally:
        controle.close()
        tmp.cleanup()


# ----------------------------------------------------------------- rollout


def test_limite_diario_prioriza_o_mais_inativo():
    controle, tmp = _controle()
    cfg = Config()
    try:
        clientes = [
            _cliente("c1", anotacao=HOJE - timedelta(days=91), feeling=HOJE - timedelta(days=91)),
            _cliente("c2", anotacao=HOJE - timedelta(days=300), feeling=HOJE - timedelta(days=300)),
            _cliente("c3", anotacao=HOJE - timedelta(days=95), feeling=HOJE - timedelta(days=95)),
        ]
        d = decidir_alertas(clientes, controle, cfg, HOJE, limite_diario=1)
        assert d["c2"][0] == "critico_120"      # 300 dias, o pior, sai primeiro
        assert d["c1"][0] == SEM_ALERTA
        assert d["c3"][0] == SEM_ALERTA
    finally:
        controle.close()
        tmp.cleanup()


def test_carencia_segura_tudo():
    controle, tmp = _controle()
    cfg = Config(data_ativacao_regra=HOJE - timedelta(days=10), carencia_inicial=30)
    try:
        c = _cliente(anotacao=HOJE - timedelta(days=400), feeling=HOJE - timedelta(days=400))
        nivel, _, dias = decidir_alertas([c], controle, cfg, HOJE, None)["c1"]
        assert nivel == SEM_ALERTA
        assert dias == 400  # o campo continua sendo calculado e gravado
    finally:
        controle.close()
        tmp.cleanup()


# ---------------------------------------------- histórico de CS Feeling


def test_baseline_nao_conta_como_atualizacao():
    """O primeiro run vê o valor atual, não uma atualização.

    Se a baseline contasse, o primeiro run gravaria "feeling atualizado hoje"
    para a base inteira e a régua ficaria muda pelos 90 dias seguintes ao
    go-live — parecendo quebrada justamente na janela em que a liderança está
    olhando para ela.
    """
    controle, tmp = _controle()
    try:
        controle.registrar_feeling("c1", "Verde", HOJE)
        assert controle.dt_ultima_mudanca_feeling("c1") is None
    finally:
        controle.close()
        tmp.cleanup()


def test_historico_so_registra_mudanca():
    controle, tmp = _controle()
    try:
        controle.registrar_feeling("c1", "Verde", HOJE)                     # baseline
        controle.registrar_feeling("c1", "Verde", HOJE + timedelta(days=1))  # sem mudança
        controle.registrar_feeling("c1", "Verde", HOJE + timedelta(days=2))  # sem mudança
        assert controle.dt_ultima_mudanca_feeling("c1") is None

        controle.registrar_feeling("c1", "Vermelho", HOJE + timedelta(days=3))
        assert controle.dt_ultima_mudanca_feeling("c1") == HOJE + timedelta(days=3)

        # Reabrir o cliente e sair sem mexer não é atualização.
        controle.registrar_feeling("c1", "Vermelho", HOJE + timedelta(days=9))
        assert controle.dt_ultima_mudanca_feeling("c1") == HOJE + timedelta(days=3)
    finally:
        controle.close()
        tmp.cleanup()


def test_sem_mudanca_de_feeling_cai_para_anotacao():
    """Cliente que nunca mexeu no feeling é medido pela anotação, não zerado."""
    controle, tmp = _controle()
    try:
        controle.registrar_feeling("c1", "Verde", HOJE - timedelta(days=150))  # baseline
        c = _cliente(anotacao=HOJE - timedelta(days=150))
        c.dt_ultima_feeling = controle.dt_ultima_mudanca_feeling("c1")
        _, dias = calcular(c, HOJE)
        assert dias == 150, dias
        assert nivel_para(dias) == "critico_120"
    finally:
        controle.close()
        tmp.cleanup()


# --------------------------------------------------------------- parsing


def test_parse_de_datas():
    assert _para_data("2026-09-01") == date(2026, 9, 1)
    assert _para_data("2026-09-01T13:45:00Z") == date(2026, 9, 1)
    assert _para_data("2026-09-01T13:45:00.123456") == date(2026, 9, 1)
    assert _para_data("01/09/2026") == date(2026, 9, 1)
    assert _para_data(None) is None
    assert _para_data("") is None
    assert _para_data("nao e data") is None


if __name__ == "__main__":
    falhas = 0
    for nome, fn in sorted(globals().items()):
        if nome.startswith("test_") and callable(fn):
            try:
                fn()
                print(f"  ok    {nome}")
            except AssertionError as exc:
                falhas += 1
                print(f"  FALHA {nome}: {exc}")
    print("\ntodos passaram" if not falhas else f"\n{falhas} falha(s)")
    raise SystemExit(1 if falhas else 0)
