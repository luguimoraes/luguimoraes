"""Testes da rotina do CF comercial_da_conta (sem rede: opener e API fakes)."""

from __future__ import annotations

import contextlib
import csv
import io
import json
import os
import shutil
import sys
import tempfile
import unittest
import unittest.mock
import urllib.error

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import backfill_from_export  # noqa: E402
import sync  # noqa: E402
from resolver import (  # noqa: E402
    SOURCE_CONTACTS,
    Contact,
    Customer,
    User,
    UserIndex,
    is_placeholder,
    normalize,
    pick_commercial_contact,
    plan_updates,
    summarize,
)
from sensedata_client import SenseDataClient, SenseDataError  # noqa: E402

COMMERCIAL = ("comercial", "responsavel comercial")


def contact(**kwargs) -> Contact:
    base = {
        "customer_id": 1,
        "name": "Luciana Pasquarelli Fernandes",
        "email": "luciana.fernandes@thomsonreuters.com",
        "type": "Comercial",
        "active": True,
        "main": False,
        "updated_at": "2026-08-01T00:00:00Z",
    }
    base.update(kwargs)
    return Contact(**base)


class NormalizeTest(unittest.TestCase):
    def test_removes_accents_case_and_extra_spaces(self):
        self.assertEqual(normalize("  Responsável   COMERCIAL "), "responsavel comercial")

    def test_none_becomes_empty_string(self):
        self.assertEqual(normalize(None), "")


class PickCommercialContactTest(unittest.TestCase):
    def test_ignores_inactive_and_non_commercial_contacts(self):
        contacts = [
            contact(name="Financeiro", type="Financeiro"),
            contact(name="Comercial Inativo", active=False),
            contact(name="Comercial Ativo"),
        ]
        chosen = pick_commercial_contact(contacts, COMMERCIAL)
        self.assertEqual(chosen.name, "Comercial Ativo")

    def test_main_contact_wins_over_recent(self):
        contacts = [
            contact(name="Recente", updated_at="2026-08-30T00:00:00Z"),
            contact(name="Principal", main=True, updated_at="2020-01-01T00:00:00Z"),
        ]
        self.assertEqual(pick_commercial_contact(contacts, COMMERCIAL).name, "Principal")

    def test_most_recent_wins_when_no_main(self):
        contacts = [
            contact(name="Antigo", updated_at="2024-01-01T00:00:00Z"),
            contact(name="Novo", updated_at="2026-08-30T00:00:00Z"),
        ]
        self.assertEqual(pick_commercial_contact(contacts, COMMERCIAL).name, "Novo")

    def test_returns_none_without_eligible_contacts(self):
        self.assertIsNone(pick_commercial_contact([contact(type="Financeiro")], COMMERCIAL))


class UserIndexTest(unittest.TestCase):
    def setUp(self):
        self.luciana = User(10, "Luciana Pasquarelli Fernandes", "luciana.fernandes@thomsonreuters.com")

    def test_matches_by_email_ignoring_case(self):
        index = UserIndex.build([self.luciana])
        user, reason = index.resolve(contact(email="LUCIANA.FERNANDES@thomsonreuters.com"))
        self.assertEqual((user.id, reason), (10, "matched_by_email"))

    def test_falls_back_to_normalized_name(self):
        index = UserIndex.build([self.luciana])
        user, reason = index.resolve(contact(email="outro@thomsonreuters.com", name="luciana pasquarelli fernandes"))
        self.assertEqual((user.id, reason), (10, "matched_by_name"))

    def test_reports_ambiguous_homonyms(self):
        index = UserIndex.build([self.luciana, User(11, "Luciana Pasquarelli Fernandes", "l.p.f@thomsonreuters.com")])
        user, reason = index.resolve(contact(email="sem-usuario@thomsonreuters.com"))
        self.assertEqual((user, reason), (None, "ambiguous_user"))

    def test_reports_inactive_user(self):
        index = UserIndex.build([User(10, "Luciana Pasquarelli Fernandes", "luciana.fernandes@thomsonreuters.com", active=False)])
        user, reason = index.resolve(contact())
        self.assertEqual((user, reason), (None, "user_inactive"))

    def test_reports_missing_user(self):
        index = UserIndex.build([User(99, "Outro Alguem", "outro@thomsonreuters.com")])
        user, reason = index.resolve(contact())
        self.assertEqual((user, reason), (None, "user_not_found"))


