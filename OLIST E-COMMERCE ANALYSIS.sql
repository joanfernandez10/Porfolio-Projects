-- ============================================================
-- OLIST E-COMMERCE ANALYSIS
-- ============================================================

-- ============================================================
-- BUSINESS QUESTION
-- ============================================================

-- What factors are associated with poor customer reviews
-- on Olist?

-- ============================================================
-- 01 - DATA EXPLORATION
-- ============================================================

-- ------------------------------------------------------------
-- 1. NUMBER OF RECORDS
-- ------------------------------------------------------------

SELECT 'customers' AS table_name, COUNT(*) AS records
FROM customers

UNION ALL

SELECT 'geolocation', COUNT(*)
FROM geolocation

UNION ALL

SELECT 'items', COUNT(*)
FROM items

UNION ALL

SELECT 'orders', COUNT(*)
FROM orders

UNION ALL

SELECT 'payments', COUNT(*)
FROM payments

UNION ALL

SELECT 'reviews', COUNT(*)
FROM reviews

UNION ALL

SELECT 'products', COUNT(*)
FROM products

UNION ALL

SELECT 'sellers', COUNT(*)
FROM sellers

UNION ALL

SELECT 'product_category_name_translation', COUNT(*)
FROM product_category_name_translation

ORDER BY records DESC;


-- ------------------------------------------------------------
-- 2. REVIEW SCORE DISTRIBUTION
-- ------------------------------------------------------------

SELECT
    review_score,
    COUNT(*) AS reviews,
    ROUND(
        COUNT(*) * 100.0 / (SELECT COUNT(*) FROM reviews),
        2
    ) AS percentage
FROM reviews
GROUP BY review_score
ORDER BY review_score;


-- ------------------------------------------------------------
-- 3. ORDER STATUS DISTRIBUTION
-- ------------------------------------------------------------

SELECT
    order_status,
    COUNT(*) AS orders,
    ROUND(
        COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders),
        2
    ) AS percentage
FROM orders
GROUP BY order_status
ORDER BY orders DESC;


-- ------------------------------------------------------------
-- 4. PAYMENT TYPE DISTRIBUTION
-- ------------------------------------------------------------

SELECT
    payment_type,
    COUNT(*) AS payments,
    ROUND(
        COUNT(*) * 100.0 / (SELECT COUNT(*) FROM payments),
        2
    ) AS percentage
FROM payments
GROUP BY payment_type
ORDER BY payments DESC;

-- ------------------------------------------------------------
-- 5. ORDERS OVER TIME
-- ------------------------------------------------------------

SELECT
    SUBSTR(order_purchase_timestamp, 1, 7) AS month,
    COUNT(*) AS orders
FROM orders
GROUP BY month
ORDER BY month;

-- ------------------------------------------------------------
-- 6. PRICE DISTRIBUTION
-- ------------------------------------------------------------

SELECT
    MIN(price) AS min_price,
    ROUND(AVG(price), 2) AS avg_price,
    MAX(price) AS max_price
FROM items;

-- ------------------------------------------------------------
-- 7. PRODUCT CATEGORIES
-- ------------------------------------------------------------

SELECT
    p.product_category_name,
    COUNT(*) AS products
FROM products p
WHERE p.product_category_name IS NOT NULL
GROUP BY p.product_category_name
ORDER BY products DESC
LIMIT 15;

-- ------------------------------------------------------------
-- 8. SELLER ACTIVITY
-- ------------------------------------------------------------

SELECT
    seller_id,
    COUNT(*) AS items_sold
FROM items
GROUP BY seller_id
ORDER BY items_sold DESC
LIMIT 15;
