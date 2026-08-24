#!/usr/bin/env python3
"""Monta o Excel de duas abas da reativacao de contatos.

Uso:
    python3 montar-excel.py inativos.csv [contatos-reativacao.xlsx]

Entra o export unico de `abas-reativacao.sql`. Saem:

    contatos-reativacao.xlsx   aba "Inativos (de-para)" com tudo
                               aba "Manutencao CSV" com o que vai subir
    manutencao.csv             o arquivo que realmente sobe

A aba da manutencao e o filtro `_Entra no arquivo` verdadeiro, sem as colunas
de controle (as que comecam com '_') e com Ativo = True. Uma query so, duas
abas: nao ha como as duas selecoes divergirem.

Tudo vai como TEXTO no xlsx: Excel nao transforma '132626-TAX' em outra coisa,
nem corta zero a esquerda, nem reinterpreta data.
"""

import csv
import sys
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

ABA_INATIVOS = "Inativos (de-para)"
ABA_MANUTENCAO = "Manutencao CSV"

COL_ENTRA = "_Entra no arquivo"
COL_ATIVO = "Ativo"
VERDADEIRO = {"t", "true", "sim", "s", "yes", "y", "1"}

LARGURA_MIN, LARGURA_MAX, LINHAS_PARA_MEDIR = 10, 46, 400


def ler_csv(caminho):
    """Le um CSV/TSV descobrindo o separador. Devolve (cabecalho, linhas)."""
    bruto = Path(caminho).read_text(encoding="utf-8-sig")
    if not bruto.strip():
        raise SystemExit(f"{caminho}: arquivo vazio")

    try:
        dialeto = csv.Sniffer().sniff(bruto[:8192], delimiters=",;\t|")
    except csv.Error:
        dialeto = csv.excel  # sem pista: virgula, que e o padrao do export

    linhas = [l for l in csv.reader(bruto.splitlines(), dialeto) if any(c.strip() for c in l)]
    if not linhas:
        raise SystemExit(f"{caminho}: nenhuma linha util")
    return [c.strip() for c in linhas[0]], linhas[1:]


def separar(cabecalho, linhas):
    """Divide o export em (tudo, arquivo da manutencao)."""
    if COL_ENTRA not in cabecalho:
        raise SystemExit(f"falta a coluna de controle {COL_ENTRA!r} no export")

    i_entra = cabecalho.index(COL_ENTRA)
    manter = [i for i, c in enumerate(cabecalho) if not c.startswith("_")]
    cab_manutencao = [cabecalho[i] for i in manter]
    i_ativo = cab_manutencao.index(COL_ATIVO) if COL_ATIVO in cab_manutencao else None

    lin_manutencao = []
    for linha in linhas:
        if linha[i_entra].strip().lower() not in VERDADEIRO:
            continue
        nova = [(linha[i] if i < len(linha) else "") for i in manter]
        if i_ativo is not None:
            nova[i_ativo] = "True"
        lin_manutencao.append(nova)

    return cab_manutencao, lin_manutencao


def larguras(cabecalho, linhas):
    larg = [len(t) for t in cabecalho]
    for linha in linhas[:LINHAS_PARA_MEDIR]:
        for i, campo in enumerate(linha):
            if i < len(larg):
                larg[i] = max(larg[i], len(campo))
    return [min(max(n + 2, LARGURA_MIN), LARGURA_MAX) for n in larg]


def montar_aba(ws, titulo, cabecalho, linhas):
    ws.title = titulo
    ws.append(cabecalho)
    fundo = PatternFill("solid", fgColor="1F3864")
    for celula in ws[1]:
        celula.font = Font(bold=True, color="FFFFFF")
        celula.fill = fundo

    for linha in linhas:
        ws.append([(linha[i] if i < len(linha) else "") for i in range(len(cabecalho))])

    for linha in ws.iter_rows(min_row=2):
        for celula in linha:
            celula.data_type = "s"
            celula.alignment = Alignment(vertical="top")

    for i, largura in enumerate(larguras(cabecalho, linhas), start=1):
        ws.column_dimensions[get_column_letter(i)].width = largura

    ws.freeze_panes = "A2"
    if linhas:
        ws.auto_filter.ref = f"A1:{get_column_letter(len(cabecalho))}{len(linhas) + 1}"


def main(argv):
    if len(argv) < 2:
        raise SystemExit(__doc__)

    entrada = argv[1]
    saida = Path(argv[2] if len(argv) > 2 else "contatos-reativacao.xlsx")
    csv_manutencao = saida.with_name("manutencao.csv")

    cabecalho, linhas = ler_csv(entrada)
    cab_manutencao, lin_manutencao = separar(cabecalho, linhas)

    wb = Workbook()
    montar_aba(wb.active, ABA_INATIVOS, cabecalho, linhas)
    montar_aba(wb.create_sheet(), ABA_MANUTENCAO, cab_manutencao, lin_manutencao)
    wb.save(saida)

    with open(csv_manutencao, "w", encoding="utf-8-sig", newline="") as f:
        escritor = csv.writer(f)
        escritor.writerow(cab_manutencao)
        escritor.writerows(lin_manutencao)

    print(f"{saida}")
    print(f"  {ABA_INATIVOS:<22} {len(linhas):>6} linhas · {len(cabecalho)} colunas")
    print(f"  {ABA_MANUTENCAO:<22} {len(lin_manutencao):>6} linhas · {len(cab_manutencao)} colunas")
    print(f"{csv_manutencao}  <- e este que sobe na manutencao")

    pendentes = sum(linha.count("<<TROCAR>>") for linha in lin_manutencao)
    if pendentes:
        print()
        print(f"  NAO SUBA: {pendentes} campos ainda com '<<TROCAR>>'.")
        print("  Rode descobrir-colunas.sql e termine o mapeamento primeiro.")


if __name__ == "__main__":
    main(sys.argv)
