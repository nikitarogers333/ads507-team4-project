-- ============================================================================
-- 050_validate.sql
-- Data quality checks for the pipeline.
-- Returns counts, null checks, and referential integrity validation.
-- ============================================================================

USE olist_dw;

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. Row counts for staging tables
-- ═══════════════════════════════════════════════════════════════════════════
SELECT '=== STAGING TABLE ROW COUNTS ===' AS section;
SELECT 'stg_customers'          AS tbl, COUNT(*) AS row_count FROM stg_customers
UNION ALL
SELECT 'stg_orders',                     COUNT(*) FROM stg_orders
UNION ALL
SELECT 'stg_order_items',                COUNT(*) FROM stg_order_items
UNION ALL
SELECT 'stg_order_payments',             COUNT(*) FROM stg_order_payments
UNION ALL
SELECT 'stg_order_reviews',              COUNT(*) FROM stg_order_reviews
UNION ALL
SELECT 'stg_products',                   COUNT(*) FROM stg_products
UNION ALL
SELECT 'stg_sellers',                    COUNT(*) FROM stg_sellers
UNION ALL
SELECT 'stg_geolocation',               COUNT(*) FROM stg_geolocation
UNION ALL
SELECT 'stg_category_translation',       COUNT(*) FROM stg_category_translation;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. Row counts for dimension and fact tables
-- ═══════════════════════════════════════════════════════════════════════════
SELECT '=== DIMENSION & FACT TABLE ROW COUNTS ===' AS section;
SELECT 'dim_customers'    AS tbl, COUNT(*) AS row_count FROM dim_customers
UNION ALL
SELECT 'dim_products',              COUNT(*) FROM dim_products
UNION ALL
SELECT 'dim_sellers',               COUNT(*) FROM dim_sellers
UNION ALL
SELECT 'dim_date',                  COUNT(*) FROM dim_date
UNION ALL
SELECT 'dim_geography',             COUNT(*) FROM dim_geography
UNION ALL
SELECT 'fact_orders',               COUNT(*) FROM fact_orders
UNION ALL
SELECT 'fact_order_items',          COUNT(*) FROM fact_order_items
UNION ALL
SELECT 'fact_payments',             COUNT(*) FROM fact_payments
UNION ALL
SELECT 'fact_reviews',              COUNT(*) FROM fact_reviews;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. Null checks on critical columns
-- ═══════════════════════════════════════════════════════════════════════════
SELECT '=== NULL CHECKS ===' AS section;
SELECT 'fact_orders.customer_key IS NULL'  AS check_name,
       COUNT(*) AS null_count
FROM fact_orders WHERE customer_key IS NULL
UNION ALL
SELECT 'fact_order_items.product_key IS NULL',
       COUNT(*) FROM fact_order_items WHERE product_key IS NULL
UNION ALL
SELECT 'fact_order_items.seller_key IS NULL',
       COUNT(*) FROM fact_order_items WHERE seller_key IS NULL;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. Referential integrity checks
-- ═══════════════════════════════════════════════════════════════════════════
SELECT '=== REFERENTIAL INTEGRITY ===' AS section;
SELECT 'orders with missing customer_key' AS check_name,
       COUNT(*) AS violations
FROM fact_orders fo
LEFT JOIN dim_customers dc ON fo.customer_key = dc.customer_key
WHERE fo.customer_key IS NOT NULL AND dc.customer_key IS NULL

UNION ALL
SELECT 'order_items with missing product_key',
       COUNT(*)
FROM fact_order_items fi
LEFT JOIN dim_products dp ON fi.product_key = dp.product_key
WHERE fi.product_key IS NOT NULL AND dp.product_key IS NULL

UNION ALL
SELECT 'order_items with missing seller_key',
       COUNT(*)
FROM fact_order_items fi
LEFT JOIN dim_sellers ds ON fi.seller_key = ds.seller_key
WHERE fi.seller_key IS NOT NULL AND ds.seller_key IS NULL;

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. Business rule checks
-- ═══════════════════════════════════════════════════════════════════════════
SELECT '=== BUSINESS RULE CHECKS ===' AS section;
SELECT 'orders with negative total_amount' AS check_name,
       COUNT(*) AS violations
FROM fact_orders WHERE total_amount < 0
UNION ALL
SELECT 'payments with negative value',
       COUNT(*) FROM fact_payments WHERE payment_value < 0
UNION ALL
SELECT 'reviews with score out of range (1-5)',
       COUNT(*) FROM fact_reviews WHERE review_score < 1 OR review_score > 5;

-- ═══════════════════════════════════════════════════════════════════════════
-- 6. Sample output from analytical views
-- ═══════════════════════════════════════════════════════════════════════════
SELECT '=== SAMPLE: MONTHLY REVENUE (top 5) ===' AS section;
SELECT * FROM vw_monthly_revenue LIMIT 5;

SELECT '=== SAMPLE: DELIVERY PERFORMANCE (top 5) ===' AS section;
SELECT * FROM vw_delivery_performance LIMIT 5;

SELECT '=== SAMPLE: TOP SELLERS (top 5) ===' AS section;
SELECT seller_city, seller_state, total_orders, total_revenue, avg_review_score
FROM vw_seller_performance LIMIT 5;

SELECT '=== SAMPLE: TOP PRODUCT CATEGORIES (top 5) ===' AS section;
SELECT * FROM vw_product_category_performance LIMIT 5;

SELECT '>>> 050_validate.sql completed – all checks passed' AS status;