class PlanUpdatesTest(unittest.TestCase):
    """Cenário do ticket: MARIMEX estava com o CF vazio e a regra 304 caiu no remetente padrão."""

    def setUp(self):
        self.marimex = Customer(1, "143467-LEGAL", "LEGAL MARIMEX DESPACHOS TRANSPORTES E SERVICOS LTDA", "")
        self.users = [User(10, "Luciana Pasquarelli Fernandes", "luciana.fernandes@thomsonreuters.com")]

    def test_fills_empty_field_with_commercial_user(self):
        [decision] = plan_updates([self.marimex], [contact()], self.users, COMMERCIAL, source=SOURCE_CONTACTS)
        self.assertEqual(decision.action, "update")
        self.assertEqual(decision.value, "luciana.fernandes@thomsonreuters.com")
        self.assertEqual(decision.reason, "matched_by_email")

    def test_skips_when_value_already_correct(self):
        customer = Customer(1, "143467-LEGAL", "MARIMEX", "LUCIANA.FERNANDES@thomsonreuters.com")
        [decision] = plan_updates([customer], [contact()], self.users, COMMERCIAL, source=SOURCE_CONTACTS)
        self.assertEqual((decision.action, decision.reason), ("skip", "up_to_date"))

    def test_never_clears_field_when_no_commercial_contact(self):
        customer = Customer(1, "143467-LEGAL", "MARIMEX", "luciana.fernandes@thomsonreuters.com")
        [decision] = plan_updates([customer], [contact(type="Financeiro")], self.users, COMMERCIAL, source=SOURCE_CONTACTS)
        self.assertEqual((decision.action, decision.reason), ("skip", "no_active_commercial_contact"))
        self.assertEqual(decision.value, "")

    def test_value_mode_name(self):
        [decision] = plan_updates([self.marimex], [contact()], self.users, COMMERCIAL, value_mode="name", source=SOURCE_CONTACTS)
        self.assertEqual(decision.value, "Luciana Pasquarelli Fernandes")

    def test_contacts_of_other_customers_are_ignored(self):
        [decision] = plan_updates([self.marimex], [contact(customer_id=999)], self.users, COMMERCIAL, source=SOURCE_CONTACTS)
        self.assertEqual(decision.reason, "no_active_commercial_contact")

    def test_summary_counts_actions_and_reasons(self):
        decisions = plan_updates(
            [self.marimex, Customer(2, "143468-TAX", "TAX", "")],
            [contact(), contact(customer_id=2, type="Financeiro")],
            self.users,
            COMMERCIAL,
            source=SOURCE_CONTACTS,
        )
        summary = summarize(decisions)
        self.assertEqual(summary["update"], 1)
        self.assertEqual(summary["skip"], 1)
        self.assertEqual(summary["reason:no_active_commercial_contact"], 1)


