import pandas as pd
import numpy as np
from faker import Faker

fake = Faker()
num_rows = 1000

data = {
    "sale_id": [f"S{1000+i}" for i in range(num_rows)],
    "sale_date": [fake.date_time_this_year() for _ in range(num_rows)],
    "customer_id": [fake.random_int(min=1, max=200) for _ in range(num_rows)],
    "item_id": [fake.random_int(min=1, max=50) for _ in range(num_rows)],
    "item_name": [fake.word().capitalize() for _ in range(num_rows)],
    "quantity": [fake.random_int(min=1, max=5) for _ in range(num_rows)],
    "unit_price": [round(fake.random_number(digits=2) + 0.99, 2) for _ in range(num_rows)]
}

df = pd.DataFrame(data)
df["total_price"] = df["quantity"] * df["unit_price"]

df.to_csv("ingestion/data/fake_sales.csv", index=False)
print("Generated fake_sales.csv with 1000 rows ✅")
