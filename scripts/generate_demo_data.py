#!/usr/bin/env python3
import os
import random
from datetime import datetime, timedelta, UTC

import numpy as np
import pandas as pd
from faker import Faker


def ensure_output_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def generate_instore_sales(fake: Faker, num_rows: int) -> pd.DataFrame:
    store_ids = [f"S{str(i).zfill(3)}" for i in range(1, 21)]
    store_cities = [fake.city() for _ in range(20)]
    payment_methods = ["cash", "card", "apple_pay", "google_pay"]
    categories = ["Apparel", "Accessories", "Footwear", "Headwear", "Home"]

    now = datetime.now(UTC)
    rows = []
    for i in range(num_rows):
        product_id = f"P{random.randint(100, 999)}"
        qty = np.random.randint(1, 6)
        unit_price = round(np.random.uniform(9, 149), 2)
        store_idx = np.random.randint(0, len(store_ids))
        rows.append(
            {
                "sale_id": f"IS-{100000 + i}",
                "sale_ts": now - timedelta(minutes=np.random.randint(0, 60 * 24 * 30)),
                "store_id": store_ids[store_idx],
                "store_city": store_cities[store_idx],
                "product_id": product_id,
                "product_name": fake.word().capitalize(),
                "category": random.choice(categories),
                "qty": int(qty),
                "unit_price": float(unit_price),
                "total": float(round(qty * unit_price, 2)),
                "payment_method": random.choice(payment_methods),
                "cashier_id": f"C{np.random.randint(10, 99)}",
                "customer_id": f"U{np.random.randint(1000, 9999)}",
            }
        )
    return pd.DataFrame(rows)


def generate_online_sales(fake: Faker, num_rows: int) -> pd.DataFrame:
    channels = ["web", "mobile_web", "ios_app", "android_app"]
    sources = ["search", "social", "email", "direct", "affiliate"]
    categories = ["Apparel", "Accessories", "Footwear", "Headwear", "Home"]
    now = datetime.now(UTC)
    rows = []
    for i in range(num_rows):
        qty = np.random.randint(1, 5)
        unit_price = round(np.random.uniform(9, 199), 2)
        discount = round(np.random.choice([0, 0, 0, 5, 10, 15], p=[0.4, 0.2, 0.1, 0.1, 0.1, 0.1]), 2)
        rows.append(
            {
                "order_id": f"ON-{200000 + i}",
                "order_ts": now - timedelta(minutes=np.random.randint(0, 60 * 24 * 30)),
                "channel": random.choice(channels),
                "source": random.choice(sources),
                "campaign": fake.bs().title(),
                "product_id": f"P{np.random.randint(100, 999)}",
                "product_name": fake.word().capitalize(),
                "category": random.choice(categories),
                "qty": int(qty),
                "unit_price": float(unit_price),
                "total": float(round(qty * unit_price * (1 - discount / 100.0), 2)),
                "discount_pct": float(discount),
                "customer_id": f"U{np.random.randint(1000, 9999)}",
                "country": fake.country_code(representation="alpha-2"),
                "device": random.choice(["desktop", "tablet", "phone"]),
            }
        )
    return pd.DataFrame(rows)


def generate_marketing_email(fake: Faker, num_days: int) -> pd.DataFrame:
    start = datetime.now(UTC).date() - timedelta(days=num_days)
    rows = []
    for d in range(num_days):
        date = start + timedelta(days=d)
        audience = np.random.randint(5000, 50000)
        sends = int(audience * np.random.uniform(0.8, 1.0))
        opens = int(sends * np.random.uniform(0.15, 0.45))
        clicks = int(opens * np.random.uniform(0.05, 0.2))
        conversions = int(clicks * np.random.uniform(0.02, 0.08))
        revenue = round(conversions * np.random.uniform(25, 120), 2)
        rows.append(
            {
                "date": date,
                "campaign": fake.catch_phrase(),
                "audience_size": int(audience),
                "sends": sends,
                "opens": opens,
                "clicks": clicks,
                "conversions": conversions,
                "revenue": float(revenue),
            }
        )
    return pd.DataFrame(rows)


def generate_marketing_tiktok(fake: Faker, num_days: int) -> pd.DataFrame:
    start = datetime.now(UTC).date() - timedelta(days=num_days)
    rows = []
    for d in range(num_days):
        date = start + timedelta(days=d)
        impressions = np.random.randint(10000, 500000)
        views = int(impressions * np.random.uniform(0.2, 0.7))
        clicks = int(views * np.random.uniform(0.01, 0.05))
        conversions = int(clicks * np.random.uniform(0.02, 0.1))
        spend = round(impressions / 1000 * np.random.uniform(5, 18), 2)
        revenue = round(conversions * np.random.uniform(20, 100), 2)
        rows.append(
            {
                "date": date,
                "campaign": f"TT-{fake.word().capitalize()} Challenge",
                "impressions": impressions,
                "views": views,
                "clicks": clicks,
                "conversions": conversions,
                "spend": float(spend),
                "revenue": float(revenue),
            }
        )
    return pd.DataFrame(rows)


def generate_photo_production(fake: Faker, num_rows: int) -> pd.DataFrame:
    project_types = ["Product", "Lifestyle", "Editorial", "Lookbook", "Ecom"]
    now = datetime.now(UTC).date()
    rows = []
    for i in range(num_rows):
        date = now - timedelta(days=np.random.randint(0, 45))
        assets = np.random.randint(10, 400)
        hours = round(np.random.uniform(2, 40), 1)
        photographers = np.random.randint(1, 4)
        editors = np.random.randint(1, 4)
        cost = round(hours * np.random.uniform(40, 120) + assets * np.random.uniform(1.0, 3.5), 2)
        chargeback = round(cost * np.random.uniform(1.1, 1.4), 2)
        rows.append(
            {
                "date": date,
                "job_id": f"PH-{300000 + i}",
                "client": fake.company(),
                "project_type": random.choice(project_types),
                "assets_shot": int(assets),
                "hours_spent": float(hours),
                "photographers": int(photographers),
                "editors": int(editors),
                "cost": float(cost),
                "internal_chargeback": float(chargeback),
            }
        )
    return pd.DataFrame(rows)


def main() -> None:
    output_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "demo_data"))
    ensure_output_dir(output_dir)

    fake = Faker()
    Faker.seed()
    np.random.seed()
    random.seed()

    generate_instore_sales(fake, 1500).to_csv(os.path.join(output_dir, "instore_sales.csv"), index=False)
    generate_online_sales(fake, 2000).to_csv(os.path.join(output_dir, "online_sales.csv"), index=False)
    generate_marketing_email(fake, 60).to_csv(os.path.join(output_dir, "marketing_email.csv"), index=False)
    generate_marketing_tiktok(fake, 60).to_csv(os.path.join(output_dir, "marketing_tiktok.csv"), index=False)
    generate_photo_production(fake, 250).to_csv(os.path.join(output_dir, "photo_production.csv"), index=False)

    print(f"Demo CSVs written to {output_dir}")


if __name__ == "__main__":
    main()


