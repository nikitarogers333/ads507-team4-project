-- ============================================================================
-- 010_clean_staging.sql
-- Data-cleaning transformations applied directly to staging tables.
-- Fixes: trailing whitespace, empty-string NULLs, date normalization.
-- ============================================================================

USE olist_dw;

-- ── Trim whitespace & normalise empty strings to NULL ───────────────────────

-- Customers
UPDATE stg_customers
SET customer_city  = TRIM(customer_city),
    customer_state = TRIM(UPPER(customer_state)),
    customer_zip_code_prefix = TRIM(customer_zip_code_prefix);

UPDATE stg_customers
SET customer_city = NULL WHERE customer_city = '';

-- Orders – set blank date columns to NULL
UPDATE stg_orders
SET order_approved_at             = NULL WHERE order_approved_at             = '0000-00-00 00:00:00';
UPDATE stg_orders
SET order_delivered_carrier_date  = NULL WHERE order_delivered_carrier_date  = '0000-00-00 00:00:00';
UPDATE stg_orders
SET order_delivered_customer_date = NULL WHERE order_delivered_customer_date = '0000-00-00 00:00:00';

-- Products – normalise category names (lowercase, trim)
UPDATE stg_products
SET product_category_name = TRIM(LOWER(product_category_name));

UPDATE stg_products
SET product_category_name = NULL WHERE product_category_name = '';

-- Sellers
UPDATE stg_sellers
SET seller_city  = TRIM(seller_city),
    seller_state = TRIM(UPPER(seller_state));

-- Reviews – NULL out blank text
UPDATE stg_order_reviews
SET review_comment_title   = NULL WHERE review_comment_title   = '';
UPDATE stg_order_reviews
SET review_comment_message = NULL WHERE review_comment_message = '';

-- Category Translation – trim
UPDATE stg_category_translation
SET product_category_name         = TRIM(LOWER(product_category_name)),
    product_category_name_english = TRIM(LOWER(product_category_name_english));

SELECT '>>> 010_clean_staging.sql completed – staging data cleaned' AS status;
