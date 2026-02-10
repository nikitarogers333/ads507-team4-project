#!/bin/sh
###############################################################################
# monitor.sh – Pipeline monitoring dashboard
#
# Displays the current state of the database: connection status,
# table sizes, recent pipeline runs, and system health.
#
# Usage (from host):
#   docker compose run --rm pipeline sh /scripts/monitor.sh
###############################################################################

set -e

MYSQL_CMD="mysql -h $MYSQL_HOST -u root -p$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE -t"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║        ADS-507 Pipeline Monitoring Dashboard                   ║"
echo "║        $(date '+%Y-%m-%d %H:%M:%S')                                     ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# ── 1. Connection status ─────────────────────────────────────────────────
echo "── Database Connection ──────────────────────────────────────────"
if $MYSQL_CMD -e "SELECT 1" > /dev/null 2>&1; then
    echo "  Status: CONNECTED"
    echo "  Host:   ${MYSQL_HOST}:${MYSQL_TCP_PORT:-3306}"
    echo "  DB:     ${MYSQL_DATABASE}"
else
    echo "  Status: DISCONNECTED"
    exit 1
fi
echo ""

# ── 2. Table sizes ───────────────────────────────────────────────────────
echo "── Table Row Counts ─────────────────────────────────────────────"
$MYSQL_CMD -e "
SELECT
    table_name AS 'Table',
    table_rows AS 'Approx Rows',
    ROUND(data_length / 1024 / 1024, 2) AS 'Data (MB)',
    ROUND(index_length / 1024 / 1024, 2) AS 'Index (MB)'
FROM information_schema.tables
WHERE table_schema = '${MYSQL_DATABASE}'
ORDER BY table_rows DESC;" 2>/dev/null
echo ""

# ── 3. Pipeline status (from dimension/fact existence) ───────────────────
echo "── Pipeline Status ──────────────────────────────────────────────"
FACT_COUNT=$($MYSQL_CMD -N -e "
SELECT COUNT(*)
FROM information_schema.tables
WHERE table_schema = '${MYSQL_DATABASE}'
  AND table_name LIKE 'fact_%';" 2>/dev/null)

DIM_COUNT=$($MYSQL_CMD -N -e "
SELECT COUNT(*)
FROM information_schema.tables
WHERE table_schema = '${MYSQL_DATABASE}'
  AND table_name LIKE 'dim_%';" 2>/dev/null)

VIEW_COUNT=$($MYSQL_CMD -N -e "
SELECT COUNT(*)
FROM information_schema.views
WHERE table_schema = '${MYSQL_DATABASE}'
  AND table_name LIKE 'vw_%';" 2>/dev/null)

echo "  Staging tables:  9 expected"
echo "  Dimension tables: ${DIM_COUNT} / 5 created"
echo "  Fact tables:      ${FACT_COUNT} / 4 created"
echo "  Analytical views: ${VIEW_COUNT} / 5 created"

if [ "$FACT_COUNT" -ge 4 ] && [ "$DIM_COUNT" -ge 5 ] && [ "$VIEW_COUNT" -ge 5 ]; then
    echo "  Overall: ALL PIPELINE STAGES COMPLETE"
else
    echo "  Overall: PIPELINE INCOMPLETE – run 'make pipeline' to execute"
fi
echo ""

# ── 4. Latest pipeline log ───────────────────────────────────────────────
echo "── Latest Pipeline Log ────────────────────────────────────────────"
LATEST_LOG=$(ls -t /logs/pipeline_*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "  Log file: ${LATEST_LOG}"
    echo "  Last 5 lines:"
    tail -5 "$LATEST_LOG" | sed 's/^/    /'
else
    echo "  No pipeline logs found."
fi
echo ""

# ── 5. MySQL process list ────────────────────────────────────────────────
echo "── Active MySQL Processes ───────────────────────────────────────"
$MYSQL_CMD -e "SHOW PROCESSLIST;" 2>/dev/null
echo ""

echo "══════════════════════════════════════════════════════════════════"
echo "  Dashboard refresh complete."
echo "══════════════════════════════════════════════════════════════════"
