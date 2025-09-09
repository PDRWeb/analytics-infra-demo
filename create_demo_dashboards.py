#!/usr/bin/env python3
import requests
import sys

# === Configuration ===
METABASE_URL = "http://localhost:3000"     # Change if needed
API_KEY = "YOUR_API_KEY_HERE"  # Replace with your actual API key from Metabase Admin Panel

HEADERS = {
    "Content-Type": "application/json",
    "X-API-KEY": API_KEY
}

# === Dashboards & Cards Definitions ===
dashboards = [
    {
        "dashboard": {
            "name": "Sales Performance Dashboard",
            "description": "Track in-store and online sales performance",
            "collection_id": None
        },
        "cards": [
            {
                "name": "Total In-Store Sales",
                "dataset_query": {
                    "type": "native",
                    "native": {"query": "SELECT SUM(total) AS total_instore_sales FROM instore_sales"},
                    "database": 1
                },
                "display": "number",
                "visualization_settings": {}
            },
            {
                "name": "Total Online Sales",
                "dataset_query": {
                    "type": "native",
                    "native": {"query": "SELECT SUM(total) AS total_online_sales FROM online_sales"},
                    "database": 1
                },
                "display": "number",
                "visualization_settings": {}
            },
            {
                "name": "Top Selling Categories (In-Store)",
                "dataset_query": {
                    "type": "native",
                    "native": {"query": "SELECT category, SUM(total) AS total_sales FROM instore_sales GROUP BY category ORDER BY total_sales DESC"},
                    "database": 1
                },
                "display": "bar",
                "visualization_settings": {}
            },
            {
                "name": "Online Sales by Channel",
                "dataset_query": {
                    "type": "native",
                    "native": {"query": "SELECT channel, SUM(total) AS total_sales FROM online_sales GROUP BY channel ORDER BY total_sales DESC"},
                    "database": 1
                },
                "display": "pie",
                "visualization_settings": {}
            },
            {
                "name": "Sales Trend (Last 30 Days)",
                "dataset_query": {
                    "type": "native",
                    "native": {
                        "query": "SELECT DATE(order_ts) AS day, SUM(total) AS daily_online, (SELECT SUM(total) FROM instore_sales s WHERE DATE(s.sale_ts)=DATE(o.order_ts)) AS daily_instore FROM online_sales o GROUP BY day ORDER BY day"
                    },
                    "database": 1
                },
                "display": "line",
                "visualization_settings": {}
            }
        ]
    },
    {
        "dashboard": {
            "name": "Marketing Performance Dashboard",
            "description": "Measure performance of email and TikTok marketing campaigns",
            "collection_id": None
        },
        "cards": [
            {
                "name": "Email Campaign Revenue",
                "dataset_query": {
                    "type": "native",
                    "native": {"query": "SELECT SUM(revenue) AS email_revenue FROM marketing_email"},
                    "database": 1
                },
                "display": "number",
                "visualization_settings": {}
            },
            {
                "name": "TikTok Campaign Revenue",
                "dataset_query": {
                    "type": "native",
                    "native": {"query": "SELECT SUM(revenue) AS tiktok_revenue FROM marketing_tiktok"},
                    "database": 1
                },
                "display": "number",
                "visualization_settings": {}
            },
            {
                "name": "Email Open & Click Rates",
                "dataset_query": {
                    "type": "native",
                    "native": {
                        "query": "SELECT date, ROUND(AVG(opens*100.0/sends),2) AS open_rate, ROUND(AVG(clicks*100.0/opens),2) AS click_rate FROM marketing_email GROUP BY date ORDER BY date"
                    },
                    "database": 1
                },
                "display": "line",
                "visualization_settings": {}
            },
            {
                "name": "TikTok ROAS (Revenue/Spend)",
                "dataset_query": {
                    "type": "native",
                    "native": {
                        "query": "SELECT date, ROUND(SUM(revenue)/NULLIF(SUM(spend),0),2) AS roas FROM marketing_tiktok GROUP BY date ORDER BY date"
                    },
                    "database": 1
                },
                    "display": "line",
                "visualization_settings": {}
            },
            {
                "name": "Top Performing Email Campaigns",
                "dataset_query": {
                    "type": "native",
                    "native": {
                        "query": "SELECT campaign, SUM(revenue) AS revenue FROM marketing_email GROUP BY campaign ORDER BY revenue DESC LIMIT 10"
                    },
                    "database": 1
                },
                "display": "bar",
                "visualization_settings": {}
            }
        ]
    },
    {
        "dashboard": {
            "name": "Photo Production Dashboard",
            "description": "Track efficiency and cost of photo production projects",
            "collection_id": None
        },
        "cards": [
            {
                "name": "Total Assets Shot",
                "dataset_query": {
                    "type": "native",
                    "native": {"query": "SELECT SUM(assets_shot) AS total_assets FROM photo_production"},
                    "database": 1
                },
                "display": "number",
                "visualization_settings": {}
            },
            {
                "name": "Total Production Cost",
                "dataset_query": {
                    "type": "native",
                    "native": {"query": "SELECT SUM(cost) AS total_cost FROM photo_production"},
                    "database": 1
                },
                "display": "number",
                "visualization_settings": {}
            },
            {
                "name": "Project Types Breakdown",
                "dataset_query": {
                    "type": "native",
                    "native": {
                        "query": "SELECT project_type, COUNT(*) AS projects, SUM(cost) AS total_cost FROM photo_production GROUP BY project_type ORDER BY total_cost DESC"
                    },
                    "database": 1
                },
                "display": "bar",
                "visualization_settings": {}
            },
            {
                "name": "Top Clients by Spend",
                "dataset_query": {
                    "type": "native",
                    "native": {
                        "query": "SELECT client, SUM(cost) AS total_spend FROM photo_production GROUP BY client ORDER BY total_spend DESC LIMIT 10"
                    },
                    "database": 1
                },
                "display": "bar",
                "visualization_settings": {}
            },
            {
                "name": "Cost vs. Chargeback Over Time",
                "dataset_query": {
                    "type": "native",
                    "native": {
                        "query": "SELECT date, SUM(cost) AS total_cost, SUM(internal_chargeback) AS total_chargeback FROM photo_production GROUP BY date ORDER BY date"
                    },
                    "database": 1
                },
                "display": "line",
                "visualization_settings": {}
            }
        ]
    }
]

