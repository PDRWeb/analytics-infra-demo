\copy merch.instore_sales FROM '/csv/instore_sales.csv' WITH (FORMAT csv, HEADER true);
\copy merch.online_sales FROM '/csv/online_sales.csv' WITH (FORMAT csv, HEADER true);
\copy merch.marketing_email_daily FROM '/csv/marketing_email.csv' WITH (FORMAT csv, HEADER true);
\copy merch.marketing_tiktok_daily FROM '/csv/marketing_tiktok.csv' WITH (FORMAT csv, HEADER true);
\copy merch.photo_production FROM '/csv/photo_production.csv' WITH (FORMAT csv, HEADER true);


