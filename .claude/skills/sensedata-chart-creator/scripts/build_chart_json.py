#!/usr/bin/env python3
"""Esqueleto pra montar um novo JSON de gráfico/tabela do SenseData.

Copie este arquivo, ajuste `query` e `data`, rode, e depois valide o resultado
com validate_chart_json.py. Montar o JSON via json.dump (em vez de digitar à
mão) evita erro de escape em aspas, emoji, %, e barra invertida de regex.
"""
import json

# Escreva a query como string multi-linha normal — fica muito mais fácil de
# ler e editar do que numa linha só. O script colapsa pra uma linha no final.
query = """SELECT
    -- suas colunas aqui
    campo_a,
    campo_b
FROM alguma_tabela
WHERE id_customer = %(id_customer)s
ORDER BY campo_a DESC
LIMIT 12"""

query_oneline = " ".join(line.strip() for line in query.splitlines())

data = {
    "_comment": "",
    "advanced_mode": True,
    "aggregation_type": None,
    "chart_type": "table",
    "columns": [
        {"field": "campo_a", "title": "Campo A", "width": "120px"},
        {"field": "campo_b", "title": "Campo B", "width": "120px"},
        # exemplo de coluna com template:
        # {"field": "campo_c", "title": "Campo C", "width": "150px",
        #  "template": "#= campo_c == null ? '-' : campo_c #"},
    ],
    "custom_data_type": None,
    "data_fields": [],
    "data_source": "alguma_tabela",
    "dimension": None,
    "fields": {
        "fields": {
            "campo_a": {"field": "campo_a", "type": "string"},
            "campo_b": {"field": "campo_b", "type": "number"},
        }
    },
    "filter": [],
    "interval_range": None,
    "interval_type": None,
    "legend": True,
    "name": "nome_interno_snake_case",
    "query": query_oneline,
    "slots": 2,
    "title": "Título visível pro usuário",
    "tooltip_template": None,
    "transpose": None,
    "type": "table",
    "x": "",
    "x_template": "",
    "x_title": "",
    "x_type": None,
    "y": [],
    "y_labels": {},
    "y_title": [],
}

OUTPUT_PATH = "saida.json"  # ajuste o caminho de saída

with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f"written: {OUTPUT_PATH}")
