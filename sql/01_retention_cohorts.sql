-- 01_retention_cohorts.sql
-- Retention cohorts, Duolingo D7/D30 style, applied to orders.
-- Cohort = month of a customer's FIRST order (any status; see README).
-- A customer is "retained" if they place a 2nd order within N days of the 1st.
-- Data ends 2018-10-17, so the 180-day window is only fully observed for
-- cohorts up to 2018-04; later cohorts are flagged censored.
WITH first_orders AS (
    SELECT c.customer_unique_id,
           MIN(o.order_purchase_timestamp) AS first_ts
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),
second_orders AS (
    SELECT c.customer_unique_id,
           MIN(o.order_purchase_timestamp) AS second_ts
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    JOIN first_orders f ON f.customer_unique_id = c.customer_unique_id
    WHERE o.order_purchase_timestamp > f.first_ts
    GROUP BY c.customer_unique_id
)
SELECT strftime('%Y-%m', f.first_ts) AS cohort_month,
       COUNT(*) AS customers,
       ROUND(100.0 * SUM(CASE WHEN s.second_ts IS NOT NULL
           AND julianday(s.second_ts) - julianday(f.first_ts) <= 30 THEN 1 ELSE 0 END)
           / COUNT(*), 2) AS repeat_30d_pct,
       ROUND(100.0 * SUM(CASE WHEN s.second_ts IS NOT NULL
           AND julianday(s.second_ts) - julianday(f.first_ts) <= 90 THEN 1 ELSE 0 END)
           / COUNT(*), 2) AS repeat_90d_pct,
       ROUND(100.0 * SUM(CASE WHEN s.second_ts IS NOT NULL
           AND julianday(s.second_ts) - julianday(f.first_ts) <= 180 THEN 1 ELSE 0 END)
           / COUNT(*), 2) AS repeat_180d_pct,
       CASE WHEN strftime('%Y-%m', f.first_ts) <= '2018-04' THEN 'full' ELSE 'censored' END
           AS window_180d
FROM first_orders f
LEFT JOIN second_orders s ON s.customer_unique_id = f.customer_unique_id
GROUP BY cohort_month
ORDER BY cohort_month;
