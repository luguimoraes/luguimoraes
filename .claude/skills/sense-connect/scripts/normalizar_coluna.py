#!/usr/bin/env python3
"""
Converte nomes de coluna para o padrão aceito no mapeamento do SenseData
(e para nomes internos de campos customizados): só a-z, 0-9 e _.

Uso:
  python3 normalizar_coluna.py "Data do diagnóstico" "Farol Cliente sem %"
  python3 normalizar_coluna.py --arquivo cabecalho.csv    # usa a 1a linha (, ; | ou tab)

Regras: minúsculas, sem acento, qualquer outro caractere vira _, sem _ repetido
nem nas pontas. Nomes que começam com número recebem prefixo c_ (a tela não
proíbe, mas evita confusão em SQL). Duplicados depois da conversão são sinalizados.
"""

import argparse
import csv
import re
import sys
import unicodedata


def normalizar(nome, prefixar_numero=True):
    s = unicodedata.normalize("NFKD", nome).encode("ascii", "ignore").decode("ascii")
    s = s.lower()
    s = re.sub(r"[^a-z0-9]+", "_", s)
    s = re.sub(r"_+", "_", s).strip("_")
    if prefixar_numero and s[:1].isdigit():
        s = f"c_{s}"
    return s or "coluna"


def ler_cabecalho(caminho):
    with open(caminho, encoding="utf-8-sig", newline="") as fh:
        primeira = fh.readline()
    dialeto = csv.Sniffer().sniff(primeira, delimiters=",;|\t")
    return next(csv.reader([primeira], dialeto))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("nomes", nargs="*")
    p.add_argument("--arquivo")
    p.add_argument("--sem-prefixo", action="store_true", help="não prefixar nomes que começam com número")
    a = p.parse_args()

    nomes = list(a.nomes)
    if a.arquivo:
        nomes += ler_cabecalho(a.arquivo)
    if not nomes:
        p.print_help()
        return 2

    vistos = {}
    largura = max(len(n) for n in nomes)
    for n in nomes:
        novo = normalizar(n, not a.sem_prefixo)
        marca = ""
        if novo in vistos:
            marca = f"   <-- DUPLICADO com {vistos[novo]!r}"
        else:
            vistos[novo] = n
        print(f"{n:<{largura}}  ->  {novo}{marca}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
