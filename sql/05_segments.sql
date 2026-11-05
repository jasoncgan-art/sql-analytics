-- 05_segments.sql
-- Segments: which states and product categories retain and engage best.
-- One query: top 10 states by customers UNION ALL top 10 categories by buyers.
-- A customer is attributed to the state of their FIRST order. A category's
-- repeat rate = share of its buyers who placed another order (any category).
-- AOV for a category = mean order value of orders containing that category.
-- NOTE: 3 of the 74 product categories have no English translation and are
-- excluded from the category half (see README).
WITH first_orders AS MATERIALIZED (
    SELECT c.customer_unique_id,
           MIN(o.order_purchase_timestamp) AS first_ts
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),
customer_state AS MATERIALIZED (
    SELECT f.customer_unique_id, MIN(c.customer_state) AS state
    FROM first_orders f
    JOIN customers c ON c.customer_unique_id = f.customer_unique_id
    JOIN orders o ON o.customer_id = c.customer_id
                 AND o.order_purchase_timestamp = f.first_ts
    GROUP BY f.customer_unique_id
),
orders_per_customer AS MATERIALIZED (
    SELECT c.customer_unique_id, COUNT(*) AS n_orders
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),
order_values AS MATERIALIZED (
    SELECT order_id, SUM(payment_value) AS order_value
    FROM payments
    GROUP BY order_id
),
customer_order_value AS MATERIALIZED (
    SELECT c.customer_unique_id, ov.order_value
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    JOIN order_values ov ON ov.order_id = o.order_id
),
state_customer_stats AS (
    SELECT cs.state AS segment,
           COUNT(*) AS customers,
           ROUND(100.0 * SUM(CASE WHEN opc.n_orders > 1 THEN 1 ELSE 0 END)
                 / COUNT(*), 2) AS repeat_rate_pct,
           ROUND(AVG(opc.n_orders), 2) AS orders_per_customer
    FROM customer_state cs
    JOIN orders_per_customer opc
         ON opc.customer_unique_id = cs.customer_unique_id
    GROUP BY cs.state
),
state_aov AS (
    SELECT cs.state AS segment,
           ROUND(AVG(cov.order_value), 2) AS mean_aov_brl
    FROM customer_state cs
    JOIN customer_order_value cov
         ON cov.customer_unique_id = cs.customer_unique_id
    GROUP BY cs.state
),
state_stats AS (
    SELECT c.segment, c.customers, c.repeat_rate_pct,
           c.orders_per_customer, a.mean_aov_brl
    FROM state_customer_stats c
    JOIN state_aov a ON a.segment = c.segment
),
category_buyers AS MATERIALIZED (
    SELECT DISTINCT ct.product_category_name_english AS category,
           c.customer_unique_id
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    JOIN category_translation ct
         ON ct.product_category_name = p.product_category_name
    JOIN orders o ON o.order_id = oi.order_id
    JOIN customers c ON c.customer_id = o.customer_id
),
category_orders AS MATERIALIZED (
    SELECT DISTINCT ct.product_category_name_english AS category,
           oi.order_id
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    JOIN category_translation ct
         ON ct.product_category_name = p.product_category_name
),
category_buyer_stats AS (
    SELECT cb.category AS segment,
           COUNT(*) AS customers,
           ROUND(100.0 * SUM(CASE WHEN opc.n_orders > 1 THEN 1 ELSE 0 END)
                 / COUNT(*), 2) AS repeat_rate_pct,
           ROUND(AVG(opc.n_orders), 2) AS orders_per_customer
    FROM category_buyers cb
    JOIN orders_per_customer opc
         ON opc.customer_unique_id = cb.customer_unique_id
    GROUP BY cb.category
),
category_aov AS (
    SELECT co.category AS segment,
           ROUND(AVG(ov.order_value), 2) AS mean_aov_brl
    FROM category_orders co
    JOIN order_values ov ON ov.order_id = co.order_id
    GROUP BY co.category
),
category_stats AS (
    SELECT b.segment, b.customers, b.repeat_rate_pct,
           b.orders_per_customer, a.mean_aov_brl
    FROM category_buyer_stats b
    JOIN category_aov a ON a.segment = b.segment
)
SELECT 'state' AS segment_type, segment, customers, repeat_rate_pct,
       orders_per_customer, mean_aov_brl
FROM (SELECT * FROM state_stats ORDER BY customers DESC LIMIT 10)
UNION ALL
SELECT 'category' AS segment_type, segment, customers, repeat_rate_pct,
       orders_per_customer, mean_aov_brl
FROM (SELECT * FROM category_stats ORDER BY customers DESC LIMIT 10);
