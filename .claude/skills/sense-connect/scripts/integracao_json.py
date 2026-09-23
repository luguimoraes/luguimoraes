#!/usr/bin/env python3
"""
Ferramenta para o JSON exportado de uma integração do SenseConnect.

Subcomandos:
  resumo   arquivo.json                 etapas, ligações, chaves e mapeamento
  decode   arquivo.json [--step ID]     mostra o SQL (Base64) de cada fonte
  build    --base X.json --sql Q.sql --out Y.json [--step ID] [--campos a,b]
                                        grava o SQL em Base64 (com round-trip),
                                        refaz o output_schema da fonte e o
                                        mapeamento do carregamento
  validar  arquivo.json                 grafo Início→Fim, chaves, mapeamento,
                                        credenciais expostas
  redigir  arquivo.json --out Y.json    remove connection_params

Estrutura observada em campo (não é documentação oficial): veja
references/json-integracao.md. Só usa a biblioteca padrão.
"""

import argparse
import base64
import copy
import json
import re
import sys
from collections import defaultdict, deque

REDIGIDO = "REDACTED__preencher_no_ambiente_SenseData"


# --------------------------------------------------------------------- leitura

def carregar(caminho):
    with open(caminho, encoding="utf-8") as fh:
        return json.load(fh)


def salvar(dados, caminho):
    with open(caminho, "w", encoding="utf-8") as fh:
        json.dump(dados, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def etapas(dados):
    return dados.get("steps", {}) or {}


def etapas_por_tipo(dados, tipo):
    return {sid: s for sid, s in etapas(dados).items() if s.get("item_type") == tipo}


def fontes_sql(dados):
    """Fontes com query em Base64 (ex.: PostgreSQL)."""
    saida = {}
    for sid, s in etapas_por_tipo(dados, "data_source").items():
        params = (s.get("args") or {}).get("integration_params") or {}
        if isinstance(params, dict) and params.get("query"):
            saida[sid] = s
    return saida


def decodificar_query(etapa):
    b64 = etapa["args"]["integration_params"]["query"]
    return base64.b64decode(b64).decode("utf-8")


def escolher_fonte_sql(dados, step):
    fontes = fontes_sql(dados)
    if step is not None:
        step = str(step)
        if step not in fontes:
            raise SystemExit(f"A etapa {step} não é uma fonte com SQL. Fontes com SQL: {sorted(fontes)}")
        return step
    if len(fontes) != 1:
        raise SystemExit(f"Informe --step. Fontes com SQL encontradas: {sorted(fontes) or 'nenhuma'}")
    return next(iter(fontes))


def sucessores(dados):
    grafo = defaultdict(list)
    for dep in dados.get("steps_dependency", []) or []:
        grafo[str(dep.get("item_id"))].append(str(dep.get("dependency_id")))
    return grafo


def antecessores(dados):
    grafo = defaultdict(list)
    for dep in dados.get("steps_dependency", []) or []:
        grafo[str(dep.get("dependency_id"))].append(str(dep.get("item_id")))
    return grafo


def rotulo(dados, sid):
    s = etapas(dados).get(str(sid), {})
    return f"{s.get('name', '?')} [{s.get('item_type', '?')} #{sid}]"


# ------------------------------------------------------------------------- SQL

def colunas_do_select(sql):
    """Aliases do SELECT final (último SELECT ... FROM de nível superior)."""
    sem_coment = re.sub(r"--[^\n]*", "", sql)
    sem_coment = re.sub(r"/\*.*?\*/", "", sem_coment, flags=re.S)

    # Localiza o último SELECT no nível de parênteses 0.
    nivel, ultimo_select = 0, None
    for m in re.finditer(r"\(|\)|\bSELECT\b", sem_coment, flags=re.I):
        tok = m.group(0)
        if tok == "(":
            nivel += 1
        elif tok == ")":
            nivel -= 1
        elif nivel == 0:
            ultimo_select = m.end()
    if ultimo_select is None:
        raise SystemExit("Não encontrei o SELECT final da query.")

    resto = sem_coment[ultimo_select:]
    # Corpo até o FROM de nível 0.
    nivel, fim = 0, None
    for m in re.finditer(r"\(|\)|\bFROM\b", resto, flags=re.I):
        tok = m.group(0)
        if tok == "(":
            nivel += 1
        elif tok == ")":
            nivel -= 1
        elif nivel == 0:
            fim = m.start()
            break
    corpo = resto[:fim] if fim is not None else resto
    corpo = re.sub(r"^\s*DISTINCT(\s+ON\s*\([^)]*\))?", "", corpo, flags=re.I)

    partes, atual, nivel = [], "", 0
    for ch in corpo:
        if ch == "(":
            nivel += 1
        elif ch == ")":
            nivel -= 1
        if ch == "," and nivel == 0:
            partes.append(atual)
            atual = ""
        else:
            atual += ch
    partes.append(atual)

    colunas = []
    for p in partes:
        p = p.strip()
        if not p:
            continue
        m = re.search(r"\bAS\s+(\"[^\"]+\"|[A-Za-z_][A-Za-z0-9_]*)\s*$", p, flags=re.I)
        if m:
            nome = m.group(1).strip('"')
        else:
            nome = p.split(".")[-1].strip().strip('"')
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", nome):
                raise SystemExit(f"Coluna sem alias explícito no SELECT final: {p!r}. Use AS nome.")
        colunas.append(nome)
    return colunas


def schema_fonte(colunas, anterior=None):
    anterior = (anterior or {}).get("fields", {}) if anterior else {}
    padrao = {
        "remove_dots_and_dash": False,
        "remove_special_char": False,
        "remove_whitespaces": False,
        "remove_zero_left": False,
        "treatment": "keep_original",
        "type": "text",
    }
    return {"fields": {c: copy.deepcopy(anterior.get(c, padrao)) for c in colunas}}


def mapeamento(colunas, campos_gravados, anterior=None):
    anterior = (anterior or {}).get("fields", {}) if anterior else {}
    campos = {}
    for c in colunas:
        if campos_gravados is not None:
            if c in campos_gravados:
                tipo = (anterior.get(c) or {}).get("type", "text")
                campos[c] = {"field_destiny": c, "options": "overwrite", "type": tipo}
            else:
                campos[c] = {"field_destiny": "", "options": "ignore", "type": "text"}
        else:
            campos[c] = copy.deepcopy(anterior.get(c) or {"field_destiny": "", "options": "ignore", "type": "text"})
    return {"fields": campos}


# ---------------------------------------------------------------- subcomandos

def cmd_resumo(args):
    dados = carregar(args.json)
    for iid, integ in (dados.get("integrations") or {}).items():
        print(f"Integração #{iid}: {integ.get('name')} (status={integ.get('status')})")
    for cid, con in (dados.get("connections") or {}).items():
        exposta = con.get("connection_params") not in (None, "", REDIGIDO)
        print(f"Conexão #{cid}: {con.get('name')} source={con.get('source')} "
              f"ativa={con.get('is_active')} credencial={'PRESENTE' if exposta else 'redigida/ausente'}")

    print("\nEtapas:")
    for sid, s in sorted(etapas(dados).items(), key=lambda kv: int(kv[0]) if kv[0].isdigit() else kv[0]):
        extra = ""
        a = s.get("args") or {}
        if s.get("item_type") == "data_source":
            p = a.get("integration_params") or {}
            extra = f" source={p.get('source')} conn={p.get('connection_id')} load_type={a.get('load_type')}"
            if p.get("query"):
                extra += " query=Base64"
        if s.get("item_type") == "load_data":
            extra = (f" destino={a.get('destiny_table')} integ_type={a.get('integ_type')} "
                     f"keys={a.get('keys')} customer_key={a.get('customer_key')}")
        print(f"  #{sid} {s.get('item_type')}: {s.get('name')}{extra}")

    print("\nLigações:")
    for dep in dados.get("steps_dependency", []) or []:
        print(f"  {rotulo(dados, dep.get('item_id'))} → {rotulo(dados, dep.get('dependency_id'))}")

    for sid, s in etapas_por_tipo(dados, "load_data").items():
        print(f"\nMapeamento do carregamento #{sid}:")
        for col, f in ((s.get("output_schema") or {}).get("fields") or {}).items():
            destino = f.get("field_destiny") or "—"
            print(f"  {col:<32} {f.get('options', '?'):<10} → {destino} ({f.get('type')})")


def cmd_decode(args):
    dados = carregar(args.json)
    fontes = fontes_sql(dados)
    if args.step:
        fontes = {str(args.step): fontes[str(args.step)]} if str(args.step) in fontes else {}
    if not fontes:
        raise SystemExit("Nenhuma fonte com SQL encontrada.")
    for sid, s in fontes.items():
        print(f"-- ===== etapa #{sid}: {s.get('name')} =====")
        print(decodificar_query(s))
        print()


def cmd_build(args):
    dados = carregar(args.base)
    sid = escolher_fonte_sql(dados, args.step)
    with open(args.sql, encoding="utf-8") as fh:
        sql = fh.read().strip()

    colunas = colunas_do_select(sql)
    campos = None
    if args.campos is not None:
        campos = [c.strip() for c in args.campos.split(",") if c.strip()]
        faltando = [c for c in campos if c not in colunas]
        if faltando:
            raise SystemExit(f"Campos de destino fora do SELECT: {faltando}. Colunas: {colunas}")

    b64 = base64.b64encode(sql.encode("utf-8")).decode("ascii")
    assert base64.b64decode(b64).decode("utf-8") == sql, "Falha no round-trip Base64"

    fonte = etapas(dados)[sid]
    fonte["args"]["integration_params"]["query"] = b64
    fonte["output_schema"] = schema_fonte(colunas, fonte.get("output_schema"))

    # Carregamentos ligados (direta ou indiretamente) a esta fonte.
    succ = sucessores(dados)
    vistos, fila, cargas = {sid}, deque([sid]), []
    while fila:
        atual = fila.popleft()
        for prox in succ.get(atual, []):
            if prox in vistos:
                continue
            vistos.add(prox)
            fila.append(prox)
            if etapas(dados).get(prox, {}).get("item_type") == "load_data":
                cargas.append(prox)

    avisos = []
    for cid in cargas:
        carga = etapas(dados)[cid]
        antecessor_direto = sid in antecessores(dados).get(cid, [])
        chaves = (carga.get("args") or {}).get("keys") or []
        if antecessor_direto:
            ausentes = [k for k in chaves if k not in colunas]
            if ausentes:
                raise SystemExit(f"A query não devolve a(s) chave(s) do carregamento #{cid}: {ausentes}")
            carga["output_schema"] = mapeamento(colunas, campos, carga.get("output_schema"))
        else:
            avisos.append(f"carregamento #{cid} não é ligado direto à fonte; mapeamento não alterado")

    salvar(dados, args.out)
    print(f"OK -> {args.out}")
    print(f"  fonte #{sid}: {len(colunas)} colunas: {', '.join(colunas)}")
    if campos is not None:
        print(f"  gravadas (Sobrescrever): {', '.join(campos) or '(nenhuma)'}")
    for cid in cargas:
        print(f"  carregamento #{cid}: keys={(etapas(dados)[cid].get('args') or {}).get('keys')}")
    print(f"  Base64 com {len(b64)} caracteres, validado por round-trip")
    for a in avisos:
        print(f"  AVISO: {a}")


def validar(dados):
    erros, avisos = [], []
    st = etapas(dados)
    if not st:
        return ["sem 'steps'"], avisos

    inicios = [sid for sid, s in st.items() if s.get("item_type") == "start"]
    fins = [sid for sid, s in st.items() if s.get("item_type") == "end"]
    if len(inicios) != 1:
        erros.append(f"esperado 1 Início, encontrado {len(inicios)}")
    if len(fins) != 1:
        erros.append(f"esperado 1 Fim, encontrado {len(fins)}")
    if not etapas_por_tipo(dados, "data_source"):
        erros.append("nenhuma fonte de dados (data_source)")
    if not etapas_por_tipo(dados, "load_data"):
        erros.append("nenhum carregamento (load_data)")

    for dep in dados.get("steps_dependency", []) or []:
        for lado in ("item_id", "dependency_id"):
            if str(dep.get(lado)) not in st:
                erros.append(f"ligação aponta para etapa inexistente: {lado}={dep.get(lado)}")

    succ, ante = sucessores(dados), antecessores(dados)

    def alcancaveis(origem, grafo):
        vistos, fila = {origem}, deque([origem])
        while fila:
            for prox in grafo.get(fila.popleft(), []):
                if prox not in vistos:
                    vistos.add(prox)
                    fila.append(prox)
        return vistos

    if len(inicios) == 1 and len(fins) == 1:
        a_partir_inicio = alcancaveis(inicios[0], succ)
        ate_fim = alcancaveis(fins[0], ante)
        for sid in st:
            if sid not in a_partir_inicio:
                erros.append(f"{rotulo(dados, sid)} não é alcançada a partir do Início")
            if sid not in ate_fim:
                erros.append(f"{rotulo(dados, sid)} não chega ao Fim")

    for sid, s in fontes_sql(dados).items():
        try:
            sql = decodificar_query(s)
        except Exception as exc:  # noqa: BLE001
            erros.append(f"{rotulo(dados, sid)}: query não é Base64 UTF-8 válido ({exc})")
            continue
        if re.search(r",\s*(IS\s+NOT\s+NULL|IS\s+NULL|FROM|WHERE)\b", sql, flags=re.I):
            erros.append(f"{rotulo(dados, sid)}: vírgula solta antes de IS NULL/FROM/WHERE (Base64 montado à mão?)")
        try:
            cols = colunas_do_select(sql)
        except SystemExit as exc:
            avisos.append(f"{rotulo(dados, sid)}: {exc}")
            cols = None
        schema = list(((s.get("output_schema") or {}).get("fields") or {}).keys())
        if cols is not None and schema and sorted(cols) != sorted(schema):
            erros.append(f"{rotulo(dados, sid)}: colunas da query {cols} ≠ output_schema {schema}")

    for sid, s in etapas_por_tipo(dados, "load_data").items():
        a = s.get("args") or {}
        chaves = a.get("keys") or []
        if not chaves:
            avisos.append(f"{rotulo(dados, sid)}: sem 'keys' (carga sem chave só insere)")
        if a.get("integ_type") not in ("update", "upsert", None):
            avisos.append(f"{rotulo(dados, sid)}: integ_type desconhecido {a.get('integ_type')!r}")
        campos = (s.get("output_schema") or {}).get("fields") or {}
        for col, f in campos.items():
            if f.get("options") == "overwrite" and not f.get("field_destiny"):
                erros.append(f"{rotulo(dados, sid)}: '{col}' em Sobrescrever sem campo de destino")
            destino = f.get("field_destiny") or ""
            if destino and not re.fullmatch(r"[a-z0-9_]+", destino):
                erros.append(f"{rotulo(dados, sid)}: destino '{destino}' fora do padrão a-z0-9_")
        for k in chaves:
            if campos and k not in campos:
                avisos.append(f"{rotulo(dados, sid)}: chave '{k}' não aparece no mapeamento")
            elif campos.get(k, {}).get("options") == "overwrite":
                avisos.append(f"{rotulo(dados, sid)}: chave '{k}' está em Sobrescrever (normalmente fica em Ignorar)")
        for aid in antecessores(dados).get(sid, []):
            origem = st.get(aid, {})
            schema = (origem.get("output_schema") or {}).get("fields") or {}
            if schema:
                for k in chaves:
                    if k not in schema:
                        erros.append(f"{rotulo(dados, sid)}: chave '{k}' não existe na saída de {rotulo(dados, aid)}")
        if not any((f.get("options") == "overwrite") for f in campos.values()):
            avisos.append(f"{rotulo(dados, sid)}: nenhum campo em Sobrescrever (a carga não grava nada?)")

    for cid, con in (dados.get("connections") or {}).items():
        if con.get("connection_params") not in (None, "", REDIGIDO):
            avisos.append(f"conexão #{cid} ({con.get('name')}) com connection_params presente: redija antes de compartilhar")
        nome = (con.get("name") or "").lower()
        if any(t in nome for t in ("hom", "homolog", "stag", "teste", "test", "dev")):
            avisos.append(f"conexão #{cid} ({con.get('name')}) parece ser de homologação: troque antes de produção")

    return erros, avisos


def cmd_validar(args):
    dados = carregar(args.json)
    erros, avisos = validar(dados)
    for e in erros:
        print(f"ERRO:  {e}")
    for a in avisos:
        print(f"AVISO: {a}")
    if not erros and not avisos:
        print("OK: nenhum problema encontrado")
    elif not erros:
        print("OK com avisos")
    return 1 if erros else 0


def cmd_redigir(args):
    dados = carregar(args.json)
    n = 0
    for con in (dados.get("connections") or {}).values():
        if "connection_params" in con and con["connection_params"] not in (None, "", REDIGIDO):
            con["connection_params"] = REDIGIDO
            n += 1
    salvar(dados, args.out)
    print(f"OK -> {args.out} ({n} credencial(is) redigida(s))")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("resumo", help="etapas, ligações, chaves e mapeamento")
    p.add_argument("json")
    p.set_defaults(func=cmd_resumo)

    p = sub.add_parser("decode", help="mostra o SQL de cada fonte")
    p.add_argument("json")
    p.add_argument("--step")
    p.set_defaults(func=cmd_decode)

    p = sub.add_parser("build", help="grava um .sql na fonte e refaz o mapeamento")
    p.add_argument("--base", required=True)
    p.add_argument("--sql", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--step")
    p.add_argument("--campos", help="colunas gravadas (Sobrescrever), separadas por vírgula")
    p.set_defaults(func=cmd_build)

    p = sub.add_parser("validar", help="checa grafo, chaves, mapeamento e credenciais")
    p.add_argument("json")
    p.set_defaults(func=cmd_validar)

    p = sub.add_parser("redigir", help="remove connection_params")
    p.add_argument("json")
    p.add_argument("--out", required=True)
    p.set_defaults(func=cmd_redigir)

    args = parser.parse_args()
    return args.func(args) or 0


if __name__ == "__main__":
    sys.exit(main())
