-- ============================================================
-- OLIST E-COMMERCE ANALYSIS
-- ============================================================

-- ============================================================
-- BUSINESS QUESTION
-- ============================================================

-- What factors are associated with poor customer reviews
-- on Olist?

-- ============================================================
-- 1 - DATA EXPLORATION
-- ============================================================

/* The database structure was reviewed using DB Browser for SQLite.
 This included:
- Tables
- Columns
- Data types
- Number of records
- Sample records
 The following queries focus on exploratory analysis
directly related to the business question.*/

-- ------------------------------------------------------------
-- 1.1 - REVIEW SCORE DISTRIBUTION
-- ------------------------------------------------------------

SELECT
    review_score,
    COUNT(*) AS reviews,
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM reviews),
        2
    ) AS percentage
FROM reviews
GROUP BY review_score
ORDER BY review_score;

-- ------------------------------------------------------------
-- 1.2 - REVIEW COVERAGE OVER TIME
-- ------------------------------------------------------------

SELECT
    SUBSTR(review_creation_date, 1, 7) AS month,
    COUNT(*) AS reviews
FROM reviews
GROUP BY month
ORDER BY month;

-- ------------------------------------------------------------
-- 1.3 - REVIEWS WITH AND WITHOUT COMMENTS
-- ------------------------------------------------------------

SELECT
    CASE
        WHEN review_comment_message IS NULL
             OR TRIM(review_comment_message) = ''
        THEN 'Without comment'
        ELSE 'With comment'
    END AS comment_status,
    COUNT(*) AS reviews,
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM reviews),
        2
    ) AS percentage
FROM reviews
GROUP BY comment_status;

-- ------------------------------------------------------------
-- 1-4 - ORDER STATUS DISTRIBUTION
-- ------------------------------------------------------------

SELECT
    order_status,
    COUNT(*) AS orders,
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM orders),
        2
    ) AS percentage
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- ------------------------------------------------------------
-- 1-5 - ORDERS OVER TIME
-- ------------------------------------------------------------

SELECT
    SUBSTR(order_purchase_timestamp, 1, 7) AS month,
    COUNT(*) AS orders
FROM orders
GROUP BY month
ORDER BY month;