def create_dashboard_with_cards(defn):
    resp = requests.post(f"{METABASE_URL}/api/dashboard", headers=HEADERS, json=defn["dashboard"])
    if not resp.ok:
        print(f"[ERROR] Dashboard '{defn['dashboard']['name']}' failed: {resp.status_code} – {resp.text}", file=sys.stderr)
        return
    dash_id = resp.json().get("id")
    print(f"Created dashboard '{defn['dashboard']['name']}' (ID: {dash_id})")

    card_layouts = []
    for idx, card in enumerate(defn["cards"]):
        c_resp = requests.post(f"{METABASE_URL}/api/card", headers=HEADERS, json=card)
        if not c_resp.ok:
            print(f"[ERROR] Card '{card['name']}' failed: {c_resp.status_code} – {c_resp.text}", file=sys.stderr)
            continue
        card_id = c_resp.json().get("id")
        print(f" Created card '{card['name']}' (ID: {card_id})")

        card_layouts.append({
            "id": -1 - idx,  # Unique negative placeholder IDs: -1, -2, -3...
            "card_id": card_id,
            "row": (idx // 3) * 4,
            "col": (idx % 3) * 4,
            "size_x": 4,
            "size_y": 4,
            "series": [],
            "visualization_settings": {},
            "parameter_mappings": []
        })

    if not card_layouts:
        print(f"[WARN] No cards to add for '{defn['dashboard']['name']}'", file=sys.stderr)
        return

    payload = {"cards": card_layouts, "ordered_tabs": []}
    put_resp = requests.put(f"{METABASE_URL}/api/dashboard/{dash_id}/cards", headers=HEADERS, json=payload)
    if not put_resp.ok:
        print(f"[ERROR] Adding cards failed (dashboard {dash_id}): {put_resp.status_code} – {put_resp.text}", file=sys.stderr)
    else:
        print(f"Added {len(card_layouts)} cards to '{defn['dashboard']['name']}'")

def main():
    for defn in dashboards:
        create_dashboard_with_cards(defn)
    print("All dashboards processed.")

if __name__ == "__main__":
    main()
