-- 04_monetization.sql
-- Monetization: average order value, payment methods, installments, and how
-- they relate to review scores.
-- Order value = SUM(payment_value) per order. "Primary payment" = the payment
-- row with the largest payment_value for that order (about 4% of orders have
-- more than one payment row, e.g. credit card + voucher).

-- Overall AOV
WITH order_values AS (
    SELECT order_id, SUM(payment_value) AS order_value
    FROM payments
    GROUP BY order_id
)
SELECT COUNT(*) AS paid_orders,
       ROUND(AVG(order_value), 2) AS mean_aov_brl,
       ROUND(MIN(order_value), 2) AS min_order_value_brl,
       ROUND(MAX(order_value), 2) AS max_order_value_brl
FROM order_values;

-- Median AOV
WITH order_values AS (
    SELECT order_id, SUM(payment_value) AS order_value
    FROM payments
    GROUP BY order_id
)
SELECT ROUND(order_value, 2) AS median_aov_brl
FROM order_values
ORDER BY order_value
LIMIT 1 OFFSET (SELECT COUNT(*) / 2 FROM order_values);

-- AOV and review score by primary payment method
WITH order_values AS (
    SELECT order_id, SUM(payment_value) AS order_value
    FROM payments
    GROUP BY order_id
),
primary_pay AS (
    SELECT order_id, payment_type, payment_installments,
           ROW_NUMBER() OVER (PARTITION BY order_id
                              ORDER BY payment_value DESC) AS rn
    FROM payments
)
SELECT pp.payment_type,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS share_pct,
       ROUND(AVG(ov.order_value), 2) AS mean_aov_brl,
       ROUND(AVG(r.review_score), 2) AS mean_review_score
FROM primary_pay pp
JOIN order_values ov ON ov.order_id = pp.order_id
LEFT JOIN reviews r ON r.order_id = pp.order_id
WHERE pp.rn = 1
GROUP BY pp.payment_type
ORDER BY orders DESC;

-- AOV and review score by installment bucket (primary payment)
WITH order_values AS (
    SELECT order_id, SUM(payment_value) AS order_value
    FROM payments
    GROUP BY order_id
),
primary_pay AS (
    SELECT order_id, payment_type, payment_installments,
           ROW_NUMBER() OVER (PARTITION BY order_id
                              ORDER BY payment_value DESC) AS rn
    FROM payments
)
SELECT CASE WHEN pp.payment_installments = 0 THEN '0'
            WHEN pp.payment_installments = 1 THEN '1'
            WHEN pp.payment_installments BETWEEN 2 AND 3 THEN '2-3'
            WHEN pp.payment_installments BETWEEN 4 AND 6 THEN '4-6'
            WHEN pp.payment_installments BETWEEN 7 AND 12 THEN '7-12'
            ELSE '13+' END AS installments,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS share_pct,
       ROUND(AVG(ov.order_value), 2) AS mean_aov_brl,
       ROUND(AVG(r.review_score), 2) AS mean_review_score
FROM primary_pay pp
JOIN order_values ov ON ov.order_id = pp.order_id
LEFT JOIN reviews r ON r.order_id = pp.order_id
WHERE pp.rn = 1
GROUP BY installments
ORDER BY MIN(pp.payment_installments);
