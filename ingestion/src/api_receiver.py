import os
import json
import psycopg2
import pandas as pd
from flask import Flask, request, jsonify
from threading import Thread
from watchdog.observers import Observer
from watchdog.observers.polling import PollingObserver
from watchdog.events import FileSystemEventHandler
from datetime import datetime
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

# Prometheus metrics
api_requests_total = Counter('api_requests_total', 'Total API requests', ['method', 'endpoint', 'status'])
api_request_duration = Histogram('api_request_duration_seconds', 'API request duration', ['method', 'endpoint'])
api_ingest_errors = Counter('api_ingest_errors_total', 'Total ingest errors', ['error_type'])

API_KEY = os.getenv("API_KEY")
DB_CONFIG = {
    "dbname": os.getenv("DB_NAME"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASS"),
    "host": os.getenv("DB_HOST"),
    "port": os.getenv("DB_PORT", 5432),
}

CSV_DIR = "/app/data"
CSV_PATH = f"{CSV_DIR}/fake_sales.csv"


def get_conn():
    return psycopg2.connect(**DB_CONFIG)


def init_db():
    """Ensure required tables exist"""
    try:
        conn = get_conn()
        cur = conn.cursor()

        cur.execute("""
        CREATE TABLE IF NOT EXISTS holding_ingest (
            id SERIAL PRIMARY KEY,
            data JSONB NOT NULL,
            received_at TIMESTAMP NOT NULL DEFAULT NOW(),
            processed BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT NOW()
        );
        """)

        cur.execute("""
        CREATE TABLE IF NOT EXISTS synced_records (
            id SERIAL PRIMARY KEY,
            holding_id INT NOT NULL,
            synced_at TIMESTAMP NOT NULL
        );
        """)

        conn.commit()
        cur.close()
        conn.close()
        print("✅ Verified that holding_ingest and synced_records tables exist")
    except Exception as e:
        print(f"❌ Error initializing database: {e}")


def ingest_csv(path=CSV_PATH):
    """Load a CSV file into holding_ingest"""
    if not os.path.exists(path):
        print(f"⚠️ CSV file not found at {path}, skipping.")
        return 0

    try:
        df = pd.read_csv(path)
        print(f"📥 Loaded {len(df)} rows from {path}")

        # Replace NaN with None so JSON is valid
        df = df.where(pd.notnull(df), None)

        conn = get_conn()
        cur = conn.cursor()

        # Batch insert for better performance
        data_tuples = []
        for _, row in df.iterrows():
            payload = row.to_dict()
            data_tuples.append((
                json.dumps(payload, default=str), 
                datetime.utcnow()
            ))
        
        # Use executemany for batch insert
        cur.executemany(
            "INSERT INTO holding_ingest (data, received_at) VALUES (%s, %s)",
            data_tuples
        )

        conn.commit()
        cur.close()
        conn.close()
        print("✅ Finished ingesting CSV into holding_ingest")
        return len(df)
    except Exception as e:
        print(f"❌ Error ingesting CSV: {e}")
        return 0


class CsvCreatedHandler(FileSystemEventHandler):
    def on_created(self, event):
        if event.is_directory:
            return
        path = event.src_path
        if path.lower().endswith(".csv"):
            try:
                print(f"👀 Detected new CSV: {path}. Ingesting...")
                rows = ingest_csv(path)
                print(f"✅ Ingested {rows} rows from {path}")
            except Exception as e:
                print(f"❌ Failed to ingest detected CSV {path}: {e}")


@app.route("/ingest", methods=["POST"])
def ingest_api():
    """Ingest data from API POST requests"""
    with api_request_duration.labels(method='POST', endpoint='/ingest').time():
        if request.headers.get("x-api-key") != API_KEY:
            api_requests_total.labels(method='POST', endpoint='/ingest', status='401').inc()
            return jsonify({"error": "Unauthorized"}), 401

        payload = request.get_json()
        if not payload:
            api_requests_total.labels(method='POST', endpoint='/ingest', status='400').inc()
            api_ingest_errors.labels(error_type='missing_json').inc()
            return jsonify({"error": "Missing JSON"}), 400

        try:
            conn = get_conn()
            cur = conn.cursor()
            cur.execute(
                "INSERT INTO holding_ingest (data, received_at) VALUES (%s, %s)",
                [json.dumps(payload), datetime.utcnow()],
            )
            conn.commit()
            cur.close()
            conn.close()
            api_requests_total.labels(method='POST', endpoint='/ingest', status='201').inc()
            return jsonify({"status": "ok"}), 201
        except Exception as e:
            api_requests_total.labels(method='POST', endpoint='/ingest', status='500').inc()
            api_ingest_errors.labels(error_type='database_error').inc()
            return jsonify({"error": str(e)}), 500

@app.route("/health")
def health():
    """Health check endpoint"""
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        return jsonify({"status": "healthy", "service": "api-receiver"}), 200
    except Exception as e:
        return jsonify({"status": "unhealthy", "error": str(e)}), 503

@app.route("/metrics")
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

def start_csv_watcher():
    os.makedirs(CSV_DIR, exist_ok=True)
    event_handler = CsvCreatedHandler()
    # Use PollingObserver to ensure changes on mounted volumes are detected across platforms
    observer = PollingObserver()
    observer.schedule(event_handler, CSV_DIR, recursive=False)
    observer.start()
    print(f"👂 Watching {CSV_DIR} for new CSV files...")
    return observer


if __name__ == "__main__":
    # 1. Ensure tables exist
    init_db()

    # 2. Start background watcher and preload CSV if present
    observer = start_csv_watcher()
    ingest_csv()

    # 3. Start API
    port = int(os.getenv("PORT", 8080))
    try:
        app.run(host="0.0.0.0", port=port)
    finally:
        observer.stop()
        observer.join()