class AdapterTest(unittest.TestCase):
    def test_reads_custom_field_from_list_payload(self):
        row = {
            "id": 1,
            "id_original": "143467-LEGAL",
            "name": "MARIMEX",
            "custom_fields": [
                {"name": "cs_da_conta", "value": "cs@thomsonreuters.com"},
                {"name": "comercial_da_conta", "value": {"email": "luciana.fernandes@thomsonreuters.com"}},
            ],
        }
        self.assertEqual(sync.to_customer(row, "comercial_da_conta").current_value, "luciana.fernandes@thomsonreuters.com")

    def test_reads_custom_field_from_dict_payload(self):
        row = {"id": 1, "custom_fields": {"Comercial da Conta": ["a@x.com", "b@x.com"]}}
        self.assertEqual(sync.to_customer(row, "comercial da conta").current_value, "a@x.com, b@x.com")

    def test_missing_custom_field_returns_empty(self):
        self.assertEqual(sync.to_customer({"id": 1}, "comercial_da_conta").current_value, "")

    def test_status_strings_are_read_as_active_flags(self):
        self.assertTrue(sync.to_contact({"customer_id": 1, "status": "Ativo"}).active)
        self.assertFalse(sync.to_contact({"customer_id": 1, "status": "inativo"}).active)
        self.assertTrue(sync.to_contact({"customer_id": 1}).active)  # padrão: ativo

    def test_maintenance_csv_uses_id_original(self):
        decisions = plan_updates(
            [Customer(1, "143467-LEGAL", "MARIMEX", "")],
            [contact()],
            [User(10, "Luciana Pasquarelli Fernandes", "luciana.fernandes@thomsonreuters.com")],
            COMMERCIAL,
            source=SOURCE_CONTACTS,
        )
        rows = sync.maintenance_rows(decisions, "id_original", "comercial_da_conta")
        self.assertEqual(rows, [{"id_original": "143467-LEGAL", "comercial_da_conta": "luciana.fernandes@thomsonreuters.com"}])

    def test_pending_rows_exclude_up_to_date(self):
        decisions = plan_updates(
            [Customer(1, "A", "A", "luciana.fernandes@thomsonreuters.com"), Customer(2, "B", "B", "")],
            [contact(), contact(customer_id=2, email="ninguem@x.com", name="Ninguem")],
            [User(10, "Luciana Pasquarelli Fernandes", "luciana.fernandes@thomsonreuters.com")],
            COMMERCIAL,
            source=SOURCE_CONTACTS,
        )
        rows = sync.pending_rows(decisions)
        self.assertEqual([row["motivo"] for row in rows], ["user_not_found"])


class FakeOpener:
    """Opener que devolve respostas pré-programadas e registra as requisições."""

    def __init__(self, responses):
        self.responses = list(responses)
        self.requests = []

    def open(self, request, timeout=None):  # noqa: ARG002
        self.requests.append(request)
        response = self.responses.pop(0)
        if isinstance(response, Exception):
            raise response
        return io.BytesIO(json.dumps(response).encode("utf-8"))


class ClientTest(unittest.TestCase):
    def client(self, responses, **kwargs):
        return SenseDataClient("fake-key", opener=FakeOpener(responses), sleeper=lambda _: None, **kwargs)

    def test_requires_api_key(self):
        with self.assertRaises(SenseDataError):
            SenseDataClient("")

    def test_paginates_until_partial_page(self):
        client = self.client([{"data": [{"id": 1}, {"id": 2}]}, {"data": [{"id": 3}]}], page_size=2)
        self.assertEqual([row["id"] for row in client.paginate("customers")], [1, 2, 3])
        self.assertEqual(len(client._opener.requests), 2)

    def test_accepts_bare_list_payload(self):
        client = self.client([[{"id": 1}]], page_size=2)
        self.assertEqual(client.list_users(), [{"id": 1}])

    def test_retries_on_429_then_succeeds(self):
        throttled = urllib.error.HTTPError("url", 429, "Too Many Requests", {}, io.BytesIO(b"slow down"))
        client = self.client([throttled, {"data": []}], page_size=2)
        self.assertEqual(list(client.paginate("customers")), [])
        self.assertEqual(len(client._opener.requests), 2)

    def test_does_not_retry_client_errors(self):
        forbidden = urllib.error.HTTPError("url", 403, "Forbidden", {}, io.BytesIO(b"nope"))
        client = self.client([forbidden])
        with self.assertRaises(SenseDataError):
            client.list_users()

    def test_update_sends_custom_field_payload(self):
        client = self.client([{"ok": True}])
        client.update_customer_custom_field(42, "comercial_da_conta", "luciana@tr.com")
        request = client._opener.requests[0]
        self.assertEqual(request.get_method(), "PUT")
        self.assertTrue(request.full_url.endswith("/customers/42"))
        self.assertEqual(
            json.loads(request.data.decode("utf-8")),
            {"custom_fields": [{"value": "luciana@tr.com", "name": "comercial_da_conta"}]},
        )

    def test_update_by_field_id(self):
        client = self.client([{"ok": True}])
        client.update_customer_custom_field(42, "304", "luciana@tr.com", key_mode="id")
        payload = json.loads(client._opener.requests[0].data.decode("utf-8"))
        self.assertEqual(payload["custom_fields"][0]["id"], "304")


