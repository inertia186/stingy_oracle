#!/bin/bash

echo "Importing production database..."
REMOTE_USER=stingy
REMOTE_DB_USER=stingy
REMOTE_DB_NAME=stingy_production

# Kill all current connections to the database and delete it.
psql stingy_development -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = 'stingy_development' AND pid <> pg_backend_pid();"
dropdb stingy_development

# Create new database and prepare it.
createdb -O stingy stingy_development

# Load database from server
ssh $REMOTE_USER@107.170.241.153 "pg_dump $REMOTE_DB_NAME -U $REMOTE_DB_USER | gzip" | gunzip | psql -U stingy stingy_development

