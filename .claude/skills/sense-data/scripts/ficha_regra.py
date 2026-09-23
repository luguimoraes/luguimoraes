#!/usr/bin/env python3
"""
Formata e revisa uma regra do SenseData descrita em JSON.

Uso:
  python3 ficha_regra.py regra.json            # um objeto ou uma lista de regras
  python3 ficha_regra.py regra.json --so-alertas
  python3 ficha_regra.py --exemplo              # imprime um JSON de exemplo

Formato:
{
  "nome": "NPS - RESPOSTA DETRATORA | ACIMA DE 5K",
  "status": "Ativo",
  "localizacao": "Fora das pastas",
  "atingir": "Contato",                      # Cliente | Contato
  "grupos": [                                # condições do mesmo grupo = E
    {"condicoes": [
      {"categoria": "Cliente", "campo": "Status", "operacao": "Igual a", "valor": "Ativo"},
      {"categoria": "NPS", "campo": "Avaliação NPS", "operacao": "Menor que", "valor": 7,
       "alimentado_por": "integracao"}       # opcional: integracao | api | regra | pessoa
    ]}
  ],
  "entre_grupos": "OU",                      # E | OU (quando há mais de um grupo)
  "recorrencia": {"data_inicio": "01/10/2026", "executar": "Todos os dias",
                  "parar": "Nunca", "atingir_novamente": "A cada intervalo de 7 dias"},
  "acoes": [
    {"tipo": "Email", "template": "Detratores", "enviar_para": "Contato",
     "remetente": "CS da Conta", "horario": "10:00", "remover_duplicados": true,
     "nao_enviar_apos_horario": true, "criar_tarefa": true},
    {"tipo": "Alerta", "texto": "Detrator estratégico", "destinatario": "CS"},
    {"tipo": "Atualização", "atributo": "Cliente", "campo": "CS", "valor": "<usuário>",
     "transferir_atividades": "antigo_responsavel"},  # antigo_responsavel | todas | nao
    {"tipo": "Playbook", "playbook": "Retorno detratores", "responsavel": "Manter padrão template"}
  ]
}

As verificações vêm do guia oficial e de padrões de campo (references/regras-avancadas.md).
Saída: a ficha em texto e uma lista de ERRO / ALERTA / INFO. Código de saída 1 se houver ERRO.
"""

import json
import re
import sys
import unicodedata

EXEMPLO = {
    "nome": "Chamados acima do SLA",
    "status": "Ativo",
    "localizacao": "Gatilhos de proteção",
    "atingir": "Cliente",
    "grupos": [{"condicoes": [
        {"categoria": "Suporte - Chamados", "campo": "Total de chamados acima do SLA",
         "operacao": "Maior que", "valor": 2}]}],
    "recorrencia": {"executar": "Todos os dias", "parar": "Nunca", "atingir_novamente": "A cada intervalo de 7 dias"},
    "acoes": [{"tipo": "Alerta", "texto": "Chamado acima do SLA", "destinatario": "CS"}],
}

REMETENTES_NATIVOS = {"cs da conta", "implementador da conta"}
ACOES_COM_EFEITO_REPETIDO = {"email", "formulario", "sms", "whatsapp", "playbook", "atividade",
                             "alerta", "webhook", "relatorio"}
DIARIAS = ("todos os dias", "segundas as sextas", "dias uteis")


def norm(s):
    s = unicodedata.normalize("NFKD", str(s or "")).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"\s+", " ", s).strip().lower()


def num(v):
    """Número a partir de 8999, "8.999", "4.999,99", "4999.99" ou "4999,99"."""
    if isinstance(v, bool):
        return None
    if isinstance(v, (int, float)):
        return float(v)
    s = str(v or "").strip()
    if "," in s:
        s = s.replace(".", "").replace(",", ".")
    elif re.fullmatch(r"\d{1,3}(\.\d{3})+", s):
        s = s.replace(".", "")
    try:
        return float(s)
    except ValueError:
        return None


# ------------------------------------------------------------------- ficha

def ficha(r):
    linhas = [f"Regra: {r.get('nome', '<sem nome>')}"]
    linhas.append(
        f"1. Informações — Nome: {r.get('nome', '?')} | Status: {r.get('status', '?')} | "
        f"Localização: {r.get('localizacao', 'Fora das pastas')} | Atingir: {r.get('atingir', '?')}")
    linhas.append("2. Condições —")
    grupos = r.get("grupos") or []
    for gi, g in enumerate(grupos):
        if gi:
            linhas.append(f"   {r.get('entre_grupos', 'E')}")
        letra = chr(ord("A") + gi)
        for ci, c in enumerate(g.get("condicoes") or []):
            prefixo = f"   Grupo {letra}: " if ci == 0 else "            E "
            extra = f"   [alimentado por: {c['alimentado_por']}]" if c.get("alimentado_por") else ""
            linhas.append(f"{prefixo}{c.get('categoria', '?')} | {c.get('campo', '?')} | "
                          f"{c.get('operacao', '?')} | {c.get('valor', '')}{extra}")
    rec = r.get("recorrencia") or {}
    linhas.append(
        f"3. Agendamento e recorrência — Data de início: {rec.get('data_inicio', '?')} | "
        f"Executar regra: {rec.get('executar', '?')} | Parar execução: {rec.get('parar', '?')} | "
        f"Atingir novamente: {rec.get('atingir_novamente', '?')}")
    linhas.append("4. Ações —")
    for a in r.get("acoes") or []:
        params = " | ".join(f"{k}: {v}" for k, v in a.items() if k != "tipo")
        linhas.append(f"   {a.get('tipo', '?')}: {params}")
    return "\n".join(linhas)


