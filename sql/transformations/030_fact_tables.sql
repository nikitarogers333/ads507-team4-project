-- ============================================================================
-- 030_fact_tables.sql
-- Creates and populates fact tables for the star schema.
-- Facts: orders, order_items, payments, reviews
-- ============================================================================

USE olist_dw;

-- Allow zero dates during transformation (LOAD DATA IGNORE may create them)
SET SESSION sql_mode = REPLACE(@@sql_mode, 'NO_ZERO_DATE', '');
SET SESSION sql_mode = REPLACE(@@sql_mode, 'NO_ZERO_IN_DATE', '');

-- ═══════════════════════════════════════════════════════════════════════════
-- fact_orders  (one row per order, enriched with computed metrics)
-- ═══════════════════════════════════════════════════════════════════════════
DROP TABLE IF EXISTS fact_orders;
CREATE TABLE fact_orders (
    order_key                       INT AUTO_INCREMENT PRIMARY KEY,
    order_id                        VARCHAR(32)  NOT NULL,
    customer_key                    INT,
    order_status                    VARCHAR(20),
    purchase_date_key               INT,
    approved_date_key               INT,
    delivered_carrier_date_key      INT,
    delivered_customer_date_key     INT,
    estimated_delivery_date_key     INT,
    total_items                     INT          DEFAULT 0,
    total_amount                    DECIMAL(12,2) DEFAULT 0,
    total_freight                   DECIMAL(12,2) DEFAULT 0,
    total_payment                   DECIMAL(12,2) DEFAULT 0,
    actual_delivery_days            INT,
    estimated_delivery_days         INT,
    is_late_delivery                TINYINT      DEFAULT 0,
    UNIQUE INDEX idx_fact_ord_id (order_id),
    INDEX idx_fact_ord_cust (customer_key),
    INDEX idx_fact_ord_pdate (purchase_date_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO fact_orders
    (order_id, customer_key, order_status,
     purchase_date_key, approved_date_key,
     delivered_carrier_date_key, delivered_customer_date_key,
     estimated_delivery_date_key,
     total_items, total_amount, total_freight, total_payment,
     actual_delivery_days, estimated_delivery_days, is_late_delivery)
SELECT
    o.order_id,
    dc.customer_key,
    o.order_status,
    -- Date keys (YYYYMMDD integer)
    CAST(DATE_FORMAT(o.order_purchase_timestamp,      '%Y%m%d') AS UNSIGNED),
    CAST(DATE_FORMAT(o.order_approved_at,             '%Y%m%d') AS UNSIGNED),
    CAST(DATE_FORMAT(o.order_delivered_carrier_date,  '%Y%m%d') AS UNSIGNED),
    CAST(DATE_FORMAT(o.order_delivered_customer_date, '%Y%m%d') AS UNSIGNED),
    CAST(DATE_FORMAT(o.order_estimated_delivery_date, '%Y%m%d') AS UNSIGNED),
    -- Aggregated item metrics
    COALESCE(items.total_items, 0),
    COALESCE(items.total_amount, 0),
    COALESCE(items.total_freight, 0),
    COALESCE(pay.total_payment, 0),
    -- Delivery performance
    DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp),
    DATEDIFF(o.order_estimated_delivery_date, o.order_purchase_timestamp),
    CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
        THEN 1 ELSE 0
    END
FROM stg_orders o
LEFT JOIN dim_customers dc ON o.customer_id = dc.customer_id
LEFT JOIN (
    SELECT order_id,
           COUNT(*)        AS total_items,
           SUM(price)      AS total_amount,
           SUM(freight_value) AS total_freight
    FROM stg_order_items
    GROUP BY order_id
) items ON o.order_id = items.order_id
LEFT JOIN (
    SELECT order_id,
           SUM(payment_value) AS total_payment
    FROM stg_order_payments
    GROUP BY order_id
) pay ON o.order_id = pay.order_id;

-- ═══════════════════════════════════════════════════════════════════════════
-- fact_order_items  (one row per line item)
-- ═══════════════════════════════════════════════════════════════════════════
DROP TABLE IF EXISTS fact_order_items;
CREATE TABLE fact_order_items (
    item_key            INT AUTO_INCREMENT PRIMARY KEY,
    order_id            VARCHAR(32) NOT NULL,
    order_item_id       INT         NOT NULL,
    product_key         INT,
    seller_key          INT,
    shipping_limit_date DATETIME,
    price               DECIMAL(10,2),
    freight_value       DECIMAL(10,2),
    INDEX idx_fact_oi_order (order_id),
    INDEX idx_fact_oi_prod  (product_key),
    INDEX idx_fact_oi_sell  (seller_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO fact_order_items
    (order_id, order_item_id, product_key, seller_key,
     shipping_limit_date, price, freight_value)
SELECT
    oi.order_id,
    oi.order_item_id,
    dp.product_key,
    ds.seller_key,
    oi.shipping_limit_date,
    oi.price,
    oi.freight_value
FROM stg_order_items oi
LEFT JOIN dim_products dp ON oi.product_id = dp.product_id
LEFT JOIN dim_sellers  ds ON oi.seller_id  = ds.seller_id;

-- ═══════════════════════════════════════════════════════════════════════════
-- fact_payments  (one row per payment line)
-- ═══════════════════════════════════════════════════════════════════════════
DROP TABLE IF EXISTS fact_payments;
CREATE TABLE fact_payments (
    payment_key          INT AUTO_INCREMENT PRIMARY KEY,
    order_id             VARCHAR(32) NOT NULL,
    payment_sequential   INT,
    payment_type         VARCHAR(30),
    payment_installments INT,
    payment_value        DECIMAL(10,2),
    INDEX idx_fact_pay_order (order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO fact_payments
    (order_id, payment_sequential, payment_type,
     payment_installments, payment_value)
SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM stg_order_payments;

-- ═══════════════════════════════════════════════════════════════════════════
-- fact_reviews  (one row per review)
-- ═══════════════════════════════════════════════════════════════════════════
DROP TABLE IF EXISTS fact_reviews;
CREATE TABLE fact_reviews (
    review_key               INT AUTO_INCREMENT PRIMARY KEY,
    review_id                VARCHAR(32) NOT NULL,
    order_id                 VARCHAR(32) NOT NULL,
    review_score             INT,
    review_comment_title     TEXT,
    review_comment_message   TEXT,
    review_creation_date     DATETIME,
    review_answer_timestamp  DATETIME,
    INDEX idx_fact_rev_order (order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO fact_reviews
    (review_id, order_id, review_score, review_comment_title,
     review_comment_message, review_creation_date, review_answer_timestamp)
SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
FROM stg_order_reviews;

SELECT '>>> 030_fact_tables.sql completed – 4 fact tables created' AS status;
