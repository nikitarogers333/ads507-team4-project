-- ============================================================================
-- 020_dim_tables.sql
-- Creates and populates dimension tables for the star schema.
-- Dimensions: customers, products, sellers, geography, date
-- ============================================================================

USE olist_dw;

-- ═══════════════════════════════════════════════════════════════════════════
-- dim_customers
-- ═══════════════════════════════════════════════════════════════════════════
DROP TABLE IF EXISTS dim_customers;
CREATE TABLE dim_customers (
    customer_key              INT AUTO_INCREMENT PRIMARY KEY,
    customer_id               VARCHAR(32) NOT NULL,
    customer_unique_id        VARCHAR(32) NOT NULL,
    customer_city             VARCHAR(100),
    customer_state            VARCHAR(2),
    customer_zip_code_prefix  VARCHAR(10),
    UNIQUE INDEX idx_dim_cust_id (customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO dim_customers
    (customer_id, customer_unique_id, customer_city,
     customer_state, customer_zip_code_prefix)
SELECT
    customer_id,
    customer_unique_id,
    customer_city,
    customer_state,
    customer_zip_code_prefix
FROM stg_customers;

-- ═══════════════════════════════════════════════════════════════════════════
-- dim_products  (joined with English category names)
-- ═══════════════════════════════════════════════════════════════════════════
DROP TABLE IF EXISTS dim_products;
CREATE TABLE dim_products (
    product_key                  INT AUTO_INCREMENT PRIMARY KEY,
    product_id                   VARCHAR(32)  NOT NULL,
    product_category_name        VARCHAR(100),
    product_category_english     VARCHAR(100),
    product_name_length          INT,
    product_description_length   INT,
    product_photos_qty           INT,
    product_weight_g             INT,
    product_length_cm            INT,
    product_height_cm            INT,
    product_width_cm             INT,
    UNIQUE INDEX idx_dim_prod_id (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO dim_products
    (product_id, product_category_name, product_category_english,
     product_name_length, product_description_length, product_photos_qty,
     product_weight_g, product_length_cm, product_height_cm, product_width_cm)
SELECT
    p.product_id,
    p.product_category_name,
    COALESCE(t.product_category_name_english, p.product_category_name),
    p.product_name_lenght,
    p.product_description_lenght,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM stg_products p
LEFT JOIN stg_category_translation t
    ON p.product_category_name = t.product_category_name;

-- ═══════════════════════════════════════════════════════════════════════════
-- dim_sellers
-- ═══════════════════════════════════════════════════════════════════════════
DROP TABLE IF EXISTS dim_sellers;
CREATE TABLE dim_sellers (
    seller_key              INT AUTO_INCREMENT PRIMARY KEY,
    seller_id               VARCHAR(32) NOT NULL,
    seller_city             VARCHAR(100),
    seller_state            VARCHAR(2),
    seller_zip_code_prefix  VARCHAR(10),
    UNIQUE INDEX idx_dim_sell_id (seller_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO dim_sellers
    (seller_id, seller_city, seller_state, seller_zip_code_prefix)
SELECT
    seller_id,
    seller_city,
    seller_state,
    seller_zip_code_prefix
FROM stg_sellers;

-- ═══════════════════════════════════════════════════════════════════════════
-- dim_date  (generated from the date range found in the orders table)
-- ═══════════════════════════════════════════════════════════════════════════
DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date (
    date_key      INT          NOT NULL PRIMARY KEY,   -- YYYYMMDD
    full_date     DATE         NOT NULL,
    year          SMALLINT     NOT NULL,
    quarter       TINYINT      NOT NULL,
    month         TINYINT      NOT NULL,
    month_name    VARCHAR(10)  NOT NULL,
    day           TINYINT      NOT NULL,
    day_of_week   TINYINT      NOT NULL,
    day_name      VARCHAR(10)  NOT NULL,
    week_of_year  TINYINT      NOT NULL,
    UNIQUE INDEX idx_dim_date (full_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Generate dates from 2016-01-01 to 2018-12-31 using a recursive CTE
INSERT INTO dim_date (date_key, full_date, year, quarter, month, month_name,
                      day, day_of_week, day_name, week_of_year)
WITH RECURSIVE dates_cte AS (
    SELECT DATE('2016-01-01') AS d
    UNION ALL
    SELECT d + INTERVAL 1 DAY FROM dates_cte WHERE d < '2018-12-31'
)
SELECT
    CAST(DATE_FORMAT(d, '%Y%m%d') AS UNSIGNED)  AS date_key,
    d                                            AS full_date,
    YEAR(d)                                      AS year,
    QUARTER(d)                                   AS quarter,
    MONTH(d)                                     AS month,
    MONTHNAME(d)                                 AS month_name,
    DAY(d)                                       AS day,
    DAYOFWEEK(d)                                 AS day_of_week,
    DAYNAME(d)                                   AS day_name,
    WEEKOFYEAR(d)                                AS week_of_year
FROM dates_cte;

-- ═══════════════════════════════════════════════════════════════════════════
-- dim_geography  (deduplicated from geolocation staging table)
-- ═══════════════════════════════════════════════════════════════════════════
DROP TABLE IF EXISTS dim_geography;
CREATE TABLE dim_geography (
    geo_key                      INT AUTO_INCREMENT PRIMARY KEY,
    zip_code_prefix              VARCHAR(10) NOT NULL,
    city                         VARCHAR(100),
    state                        VARCHAR(2),
    avg_latitude                 DECIMAL(12,8),
    avg_longitude                DECIMAL(12,8),
    UNIQUE INDEX idx_dim_geo_zip (zip_code_prefix)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO dim_geography
    (zip_code_prefix, city, state, avg_latitude, avg_longitude)
SELECT
    geolocation_zip_code_prefix,
    MAX(geolocation_city),
    MAX(geolocation_state),
    AVG(geolocation_lat),
    AVG(geolocation_lng)
FROM stg_geolocation
GROUP BY geolocation_zip_code_prefix;

SELECT '>>> 020_dim_tables.sql completed – 5 dimension tables created' AS status;
