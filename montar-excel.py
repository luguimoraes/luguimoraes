#!/usr/bin/env python3
"""Monta o Excel de duas abas da reativacao de contatos.

Uso:
    python3 montar-excel.py export.csv selecao.csv [contatos-reativacao.xlsx]

    export.csv    export de contatos do SenseData, com as 41 colunas
    selecao.csv   saida de abas-reativacao.sql: chave + veredito

Saem:

    contatos-reativacao.xlsx   aba "Inativos (de-para)" e aba "Manutencao CSV"
    manutencao.csv             o arquivo que realmente sobe

As duas abas tem papeis diferentes e nao sao o mesmo recorte de colunas:

    Inativos (de-para)   as 41 colunas do export + as de controle da selecao.
                         E a aba de conferencia: quem ficou inativo e por que.
                         O 'Ativo' aqui e o estado ATUAL, ou seja, False.

    Manutencao CSV       duas colunas: 'ID Contato' e 'Ativo' = Sim. E o que
                         sobe. A manutencao casa por ID e grava so as colunas
                         presentes no arquivo, entao duas colunas nao tem como
                         apagar Cargo, Telefone ou Benchmarking de ninguem.

O arquivo que sobe sai da SELECAO, nao do export: se o export vier incompleto,
a aba de conferencia sai furada mas a reativacao continua inteira.

Os dois arquivos precisam da coluna 'ID Contato'. Sem ela nao da para separar
dois contatos que dividem o mesmo e-mail na mesma conta — que e justamente o
caso do alvo.

O cabecalho do export sai byte a byte como entrou. 'Brand ' e 'Produto ' tem
espaco no fim de verdade; se o script aparar, a manutencao nao reconhece.

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

COL_ID = "ID Contato"
COL_ATIVO = "Ativo"
COL_ENTRA = "_Entra no arquivo"
VALOR_ATIVO = "Sim"
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
        dialeto = csv.excel
    linhas = [l for l in csv.reader(bruto.splitlines(), dialeto) if any(c.strip() for c in l)]
    if not linhas:
        raise SystemExit(f"{caminho}: nenhuma linha util")
    return linhas[0], linhas[1:]


def indice(cabecalho, nome, onde):
    for i, coluna in enumerate(cabecalho):
        if coluna.strip() == nome:
            return i
    raise SystemExit(f"{onde}: falta a coluna {nome!r}")


def campo(linha, i):
    return linha[i].strip() if i < len(linha) else ""


def larguras(cabecalho, linhas):
    larg = [len(t) for t in cabecalho]
    for linha in linhas[:LINHAS_PARA_MEDIR]:
        for i, valor in enumerate(linha):
            if i < len(larg):
                larg[i] = max(larg[i], len(valor))
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
    if len(argv) < 3:
        raise SystemExit(__doc__)

    saida = Path(argv[3] if len(argv) > 3 else "contatos-reativacao.xlsx")
    cab_export, lin_export = ler_csv(argv[1])
    cab_selecao, lin_selecao = ler_csv(argv[2])

    i_id_exp = indice(cab_export, COL_ID, "export")
    i_id_sel = indice(cab_selecao, COL_ID, "selecao")
    i_entra = indice(cab_selecao, COL_ENTRA, "selecao")
    i_controle = [i for i, c in enumerate(cab_selecao) if c.strip().startswith("_")]
    controle = [cab_selecao[i].strip() for i in i_controle]

    veredito = {campo(l, i_id_sel): l for l in lin_selecao}
    if len(veredito) != len(lin_selecao):
        raise SystemExit(f"selecao: {COL_ID} repetido — a selecao devia ter um por contato")

    # O que sobe sai da selecao, nao do export: um export incompleto fura a aba
    # de conferencia, mas nao pode encolher a reativacao.
    # ordenado por ID para bater linha a linha com a saida de reativar-csv.sql
    lin_manutencao = sorted(([chave, VALOR_ATIVO]
                             for chave, l in veredito.items()
                             if campo(l, i_entra).lower() in VERDADEIRO),
                            key=lambda l: (len(l[0]), l[0]))

    cab_inativos = cab_export + controle
    lin_inativos = []
    for linha in lin_export:
        sel = veredito.get(campo(linha, i_id_exp))
        if sel is not None:
            lin_inativos.append(linha + [(sel[i] if i < len(sel) else "") for i in i_controle])

    wb = Workbook()
    montar_aba(wb.active, ABA_INATIVOS, cab_inativos, lin_inativos)
    montar_aba(wb.create_sheet(), ABA_MANUTENCAO, [COL_ID, COL_ATIVO], lin_manutencao)
    wb.save(saida)

    csv_manutencao = saida.with_name("manutencao.csv")
    with open(csv_manutencao, "w", encoding="utf-8-sig", newline="") as f:
        escritor = csv.writer(f)
        escritor.writerow([COL_ID, COL_ATIVO])
        escritor.writerows(lin_manutencao)

    print(f"{saida}")
    print(f"  {ABA_INATIVOS:<22} {len(lin_inativos):>6} linhas · {len(cab_inativos)} colunas")
    print(f"  {ABA_MANUTENCAO:<22} {len(lin_manutencao):>6} linhas · 2 colunas")
    print(f"{csv_manutencao}  <- e este que sobe")

    faltando = len(veredito) - len(lin_inativos)
    if faltando:
        print()
        print(f"  ATENCAO: {faltando} contatos da selecao nao estao no export.")
        print(f"  So a aba '{ABA_INATIVOS}' sai incompleta — o arquivo que sobe")
        print("  vem da selecao e continua inteiro. Reexporte incluindo os inativos.")


if __name__ == "__main__":
    main(sys.argv)
