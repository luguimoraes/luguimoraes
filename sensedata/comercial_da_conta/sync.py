#!/usr/bin/env python3
"""Rotina diária de atualização do CF ``comercial_da_conta`` no SenseData.

Modos de execução:
  * ``--mode dry-run`` (padrão): só relata o que mudaria — seguro para validar;
  * ``--mode apply``: grava os valores via API (PUT /customers/{id});
  * ``--mode csv``: gera o arquivo para "Configurações > Clientes > Manutenção
    via CSV" (ação Atualização), usado no backfill inicial.

Em qualquer modo é gerado um CSV de pendências com os clientes que ficaram sem
comercial resolvido, para tratamento do CS.
"""

from __future__ import annotations

import argparse
import csv
import logging
import os
import sys
from typing import Any, Iterable

from resolver import (
    DEFAULT_COMMERCIAL_CONTACT_TYPES,
    SOURCE_CONTACTS,
    SOURCE_CUSTOMER_FIELD,
    Contact,
    Customer,
    Decision,
    User,
    normalize,
    plan_updates,
    summarize,
)
from sensedata_client import SenseDataClient, SenseDataError

LOGGER = logging.getLogger("comercial_da_conta")

_TRUTHY = {"1", "true", "t", "yes", "y", "sim", "ativo", "ativa", "active", "enabled"}


def _first(row: dict, *keys: str, default: Any = None) -> Any:
    """Primeiro valor não vazio entre as chaves — a API varia o nome do campo."""
    for key in keys:
        value = row.get(key)
        if value not in (None, "", [], {}):
            return value
    return default


def _as_bool(value: Any, default: bool = True) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    return normalize(value) in _TRUTHY


def _custom_field_value(row: dict, field_name: str) -> str:
    """Lê o valor atual do CF, aceitando lista de objetos ou dicionário."""
    fields = row.get("custom_fields") or row.get("customFields") or {}
    target = normalize(field_name)

    if isinstance(fields, dict):
        for key, value in fields.items():
            if normalize(key) == target:
                return _flatten(value)
    elif isinstance(fields, list):
        for item in fields:
            if not isinstance(item, dict):
                continue
            key = _first(item, "name", "alias", "key", "label", "id", default="")
            if normalize(key) == target:
                return _flatten(_first(item, "value", "values", "text", default=""))
    return _flatten(row.get(field_name, ""))


def _flatten(value: Any) -> str:
    """CF de lista de usuários pode voltar como lista/objeto — reduz para texto."""
    if value is None:
        return ""
    if isinstance(value, dict):
        return str(_first(value, "email", "name", "id", default=""))
    if isinstance(value, list):
        return ", ".join(filter(None, (_flatten(item) for item in value)))
    return str(value)


# ------------------------------------------------------------------ Adaptadores
def to_user(row: dict) -> User:
    return User(
        id=_first(row, "id", "user_id", default=""),
        name=str(_first(row, "name", "full_name", "nome", default="")),
        email=str(_first(row, "email", "mail", default="")),
        active=_as_bool(_first(row, "active", "is_active", "status", "situacao")),
    )


def to_customer(row: dict, field_name: str, source_field: str = "Comercial") -> Customer:
    commercial = _custom_field_value(row, source_field) or str(_first(row, "commercial", "comercial", default=""))
    return Customer(
        id=_first(row, "id", "customer_id", "id_sensedata", default=""),
        id_original=str(_first(row, "id_original", "external_id", "idOriginal", default="")),
        name=str(_first(row, "name", "customer_name", "nome", default="")),
        current_value=_custom_field_value(row, field_name),
        commercial_name=commercial,
        status=str(_first(row, "status", "situacao_cadastro", default="")),
    )


