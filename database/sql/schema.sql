-- Main DB schema for demo merch company
CREATE SCHEMA IF NOT EXISTS merch;

-- In-store sales
CREATE TABLE IF NOT EXISTS merch.instore_sales (
    sale_id TEXT PRIMARY KEY,
    sale_ts TIMESTAMP NOT NULL,
    store_id TEXT NOT NULL,
    store_city TEXT,
    product_id TEXT NOT NULL,
    product_name TEXT,
    category TEXT,
    qty INTEGER NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    total NUMERIC(12,2) NOT NULL,
    payment_method TEXT,
    cashier_id TEXT,
    customer_id TEXT
);

-- Online sales
CREATE TABLE IF NOT EXISTS merch.online_sales (
    order_id TEXT PRIMARY KEY,
    order_ts TIMESTAMP NOT NULL,
    channel TEXT,
    source TEXT,
    campaign TEXT,
    product_id TEXT NOT NULL,
    product_name TEXT,
    category TEXT,
    qty INTEGER NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    total NUMERIC(12,2) NOT NULL,
    discount_pct NUMERIC(5,2),
    customer_id TEXT,
    country TEXT,
    device TEXT
);

-- Marketing: Email (EMTA-like)
CREATE TABLE IF NOT EXISTS merch.marketing_email_daily (
    date DATE PRIMARY KEY,
    campaign TEXT,
    audience_size INTEGER,
    sends INTEGER,
    opens INTEGER,
    clicks INTEGER,
    conversions INTEGER,
    revenue NUMERIC(12,2)
);

-- Marketing: TikTok
CREATE TABLE IF NOT EXISTS merch.marketing_tiktok_daily (
    date DATE PRIMARY KEY,
    campaign TEXT,
    impressions BIGINT,
    views BIGINT,
    clicks BIGINT,
    conversions BIGINT,
    spend NUMERIC(12,2),
    revenue NUMERIC(12,2)
);

-- In-house photo studio production
CREATE TABLE IF NOT EXISTS merch.photo_production (
    date DATE NOT NULL,
    job_id TEXT PRIMARY KEY,
    client TEXT,
    project_type TEXT,
    assets_shot INTEGER,
    hours_spent NUMERIC(6,1),
    photographers INTEGER,
    editors INTEGER,
    cost NUMERIC(12,2),
    internal_chargeback NUMERIC(12,2)
);


