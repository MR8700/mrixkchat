#!/bin/bash
set -e

if [ -z "$DATABASE_URL" ]; then
  echo "Error: DATABASE_URL environment variable is not set."
  echo "Usage: DATABASE_URL='postgres://user:pass@host:port/db' ./infrastructure/postgres/run-migrations.sh"
  exit 1
fi

MIGRATIONS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/migrations" && pwd)"

echo "==> Applying migrations from $MIGRATIONS_DIR"
for file in $(ls -1 "$MIGRATIONS_DIR"/*.up.sql | sort); do
  echo "-> Executing: $(basename "$file")"
  psql "$DATABASE_URL" -f "$file"
done

echo "==> All migrations executed successfully!"
