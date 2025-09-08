#!/bin/bash

set -euo pipefail

# Migrate Metabase application data from H2 file to Postgres app DB using Docker image's JAR
# Docs: https://www.metabase.com/docs/latest/installation-and-operation/migrating-from-h2

# Load needed vars from .env safely (only KEY=VALUE lines)
if [ -f ./.env ]; then
  while IFS= read -r line; do
    case "$line" in
      ''|\#*) continue;;
      *=*) key="${line%%=*}"; val="${line#*=}"; export "$key"="$val";;
      *) ;; # skip invalid lines
    esac
  done < ./.env
fi

METABASE_IMAGE_TAG="metabase/metabase:v0.48.0"
H2_DIR="./visualization/metabase"
H2_FILE_BASENAME="metabase.db"   # The command expects path without .mv.db

# Target DB connection (uses MAIN_DB_* envs and optional METABASE_APP_DB_NAME)
APP_DB_HOST="postgres_main"
APP_DB_PORT="5432"
APP_DB_NAME="${METABASE_APP_DB_NAME:-metabase}"
APP_DB_USER="${MAIN_DB_USER:-postgres}"
APP_DB_PASS="${MAIN_DB_PASS:-postgres}"

echo "[INFO] Checking for Metabase H2 database in ${H2_DIR}"

if [ ! -d "${H2_DIR}" ]; then
  echo "[WARNING] ${H2_DIR} not found; nothing to migrate"
  exit 0
fi

H2_MV_DB_PATH="${H2_DIR}/${H2_FILE_BASENAME}.mv.db"
if [ ! -f "${H2_MV_DB_PATH}" ]; then
  echo "[INFO] No H2 file found at ${H2_MV_DB_PATH}; nothing to migrate"
  exit 0
fi

echo "[INFO] Preparing to migrate H2 -> Postgres app DB ${APP_DB_NAME} on ${APP_DB_HOST}:${APP_DB_PORT}"

# Ensure target DB exists (idempotent)
echo "[INFO] Ensuring target Metabase app DB exists..."
if ! docker-compose exec -T postgres_main psql -U "${APP_DB_USER}" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${APP_DB_NAME}'" | grep -q 1; then
  echo "[INFO] Creating database ${APP_DB_NAME}"
  docker-compose exec -T postgres_main createdb -U "${APP_DB_USER}" "${APP_DB_NAME}" || {
    echo "[WARNING] Failed to create ${APP_DB_NAME}. Ensure user has CREATEDB privileges."
  }
else
  echo "[INFO] Database ${APP_DB_NAME} already exists"
fi

# Check if migration already done: look for a known table in target DB
echo "[INFO] Checking if migration is already completed..."
if docker-compose exec -T postgres_main psql -U "${APP_DB_USER}" -d "${APP_DB_NAME}" -tAc "SELECT to_regclass('public.core_user') IS NOT NULL" | grep -q "t"; then
  echo "[SUCCESS] Metabase app DB already populated; skipping migration"
  exit 0
fi

echo "[INFO] Running load-from-h2 using ${METABASE_IMAGE_TAG}"

# Run the migration using the Metabase JAR inside the Docker image
docker run --rm \
  -e MB_DB_TYPE=postgres \
  -e MB_DB_HOST="${APP_DB_HOST}" \
  -e MB_DB_PORT="${APP_DB_PORT}" \
  -e MB_DB_DBNAME="${APP_DB_NAME}" \
  -e MB_DB_USER="${APP_DB_USER}" \
  -e MB_DB_PASS="${APP_DB_PASS}" \
  -v "$(pwd)/visualization/metabase":/metabase-data \
  "${METABASE_IMAGE_TAG}" \
  load-from-h2 "/metabase-data/${H2_FILE_BASENAME}"

echo "[SUCCESS] Metabase application data migrated to Postgres (${APP_DB_NAME})"


