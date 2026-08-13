#!/usr/bin/env python3
"""
Gera o JSON da integracao "Grupos_Economicos" do SenseData a partir de um
arquivo .sql, cuidando do encode Base64 do step 122 e do mapeamento de
campos do step 123.

Motivacao: o Base64 publicado no documento de estruturacao foi montado a
mao e saiu quebrado (virou  WHERE "group",  IS NOT NULL  -- virgula a
mais). Encode manual nao escala; este script elimina a classe do erro.

Uso:
    # apenas conferir o que esta no JSON hoje
    python3 gerar_integracao.py decode ../integracao/Grupos_Economicos.json

    # gerar a versao v1 (mesmo mapeamento de hoje)
    python3 gerar_integracao.py build \\
        --base ../integracao/Grupos_Economicos.json \\
        --sql  ../sql/10_query_v1_correcao_minima.sql \\
        --out  ../integracao/Grupos_Economicos_v1_correcao_minima.json \\
        --campos cs_feeling,anotacoes_grupo

    # gerar a versao v2 (campos dedicados de grupo)
    python3 gerar_integracao.py build \\
        --base ../integracao/Grupos_Economicos.json \\
        --sql  ../sql/20_query_v2_recomendada.sql \\
        --out  ../integracao/Grupos_Economicos_v2_recomendada.json \\
        --campos cs_feeling_grupo,anotacoes_grupo,conta_matriz_nome,grupo_atualizado_em
"""

import argparse
import base64
import json
import re
import sys

STEP_DATA_SOURCE = "122"
STEP_LOAD_DATA = "123"

# Colunas que a query devolve mas que NAO sao gravadas na conta.
# Servem para conferencia/auditoria no preview da integracao.
COLUNAS_SO_LEITURA = [
    "customer_id",
    "customer_id_legacy",
    "customer_name",
    "customer_cnpj",
    "customer_group",
]


def carregar(caminho):
    with open(caminho, encoding="utf-8") as fh:
        return json.load(fh)


def query_do_json(dados):
    b64 = dados["steps"][STEP_DATA_SOURCE]["args"]["integration_params"]["query"]
    return base64.b64decode(b64).decode("utf-8")


def colunas_do_select(sql):
    """Extrai os aliases do SELECT final (o ultimo SELECT ... FROM do arquivo)."""
    sem_comentario = re.sub(r"--[^\n]*", "", sql)
    blocos = re.findall(
        r"SELECT\s+(.*?)\s+FROM\s", sem_comentario, flags=re.S | re.I
    )
    if not blocos:
        raise SystemExit("Nao consegui identificar o SELECT final da query.")
    corpo = blocos[-1]

    colunas, atual, profundidade = [], "", 0
    for ch in corpo:
        if ch == "(":
            profundidade += 1
        elif ch == ")":
            profundidade -= 1
        if ch == "," and profundidade == 0:
            colunas.append(atual)
            atual = ""
        else:
            atual += ch
    colunas.append(atual)

    saida = []
    for col in colunas:
        col = col.strip()
        if not col:
            continue
        alias = re.split(r"\s+AS\s+", col, flags=re.I)[-1]
        saida.append(alias.strip().strip('"').split(".")[-1])
    return saida


def montar_output_schema(colunas):
    return {
        "fields": {
            nome: {
                "remove_dots_and_dash": False,
                "remove_special_char": False,
                "remove_whitespaces": False,
                "remove_zero_left": False,
                "treatment": "keep_original",
                "type": "text",
            }
            for nome in colunas
        }
    }


def montar_mapeamento(colunas, campos_gravados):
    campos = {}
    for nome in colunas:
        if nome in campos_gravados:
            campos[nome] = {
                "field_destiny": nome,
                "options": "overwrite",
                "type": "text",
            }
        else:
            campos[nome] = {"field_destiny": "", "options": "ignore", "type": "text"}
    return {"fields": campos}


def cmd_decode(args):
    dados = carregar(args.json)
    print(query_do_json(dados))


def cmd_build(args):
    dados = carregar(args.base)

    with open(args.sql, encoding="utf-8") as fh:
        sql = fh.read().strip()

    colunas = colunas_do_select(sql)
    campos_gravados = [c.strip() for c in args.campos.split(",") if c.strip()]

    faltando = [c for c in campos_gravados if c not in colunas]
    if faltando:
        raise SystemExit(
            f"Estes campos de destino nao existem no SELECT da query: {faltando}\n"
            f"Colunas encontradas: {colunas}"
        )

    for coluna in COLUNAS_SO_LEITURA:
        if coluna == "customer_id_legacy" and coluna not in colunas:
            raise SystemExit(
                "A query nao devolve customer_id_legacy, que e a chave de "
                "carga configurada no step 123."
            )

    b64 = base64.b64encode(sql.encode("utf-8")).decode("ascii")

    # Round-trip obrigatorio: garante que o que sera publicado e
    # exatamente o SQL revisado.
    assert base64.b64decode(b64).decode("utf-8") == sql, "Falha no round-trip Base64"

    dados["steps"][STEP_DATA_SOURCE]["args"]["integration_params"]["query"] = b64
    dados["steps"][STEP_DATA_SOURCE]["output_schema"] = montar_output_schema(colunas)
    dados["steps"][STEP_LOAD_DATA]["output_schema"] = montar_mapeamento(
        colunas, campos_gravados
    )

    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(dados, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    chaves = dados["steps"][STEP_LOAD_DATA]["args"]["keys"]
    print(f"OK -> {args.out}")
    print(f"  colunas da query : {', '.join(colunas)}")
    print(f"  gravados na conta: {', '.join(campos_gravados)}")
    print(f"  chave de carga   : {', '.join(chaves)}")
    print(f"  base64 ({len(b64)} chars) validado por round-trip")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_dec = sub.add_parser("decode", help="mostra o SQL que esta no JSON")
    p_dec.add_argument("json")
    p_dec.set_defaults(func=cmd_decode)

    p_bui = sub.add_parser("build", help="gera um novo JSON a partir de um .sql")
    p_bui.add_argument("--base", required=True)
    p_bui.add_argument("--sql", required=True)
    p_bui.add_argument("--out", required=True)
    p_bui.add_argument("--campos", required=True,
                       help="colunas gravadas na conta, separadas por virgula")
    p_bui.set_defaults(func=cmd_build)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    sys.exit(main())
