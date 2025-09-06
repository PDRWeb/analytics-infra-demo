#!/bin/bash
set -e
DATE=$(date +%Y%m%d_%H%M%S)
docker exec postgres_main pg_dump -U $PG_USER $PG_DB > ./backups/backup_$DATE.sql

if [ -s "./backups/backup_$DATE.sql" ]; then
	echo "Backup complete: ./backups/backup_$DATE.sql"
else
	echo "Backup failed: backup file not created or empty" >&2
	exit 1
fi
