#!/bin/bash
###############################################################################
# test_pipeline.sh – Automated integration tests for the ETL pipeline
#
# Prerequisites: Docker must be running and the pipeline must have completed.
# Usage:  bash tests/test_pipeline.sh
#         make test
###############################################################################

set -e

PASS=0
FAIL=0
TOTAL=0

# Colours for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'  # No colour

assert() {
    TOTAL=$((TOTAL + 1))
    local desc="$1"
    local query="$2"
    local expected="$3"

    actual=$(docker compose exec -T mysql \
        mysql -u root -p"${MYSQL_ROOT_PASSWORD:-rootpass507}" \
        "${MYSQL_DATABASE:-olist_dw}" -N -e "$query" 2>/dev/null | tr -d '[:space:]')

    if [ "$actual" = "$expected" ]; then
        printf "${GREEN}  PASS${NC} %s (got: %s)\n" "$desc" "$actual"
        PASS=$((PASS + 1))
    else
        printf "${RED}  FAIL${NC} %s (expected: %s, got: %s)\n" "$desc" "$expected" "$actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_gt() {
    TOTAL=$((TOTAL + 1))
    local desc="$1"
    local query="$2"
    local min_value="$3"

    actual=$(docker compose exec -T mysql \
        mysql -u root -p"${MYSQL_ROOT_PASSWORD:-rootpass507}" \
        "${MYSQL_DATABASE:-olist_dw}" -N -e "$query" 2>/dev/null | tr -d '[:space:]')

    if [ "$actual" -gt "$min_value" ] 2>/dev/null; then
        printf "${GREEN}  PASS${NC} %s (got: %s > %s)\n" "$desc" "$actual" "$min_value"
        PASS=$((PASS + 1))
    else
        printf "${RED}  FAIL${NC} %s (expected > %s, got: %s)\n" "$desc" "$min_value" "$actual"
        FAIL=$((FAIL + 1))
    fi
}

echo "============================================="
echo "  ADS-507 Pipeline – Integration Tests"
echo "============================================="
echo ""

# ── 1. Container health ──────────────────────────────────────────────────
echo "── Container Health ─────────────────────────────────────────────"
TOTAL=$((TOTAL + 1))
if docker compose ps mysql | grep -q "running"; then
    printf "${GREEN}  PASS${NC} MySQL container is running\n"
    PASS=$((PASS + 1))
else
    printf "${RED}  FAIL${NC} MySQL container is not running\n"
    FAIL=$((FAIL + 1))
    echo "Cannot proceed without MySQL. Exiting."
    exit 1
fi
echo ""

# ── 2. Staging table row counts ──────────────────────────────────────────
echo "── Staging Tables ───────────────────────────────────────────────"
assert_gt "stg_customers has rows"         "SELECT COUNT(*) FROM stg_customers;"         0
assert_gt "stg_orders has rows"            "SELECT COUNT(*) FROM stg_orders;"            0
assert_gt "stg_order_items has rows"       "SELECT COUNT(*) FROM stg_order_items;"       0
assert_gt "stg_order_payments has rows"    "SELECT COUNT(*) FROM stg_order_payments;"    0
assert_gt "stg_order_reviews has rows"     "SELECT COUNT(*) FROM stg_order_reviews;"     0
assert_gt "stg_products has rows"          "SELECT COUNT(*) FROM stg_products;"          0
assert_gt "stg_sellers has rows"           "SELECT COUNT(*) FROM stg_sellers;"           0
assert_gt "stg_geolocation has rows"       "SELECT COUNT(*) FROM stg_geolocation;"       0
assert_gt "stg_category_translation rows"  "SELECT COUNT(*) FROM stg_category_translation;" 0
echo ""

# ── 3. Dimension tables ─────────────────────────────────────────────────
echo "── Dimension Tables ─────────────────────────────────────────────"
assert_gt "dim_customers has rows"    "SELECT COUNT(*) FROM dim_customers;"    0
assert_gt "dim_products has rows"     "SELECT COUNT(*) FROM dim_products;"     0
assert_gt "dim_sellers has rows"      "SELECT COUNT(*) FROM dim_sellers;"      0
assert_gt "dim_date has rows"         "SELECT COUNT(*) FROM dim_date;"         0
assert_gt "dim_geography has rows"    "SELECT COUNT(*) FROM dim_geography;"    0
echo ""

# ── 4. Fact tables ───────────────────────────────────────────────────────
echo "── Fact Tables ──────────────────────────────────────────────────"
assert_gt "fact_orders has rows"       "SELECT COUNT(*) FROM fact_orders;"       0
assert_gt "fact_order_items has rows"  "SELECT COUNT(*) FROM fact_order_items;"  0
assert_gt "fact_payments has rows"     "SELECT COUNT(*) FROM fact_payments;"     0
assert_gt "fact_reviews has rows"      "SELECT COUNT(*) FROM fact_reviews;"      0
echo ""

# ── 5. Analytical views ─────────────────────────────────────────────────
echo "── Analytical Views ─────────────────────────────────────────────"
assert_gt "vw_monthly_revenue has rows"            "SELECT COUNT(*) FROM vw_monthly_revenue;"            0
assert_gt "vw_delivery_performance has rows"       "SELECT COUNT(*) FROM vw_delivery_performance;"       0
assert_gt "vw_seller_performance has rows"         "SELECT COUNT(*) FROM vw_seller_performance;"         0
assert_gt "vw_product_category_performance rows"   "SELECT COUNT(*) FROM vw_product_category_performance;" 0
assert_gt "vw_customer_segments has rows"          "SELECT COUNT(*) FROM vw_customer_segments;"          0
echo ""

# ── 6. Data integrity ───────────────────────────────────────────────────
echo "── Data Integrity ───────────────────────────────────────────────"
assert "No orphan fact_orders.customer_key" \
    "SELECT COUNT(*) FROM fact_orders fo LEFT JOIN dim_customers dc ON fo.customer_key = dc.customer_key WHERE fo.customer_key IS NOT NULL AND dc.customer_key IS NULL;" \
    "0"

assert "No negative payment values" \
    "SELECT COUNT(*) FROM fact_payments WHERE payment_value < 0;" \
    "0"

assert "All review scores 1-5" \
    "SELECT COUNT(*) FROM fact_reviews WHERE review_score < 1 OR review_score > 5;" \
    "0"
echo ""

# ── Summary ──────────────────────────────────────────────────────────────
echo "============================================="
printf "  Results: ${GREEN}%d passed${NC}, ${RED}%d failed${NC}, %d total\n" "$PASS" "$FAIL" "$TOTAL"
echo "============================================="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
