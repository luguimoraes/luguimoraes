#!/usr/bin/env python3
"""
Valida o "Caminho de resposta" da fonte Outras APIs contra uma resposta de exemplo.

Uso:
  python3 validar_caminho_resposta.py resposta.json '$.custom_data'
  python3 validar_caminho_resposta.py resposta.json          # sugere caminhos válidos
  cat resposta.json | python3 validar_caminho_resposta.py - '$.data[0].items'

Regras do manual: começa com $, .chave entra num objeto, [n] entra numa lista
(começando em 0), e o ponto final precisa ser uma LISTA de OBJETOS. As chaves
desses objetos são as colunas que aparecem em "Editar tipo de campo".
"""

import json
import re
import sys

TOKEN = re.compile(r"\.([A-Za-z0-9_\-]+)|\[(\d+)\]")


def tipo(v):
    if isinstance(v, dict):
        return "um objeto"
    if isinstance(v, list):
        return "uma lista"
    if v is None:
        return "null"
    return f"um valor simples ({type(v).__name__})"


def percorrer(dados, caminho):
    if not caminho.startswith("$"):
        raise ValueError("o caminho precisa começar com $")
    pos, atual, feito = 1, dados, "$"
    while pos < len(caminho):
        m = TOKEN.match(caminho, pos)
        if not m:
            raise ValueError(f"trecho inválido em {caminho[pos:]!r} (use .chave ou [n])")
        chave, indice = m.group(1), m.group(2)
        if chave is not None:
            if not isinstance(atual, dict):
                raise ValueError(f"em {feito} há {tipo(atual)}; não dá para usar .{chave}")
            if chave not in atual:
                raise ValueError(f"a chave '{chave}' não existe em {feito}. Chaves: {', '.join(atual) or '(nenhuma)'}")
            atual, feito = atual[chave], f"{feito}.{chave}"
        else:
            n = int(indice)
            if not isinstance(atual, list):
                raise ValueError(f"em {feito} há {tipo(atual)}; não dá para usar [{n}]")
            if n >= len(atual):
                raise ValueError(f"{feito} tem {len(atual)} itens; [{n}] não existe (começa em 0)")
            atual, feito = atual[n], f"{feito}[{n}]"
        pos = m.end()
    return atual


def chaves_da_lista(lista):
    chaves = []
    for item in lista:
        if isinstance(item, dict):
            for k in item:
                if k not in chaves:
                    chaves.append(k)
    return chaves


def sugerir(dados, caminho="$", saida=None, profundidade=0):
    saida = [] if saida is None else saida
    if profundidade > 8:
        return saida
    if isinstance(dados, list):
        if dados and all(isinstance(i, dict) for i in dados):
            saida.append((caminho, len(dados), chaves_da_lista(dados)))
        for i, item in enumerate(dados[:1]):
            sugerir(item, f"{caminho}[{i}]", saida, profundidade + 1)
    elif isinstance(dados, dict):
        for k, v in dados.items():
            nome = f"{caminho}.{k}" if re.fullmatch(r"[A-Za-z0-9_\-]+", k) else None
            if nome:
                sugerir(v, nome, saida, profundidade + 1)
    return saida


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    fonte = sys.argv[1]
    texto = sys.stdin.read() if fonte == "-" else open(fonte, encoding="utf-8").read()
    dados = json.loads(texto)

    if len(sys.argv) < 3:
        opcoes = sugerir(dados)
        if not opcoes:
            print("Nenhum caminho termina numa lista de objetos. A API pode não ser compatível sem tratamento.")
            return 1
        print("Caminhos que terminam numa lista de objetos:")
        for caminho, n, chaves in opcoes:
            print(f"  {caminho}   ({n} itens; chaves: {', '.join(chaves)})")
        return 0

    caminho = sys.argv[2].strip()
    try:
        alvo = percorrer(dados, caminho)
    except ValueError as exc:
        print(f"ERRO: {exc}")
        return 1
    if not isinstance(alvo, list):
        print(f"ERRO: o caminho termina em {tipo(alvo)}, não em uma lista de objetos.")
        return 1
    if not alvo:
        print("AVISO: a lista está vazia nesta resposta; não dá para conferir as colunas.")
        return 0
    nao_objetos = [i for i in alvo if not isinstance(i, dict)]
    if nao_objetos:
        print(f"ERRO: a lista tem {len(nao_objetos)} item(ns) que não são objetos (ex.: {nao_objetos[0]!r}).")
        return 1
    chaves = chaves_da_lista(alvo)
    print(f"OK: {caminho} é uma lista com {len(alvo)} objeto(s).")
    print(f"Colunas disponíveis em 'Editar tipo de campo': {', '.join(chaves)}")
    aninhados = [k for k in chaves if any(isinstance(i.get(k), (dict, list)) for i in alvo)]
    if aninhados:
        print(f"Campos com JSON aninhado (use Separação > Json por atributo): {', '.join(aninhados)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
