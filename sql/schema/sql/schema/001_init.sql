-- Creating the database
CREATE DATABASE olist_database;
USE olist_database;

-- Customer data
CREATE TABLE customers (
  customer_id VARCHAR(255),
  customer_unique_id VARCHAR(255),
  customer_zip_code_prefix INT, 
  customer_city VARCHAR(255),
  customer_state VARCHAR(255)
);

-- Order data
CREATE TABLE orders (
  order_id VARCHAR(255),
  customer_id VARCHAR(255),
  order_status VARCHAR(50),
  order_purchase_timestamp DATETIME,
  order_approved_at DATETIME,
  order_delivered_customer_date DATETIME,
  order_estimated_delivery_date DATETIME
);

-- Items in the orders
CREATE TABLE order_items (
  order_id VARCHAR(255),
  order_item_id INT,
  product_id VARCHAR(255),
  seller_id VARCHAR(255),
  price FLOAT,
  freight_value FLOAT
);

-- Product details
CREATE TABLE products (
  product_id VARCHAR(255),
  product_category_name VARCHAR(255),
  product_weight_g INT,
  product_length_cm INT,
  product_height_cm INT,
  product_width_cm INT
);

-- Payments
CREATE TABLE payments (
  order_id VARCHAR(255),
  payment_type VARCHAR(50),
  payment_installments INT,
  payment_value FLOAT
);