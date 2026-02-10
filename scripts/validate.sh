#!/bin/sh
###############################################################################
# validate.sh – Run data quality checks
#
# Usage (from host):
#   docker compose run --rm pipeline sh /scripts/validate.sh
###############################################################################

set -e

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running data validation..."
echo ""

mysql -h "$MYSQL_HOST" -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" -t \
    < /sql/validation/050_validate.sql

echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Validation complete."
