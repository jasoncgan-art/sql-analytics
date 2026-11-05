-- 02_funnel.sql
-- Order funnel: placed -> paid -> shipped -> delivered -> reviewed.
-- "Paid" = the order has at least one row in payments.
-- "Shipped"/"delivered" come from order_status, NOT from the delivery-date
-- columns: those date fields are populated even for canceled orders, so they
-- cannot be used as stage signals.
WITH stages AS (
    SELECT '1_ordered'   AS stage, 1 AS step, COUNT(*) AS orders FROM orders
    UNION ALL
    SELECT '2_paid', 2, COUNT(DISTINCT order_id) FROM payments
    UNION ALL
    SELECT '3_shipped', 3, COUNT(*) FROM orders
        WHERE order_status IN ('shipped', 'delivered')
    UNION ALL
    SELECT '4_delivered', 4, COUNT(*) FROM orders
        WHERE order_status = 'delivered'
    UNION ALL
    SELECT '5_reviewed', 5, COUNT(DISTINCT o.order_id)
        FROM orders o JOIN reviews r ON r.order_id = o.order_id
        WHERE o.order_status = 'delivered'
)
SELECT stage,
       orders,
       ROUND(100.0 * orders / LAG(orders) OVER (ORDER BY step), 2)
           AS step_conversion_pct,
       ROUND(100.0 * orders / FIRST_VALUE(orders) OVER (ORDER BY step), 2)
           AS overall_conversion_pct
FROM stages
ORDER BY step;

-- Diagnostic: where do orders that never ship go?
SELECT order_status, COUNT(*) AS orders
FROM orders
WHERE order_status NOT IN ('shipped', 'delivered')
GROUP BY order_status
ORDER BY orders DESC;