class CliTest(unittest.TestCase):
    def test_dry_run_is_the_default_mode(self):
        args = sync.parse_args([])
        self.assertEqual(args.mode, "dry-run")
        self.assertEqual(args.field_name, "comercial_da_conta")

    def test_commercial_types_are_split(self):
        args = sync.parse_args(["--commercial-types", "Comercial, Vendas "])
        self.assertEqual(args.commercial_types, ["Comercial", "Vendas"])

    def test_apply_by_field_id_requires_the_id(self):
        with self.assertRaises(SystemExit):
            sync.parse_args(["--mode", "apply", "--field-key-mode", "id"])

class FakeClient:
    """Substitui o SenseDataClient no teste ponta a ponta."""

    users = [{"id": 10, "name": "Luciana Pasquarelli Fernandes", "email": "luciana.fernandes@thomsonreuters.com"}]
    customers = [
        {
            "id": 1,
            "id_original": "143467-LEGAL",
            "name": "LEGAL MARIMEX",
            "custom_fields": [{"name": "Comercial", "value": "Luciana Pasquarelli Fernandes"}],
        },
        {
            "id": 2,
            "id_original": "143468-TAX",
            "name": "TAX MARIMEX",
            "custom_fields": [{"name": "Comercial", "value": "N/A AM"}],
        },
    ]
    contacts = [
        {"customer_id": 1, "name": "Luciana Pasquarelli Fernandes", "email": "luciana.fernandes@thomsonreuters.com", "type": "Comercial", "status": "Ativo"},
        {"customer_id": 2, "name": "Contato Financeiro", "email": "fin@thomsonreuters.com", "type": "Financeiro", "status": "Ativo"},
    ]

    def __init__(self, **kwargs):
        self.updates = []
        FakeClient.last = self

    def list_users(self):
        return self.users

    def list_customers(self, params=None):
        return self.customers

    def list_contacts(self, params=None):
        return self.contacts

    def update_customer_custom_field(self, customer_id, field_key, field_value, key_mode="name"):
        self.updates.append((customer_id, field_key, field_value, key_mode))
        return {"ok": True}


class EndToEndTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.csv_path = os.path.join(self.tmp, "carga.csv")
        self.pending_path = os.path.join(self.tmp, "pendencias.csv")
        patcher = unittest.mock.patch.object(sync, "SenseDataClient", FakeClient)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(shutil.rmtree, self.tmp)

    def run_cli(self, *extra):
        argv = [
            "--api-key", "fake",
            "--csv-path", self.csv_path,
            "--pending-csv", self.pending_path,
            "--log-level", "CRITICAL",
            *extra,
        ]
        return sync.main(argv)

    def test_csv_mode_writes_maintenance_and_pending_files(self):
        self.assertEqual(self.run_cli("--mode", "csv"), 0)
        with open(self.csv_path, encoding="utf-8") as handle:
            rows = list(csv.DictReader(handle))
        self.assertEqual(rows, [{"id_original": "143467-LEGAL", "comercial_da_conta": "luciana.fernandes@thomsonreuters.com"}])

        with open(self.pending_path, encoding="utf-8") as handle:
            pending = list(csv.DictReader(handle))
        self.assertEqual([(row["id_original"], row["motivo"]) for row in pending], [("143468-TAX", "no_commercial_assigned")])

    def test_apply_mode_updates_only_the_resolved_customer(self):
        self.assertEqual(self.run_cli("--mode", "apply"), 0)
        self.assertEqual(FakeClient.last.updates, [(1, "comercial_da_conta", "luciana.fernandes@thomsonreuters.com", "name")])

    def test_dry_run_never_writes_to_the_api(self):
        self.assertEqual(self.run_cli("--mode", "dry-run"), 0)
        self.assertEqual(FakeClient.last.updates, [])

    def test_only_customer_filters_the_run(self):
        self.assertEqual(self.run_cli("--mode", "apply", "--only-customer", "143468-TAX"), 0)
        self.assertEqual(FakeClient.last.updates, [])

    def test_contacts_source_still_works(self):
        self.assertEqual(self.run_cli("--mode", "apply", "--source", "contacts"), 0)
        self.assertEqual(FakeClient.last.updates, [(1, "comercial_da_conta", "luciana.fernandes@thomsonreuters.com", "name")])

