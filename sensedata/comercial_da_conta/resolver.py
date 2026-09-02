"""Regra de preenchimento do campo customizado ``comercial_da_conta``.

Lógica de negócio (a mesma descrita pela Jaqueline no ticket 496060):
para cada cliente, o comercial da conta é o **contato ativo de tipo comercial**
do cliente, resolvido para um **usuário do SenseData** — porque o CF é do tipo
"lista de usuários" e a regra 304 usa esse usuário como remetente.

Este módulo é puro: não faz I/O. Toda a integração fica em ``sync.py``.
"""

from __future__ import annotations

import unicodedata
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Any, Iterable

# Tipos de contato considerados "responsável comercial" (comparados normalizados).
DEFAULT_COMMERCIAL_CONTACT_TYPES = ("comercial", "responsavel comercial", "executivo comercial", "vendas")


def normalize(text: Any) -> str:
    """Minúsculas, sem acento e com espaços colapsados — para casar nomes/tipos."""
    if text is None:
        return ""
    decomposed = unicodedata.normalize("NFKD", str(text))
    stripped = "".join(char for char in decomposed if not unicodedata.combining(char))
    return " ".join(stripped.lower().split())


@dataclass(frozen=True)
class User:
    id: Any
    name: str
    email: str
    active: bool = True


@dataclass(frozen=True)
class Contact:
    customer_id: Any
    name: str
    email: str
    type: str
    active: bool = True
    main: bool = False
    updated_at: str = ""


@dataclass(frozen=True)
class Customer:
    id: Any
    id_original: str
    name: str
    current_value: str = ""


@dataclass(frozen=True)
class Decision:
    customer: Customer
    action: str  # "update" | "skip"
    reason: str
    contact: Contact | None = None
    user: User | None = None
    value: str = ""


@dataclass
class UserIndex:
    """Índice de usuários por e-mail e por nome normalizado."""

    by_email: dict[str, User] = field(default_factory=dict)
    by_name: dict[str, list[User]] = field(default_factory=lambda: defaultdict(list))

    @classmethod
    def build(cls, users: Iterable[User]) -> "UserIndex":
        index = cls()
        for user in users:
            if user.email:
                index.by_email.setdefault(normalize(user.email), user)
            if user.name:
                index.by_name[normalize(user.name)].append(user)
        return index

    def resolve(self, contact: Contact) -> tuple[User | None, str]:
        """Casa o contato com um usuário: e-mail primeiro, nome como fallback."""
        user = self.by_email.get(normalize(contact.email))
        if user:
            return (user, "matched_by_email") if user.active else (None, "user_inactive")

        candidates = self.by_name.get(normalize(contact.name), [])
        actives = [candidate for candidate in candidates if candidate.active]
        if not candidates:
            return None, "user_not_found"
        if not actives:
            return None, "user_inactive"
        if len(actives) > 1:
            return None, "ambiguous_user"
        return actives[0], "matched_by_name"


def is_commercial(contact: Contact, commercial_types: Iterable[str]) -> bool:
    return normalize(contact.type) in {normalize(item) for item in commercial_types}


def pick_commercial_contact(contacts: Iterable[Contact], commercial_types: Iterable[str]) -> Contact | None:
    """Escolhe o contato comercial: ativo, tipo comercial, principal na frente."""
    eligible = [
        contact
        for contact in contacts
        if contact.active and is_commercial(contact, commercial_types)
    ]
    if not eligible:
        return None
    # Desempate estável: contato principal > atualização mais recente > nome.
    eligible.sort(key=lambda contact: (not contact.main, _desc(contact.updated_at), normalize(contact.name)))
    return eligible[0]


def _desc(value: str) -> str:
    """Chave de ordenação decrescente para strings ISO (inverte cada caractere)."""
    return "".join(chr(0x10FFFD - ord(char)) for char in str(value or ""))


def user_value(user: User, mode: str = "email") -> str:
    """Valor gravado no CF (o formato aceito depende de como o CF foi criado)."""
    if mode == "id":
        return str(user.id)
    if mode == "name":
        return user.name
    return user.email or user.name


def plan_updates(
    customers: Iterable[Customer],
    contacts: Iterable[Contact],
    users: Iterable[User],
    commercial_types: Iterable[str] = DEFAULT_COMMERCIAL_CONTACT_TYPES,
    value_mode: str = "email",
) -> list[Decision]:
    """Monta a lista de decisões (o que atualizar e o que deixar como está)."""
    index = UserIndex.build(users)

    by_customer: dict[Any, list[Contact]] = defaultdict(list)
    for contact in contacts:
        by_customer[contact.customer_id].append(contact)

    decisions: list[Decision] = []
    for customer in customers:
        contact = pick_commercial_contact(by_customer.get(customer.id, []), commercial_types)
        if contact is None:
            decisions.append(Decision(customer, "skip", "no_active_commercial_contact"))
            continue

        user, reason = index.resolve(contact)
        if user is None:
            decisions.append(Decision(customer, "skip", reason, contact=contact))
            continue

        value = user_value(user, value_mode)
        if normalize(customer.current_value) == normalize(value):
            decisions.append(Decision(customer, "skip", "up_to_date", contact=contact, user=user, value=value))
            continue

        decisions.append(Decision(customer, "update", reason, contact=contact, user=user, value=value))

    return decisions


def summarize(decisions: Iterable[Decision]) -> dict[str, int]:
    summary: dict[str, int] = defaultdict(int)
    for decision in decisions:
        summary[decision.action] += 1
        summary[f"reason:{decision.reason}"] += 1
    return dict(sorted(summary.items()))
