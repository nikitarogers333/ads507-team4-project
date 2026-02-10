-- ============================================================================
-- 002_load_data.sql
-- Loads raw CSV files from /data/raw into the staging tables.
-- Uses @variables + SET NULLIF() to handle empty-string NULLs in CSV data.
-- ============================================================================

USE olist_dw;

-- ── Customers ───────────────────────────────────────────────────────────────
LOAD DATA INFILE '/data/raw/olist_customers_dataset.csv'
IGNORE INTO TABLE stg_customers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, customer_unique_id, customer_zip_code_prefix,
 customer_city, customer_state);

-- ── Orders ──────────────────────────────────────────────────────────────────
LOAD DATA INFILE '/data/raw/olist_orders_dataset.csv'
IGNORE INTO TABLE stg_orders
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, customer_id, order_status,
 @purchase, @approved, @carrier, @delivered, @estimated)
SET
    order_purchase_timestamp      = NULLIF(@purchase, ''),
    order_approved_at             = NULLIF(@approved, ''),
    order_delivered_carrier_date  = NULLIF(@carrier, ''),
    order_delivered_customer_date = NULLIF(@delivered, ''),
    order_estimated_delivery_date = NULLIF(@estimated, '');

-- ── Order Items ─────────────────────────────────────────────────────────────
LOAD DATA INFILE '/data/raw/olist_order_items_dataset.csv'
IGNORE INTO TABLE stg_order_items
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, order_item_id, product_id, seller_id,
 @shipping_limit, price, freight_value)
SET
    shipping_limit_date = NULLIF(@shipping_limit, '');

-- ── Order Payments ──────────────────────────────────────────────────────────
LOAD DATA INFILE '/data/raw/olist_order_payments_dataset.csv'
IGNORE INTO TABLE stg_order_payments
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, payment_sequential, payment_type,
 payment_installments, payment_value);

-- ── Order Reviews ───────────────────────────────────────────────────────────
LOAD DATA INFILE '/data/raw/olist_order_reviews_dataset.csv'
IGNORE INTO TABLE stg_order_reviews
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(review_id, order_id, review_score,
 @title, @message, @creation, @answer)
SET
    review_comment_title    = NULLIF(@title, ''),
    review_comment_message  = NULLIF(@message, ''),
    review_creation_date    = NULLIF(@creation, ''),
    review_answer_timestamp = NULLIF(@answer, '');

-- ── Products ────────────────────────────────────────────────────────────────
LOAD DATA INFILE '/data/raw/olist_products_dataset.csv'
IGNORE INTO TABLE stg_products
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(product_id, @cat, @name_len, @desc_len, @photos,
 @weight, @length, @height, @width)
SET
    product_category_name      = NULLIF(@cat, ''),
    product_name_lenght        = NULLIF(@name_len, ''),
    product_description_lenght = NULLIF(@desc_len, ''),
    product_photos_qty         = NULLIF(@photos, ''),
    product_weight_g           = NULLIF(@weight, ''),
    product_length_cm          = NULLIF(@length, ''),
    product_height_cm          = NULLIF(@height, ''),
    product_width_cm           = NULLIF(@width, '');

-- ── Sellers ─────────────────────────────────────────────────────────────────
LOAD DATA INFILE '/data/raw/olist_sellers_dataset.csv'
IGNORE INTO TABLE stg_sellers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(seller_id, seller_zip_code_prefix, seller_city, seller_state);

-- ── Geolocation (reassembled from 11 parts) ─────────────────────────────────
LOAD DATA INFILE '/data/raw/olist_geolocation_dataset.csv'
IGNORE INTO TABLE stg_geolocation
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(geolocation_zip_code_prefix, geolocation_lat, geolocation_lng,
 geolocation_city, geolocation_state);

-- ── Product Category Translation ────────────────────────────────────────────
LOAD DATA INFILE '/data/raw/product_category_name_translation.csv'
IGNORE INTO TABLE stg_category_translation
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(product_category_name, product_category_name_english);

SELECT '>>> 002_load_data.sql completed – all staging tables loaded' AS status;
