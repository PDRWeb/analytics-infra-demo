#!/bin/bash
set -e
LATEST=$(ls -t ./backups/*.sql | head -1)
docker exec -i postgres_main psql -U $PG_USER -d $PG_DB < $LATEST
echo "Restore test complete from $LATEST"
