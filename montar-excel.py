#!/usr/bin/env python3
"""Monta o Excel de duas abas da reativacao de contatos.

Uso:
    python3 montar-excel.py export.csv selecao.csv [contatos-reativacao.xlsx]

    export.csv    export de contatos do SenseData, com as 41 colunas
    selecao.csv   saida de abas-reativacao.sql: chave + veredito

As 41 colunas nao sao reconstruidas no SQL — elas ja vem preenchidas no
export. O banco so diz quais linhas entram e o script vira o Ativo. Saem:

    contatos-reativacao.xlsx   aba "Inativos (de-para)" e aba "Manutencao CSV"
    manutencao.csv             o arquivo que realmente sobe

O cruzamento e por 'ID Contato' quando as duas pontas tem a coluna; se nao,
cai para (ID Original, Email), sem caixa e sem espaco nas bordas — e essa
volta so vale se nenhuma conta tiver o mesmo e-mail em dois contatos, senao
nao ha como saber qual dos dois e a linha.

O cabecalho do export sai byte a byte como entrou. 'Brand ' e 'Produto ' tem
espaco no fim de verdade; se o script aparar, a manutencao nao reconhece a
coluna.

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
COL_CONTA = "ID Original"
COL_EMAIL = "Email"
COL_ATIVO = "Ativo"
COL_ENTRA = "_Entra no arquivo"
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


def tem(cabecalho, nome):
    return any(c.strip() == nome for c in cabecalho)


def indice(cabecalho, nome, onde):
    for i, coluna in enumerate(cabecalho):
        if coluna.strip() == nome:
            return i
    raise SystemExit(f"{onde}: falta a coluna {nome!r}")


def chaveiro(cabecalho, onde, por_id):
    """Devolve uma funcao que extrai a chave de uma linha."""
    if por_id:
        i = indice(cabecalho, COL_ID, onde)
        return lambda linha: linha[i].strip() if i < len(linha) else ""
    ic = indice(cabecalho, COL_CONTA, onde)
    ie = indice(cabecalho, COL_EMAIL, onde)
    return lambda linha: (
        linha[ic].strip().lower() if ic < len(linha) else "",
        linha[ie].strip().lower() if ie < len(linha) else "",
    )


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
    if len(argv) < 3:
        raise SystemExit(__doc__)

    saida = Path(argv[3] if len(argv) > 3 else "contatos-reativacao.xlsx")
    cab_export, lin_export = ler_csv(argv[1])
    cab_selecao, lin_selecao = ler_csv(argv[2])

    por_id = tem(cab_export, COL_ID) and tem(cab_selecao, COL_ID)
    chave_export = chaveiro(cab_export, "export", por_id)
    chave_selecao = chaveiro(cab_selecao, "selecao", por_id)

    i_controle = [i for i, c in enumerate(cab_selecao) if c.strip().startswith("_")]
    controle = [cab_selecao[i].strip() for i in i_controle]
    i_entra = indice(cab_selecao, COL_ENTRA, "selecao")
    i_ativo = indice(cab_export, COL_ATIVO, "export")

    veredito, repetidas = {}, 0
    for linha in lin_selecao:
        k = chave_selecao(linha)
        repetidas += k in veredito
        veredito[k] = linha
    if repetidas:
        raise SystemExit(
            f"selecao: {repetidas} linhas com a chave repetida "
            f"({COL_ID if por_id else f'{COL_CONTA} + {COL_EMAIL}'}).\n"
            f"Sem {COL_ID!r} nos dois arquivos nao da para separar dois contatos\n"
            f"que dividem o mesmo e-mail na mesma conta. Refaca o export com\n"
            f"a coluna {COL_ID!r}."
        )

    cab_inativos = cab_export + controle
    lin_inativos, lin_manutencao, achados = [], [], set()

    for linha in lin_export:
        k = chave_export(linha)
        sel = veredito.get(k)
        if sel is None:
            continue
        achados.add(k)
        extras = [(sel[i] if i < len(sel) else "") for i in i_controle]
        lin_inativos.append(linha + extras)
        if sel[i_entra].strip().lower() in VERDADEIRO:
            nova = list(linha) + [""] * (len(cab_export) - len(linha))
            nova[i_ativo] = "True"
            lin_manutencao.append(nova)

    wb = Workbook()
    montar_aba(wb.active, ABA_INATIVOS, cab_inativos, lin_inativos)
    montar_aba(wb.create_sheet(), ABA_MANUTENCAO, cab_export, lin_manutencao)
    wb.save(saida)

    csv_manutencao = saida.with_name("manutencao.csv")
    with open(csv_manutencao, "w", encoding="utf-8-sig", newline="") as f:
        escritor = csv.writer(f)
        escritor.writerow(cab_export)
        escritor.writerows(lin_manutencao)

    print(f"cruzamento por {COL_ID if por_id else f'{COL_CONTA} + {COL_EMAIL}'}")
    print(f"{saida}")
    print(f"  {ABA_INATIVOS:<22} {len(lin_inativos):>6} linhas · {len(cab_inativos)} colunas")
    print(f"  {ABA_MANUTENCAO:<22} {len(lin_manutencao):>6} linhas · {len(cab_export)} colunas")
    print(f"{csv_manutencao}  <- e este que sobe")

    faltando = len(veredito) - len(achados)
    if faltando:
        print()
        print(f"  ATENCAO: {faltando} contatos da selecao nao estao no export.")
        print("  O export precisa incluir os inativos, senao a aba sai incompleta.")


if __name__ == "__main__":
    main(sys.argv)
