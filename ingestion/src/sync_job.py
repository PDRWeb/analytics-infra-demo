import os
import psycopg2
import time
import json

HOLDING_DB = {
    "dbname": os.getenv("DB_NAME"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASS"),
    "host": os.getenv("DB_HOST"),
    "port": os.getenv("DB_PORT", 5432),
}

MAIN_DB = {
    "dbname": os.getenv("MAIN_DB_NAME"),
    "user": os.getenv("MAIN_DB_USER"),
    "password": os.getenv("MAIN_DB_PASS"),
    "host": os.getenv("MAIN_DB_HOST"),
    "port": os.getenv("MAIN_DB_PORT", 5432),
}

def get_conn(cfg):
    return psycopg2.connect(**cfg)

def sync():
    holding = get_conn(HOLDING_DB)
    main = get_conn(MAIN_DB)
    h_cur = holding.cursor()
    m_cur = main.cursor()

    h_cur.execute("SELECT h.id, h.data, h.received_at FROM holding_ingest h LEFT JOIN synced_records s ON h.id = s.holding_id WHERE s.holding_id IS NULL")
    rows = h_cur.fetchall()

    for row in rows:
        hid, data, ts = row
        try:
            # Begin transaction for both databases
            main.autocommit = False
            holding.autocommit = False

            m_cur.execute("INSERT INTO main_ingest (data, received_at) VALUES (%s, %s) RETURNING id", [json.dumps(data), ts])
            # log sync
            h_cur.execute("INSERT INTO synced_records (holding_id, synced_at) VALUES (%s, NOW())", [hid])

            main.commit()
            holding.commit()
        except Exception as e:
            main.rollback()
            holding.rollback()
            print(f"Error syncing row {hid}: {e}")
        finally:
            main.autocommit = True
            holding.autocommit = True

    h_cur.close()
    m_cur.close()
    holding.close()
    main.close()

if __name__ == "__main__":
    while True:
        sync()
        time.sleep(60)
