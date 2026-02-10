#!/bin/sh
###############################################################################
# run_pipeline.sh – Master ETL pipeline orchestrator
#
# Runs inside the Alpine-based pipeline container.
# Steps:
#   1. Install dependencies (curl, mysql-client)
#   2. Download raw CSV files from GitHub release
#   3. Wait for MySQL to be fully ready
#   4. Load CSV data into staging tables
#   5. Run SQL transformations (clean → dim → fact → views)
#   6. Run data validation checks
###############################################################################

set -e

LOG_DIR="/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/pipeline_${TIMESTAMP}.log"
mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

# Record pipeline start
PIPELINE_START=$(date +%s)
log "=========================================="
log "  ADS-507 E-Commerce ETL Pipeline"
log "  Team 4 – Olist Dataset"
log "=========================================="

# ── Step 0: Install dependencies ──────────────────────────────────────────
log "STEP 0 – Installing dependencies..."
apk add --no-cache curl mysql-client dos2unix >> "$LOG_FILE" 2>&1
log "Dependencies installed."

# ── Step 1: Download raw data ─────────────────────────────────────────────
log "STEP 1 – Downloading raw data from GitHub release..."
BASE_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${RELEASE_TAG}"
DATA_DIR="/data/raw"
mkdir -p "$DATA_DIR"

download_file() {
    local filename="$1"
    if [ -f "${DATA_DIR}/${filename}" ]; then
        log "  [skip] ${filename} already exists"
    else
        log "  [download] ${filename}..."
        curl -sSL -o "${DATA_DIR}/${filename}" "${BASE_URL}/${filename}" 2>> "$LOG_FILE"
        if [ $? -ne 0 ]; then
            log_error "Failed to download ${filename}"
            return 1
        fi
    fi
}

# Download core datasets
for f in \
    olist_customers_dataset.csv \
    olist_orders_dataset.csv \
    olist_order_items_dataset.csv \
    olist_order_payments_dataset.csv \
    olist_order_reviews_dataset.csv \
    olist_products_dataset.csv \
    olist_sellers_dataset.csv \
    product_category_name_translation.csv; do
    download_file "$f"
done

# Download geolocation parts and reassemble
log "  Downloading geolocation parts..."
GEO_REASSEMBLED="${DATA_DIR}/olist_geolocation_dataset.csv"
if [ -f "$GEO_REASSEMBLED" ]; then
    log "  [skip] olist_geolocation_dataset.csv already exists"
else
    # Download part 1 (has the header row)
    for i in 1 2 3 4 5 6 7 8 9 10 11; do
        download_file "geo_part_${i}.csv"
    done
    # Reassemble: keep header from part 1, skip headers from parts 2-11
    cp "${DATA_DIR}/geo_part_1.csv" "$GEO_REASSEMBLED"
    for i in 2 3 4 5 6 7 8 9 10 11; do
        tail -n +2 "${DATA_DIR}/geo_part_${i}.csv" >> "$GEO_REASSEMBLED"
    done
    log "  Reassembled geolocation dataset from 11 parts."
fi

# Convert line endings (Windows → Unix)
log "  Converting line endings..."
for csvfile in "${DATA_DIR}"/*.csv; do
    dos2unix "$csvfile" 2>/dev/null || true
done

FILE_COUNT=$(ls -1 "${DATA_DIR}"/olist_*.csv "${DATA_DIR}"/product_*.csv 2>/dev/null | wc -l)
log "  ${FILE_COUNT} CSV files ready in ${DATA_DIR}."

# ── Step 2: Wait for MySQL ────────────────────────────────────────────────
log "STEP 2 – Waiting for MySQL to be ready..."
ATTEMPTS=0
MAX_ATTEMPTS=60
until mysql -h "$MYSQL_HOST" -u root -p"$MYSQL_ROOT_PASSWORD" \
      -e "SELECT 1 FROM information_schema.tables WHERE table_schema='${MYSQL_DATABASE}' AND table_name='stg_customers' LIMIT 1" \
      > /dev/null 2>&1; do
    ATTEMPTS=$((ATTEMPTS + 1))
    if [ "$ATTEMPTS" -ge "$MAX_ATTEMPTS" ]; then
        log_error "MySQL not ready after ${MAX_ATTEMPTS} attempts. Aborting."
        exit 1
    fi
    sleep 2
done
log "MySQL is ready (${ATTEMPTS} wait cycles)."

# ── Step 3: Load data ────────────────────────────────────────────────────
log "STEP 3 – Loading CSV data into staging tables..."
LOAD_START=$(date +%s)
mysql -h "$MYSQL_HOST" -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" \
    < /sql/load/002_load_data.sql 2>> "$LOG_FILE"
LOAD_END=$(date +%s)
log "  Data loaded in $((LOAD_END - LOAD_START)) seconds."

# Quick row count check after load
log "  Staging row counts:"
mysql -h "$MYSQL_HOST" -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" -t -e "
    SELECT 'stg_customers' AS tbl, COUNT(*) AS cnt FROM stg_customers
    UNION ALL SELECT 'stg_orders', COUNT(*) FROM stg_orders
    UNION ALL SELECT 'stg_order_items', COUNT(*) FROM stg_order_items
    UNION ALL SELECT 'stg_products', COUNT(*) FROM stg_products
    UNION ALL SELECT 'stg_sellers', COUNT(*) FROM stg_sellers
    UNION ALL SELECT 'stg_geolocation', COUNT(*) FROM stg_geolocation;" \
    2>/dev/null | tee -a "$LOG_FILE"

# ── Step 4: Run transformations ──────────────────────────────────────────
log "STEP 4 – Running SQL transformations..."
TRANSFORM_START=$(date +%s)
for sql_file in /sql/transformations/0*.sql; do
    log "  Executing $(basename "$sql_file")..."
    mysql -h "$MYSQL_HOST" -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" \
        < "$sql_file" 2>> "$LOG_FILE"
done
TRANSFORM_END=$(date +%s)
log "  Transformations completed in $((TRANSFORM_END - TRANSFORM_START)) seconds."

# ── Step 5: Validate ─────────────────────────────────────────────────────
log "STEP 5 – Running data validation..."
mysql -h "$MYSQL_HOST" -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" -t \
    < /sql/validation/050_validate.sql 2>> "$LOG_FILE" | tee -a "$LOG_FILE"

# ── Done ──────────────────────────────────────────────────────────────────
PIPELINE_END=$(date +%s)
DURATION=$((PIPELINE_END - PIPELINE_START))
log "=========================================="
log "  Pipeline completed successfully!"
log "  Total duration: ${DURATION} seconds"
log "  Log file: ${LOG_FILE}"
log "=========================================="
