-- ============================================================================
-- 002_load_data.sql
-- Loads raw CSV files from /data/raw into the staging tables.
-- CSV files are downloaded from the GitHub release by the pipeline script.
-- ============================================================================

USE olist_dw;

-- ── Customers ───────────────────────────────────────────────────────────────
LOAD DATA INFILE '/data/raw/olist_customers_dataset.csv'
INTO TABLE stg_customers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, customer_unique_id, customer_zip_code_prefix,
 customer_city, customer_state);

-- ── Orders ──────────────────────────────────────────────────────────────────
LOAD DATA INFILE '/data/raw/olist_orders_dataset.csv'
INTO TABLE stg_orders
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, customer_id, order_status, order_purchase_timestamp,
 order_approved_at, order_delivered_carrier_date,
 order_delivered_customer_date, order_estimated_delivery_date);

-- ── Order Items ─────────────────────────────────────────────────────────────
LOAD DATA INFILE '/data/raw/olist_order_items_dataset.csv'
INTO TABLE stg_order_items
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, order_item_id, product_id, seller_id,
 shipping_limit_date, price, freight_value);

-- ── Order Payments ──────────────────────────────────────────────────────────
LOAD DATA INFILE '/data/raw/olist_order_payments_dataset.csv'
INTO TABLE stg_order_payments
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, payment_sequential, payment_type,
 payment_installments, payment_value);

-- ── Order Reviews ───────────────────────────────────────────────────────────
LOAD DATA INFILE '/data/raw/olist_order_reviews_dataset.csv'
INTO TABLE stg_order_reviews
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(review_id, order_id, review_score, review_comment_title,
 review_comment_message, review_creation_date, review_answer_timestamp);

-- ── Products ────────────────────────────────────────────────────────────────
LOAD DATA INFILE '/data/raw/olist_products_dataset.csv'
INTO TABLE stg_products
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(product_id, product_category_name, product_name_lenght,
 product_description_lenght, product_photos_qty, product_weight_g,
 product_length_cm, product_height_cm, product_width_cm);

-- ── Sellers ─────────────────────────────────────────────────────────────────
LOAD DATA INFILE '/data/raw/olist_sellers_dataset.csv'
INTO TABLE stg_sellers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(seller_id, seller_zip_code_prefix, seller_city, seller_state);

-- ── Geolocation (reassembled from 11 parts) ─────────────────────────────────
LOAD DATA INFILE '/data/raw/olist_geolocation_dataset.csv'
INTO TABLE stg_geolocation
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(geolocation_zip_code_prefix, geolocation_lat, geolocation_lng,
 geolocation_city, geolocation_state);

-- ── Product Category Translation ────────────────────────────────────────────
LOAD DATA INFILE '/data/raw/product_category_name_translation.csv'
INTO TABLE stg_category_translation
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(product_category_name, product_category_name_english);

SELECT '>>> 002_load_data.sql completed – all staging tables loaded' AS status;
