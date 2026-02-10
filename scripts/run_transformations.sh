#!/bin/sh
###############################################################################
# run_transformations.sh – Re-run SQL transformations only
# Useful when staging data is already loaded and you want to rebuild
# the dimension/fact tables and views.
#
# Usage (from host):
#   docker compose exec pipeline sh /scripts/run_transformations.sh
# Or:
#   docker compose run --rm pipeline sh /scripts/run_transformations.sh
###############################################################################

set -e

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running SQL transformations..."

for sql_file in /sql/transformations/0*.sql; do
    echo "  Executing $(basename "$sql_file")..."
    mysql -h "$MYSQL_HOST" -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" \
        < "$sql_file"
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Transformations complete."
