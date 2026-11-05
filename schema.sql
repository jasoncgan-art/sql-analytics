-- Olist Brazilian e-commerce, loaded from data/*.csv (see src/load.py).
-- Dates are stored as TEXT in ISO format; SQLite date functions work on them.
-- Primary keys are declared only where the source guarantees uniqueness.

DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS sellers;
DROP TABLE IF EXISTS category_translation;

CREATE TABLE customers (
    customer_id            TEXT PRIMARY KEY,
    customer_unique_id     TEXT,
    customer_zip_code_prefix TEXT,
    customer_city          TEXT,
    customer_state         TEXT
);

CREATE TABLE orders (
    order_id                    TEXT PRIMARY KEY,
    customer_id                 TEXT,
    order_status                TEXT,
    order_purchase_timestamp    TEXT,
    order_approved_at           TEXT,
    order_delivered_carrier_date TEXT,
    order_delivered_customer_date TEXT,
    order_estimated_delivery_date TEXT
);

CREATE TABLE order_items (
    order_id            TEXT,
    order_item_id       INTEGER,
    product_id          TEXT,
    seller_id           TEXT,
    shipping_limit_date TEXT,
    price               REAL,
    freight_value       REAL,
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE payments (
    order_id             TEXT,
    payment_sequential   INTEGER,
    payment_type         TEXT,
    payment_installments INTEGER,
    payment_value        REAL,
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE reviews (
    -- NOTE: review_id is NOT unique in the source data (duplicates exist),
    -- so no PRIMARY KEY here. One row = one review as shipped in the CSV.
    review_id              TEXT,
    order_id               TEXT,
    review_score           INTEGER,
    review_comment_title   TEXT,
    review_comment_message TEXT,
    review_creation_date   TEXT,
    review_answer_timestamp TEXT
);

CREATE TABLE products (
    product_id               TEXT PRIMARY KEY,
    product_category_name    TEXT,
    product_name_lenght      INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty       INTEGER,
    product_weight_g         INTEGER,
    product_length_cm        REAL,
    product_height_cm        REAL,
    product_width_cm         REAL
);

CREATE TABLE sellers (
    seller_id              TEXT PRIMARY KEY,
    seller_zip_code_prefix TEXT,
    seller_city            TEXT,
    seller_state           TEXT
);

CREATE TABLE category_translation (
    product_category_name         TEXT PRIMARY KEY,
    product_category_name_english TEXT
);

-- Indexes for the join keys used by sql/*.sql
CREATE INDEX idx_orders_customer   ON orders(customer_id);
CREATE INDEX idx_customers_unique  ON customers(customer_unique_id);
CREATE INDEX idx_items_order      ON order_items(order_id);
CREATE INDEX idx_items_product    ON order_items(product_id);
CREATE INDEX idx_payments_order   ON payments(order_id);
CREATE INDEX idx_reviews_order    ON reviews(order_id);
CREATE INDEX idx_products_category ON products(product_category_name);
