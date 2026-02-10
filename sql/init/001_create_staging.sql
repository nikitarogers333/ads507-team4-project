-- ============================================================================
-- 001_create_staging.sql
-- Creates staging tables that mirror the raw Olist CSV files.
-- This script runs automatically on the first `docker compose up` via
-- the MySQL docker-entrypoint-initdb.d mechanism.
-- ============================================================================

USE olist_dw;

-- ── Customers ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stg_customers (
    customer_id                VARCHAR(32)  NOT NULL,
    customer_unique_id         VARCHAR(32)  NOT NULL,
    customer_zip_code_prefix   VARCHAR(10),
    customer_city              VARCHAR(100),
    customer_state             VARCHAR(2),
    PRIMARY KEY (customer_id),
    INDEX idx_stg_cust_unique (customer_unique_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Orders ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stg_orders (
    order_id                        VARCHAR(32)  NOT NULL,
    customer_id                     VARCHAR(32)  NOT NULL,
    order_status                    VARCHAR(20),
    order_purchase_timestamp        DATETIME,
    order_approved_at               DATETIME,
    order_delivered_carrier_date    DATETIME,
    order_delivered_customer_date   DATETIME,
    order_estimated_delivery_date   DATETIME,
    PRIMARY KEY (order_id),
    INDEX idx_stg_ord_cust (customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Order Items ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stg_order_items (
    order_id            VARCHAR(32)  NOT NULL,
    order_item_id       INT          NOT NULL,
    product_id          VARCHAR(32)  NOT NULL,
    seller_id           VARCHAR(32)  NOT NULL,
    shipping_limit_date DATETIME,
    price               DECIMAL(10,2),
    freight_value       DECIMAL(10,2),
    PRIMARY KEY (order_id, order_item_id),
    INDEX idx_stg_oi_prod (product_id),
    INDEX idx_stg_oi_seller (seller_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Order Payments ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stg_order_payments (
    order_id             VARCHAR(32) NOT NULL,
    payment_sequential   INT         NOT NULL,
    payment_type         VARCHAR(30),
    payment_installments INT,
    payment_value        DECIMAL(10,2),
    PRIMARY KEY (order_id, payment_sequential)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Order Reviews ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stg_order_reviews (
    review_id                VARCHAR(32)  NOT NULL,
    order_id                 VARCHAR(32)  NOT NULL,
    review_score             INT,
    review_comment_title     TEXT,
    review_comment_message   TEXT,
    review_creation_date     DATETIME,
    review_answer_timestamp  DATETIME,
    PRIMARY KEY (review_id),
    INDEX idx_stg_rev_order (order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Products ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stg_products (
    product_id                  VARCHAR(32) NOT NULL,
    product_category_name       VARCHAR(100),
    product_name_lenght         INT,
    product_description_lenght  INT,
    product_photos_qty          INT,
    product_weight_g            INT,
    product_length_cm           INT,
    product_height_cm           INT,
    product_width_cm            INT,
    PRIMARY KEY (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Sellers ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stg_sellers (
    seller_id               VARCHAR(32) NOT NULL,
    seller_zip_code_prefix  VARCHAR(10),
    seller_city             VARCHAR(100),
    seller_state            VARCHAR(2),
    PRIMARY KEY (seller_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Geolocation ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stg_geolocation (
    geolocation_zip_code_prefix  VARCHAR(10),
    geolocation_lat              DECIMAL(12,8),
    geolocation_lng              DECIMAL(12,8),
    geolocation_city             VARCHAR(100),
    geolocation_state            VARCHAR(2),
    INDEX idx_stg_geo_zip (geolocation_zip_code_prefix)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Product Category Translation ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stg_category_translation (
    product_category_name          VARCHAR(100) NOT NULL,
    product_category_name_english  VARCHAR(100),
    PRIMARY KEY (product_category_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SELECT '>>> 001_create_staging.sql completed – 9 staging tables created' AS status;
