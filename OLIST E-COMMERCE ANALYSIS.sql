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

-- ============================================================
-- 2 - DATA QUALITY CHECK
-- ============================================================

/* Data quality checks are performed to identify missing,
invalid, inconsistent, or duplicated records that could
affect the analysis of customer reviews and the factors
associated with poor ratings. */

-- ------------------------------------------------------------
-- 2.1 - MISSING REVIEW SCORES
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_reviews,
    COUNT(review_score) AS reviews_with_score,
    COUNT(*) - COUNT(review_score) AS missing_scores,
    ROUND(
        (COUNT(*) - COUNT(review_score)) * 100.0 /
        COUNT(*),
        2
    ) AS missing_percentage
FROM reviews;

-- ------------------------------------------------------------
-- 2.2 - INVALID REVIEW SCORES
-- ------------------------------------------------------------

SELECT
    review_score,
    COUNT(*) AS reviews
FROM reviews
WHERE review_score < 1
   OR review_score > 5
   OR review_score IS NULL
GROUP BY review_score
ORDER BY review_score;

-- ------------------------------------------------------------
-- 2.3 - DUPLICATE REVIEWS
-- ------------------------------------------------------------

SELECT
    review_id,
    COUNT(*) AS occurrences
FROM reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

-- ------------------------------------------------------------
-- 2.3.1 - REPEATED REVIEW IDs
-- ------------------------------------------------------------

SELECT
    review_id,
    COUNT(*) AS occurrences,
    COUNT(DISTINCT order_id) AS distinct_orders
FROM reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

-- ------------------------------------------------------------
-- 2.3.2 - DETAILS OF REPEATED REVIEW IDs
-- ------------------------------------------------------------

SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
FROM reviews
WHERE review_id IN (
    SELECT review_id
    FROM reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
)
ORDER BY review_id, order_id;

-- ------------------------------------------------------------
-- 2.3.3 - EXACT DUPLICATE REVIEW RECORDS
-- ------------------------------------------------------------

SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp,
    COUNT(*) AS occurrences
FROM reviews
GROUP BY
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

-- ------------------------------------------------------------
-- 2.3.4 - REPEATED REVIEW IDs AND POOR RATINGS
-- ------------------------------------------------------------

WITH repeated_reviews AS (
    SELECT
        review_id,
        MAX(review_score) AS review_score
    FROM reviews
    GROUP BY review_id
    HAVING COUNT(DISTINCT order_id) > 1
)

SELECT
    COUNT(*) AS repeated_review_ids,

    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(DISTINCT review_id) FROM reviews),
        2
    ) AS percentage_repeated_reviews,

    SUM(
        CASE
            WHEN review_score IN (1, 2)
            THEN 1
            ELSE 0
        END
    ) AS repeated_poor_reviews,

    ROUND(
        SUM(
            CASE
                WHEN review_score IN (1, 2)
                THEN 1
                ELSE 0
            END
        ) * 100.0 /
        (SELECT COUNT(DISTINCT review_id) FROM reviews),
        2
    ) AS percentage_poor_repeated_reviews

FROM repeated_reviews;

-- ------------------------------------------------------------
-- 2.4 - MISSING ORDER DATES
-- ------------------------------------------------------------

SELECT
    COUNT(CASE WHEN order_purchase_timestamp IS NOT NULL THEN 1 END) AS purchase_date_not_nulls,
    COUNT(CASE WHEN order_approved_at IS NULL THEN 1 END) AS approved_date_nulls,
    COUNT(CASE WHEN order_delivered_carrier_date IS NULL THEN 1 END) AS carrier_date_nulls,
    COUNT(CASE WHEN order_delivered_customer_date IS NULL THEN 1 END) AS customer_delivery_date_nulls,
    COUNT(CASE WHEN order_estimated_delivery_date IS NULL THEN 1 END) AS estimated_delivery_date_nulls
FROM orders;

-- ------------------------------------------------------------
-- 2.5 - INCONSISTENT ORDER DATES
-- ------------------------------------------------------------

-- Delivery before purchase

SELECT
    order_id,
    order_purchase_timestamp,
    order_delivered_customer_date
FROM orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_delivered_customer_date < order_purchase_timestamp;

-- Delivery before carrier shipment

SELECT
    order_id,
    order_delivered_carrier_date,
    order_delivered_customer_date
FROM orders
WHERE order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
  AND order_delivered_customer_date < order_delivered_carrier_date;

-- ------------------------------------------------------------
-- 2.6 - ORDER STATUS AND DELIVERY DATE CONSISTENCY
-- ------------------------------------------------------------

SELECT
    order_status,
    COUNT(*) AS orders,
    SUM(
        CASE
            WHEN order_delivered_customer_date IS NOT NULL
            THEN 1
            ELSE 0
        END
    ) AS with_delivery_date,
    SUM(
        CASE
            WHEN order_delivered_customer_date IS NULL
            THEN 1
            ELSE 0
        END
    ) AS without_delivery_date
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- ------------------------------------------------------------
-- 2.7 - MISSING VALUES IN POTENTIAL ANALYSIS VARIABLES
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_items,
    COUNT(price) AS price_not_null,
    COUNT(freight_value) AS freight_not_null
FROM items;

SELECT
    COUNT(*) AS total_products,
    COUNT(product_category_name) AS category_not_null,
    COUNT(product_weight_g) AS weight_not_null,
    COUNT(product_length_cm) AS length_not_null,
    COUNT(product_height_cm) AS height_not_null,
    COUNT(product_width_cm) AS width_not_null
FROM products;

-- ------------------------------------------------------------
-- 2.8 - INVALID NUMERICAL VALUES
-- ------------------------------------------------------------

-- Negative or zero prices

SELECT
    COUNT(*) AS invalid_prices
FROM items
WHERE price <= 0;

-- Invalid product dimensions

SELECT
    COUNT(*) AS invalid_dimensions
FROM products
WHERE product_weight_g <= 0
   OR product_length_cm <= 0
   OR product_height_cm <= 0
   OR product_width_cm <= 0;

-- ------------------------------------------------------------
-- 2.9 - REFERENTIAL INTEGRITY
-- ------------------------------------------------------------

-- Reviews without a matching order

SELECT
    r.review_id,
    r.order_id
FROM reviews r
LEFT JOIN orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;


-- Items without a matching product

SELECT
    i.order_id,
    i.product_id
FROM items i
LEFT JOIN products p
    ON i.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Items without a matching seller

SELECT
    i.order_id,
    i.seller_id
FROM items i
LEFT JOIN sellers s
    ON i.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- ============================================================
-- DATA QUALITY FINDINGS
-- ============================================================

 /* 
   789 review IDs are associated with multiple orders,
   representing approximately 0.8% of all review IDs.
   These are not exact duplicates, as each occurrence is
   associated with a different order_id. They will be retained
   in the raw data.

   23 orders have a customer delivery date earlier than the
   carrier delivery date, representing approximately 0.023%
   of all orders. These records will be retained and their
   impact will be considered when calculating delivery metrics.

   8 orders marked as "delivered" have no customer delivery date,
   while 6 orders marked as "canceled" have a customer delivery
   date. These cases will be retained for further analysis.

   610 products have no product category. This may limit the
   use of product category as an explanatory variable for some
   observations.

   4 products contain invalid dimensions
   (weight, length, height or width <= 0).
   These records will be reviewed before using product dimensions
   in the analysis.
*/
