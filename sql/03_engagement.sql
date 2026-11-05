-- 03_engagement.sql
-- Engagement: how often customers come back, how fast, and how recently.
-- Customer identity is customer_unique_id (one person can have several
-- customer_id rows; 2,997 people do).

-- Distribution of orders per customer
WITH per_customer AS (
    SELECT c.customer_unique_id, COUNT(*) AS n_orders
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT CASE WHEN n_orders >= 5 THEN '5+' ELSE CAST(n_orders AS TEXT) END
           AS orders_per_customer,
       COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM per_customer), 2)
           AS share_pct
FROM per_customer
GROUP BY orders_per_customer
ORDER BY orders_per_customer;

-- Headline engagement stats
WITH per_customer AS (
    SELECT c.customer_unique_id, COUNT(*) AS n_orders
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT COUNT(*) AS customers,
       ROUND(AVG(n_orders), 3) AS mean_orders_per_customer,
       ROUND(100.0 * SUM(CASE WHEN n_orders > 1 THEN 1 ELSE 0 END) / COUNT(*), 2)
           AS repeat_rate_pct,
       ROUND(AVG(CASE WHEN n_orders > 1 THEN n_orders END), 2)
           AS mean_orders_among_repeat_customers
FROM per_customer;

-- Time from 1st to 2nd order (repeat customers only)
WITH first_orders AS (
    SELECT c.customer_unique_id,
           MIN(o.order_purchase_timestamp) AS first_ts
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),
gaps AS (
    SELECT CAST(julianday(MIN(o.order_purchase_timestamp))
                - julianday(f.first_ts) AS INTEGER) AS gap_days
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    JOIN first_orders f ON f.customer_unique_id = c.customer_unique_id
    WHERE o.order_purchase_timestamp > f.first_ts
    GROUP BY c.customer_unique_id
)
SELECT 'median_days_to_2nd_order' AS metric,
       gap_days AS value
FROM gaps
ORDER BY gap_days
LIMIT 1 OFFSET (SELECT COUNT(*) / 2 FROM gaps);

WITH first_orders AS (
    SELECT c.customer_unique_id,
           MIN(o.order_purchase_timestamp) AS first_ts
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),
gaps AS (
    SELECT CAST(julianday(MIN(o.order_purchase_timestamp))
                - julianday(f.first_ts) AS INTEGER) AS gap_days
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    JOIN first_orders f ON f.customer_unique_id = c.customer_unique_id
    WHERE o.order_purchase_timestamp > f.first_ts
    GROUP BY c.customer_unique_id
)
SELECT CASE WHEN gap_days <= 7 THEN '0-7 days'
            WHEN gap_days <= 30 THEN '8-30 days'
            WHEN gap_days <= 90 THEN '31-90 days'
            WHEN gap_days <= 180 THEN '91-180 days'
            ELSE '>180 days' END AS gap_bucket,
       COUNT(*) AS repeat_customers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM gaps), 2) AS share_pct,
       ROUND(AVG(gap_days), 1) AS mean_gap_days
FROM gaps
GROUP BY gap_bucket
ORDER BY MIN(gap_days);

-- Recency: days since each customer's last order, as of the last order in
-- the data (2018-10-17)
WITH last_orders AS (
    SELECT c.customer_unique_id,
           MAX(o.order_purchase_timestamp) AS last_ts
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),
recency AS (
    SELECT CAST(julianday('2018-10-17') - julianday(last_ts) AS INTEGER)
               AS days_since_last_order
    FROM last_orders
)
SELECT CASE WHEN days_since_last_order <= 30 THEN '0-30 days'
            WHEN days_since_last_order <= 90 THEN '31-90 days'
            WHEN days_since_last_order <= 180 THEN '91-180 days'
            WHEN days_since_last_order <= 365 THEN '181-365 days'
            ELSE '>365 days' END AS recency_bucket,
       COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM recency), 2) AS share_pct
FROM recency
GROUP BY recency_bucket
ORDER BY MIN(days_since_last_order);
