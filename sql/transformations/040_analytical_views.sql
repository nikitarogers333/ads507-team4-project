-- ============================================================================
-- 040_analytical_views.sql
-- Creates analytical views that serve as the pipeline's output.
-- These views power dashboards and ad-hoc analysis.
-- ============================================================================

USE olist_dw;

-- ═══════════════════════════════════════════════════════════════════════════
-- vw_monthly_revenue – Revenue and order trends by month
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vw_monthly_revenue AS
SELECT
    dd.year,
    dd.month,
    dd.month_name,
    COUNT(DISTINCT fo.order_id)           AS total_orders,
    SUM(fo.total_amount)                  AS gross_revenue,
    SUM(fo.total_freight)                 AS total_freight_revenue,
    SUM(fo.total_payment)                 AS total_payments,
    ROUND(AVG(fo.total_payment), 2)       AS avg_order_value,
    SUM(fo.total_items)                   AS total_items_sold
FROM fact_orders fo
JOIN dim_date dd ON fo.purchase_date_key = dd.date_key
WHERE fo.order_status NOT IN ('canceled', 'unavailable')
GROUP BY dd.year, dd.month, dd.month_name
ORDER BY dd.year, dd.month;

-- ═══════════════════════════════════════════════════════════════════════════
-- vw_delivery_performance – Delivery metrics by state and month
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vw_delivery_performance AS
SELECT
    dc.customer_state                               AS state,
    dd.year,
    dd.month,
    COUNT(*)                                        AS total_orders,
    ROUND(AVG(fo.actual_delivery_days), 1)          AS avg_delivery_days,
    ROUND(AVG(fo.estimated_delivery_days), 1)       AS avg_estimated_days,
    SUM(fo.is_late_delivery)                        AS late_deliveries,
    ROUND(100.0 * SUM(fo.is_late_delivery) / COUNT(*), 1)  AS late_pct
FROM fact_orders fo
JOIN dim_customers dc ON fo.customer_key = dc.customer_key
JOIN dim_date dd      ON fo.purchase_date_key = dd.date_key
WHERE fo.order_status = 'delivered'
GROUP BY dc.customer_state, dd.year, dd.month
ORDER BY dd.year, dd.month, dc.customer_state;

-- ═══════════════════════════════════════════════════════════════════════════
-- vw_seller_performance – Seller scoreboard
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vw_seller_performance AS
SELECT
    ds.seller_key,
    ds.seller_id,
    ds.seller_city,
    ds.seller_state,
    COUNT(DISTINCT fi.order_id)         AS total_orders,
    SUM(fi.price)                       AS total_revenue,
    ROUND(AVG(fi.price), 2)             AS avg_item_price,
    SUM(fi.freight_value)               AS total_freight,
    COUNT(fi.item_key)                  AS total_items_sold,
    ROUND(AVG(fr.review_score), 2)      AS avg_review_score
FROM fact_order_items fi
JOIN dim_sellers ds   ON fi.seller_key = ds.seller_key
LEFT JOIN fact_reviews fr ON fi.order_id = fr.order_id
GROUP BY ds.seller_key, ds.seller_id, ds.seller_city, ds.seller_state
ORDER BY total_revenue DESC;

-- ═══════════════════════════════════════════════════════════════════════════
-- vw_product_category_performance – Category-level analysis
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vw_product_category_performance AS
SELECT
    COALESCE(dp.product_category_english, 'unknown')  AS category,
    COUNT(DISTINCT fi.order_id)                       AS total_orders,
    COUNT(fi.item_key)                                AS total_items_sold,
    ROUND(SUM(fi.price), 2)                           AS total_revenue,
    ROUND(AVG(fi.price), 2)                           AS avg_price,
    ROUND(AVG(fr.review_score), 2)                    AS avg_review_score
FROM fact_order_items fi
JOIN dim_products dp  ON fi.product_key = dp.product_key
LEFT JOIN fact_reviews fr ON fi.order_id = fr.order_id
GROUP BY COALESCE(dp.product_category_english, 'unknown')
ORDER BY total_revenue DESC;

-- ═══════════════════════════════════════════════════════════════════════════
-- vw_customer_segments – RFM-style customer segmentation
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vw_customer_segments AS
SELECT
    dc.customer_unique_id,
    dc.customer_city,
    dc.customer_state,
    COUNT(DISTINCT fo.order_id)                          AS order_count,
    ROUND(SUM(fo.total_payment), 2)                      AS lifetime_value,
    ROUND(AVG(fo.total_payment), 2)                      AS avg_order_value,
    MIN(dd.full_date)                                    AS first_order_date,
    MAX(dd.full_date)                                    AS last_order_date,
    DATEDIFF(MAX(dd.full_date), MIN(dd.full_date))       AS customer_tenure_days,
    CASE
        WHEN COUNT(DISTINCT fo.order_id) >= 3 THEN 'loyal'
        WHEN COUNT(DISTINCT fo.order_id) = 2  THEN 'returning'
        ELSE 'one-time'
    END                                                  AS customer_segment
FROM fact_orders fo
JOIN dim_customers dc ON fo.customer_key = dc.customer_key
JOIN dim_date dd      ON fo.purchase_date_key = dd.date_key
WHERE fo.order_status NOT IN ('canceled', 'unavailable')
GROUP BY dc.customer_unique_id, dc.customer_city, dc.customer_state;

SELECT '>>> 040_analytical_views.sql completed – 5 views created' AS status;
