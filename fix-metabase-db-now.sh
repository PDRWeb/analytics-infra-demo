#!/bin/bash

# Immediate fix for Metabase database issue
# Run this script to manually create the metabase database

echo "🔧 Creating Metabase database manually..."

# Get the database credentials from environment or use defaults
DB_USER="${MAIN_DB_USER:-analytics_user}"
DB_PASS="${MAIN_DB_PASS:-analytics123}"
DB_NAME="${METABASE_APP_DB_NAME:-metabase}"

echo "📊 Creating database: $DB_NAME"
echo "👤 Using user: $DB_USER"

# Create the database
docker exec postgres_main createdb -U "$DB_USER" "$DB_NAME" || {
    echo "❌ Failed to create database with user $DB_USER"
    echo "🔄 Trying with postgres user..."
    docker exec postgres_main createdb -U postgres "$DB_NAME" || {
        echo "❌ Failed to create database with postgres user"
        echo "💡 Check if postgres_main container is running:"
        echo "   docker ps | grep postgres_main"
        exit 1
    }
}

echo "✅ Database '$DB_NAME' created successfully!"

# Restart Metabase to pick up the new database
echo "🔄 Restarting Metabase..."
docker restart metabase

echo "🎉 Metabase should now work with the new database!"
echo "🌐 Check Metabase at: http://localhost:3000"
