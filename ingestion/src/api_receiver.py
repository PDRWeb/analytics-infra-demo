import os
import json
import psycopg2
from flask import Flask, request, jsonify
from datetime import datetime

app = Flask(__name__)

API_KEY = os.getenv("API_KEY")
DB_CONFIG = {
    "dbname": os.getenv("DB_NAME"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASS"),
    "host": os.getenv("DB_HOST"),
    "port": os.getenv("DB_PORT", 5432),
}

def get_conn():
    return psycopg2.connect(**DB_CONFIG)

@app.route("/ingest", methods=["POST"])
def ingest():
    if request.headers.get("x-api-key") != API_KEY:
        return jsonify({"error": "Unauthorized"}), 401

    payload = request.get_json()
    if not payload:
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
        return jsonify({"status": "ok"}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
