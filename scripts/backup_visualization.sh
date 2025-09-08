#!/bin/bash

set -euo pipefail

BACKUP_ROOT="./visualization/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DEST_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

mkdir -p "${DEST_DIR}"

echo "[INFO] Backing up visualization configs to ${DEST_DIR}"

# Metabase application DB dump (Postgres)
echo "[INFO] Dumping Metabase application database (Postgres)"
METABASE_DB_NAME=${METABASE_APP_DB_NAME:-metabase}
# Read POSTGRES_USER from container env to avoid host env dependency
POSTGRES_USER_IN_CONTAINER=$(docker-compose exec -T postgres_main env | awk -F= '/^POSTGRES_USER=/{print $2}' || true)
POSTGRES_USER_IN_CONTAINER=${POSTGRES_USER_IN_CONTAINER:-postgres}
if docker-compose ps postgres_main >/dev/null 2>&1; then
  if docker-compose exec -T postgres_main bash -lc "psql -U '${POSTGRES_USER_IN_CONTAINER}' -d postgres -tAc \"SELECT 1 FROM pg_database WHERE datname='${METABASE_DB_NAME}'\"" | grep -q 1; then
    if docker-compose exec -T postgres_main which pg_dump >/dev/null 2>&1; then
      docker-compose exec -T postgres_main pg_dump -U "${POSTGRES_USER_IN_CONTAINER}" -d "${METABASE_DB_NAME}" | gzip > "${DEST_DIR}/metabase.sql.gz" \
        && echo "[SUCCESS] Metabase DB dump saved to ${DEST_DIR}/metabase.sql.gz" \
        || echo "[WARNING] Failed to dump Metabase DB"
    else
      echo "[WARNING] pg_dump not found in postgres_main container"
    fi
  else
    echo "[WARNING] Database ${METABASE_DB_NAME} not found on postgres_main; skipping DB dump"
  fi
else
  echo "[WARNING] postgres_main container not found; skipping DB dump"
fi

# Metabase app data (contains H2 or plugins/config if used)
if [ -d "./visualization/metabase" ]; then
  tar -czf "${DEST_DIR}/metabase.tar.gz" -C ./visualization metabase
  echo "[SUCCESS] Metabase backup created"
else
  echo "[WARNING] ./visualization/metabase not found; skipping Metabase backup"
fi

# Grafana (monitoring) data and provisioning
if [ -d "./monitoring/grafana" ]; then
  tar -czf "${DEST_DIR}/grafana-monitoring.tar.gz" -C ./monitoring grafana
  echo "[SUCCESS] Grafana monitoring backup created"
else
  echo "[WARNING] ./monitoring/grafana not found; skipping Grafana monitoring backup"
fi

# Grafana (logs) data and provisioning
if [ -d "./logging/grafana-logs" ]; then
  tar -czf "${DEST_DIR}/grafana-logs.tar.gz" -C ./logging grafana-logs
  echo "[SUCCESS] Grafana logs backup created"
else
  echo "[WARNING] ./logging/grafana-logs not found; skipping Grafana logs backup"
fi

echo "[SUCCESS] Visualization backups complete"


