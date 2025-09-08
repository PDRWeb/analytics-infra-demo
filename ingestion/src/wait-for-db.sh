#!/bin/sh
# wait-for-db.sh
set -e

host="holding_db"
port=5432

echo "⏳ Waiting for Postgres at $host:$port..."

# Wait until Postgres is ready using Python
until python -c "
import socket
import sys
try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(1)
    result = sock.connect_ex(('$host', $port))
    sock.close()
    sys.exit(result)
except Exception as e:
    sys.exit(1)
" 2>/dev/null; do
  echo "Waiting for DB..."
  sleep 2
done

echo "✅ Postgres is ready. Starting API..."
exec python /app/src/api_receiver.py