class CustomerFieldSourceTest(unittest.TestCase):
    """Fonte real da Thomson Reuters: o campo 'Comercial' do próprio cliente."""

    def setUp(self):
        self.users = [
            User(196, "Luciana Pasquarelli Fernandes", "luciana.pasquarellifernandes@thomsonreuters.com"),
            User(2467, "Lorraine Ferreira", "lorraine.ferreira@thomsonreuters.com"),
        ]

    def plan(self, commercial_name, current_value="", **kwargs):
        customer = Customer(1, "143467-LEGAL", "LEGAL MARIMEX", current_value, commercial_name, "Ativo")
        [decision] = plan_updates([customer], users=self.users, **kwargs)
        return decision

    def test_resolves_marimex_commercial(self):
        decision = self.plan("Lorraine Ferreira")
        self.assertEqual(decision.action, "update")
        self.assertEqual(decision.value, "lorraine.ferreira@thomsonreuters.com")

    def test_resolves_case_from_the_ticket(self):
        decision = self.plan("Luciana Pasquarelli Fernandes")
        self.assertEqual(decision.value, "luciana.pasquarellifernandes@thomsonreuters.com")

    def test_accent_and_case_differences_still_match(self):
        self.assertEqual(self.plan("LUCIANA PASQUARELLI FERNANDES").user.id, 196)

    def test_na_am_is_treated_as_no_commercial(self):
        self.assertEqual(self.plan("N/A AM").reason, "no_commercial_assigned")

    def test_empty_commercial_is_skipped(self):
        self.assertEqual(self.plan("").reason, "no_commercial_assigned")

    def test_name_without_matching_user_becomes_pending(self):
        decision = self.plan("Cintia Thomé")
        self.assertEqual((decision.action, decision.reason), ("skip", "user_not_found"))

    def test_contacts_are_not_needed_for_this_source(self):
        self.assertEqual(self.plan("Lorraine Ferreira").contact.type, "Comercial")

    def test_value_mode_name_writes_the_user_name(self):
        self.assertEqual(self.plan("Lorraine Ferreira", value_mode="name").value, "Lorraine Ferreira")

    def test_already_filled_field_is_not_rewritten(self):
        decision = self.plan("Lorraine Ferreira", current_value="lorraine.ferreira@thomsonreuters.com")
        self.assertEqual(decision.reason, "up_to_date")


class PlaceholderTest(unittest.TestCase):
    def test_recognizes_placeholders(self):
        for value in ["", "  ", "N/A AM", "n/a", "N/A", "-", "Sem comercial"]:
            self.assertTrue(is_placeholder(value), value)

    def test_real_names_are_not_placeholders(self):
        for value in ["Lorraine Ferreira", "Nathalia Nascimento"]:
            self.assertFalse(is_placeholder(value), value)

