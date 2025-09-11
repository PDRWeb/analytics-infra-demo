#!/bin/bash

# Initialize Metabase database for Dokploy deployment
# This script creates the metabase database if it doesn't exist
# Runs inside a PostgreSQL container, so uses psql directly

set -euo pipefail

echo "🔧 Initializing Metabase database..."

# Set default values
DB_NAME="${METABASE_APP_DB_NAME:-metabase}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_PASS="${POSTGRES_PASSWORD:-postgres}"
MAIN_DB_HOST="${MAIN_DB_HOST:-postgres_main}"
MAIN_DB_PORT="${MAIN_DB_PORT:-5432}"

echo "📊 Database: $DB_NAME"
echo "👤 User: $DB_USER"
echo "🌐 Host: $MAIN_DB_HOST:$MAIN_DB_PORT"

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready at ${MAIN_DB_HOST}:${MAIN_DB_PORT}..."
until PGPASSWORD="${DB_PASS}" psql -h "${MAIN_DB_HOST}" -p "${MAIN_DB_PORT}" -U "${DB_USER}" -d postgres -c '\q'; do
  echo "   PostgreSQL is unavailable - sleeping..."
  sleep 2
done

echo "✅ PostgreSQL is ready!"

# Create the metabase database if it doesn't exist
echo "🔍 Checking if database '$DB_NAME' exists..."
if ! PGPASSWORD="${DB_PASS}" psql -h "${MAIN_DB_HOST}" -p "${MAIN_DB_PORT}" -U "${DB_USER}" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  echo "📝 Creating database '$DB_NAME'..."
  PGPASSWORD="${DB_PASS}" psql -h "${MAIN_DB_HOST}" -p "${MAIN_DB_PORT}" -U "${DB_USER}" -d postgres -c "CREATE DATABASE \"${DB_NAME}\";" || {
    echo "❌ Failed to create database '$DB_NAME'"
    echo "💡 Make sure the user '$DB_USER' has CREATEDB privileges"
    exit 1
  }
  echo "✅ Database '$DB_NAME' created successfully!"
else
  echo "✅ Database '$DB_NAME' already exists!"
fi

echo "🎉 Metabase database initialization complete!"
