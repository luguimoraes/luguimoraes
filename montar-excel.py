#!/usr/bin/env python3
"""Monta o Excel de duas abas da reativacao de contatos.

Uso:
    python3 montar-excel.py inativos.csv manutencao.csv [saida.xlsx]

    inativos.csv    export da aba 1 — todo contato inativo do escopo, com o
                    veredito e a marca de quem entra no arquivo
    manutencao.csv  export da aba 2 — o arquivo que vai para a manutencao

Gera um .xlsx com as duas abas. Tudo vai como TEXTO: Excel nao pode
transformar '132626-TAX' em outra coisa, nem cortar zero a esquerda, nem
reinterpretar data. O arquivo que sobe na manutencao continua sendo o CSV —
o Excel aqui e so para conferencia e para mandar para a Jaqueline.
"""

import csv
import sys
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

ABA_INATIVOS = "Inativos (de-para)"
ABA_MANUTENCAO = "Manutencao CSV"

LARGURA_MIN = 10
LARGURA_MAX = 46
LINHAS_PARA_MEDIR = 400


def ler_csv(caminho):
    """Le um CSV/TSV descobrindo o separador. Devolve (cabecalho, linhas)."""
    bruto = Path(caminho).read_text(encoding="utf-8-sig")
    if not bruto.strip():
        raise SystemExit(f"{caminho}: arquivo vazio")

    amostra = bruto[:8192]
    try:
        dialeto = csv.Sniffer().sniff(amostra, delimiters=",;\t|")
    except csv.Error:
        # sem pista: assume virgula, que e o padrao do export
        dialeto = csv.excel

    linhas = list(csv.reader(bruto.splitlines(), dialeto))
    linhas = [linha for linha in linhas if any(campo.strip() for campo in linha)]
    if not linhas:
        raise SystemExit(f"{caminho}: nenhuma linha util")

    cabecalho = [campo.strip() for campo in linhas[0]]
    return cabecalho, linhas[1:]


def larguras(cabecalho, linhas):
    larg = [len(titulo) for titulo in cabecalho]
    for linha in linhas[:LINHAS_PARA_MEDIR]:
        for i, campo in enumerate(linha):
            if i < len(larg):
                larg[i] = max(larg[i], len(campo))
    return [min(max(n + 2, LARGURA_MIN), LARGURA_MAX) for n in larg]


def montar_aba(wb, titulo, cabecalho, linhas, primeira):
    ws = wb.active if primeira else wb.create_sheet()
    ws.title = titulo

    ws.append(cabecalho)
    fundo = PatternFill("solid", fgColor="1F3864")
    for celula in ws[1]:
        celula.font = Font(bold=True, color="FFFFFF")
        celula.fill = fundo
        celula.alignment = Alignment(vertical="center", wrap_text=False)

    for linha in linhas:
        # tudo como texto, na largura do cabecalho
        valores = [(linha[i] if i < len(linha) else "") for i in range(len(cabecalho))]
        ws.append(valores)

    for linha in ws.iter_rows(min_row=2):
        for celula in linha:
            celula.data_type = "s"
            celula.alignment = Alignment(vertical="top")

    for i, largura in enumerate(larguras(cabecalho, linhas), start=1):
        ws.column_dimensions[get_column_letter(i)].width = largura

    ws.freeze_panes = "A2"
    if linhas:
        ws.auto_filter.ref = f"A1:{get_column_letter(len(cabecalho))}{len(linhas) + 1}"
    return ws


def main(argv):
    if len(argv) < 3:
        raise SystemExit(__doc__)

    inativos_csv, manutencao_csv = argv[1], argv[2]
    saida = argv[3] if len(argv) > 3 else "contatos-reativacao.xlsx"

    cab_inativos, lin_inativos = ler_csv(inativos_csv)
    cab_manutencao, lin_manutencao = ler_csv(manutencao_csv)

    wb = Workbook()
    montar_aba(wb, ABA_INATIVOS, cab_inativos, lin_inativos, primeira=True)
    montar_aba(wb, ABA_MANUTENCAO, cab_manutencao, lin_manutencao, primeira=False)
    wb.save(saida)

    print(f"{saida}")
    print(f"  {ABA_INATIVOS:<22} {len(lin_inativos):>6} linhas · {len(cab_inativos)} colunas")
    print(f"  {ABA_MANUTENCAO:<22} {len(lin_manutencao):>6} linhas · {len(cab_manutencao)} colunas")

    faltando = [c for c in cab_manutencao if c not in cab_inativos]
    if faltando:
        print(f"  aviso: colunas so na aba de manutencao: {', '.join(faltando)}")

    print()
    print("O upload na manutencao usa o CSV, nao este .xlsx.")


if __name__ == "__main__":
    main(sys.argv)
