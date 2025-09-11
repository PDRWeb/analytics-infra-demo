#!/bin/bash

# Initialize Metabase database for Dokploy deployment
# This script creates the metabase database if it doesn't exist

set -euo pipefail

echo "🔧 Initializing Metabase database..."

# Load environment variables
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Set default values
DB_NAME="${METABASE_APP_DB_NAME:-metabase}"
DB_USER="${MAIN_DB_USER:-analytics_user}"
DB_PASS="${MAIN_DB_PASS:-analytics123}"

echo "📊 Database: $DB_NAME"
echo "👤 User: $DB_USER"

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
until docker exec postgres_main pg_isready -U "$DB_USER" -d postgres; do
  echo "   PostgreSQL is unavailable - sleeping..."
  sleep 2
done

echo "✅ PostgreSQL is ready!"

# Create the metabase database if it doesn't exist
echo "🔍 Checking if database '$DB_NAME' exists..."
if ! docker exec postgres_main psql -U "$DB_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
  echo "📝 Creating database '$DB_NAME'..."
  docker exec postgres_main createdb -U "$DB_USER" "$DB_NAME" || {
    echo "❌ Failed to create database '$DB_NAME'"
    echo "💡 Make sure the user '$DB_USER' has CREATEDB privileges"
    exit 1
  }
  echo "✅ Database '$DB_NAME' created successfully!"
else
  echo "✅ Database '$DB_NAME' already exists!"
fi

echo "🎉 Metabase database initialization complete!"
