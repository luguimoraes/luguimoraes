#!/usr/bin/env python3
"""Gera o CSV de Manutenção via CSV a partir dos exports do SenseData.

Não depende de API: recebe o export da tabela de clientes e o export da tabela
de usuários (ambos delimitados por "|", como saem da plataforma) e produz:

  * ``--out``     – arquivo pronto para Configurações > Clientes > Manutenção via
    CSV (ação Atualização), com o ID do cliente e o comercial resolvido;
  * ``--pending`` – clientes que ficaram sem comercial resolvido, com o motivo;
  * ``--report``  – opcional: todos os clientes analisados com o remetente atual
    (campo CS) ao lado do comercial resolvido, para dimensionar o impacto de
    repontar a régua para o campo ``comercial_da_conta``.

Usa a mesma regra da rotina diária (``resolver.py``): o nome que está no campo
"Comercial" do cliente é resolvido para um usuário da plataforma.

Atenção: o export traz DUAS colunas parecidas — "Comercial" (nome do comercial,
texto) e "Comercial " (com espaço no fim: o campo de lista de usuários, alvo da
atualização). Elas são lidas pelo nome exato, sem normalização.
"""

from __future__ import annotations

import argparse
import csv
import sys
from collections import Counter

from resolver import SOURCE_CUSTOMER_FIELD, Customer, User, normalize, plan_updates, summarize


def read_export(path: str, delimiter: str, encoding: str) -> list[dict]:
    with open(path, encoding=encoding, newline="") as handle:
        return list(csv.DictReader(handle, delimiter=delimiter))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--customers", required=True, help="Export da tabela de clientes")
    parser.add_argument("--users", required=True, help="Export da tabela de usuários")
    parser.add_argument("--delimiter", default="|")
    parser.add_argument("--encoding", default="utf-8-sig")
    parser.add_argument("--status", default="Ativo", help="Filtra por status do cliente ('' = todos)")
    parser.add_argument("--source-column", default="Comercial", help="Coluna com o nome do comercial")
    parser.add_argument("--cf-column", default="Comercial ", help="Coluna do CF alvo no export (valor atual)")
    parser.add_argument("--id-column", default="ID Original", choices=("ID Original", "ID Sensedata"))
    parser.add_argument("--value-mode", default="email", choices=("email", "name", "id"))
    parser.add_argument("--out", default="carga_comercial_da_conta.csv")
    parser.add_argument("--out-field-column", default="comercial_da_conta", help="Cabeçalho do CF no arquivo gerado")
    parser.add_argument("--pending", default="pendencias_comercial_da_conta.csv")
    parser.add_argument("--report", default="", help="CSV com CS atual x comercial resolvido (opcional)")
    parser.add_argument("--cs-column", default="CS", help="Coluna com o remetente usado hoje pela régua")
    args = parser.parse_args(argv)

    user_rows = read_export(args.users, args.delimiter, args.encoding)
    customer_rows = read_export(args.customers, args.delimiter, args.encoding)

    users = [
        User(
            id=row.get("ID", ""),
            name=row.get("Nome") or row.get("Usuário", ""),
            email=row.get("Email", ""),
            active=(row.get("Status", "Ativo").strip().lower() == "ativo"),
        )
        for row in user_rows
    ]

    if args.status:
        customer_rows = [row for row in customer_rows if (row.get("Status") or "").strip() == args.status]

    cs_by_id = {row.get("ID Original", ""): (row.get(args.cs_column) or "").strip() for row in customer_rows}

    customers = [
        Customer(
            id=row.get("ID Sensedata", ""),
            id_original=row.get("ID Original", ""),
            name=row.get("Cliente", ""),
            current_value=(row.get(args.cf_column) or "").strip(),
            commercial_name=(row.get(args.source_column) or "").strip(),
            status=(row.get("Status") or "").strip(),
        )
        for row in customer_rows
    ]

    decisions = plan_updates(customers, users=users, value_mode=args.value_mode, source=SOURCE_CUSTOMER_FIELD)

    print(f"Clientes analisados : {len(customers)} (status={args.status or 'todos'})")
    print(f"Usuários carregados : {len(users)}")
    for key, value in summarize(decisions).items():
        print(f"  {key:<38} {value}")

    updates = [decision for decision in decisions if decision.action == "update"]
    with open(args.out, "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow([args.id_column, args.out_field_column])
        for decision in updates:
            identifier = decision.customer.id_original if args.id_column == "ID Original" else decision.customer.id
            writer.writerow([identifier, decision.value])
    print(f"\nArquivo de carga    : {args.out} ({len(updates)} clientes)")

    pending = [decision for decision in decisions if decision.action == "skip" and decision.reason != "up_to_date"]
    with open(args.pending, "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["ID Original", "ID Sensedata", "Cliente", "Comercial (texto)", "Motivo"])
        for decision in pending:
            writer.writerow([
                decision.customer.id_original,
                decision.customer.id,
                decision.customer.name,
                decision.customer.commercial_name,
                decision.reason,
            ])
    print(f"Pendências          : {args.pending} ({len(pending)} clientes)")

    if args.report:
        with open(args.report, "w", newline="", encoding="utf-8") as handle:
            writer = csv.writer(handle)
            writer.writerow([
                "ID Original", "Cliente", "CS (remetente hoje)", "Comercial (texto)",
                "Comercial resolvido", "Situação", "Remetente muda?",
            ])
            for decision in decisions:
                customer = decision.customer
                cs_atual = cs_by_id.get(customer.id_original, "")
                muda = "sim" if decision.value and normalize(cs_atual) != normalize(decision.value_user_name) else "nao"
                writer.writerow([
                    customer.id_original,
                    customer.name,
                    cs_atual,
                    customer.commercial_name,
                    decision.value,
                    decision.reason,
                    muda if decision.value else "sem comercial",
                ])
        print(f"Relatório           : {args.report} ({len(decisions)} clientes)")

    if pending:
        print("\nNomes que não casaram com nenhum usuário ativo:")
        orphans = Counter(
            decision.customer.commercial_name
            for decision in pending
            if decision.reason in ("user_not_found", "user_inactive", "ambiguous_user")
        )
        for name, count in orphans.most_common():
            print(f"  {count:5}  {name}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