# --------------------------------------------------------------- verificações

def revisar(r):
    achados = []

    def add(nivel, codigo, msg):
        achados.append((nivel, codigo, msg))

    atingir = norm(r.get("atingir"))
    if atingir not in ("cliente", "clientes", "contato", "contatos"):
        add("ERRO", "R01", "Defina 'atingir' como Cliente ou Contato.")
    if not r.get("grupos"):
        add("ALERTA", "R02", "Sem condições: a regra atinge a base inteira.")
    if len(r.get("grupos") or []) > 1 and norm(r.get("entre_grupos")) not in ("e", "ou"):
        add("ALERTA", "R03", "Há mais de um grupo: defina 'entre_grupos' (E ou OU).")

    todas = [c for g in r.get("grupos") or [] for c in g.get("condicoes") or []]

    for gi, g in enumerate(r.get("grupos") or []):
        conds = g.get("condicoes") or []
        letra = chr(ord("A") + gi)
        # Igual a com valores diferentes no mesmo campo, no mesmo grupo (E)
        iguais = {}
        for c in conds:
            if norm(c.get("operacao")) == "igual a":
                iguais.setdefault(norm(c.get("campo")), set()).add(norm(c.get("valor")))
        for campo, valores in iguais.items():
            if len(valores) > 1:
                add("ERRO", "R04", f"Grupo {letra}: '{campo}' Igual a {sorted(valores)} ao mesmo tempo nunca é "
                                   "verdadeiro (condições do mesmo grupo são E). Use grupos separados com OU.")
        # faixa vazia: Maior que X E Menor que Y com X >= Y
        faixas = {}
        for c in conds:
            op, v = norm(c.get("operacao")), num(c.get("valor"))
            if v is None:
                continue
            f = faixas.setdefault(norm(c.get("campo")), {"min": None, "max": None})
            if op.startswith("maior"):
                f["min"] = v if f["min"] is None else max(f["min"], v)
            elif op.startswith("menor"):
                f["max"] = v if f["max"] is None else min(f["max"], v)
        for campo, f in faixas.items():
            if f["min"] is not None and f["max"] is not None and f["min"] >= f["max"]:
                add("ERRO", "R05", f"Grupo {letra}: '{campo}' maior que {f['min']:g} e menor que {f['max']:g} é uma faixa vazia.")

    for c in todas:
        campo, op, valor = norm(c.get("campo")), norm(c.get("operacao")), c.get("valor")
        v = num(valor)
        if op == "maior que" and v == 1 and re.search(r"atras|vencid|chamad|titul|ticket|pendenc", campo):
            add("ALERTA", "R06", f"'{c.get('campo')}' Maior que 1 só atinge quem tem 2 ou mais. Para 'algum', use Maior que 0.")
        if op in ("contem", "contém") and norm(valor) == "ativo":
            add("ALERTA", "R07", "'Contém ativo' também casa 'Inativo'. Prefira 'Igual a Ativo' com a grafia confirmada.")
        if op == "igual a" and isinstance(valor, str) and campo in ("status", "fase", "porte") and valor[:1].islower():
            add("INFO", "R08", f"Valor '{valor}' em minúsculas no campo {c.get('campo')}: texto diferencia maiúsculas. Confirme a grafia na tela.")
        if op == "igual a" and v is not None and re.search(r"\bdias\b|dias_|_dias", campo):
            add("ALERTA", "R09", f"'{c.get('campo')}' Igual a {valor}: dispara uma vez, mas se o cálculo falhar nesse dia o alerta é perdido. "
                                 "Considere janela (≥ e <) ou campo de nível.")
        if c.get("alimentado_por") in ("integracao", "api"):
            add("INFO", "R10", f"'{c.get('campo')}' é alimentado por {c['alimentado_por']}: agende a regra depois da carga/rotina, com folga.")
        if norm(c.get("categoria")) == "nps" and atingir.startswith("cliente"):
            add("ALERTA", "R11", "Condição de NPS com 'Atingir: Cliente': todos os contatos do cliente recebem a ação. Use 'Atingir: Contato'.")

    rec = r.get("recorrencia") or {}
    executar, novamente = norm(rec.get("executar")), norm(rec.get("atingir_novamente"))
    acoes = r.get("acoes") or []
    tipos = [norm(a.get("tipo")) for a in acoes]
    tipos_repetidos = [a.get("tipo") for a, t in zip(acoes, tipos) if t in ACOES_COM_EFEITO_REPETIDO]
    if any(executar.startswith(d) for d in DIARIAS) and novamente == "sempre" and tipos_repetidos:
        add("ALERTA", "R12", f"Execução diária + 'Atingir novamente: Sempre' com {', '.join(tipos_repetidos)}: enquanto a condição valer, "
                             "a ação se repete todo dia. Use Nunca, 'A cada intervalo de N dias', janela ou campo de nível.")
    if not rec.get("atingir_novamente"):
        add("ALERTA", "R13", "Defina 'Atingir novamente o mesmo cliente'.")
    if norm(rec.get("parar")) not in ("", "nunca") and "ocorr" not in norm(rec.get("parar")) and not re.search(r"\d", str(rec.get("parar"))):
        add("INFO", "R14", f"Parar execução = {rec.get('parar')!r}: confirme a data/ocorrências.")

    if not acoes:
        add("ERRO", "R15", "Nenhuma ação.")
    for a in acoes:
        t = norm(a.get("tipo"))
        if t == "alerta" and not a.get("destinatario"):
            add("ERRO", "R16", "Alerta sem destinatário.")
        if t in ("atualizacao", "atualização") and norm(a.get("campo")) in ("cs", "responsavel", "csm") \
                and norm(a.get("transferir_atividades")) in ("", "nao", "não", "false"):
            add("ALERTA", "R17", "Troca de responsável sem transferir as atividades em aberto: elas ficam com o CS antigo.")
        if t in ("atualizacao", "atualização") and norm(a.get("campo")) == "status" and norm(a.get("valor")).startswith("inativ"):
            add("INFO", "R18", "Inativação por regra altera só o status: data e motivo do cancelamento ficam para preencher à mão.")
        if t == "distribuicao automatica" and not a.get("usuarios"):
            add("ERRO", "R19", "Distribuição automática sem usuários.")
        if t == "playbook":
            add("INFO", "R20", f"Confirme que o playbook '{a.get('playbook', '?')}' está Ativo.")
        if t in ("email", "formulario"):
            rem = a.get("remetente")
            if not rem:
                add("ALERTA", "R21", f"{a.get('tipo')}: defina o remetente.")
            elif "@" not in str(rem) and norm(rem) not in REMETENTES_NATIVOS:
                guardado = any(norm(c.get("campo")) == norm(rem) for c in todas)
                if not guardado:
                    add("ALERTA", "R22", f"Remetente dinâmico '{rem}' sem condição de guarda: onde o campo estiver vazio, "
                                         f"o e-mail sai pelo remetente padrão (CS da conta). Adicione '{rem} não vazio' ou aceite o fallback.")
            if not a.get("remover_duplicados"):
                add("INFO", "R23", f"{a.get('tipo')}: considere 'Remover e-mails duplicados entre clientes'.")
            if not a.get("horario"):
                add("INFO", "R24", f"{a.get('tipo')}: defina 'Enviar email às' e, se fizer sentido, 'Não enviar mensagem após o horário'.")
            if t == "email" and not a.get("template"):
                add("ERRO", "R25", "Email sem template ('Criar email a partir de').")
            add("INFO", "R26", f"{a.get('tipo')}: faça 'Enviar Teste' e confira 'Ver amostra de destinatários' antes de ativar.")

    if norm(r.get("status")) == "ativo" and any(t in ("email", "formulario", "sms", "whatsapp") for t in tipos):
        add("INFO", "R27", "Regra de comunicação criada já como Ativa: considere criar Inativa, testar com uma condição que só atinja você e então ativar.")
    return achados


def main():
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return 2
    if args[0] == "--exemplo":
        print(json.dumps(EXEMPLO, ensure_ascii=False, indent=2))
        return 0
    so_alertas = "--so-alertas" in args
    with open(args[0], encoding="utf-8") as fh:
        dados = json.load(fh)
    regras = dados if isinstance(dados, list) else [dados]

    houve_erro = False
    ordem = {"ERRO": 0, "ALERTA": 1, "INFO": 2}
    for i, r in enumerate(regras):
        if i:
            print("\n" + "-" * 72 + "\n")
        if not so_alertas:
            print(ficha(r))
            print()
        achados = sorted(revisar(r), key=lambda x: ordem[x[0]])
        if not achados:
            print("Revisão: nenhum ponto de atenção.")
        for nivel, codigo, msg in achados:
            if so_alertas and nivel == "INFO":
                continue
            print(f"{nivel:<6} {codigo}  {msg}")
        houve_erro |= any(n == "ERRO" for n, _, _ in achados)
    return 1 if houve_erro else 0


if __name__ == "__main__":
    sys.exit(main())