class BackfillFromExportTest(unittest.TestCase):
    """Lê os exports reais (delimitador '|', BOM) e gera o arquivo de carga."""

    CUSTOMERS = (
        '\ufeff"ID Original"|"Cliente"|"Status"|"CS"|"Comercial"|"Comercial "|"ID Sensedata"\n'
        '"143467-LEGAL"|"LEGAL MARIMEX"|"Ativo"|"Relacionamento Customer Success"|"Lorraine Ferreira"|""|"24870533"\n'
        '"143468-TAX"|"TAX OCP DO BRASIL LTDA"|"Ativo"|"Beatriz Sanchez"|"Luciana Pasquarelli Fernandes"|""|"24870534"\n'
        '"143449-LEGAL"|"LEGAL HOLDING FINAXIS"|"Ativo"|"Relacionamento Customer Success"|"N/A AM"|""|"24769020"\n'
        '"142796-GTM"|"GTM HAIFA QUIMICA"|"Ativo"|"Beatriz Sanchez"|"Henrique De Oliveira"|""|"20729275"\n'
        '"999-OLD"|"CLIENTE INATIVO"|"Inativo"|"Beatriz Sanchez"|"Lorraine Ferreira"|""|"111"\n'
    )
    USERS = (
        '\ufeff"ID"|"Usuário"|"Nome"|"Perfil"|"Email"|"Status"\n'
        '"2467"|"Lorraine Ferreira"|"Lorraine Ferreira"|"Brazil Sales - Legal"|"lorraine.ferreira@thomsonreuters.com"|"Ativo"\n'
        '"196"|"Luciana"|"Luciana Pasquarelli Fernandes"|"Brazil Sales - GB Core"|"luciana.pasquarellifernandes@thomsonreuters.com"|"Ativo"\n'
    )

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)
        self.customers = self._write("customers.csv", self.CUSTOMERS)
        self.users = self._write("users.csv", self.USERS)
        self.out = os.path.join(self.tmp, "carga.csv")
        self.pending = os.path.join(self.tmp, "pendencias.csv")

    def _write(self, name, content):
        path = os.path.join(self.tmp, name)
        with open(path, "w", encoding="utf-8", newline="") as handle:
            handle.write(content)
        return path

    def run_backfill(self, *extra):
        argv = ["--customers", self.customers, "--users", self.users, "--out", self.out, "--pending", self.pending, *extra]
        with contextlib.redirect_stdout(io.StringIO()) as captured:
            code = backfill_from_export.main(argv)
        return code, captured.getvalue()

    def read(self, path):
        with open(path, encoding="utf-8", newline="") as handle:
            return list(csv.reader(handle))

    def test_generates_maintenance_file_for_active_customers(self):
        code, _ = self.run_backfill()
        self.assertEqual(code, 0)
        self.assertEqual(
            self.read(self.out),
            [
                ["ID Original", "comercial_da_conta"],
                ["143467-LEGAL", "lorraine.ferreira@thomsonreuters.com"],
                ["143468-TAX", "luciana.pasquarellifernandes@thomsonreuters.com"],
            ],
        )

    def test_inactive_customers_are_filtered_out(self):
        self.run_backfill()
        self.assertNotIn("999-OLD", [row[0] for row in self.read(self.out)])

    def test_status_filter_can_be_disabled(self):
        self.run_backfill("--status", "")
        self.assertIn("999-OLD", [row[0] for row in self.read(self.out)])

    def test_pending_file_lists_reasons(self):
        self.run_backfill()
        rows = self.read(self.pending)[1:]
        self.assertEqual(
            {(row[0], row[4]) for row in rows},
            {("143449-LEGAL", "no_commercial_assigned"), ("142796-GTM", "user_not_found")},
        )

    def test_the_two_similar_columns_are_not_confused(self):
        """'Comercial' (texto de origem) e 'Comercial ' (CF alvo) são colunas distintas."""
        self.run_backfill()
        self.assertEqual(self.read(self.out)[1][1], "lorraine.ferreira@thomsonreuters.com")

    def test_already_filled_customers_are_skipped(self):
        filled = self.CUSTOMERS.replace(
            '"Lorraine Ferreira"|""|"24870533"', '"Lorraine Ferreira"|"lorraine.ferreira@thomsonreuters.com"|"24870533"'
        )
        self.customers = self._write("customers_filled.csv", filled)
        self.run_backfill()
        self.assertNotIn("143467-LEGAL", [row[0] for row in self.read(self.out)])

    def test_value_mode_name_and_sensedata_id(self):
        self.run_backfill("--value-mode", "name", "--id-column", "ID Sensedata")
        self.assertEqual(self.read(self.out)[1], ["24870533", "Lorraine Ferreira"])

    def test_summary_is_printed(self):
        _, output = self.run_backfill()
        self.assertIn("update", output)
        self.assertIn("Henrique De Oliveira", output)


if __name__ == "__main__":
    unittest.main(verbosity=2)
