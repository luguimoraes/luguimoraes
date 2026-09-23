#!/usr/bin/env python3
"""Valida um JSON de gráfico/KPI do SenseData antes de entregar.

Uso:
    python3 validate_chart_json.py caminho/para/arquivo.json

Roda as checagens manuais que já pegaram bug real nesta conta (jsonschema nem
sempre está disponível no ambiente, então isso é tudo feito com json + regex
puros). Sai com código 0 se tudo passar, 1 se algo falhar.
"""
import json
import re
import sys

REQUIRED_TOP_LEVEL = ["chart_type", "columns", "fields", "query", "slots", "type"]


def check(label, condition, detail=""):
    status = "OK  " if condition else "FAIL"
    print(f"[{status}] {label}" + (f" — {detail}" if detail and not condition else ""))
    return condition


def main(path):
    with open(path, encoding="utf-8") as f:
        raw = f.read()

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"[FAIL] JSON inválido: {e}")
        return 1

    ok = True

    missing = [k for k in REQUIRED_TOP_LEVEL if k not in data]
    ok &= check("campos obrigatórios presentes", not missing, f"faltando: {missing}")

    ok &= check("slots == 2", data.get("slots") == 2, f"slots = {data.get('slots')!r}")

    columns = data.get("columns", [])
    fields_def = data.get("fields", {}).get("fields", {})
    col_fields = {c["field"] for c in columns if "field" in c}
    fdef_fields = set(fields_def.keys())

    missing_defs = col_fields - fdef_fields
    ok &= check(
        "todo field de columns tem entrada em fields.fields",
        not missing_defs,
        f"sem definição: {missing_defs}",
    )

    extra_defs = fdef_fields - col_fields
    if extra_defs:
        print(f"[INFO] fields.fields com entradas não usadas como coluna própria "
              f"(ok se usadas dentro de algum template): {extra_defs}")

    query = data.get("query", "")

    bare_percent = re.findall(r"%(?!\(|%)", query)
    ok &= check(
        "sem '%' solto na query (fora de %(nome)s ou %%)",
        len(bare_percent) == 0,
        f"{len(bare_percent)} ocorrência(s) encontrada(s)",
    )

    ok &= check(
        "aspas simples em número par na query",
        query.count("'") % 2 == 0,
        f"count = {query.count(chr(39))}",
    )

    ok &= check(
        "parênteses balanceados na query",
        query.count("(") == query.count(")"),
        f"'(' = {query.count('(')}, ')' = {query.count(')')}",
    )

    for col in columns:
        tmpl = col.get("template")
        if not tmpl:
            continue
        n = tmpl.count("#")
        ok &= check(
            f"template da coluna '{col.get('field')}' tem '#' em pares",
            n % 2 == 0,
            f"{n} ocorrência(s) de '#'",
        )
        dq = tmpl.count('"')
        ok &= check(
            f"template da coluna '{col.get('field')}' tem aspas duplas balanceadas",
            dq % 2 == 0,
            f"{dq} ocorrência(s) de '\"'",
        )

    print()
    print("RESULTADO: " + ("tudo passou ✅" if ok else "tem coisa pra corrigir ❌"))
    return 0 if ok else 1


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