def to_contact(row: dict) -> Contact:
    return Contact(
        customer_id=_first(row, "customer_id", "id_customer", "customerId", default=""),
        name=str(_first(row, "name", "contact_name", "nome", default="")),
        email=str(_first(row, "email", "mail", default="")),
        type=str(_first(row, "type", "contact_type", "tipo", "tipo_contato", default="")),
        active=_as_bool(_first(row, "active", "is_active", "status", "situacao")),
        main=_as_bool(_first(row, "main", "is_main", "primary", "principal"), default=False),
        updated_at=str(_first(row, "updated_at", "modified_at", "created_at", default="")),
    )


# ----------------------------------------------------------------------- Saídas
def write_csv(path: str, rows: Iterable[dict], header: list[str]) -> int:
    rows = list(rows)
    with open(path, "w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=header)
        writer.writeheader()
        writer.writerows(rows)
    return len(rows)


def maintenance_rows(decisions: Iterable[Decision], id_column: str, field_column: str) -> list[dict]:
    """Linhas do CSV de Manutenção via CSV (ID Original + campo customizado)."""
    return [
        {id_column: decision.customer.id_original or decision.customer.id, field_column: decision.value}
        for decision in decisions
        if decision.action == "update"
    ]


def pending_rows(decisions: Iterable[Decision]) -> list[dict]:
    return [
        {
            "id_original": decision.customer.id_original,
            "id_sensedata": decision.customer.id,
            "cliente": decision.customer.name,
            "motivo": decision.reason,
            "contato": decision.contact.name if decision.contact else "",
            "email_contato": decision.contact.email if decision.contact else "",
            "valor_atual": decision.customer.current_value,
        }
        for decision in decisions
        if decision.action == "skip" and decision.reason != "up_to_date"
    ]


# ------------------------------------------------------------------- Orquestração
def run(args: argparse.Namespace) -> int:
    client = SenseDataClient(
        api_key=args.api_key,
        base_url=args.base_url,
        page_size=args.page_size,
    )

    LOGGER.info("Carregando usuários, clientes e contatos do SenseData...")
    users = [to_user(row) for row in client.list_users()]
    customer_rows = client.list_customers()
    # Contatos só são necessários quando a fonte do comercial são os contatos do cliente.
    contacts = [to_contact(row) for row in client.list_contacts()] if args.source == SOURCE_CONTACTS else []

    customers = [to_customer(row, args.field_name, args.source_field) for row in customer_rows]
    if args.only_customer:
        wanted = {normalize(item) for item in args.only_customer}
        customers = [
            customer
            for customer in customers
            if normalize(customer.id_original) in wanted or normalize(customer.id) in wanted
        ]
    if args.limit:
        customers = customers[: args.limit]

    LOGGER.info("%d usuários, %d clientes, %d contatos", len(users), len(customers), len(contacts))

    decisions = plan_updates(
        customers=customers,
        contacts=contacts,
        users=users,
        commercial_types=args.commercial_types,
        value_mode=args.value_mode,
        source=args.source,
    )

    for key, value in summarize(decisions).items():
        LOGGER.info("  %-38s %d", key, value)

    pending = pending_rows(decisions)
    if args.pending_csv:
        written = write_csv(
            args.pending_csv,
            pending,
            ["id_original", "id_sensedata", "cliente", "motivo", "contato", "email_contato", "valor_atual"],
        )
        LOGGER.info("Pendências gravadas em %s (%d clientes)", args.pending_csv, written)

    updates = [decision for decision in decisions if decision.action == "update"]

    if args.mode == "csv":
        written = write_csv(
            args.csv_path,
            maintenance_rows(updates, args.csv_id_column, args.csv_field_column),
            [args.csv_id_column, args.csv_field_column],
        )
        LOGGER.info("CSV de manutenção gerado em %s (%d clientes)", args.csv_path, written)
        return 0

    if args.mode == "dry-run":
        for decision in updates[: args.preview]:
            LOGGER.info(
                "[dry-run] %s (%s): '%s' -> '%s' (contato %s)",
                decision.customer.name,
                decision.customer.id_original,
                decision.customer.current_value or "vazio",
                decision.value,
                decision.contact.name if decision.contact else "",
            )
        LOGGER.info("Dry-run: %d clientes seriam atualizados. Nada foi gravado.", len(updates))
        return 0

    failures = 0
    for decision in updates:
        try:
            client.update_customer_custom_field(
                customer_id=decision.customer.id,
                field_key=args.field_key if args.field_key_mode == "id" else args.field_name,
                field_value=decision.value,
                key_mode=args.field_key_mode,
            )
            LOGGER.info("OK %s (%s) -> %s", decision.customer.name, decision.customer.id_original, decision.value)
        except SenseDataError as exc:
            failures += 1
            LOGGER.error("FALHA %s (%s): %s", decision.customer.name, decision.customer.id_original, exc)

    LOGGER.info("Atualizados %d/%d clientes (%d falhas).", len(updates) - failures, len(updates), failures)
    return 1 if failures else 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Atualiza o CF comercial_da_conta no SenseData.")
    parser.add_argument("--mode", choices=("dry-run", "apply", "csv"), default="dry-run")
    parser.add_argument(
        "--source",
        choices=(SOURCE_CUSTOMER_FIELD, SOURCE_CONTACTS),
        default=os.getenv("SENSEDATA_SOURCE", SOURCE_CUSTOMER_FIELD),
        help="De onde vem o nome do comercial: campo do cliente (padrão) ou contatos ativos.",
    )
    parser.add_argument(
        "--source-field",
        default=os.getenv("SENSEDATA_SOURCE_FIELD", "Comercial"),
        help="Campo do cliente que contém o nome do comercial (usado com --source customer_field).",
    )
    parser.add_argument("--api-key", default=os.getenv("SENSEDATA_API_KEY", ""))
    parser.add_argument("--base-url", default=os.getenv("SENSEDATA_BASE_URL", "https://api.sensedata.io/v2"))
    parser.add_argument("--field-name", default=os.getenv("SENSEDATA_CF_NAME", "comercial_da_conta"))
    parser.add_argument("--field-key", default=os.getenv("SENSEDATA_CF_ID", ""), help="ID do CF (quando --field-key-mode=id)")
    parser.add_argument("--field-key-mode", choices=("name", "id"), default=os.getenv("SENSEDATA_CF_KEY_MODE", "name"))
    parser.add_argument("--value-mode", choices=("email", "name", "id"), default=os.getenv("SENSEDATA_CF_VALUE_MODE", "email"))
    parser.add_argument(
        "--commercial-types",
        default=os.getenv("SENSEDATA_COMMERCIAL_TYPES", ",".join(DEFAULT_COMMERCIAL_CONTACT_TYPES)),
        help="Tipos de contato tratados como comercial, separados por vírgula.",
    )
    parser.add_argument("--csv-path", default="comercial_da_conta.csv")
    parser.add_argument("--csv-id-column", default=os.getenv("SENSEDATA_CSV_ID_COLUMN", "id_original"))
    parser.add_argument("--csv-field-column", default=os.getenv("SENSEDATA_CSV_FIELD_COLUMN", "comercial_da_conta"))
    parser.add_argument("--pending-csv", default="pendencias_comercial_da_conta.csv")
    parser.add_argument("--only-customer", nargs="*", default=[], help="Filtra por ID Original (validação pontual).")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--preview", type=int, default=20, help="Linhas exibidas no dry-run.")
    parser.add_argument("--page-size", type=int, default=200)
    parser.add_argument("--log-level", default=os.getenv("LOG_LEVEL", "INFO"))

    args = parser.parse_args(argv)
    args.commercial_types = [item.strip() for item in args.commercial_types.split(",") if item.strip()]
    if args.mode == "apply" and args.field_key_mode == "id" and not args.field_key:
        parser.error("--field-key é obrigatório quando --field-key-mode=id")
    return args


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    logging.basicConfig(level=args.log_level.upper(), format="%(asctime)s %(levelname)-7s %(message)s")
    try:
        return run(args)
    except SenseDataError as exc:
        LOGGER.error("Rotina abortada: %s", exc)
        return 2


if __name__ == "__main__":
    sys.exit(main())
