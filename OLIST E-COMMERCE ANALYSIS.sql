-- =====================================================================
-- OLIST BRAZILIAN E-COMMERCE — ¿Qué factores se asocian a malas reviews?
-- =====================================================================
/* Dataset: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
   Dialecto: SQLite 3.25+ (usa funciones de ventana y julianday())

   Tablas usadas (nombres tal como fueron importados en este proyecto):
     customers    -> olist_customers_dataset.csv
     orders       -> olist_orders_dataset.csv
     items        -> olist_order_items_dataset.csv
     payments     -> olist_order_payments_dataset.csv
     reviews      -> olist_order_reviews_dataset.csv
     products     -> olist_products_dataset.csv
     sellers      -> olist_sellers_dataset.csv
     geolocation  -> olist_geolocation_dataset.csv
     product_category_name_translation
   ===================================================================== */

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

/* ============================================================
   EXPLORATION FINDINGS
   ============================================================

   Reviews are strongly concentrated in positive ratings:
   5 stars: 57.78% | 4 stars: 19.29% | 3 stars: 8.24%
   2 stars: 3.18%  | 1 star: 11.51%

   1- and 2-star reviews account for 14.69% of all reviews
   and will be the main focus of the analysis.

   Most reviews do not contain written comments, so review
   scores will be the primary measure of customer satisfaction,
   with comments used to investigate the reasons behind poor
   ratings.

   Most orders are delivered, and order activity varies over
   time, allowing delivery-related factors and temporal patterns
   to be investigated.
*/ 

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

/* ============================================================
   DATA QUALITY FINDINGS
   ============================================================

   789 review IDs are associated with multiple orders
   (approximately 0.8% of all review IDs). These are not
   exact duplicates and will be retained.

   23 orders have a customer delivery date earlier than the
   carrier delivery date (0.023% of orders). These records
   will be retained and considered when analyzing delivery time.

   8 delivered orders have no customer delivery date, while
   6 canceled orders have a delivery date. These cases will
   be retained for further analysis.

   610 products have no category, which may limit category-based
   analysis for these observations.

   4 products contain invalid dimensions and will be excluded
   when product dimensions are used.

   Some variables contain a non-negligible number of missing
   values. These observations will be retained, as SQL aggregate
   functions generally ignore NULL values by default.
*/


/*
   Notas de compatibilidad SQLite:
     - No existe EXTRACT(); las diferencias de fecha se calculan con
       julianday(fecha_a) - julianday(fecha_b), que devuelve días
       (con decimales) directamente.
     - Los campos de fecha del CSV deben quedar como TEXT en formato
       'YYYY-MM-DD HH:MM:SS' para que julianday() los interprete bien.
     - CAST(... AS REAL) se usa para evitar división entera.

   Definición de trabajo:
     "Mala review" = review_score IN (1, 2)
     "Buena review" = review_score IN (4, 5)
   ===================================================================== */

/* ---------------------------------------------------------------------
   1. TIEMPO DE ENTREGA vs REVIEW SCORE
   Hipótesis: pedidos que tardan más en llegar reciben peores reviews.
--------------------------------------------------------------------- */
WITH orders_delivery AS (
    SELECT
        o.order_id,
        julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp)
            AS delivery_days,
        julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date)
            AS delay_days   -- positivo = llegó tarde respecto a lo estimado
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT
    r.review_score,
    ROUND(AVG(d.delivery_days), 1) AS avg_delivery_days,
    ROUND(AVG(d.delay_days), 1)    AS avg_delay_vs_estimate,
    COUNT(*)                       AS n_orders
FROM orders_delivery d
JOIN reviews r ON r.order_id = d.order_id
GROUP BY r.review_score
ORDER BY r.review_score;


/* ---------------------------------------------------------------------
   1.b LLEGÓ TARDE vs A TIEMPO — comparación directa
--------------------------------------------------------------------- */
WITH orders_delivery AS (
    SELECT
        o.order_id,
        CASE
            WHEN julianday(o.order_delivered_customer_date) > julianday(o.order_estimated_delivery_date)
                THEN 'Entrega tardía'
            ELSE 'Entrega a tiempo'
        END AS delivery_status
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT
    d.delivery_status,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(100.0 * SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) / COUNT(*), 2)
        AS pct_malas_reviews,
    COUNT(*) AS n_orders
FROM orders_delivery d
JOIN reviews r ON r.order_id = d.order_id
GROUP BY d.delivery_status
ORDER BY avg_review_score;


/* ---------------------------------------------------------------------
   2. COSTO DE FLETE (freight_value) vs REVIEW SCORE
--------------------------------------------------------------------- */
WITH order_freight AS (
    SELECT
        oi.order_id,
        SUM(oi.price) AS total_price,
        SUM(oi.freight_value) AS total_freight,
        ROUND(SUM(oi.freight_value) / NULLIF(CAST(SUM(oi.price) AS REAL), 0), 3)
            AS freight_ratio
    FROM items oi
    GROUP BY oi.order_id
)
SELECT
    r.review_score,
    ROUND(AVG(f.total_price), 2)   AS avg_price,
    ROUND(AVG(f.total_freight), 2) AS avg_freight,
    ROUND(AVG(f.freight_ratio), 3) AS avg_freight_ratio,
    COUNT(*)                       AS n_orders
FROM order_freight f
JOIN reviews r ON r.order_id = f.order_id
GROUP BY r.review_score
ORDER BY r.review_score;


/* ---------------------------------------------------------------------
   3. CATEGORÍA DE PRODUCTO vs REVIEW SCORE
   Top categorías con peor score promedio (mínimo 50 reviews).
--------------------------------------------------------------------- */
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name) AS category,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(100.0 * SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) / COUNT(*), 2)
        AS pct_malas_reviews,
    COUNT(*) AS n_reviews
FROM items oi
JOIN products p
    ON p.product_id = oi.product_id
LEFT JOIN product_category_name_translation t
    ON t.product_category_name = p.product_category_name
JOIN reviews r
    ON r.order_id = oi.order_id
GROUP BY category
HAVING COUNT(*) >= 50
ORDER BY avg_review_score ASC
LIMIT 15;


/* ---------------------------------------------------------------------
   4. MÉTODO DE PAGO Y CUOTAS vs REVIEW SCORE
--------------------------------------------------------------------- */
SELECT
    pay.payment_type,
    ROUND(AVG(pay.payment_installments), 1) AS avg_installments,
    ROUND(AVG(r.review_score), 2)           AS avg_review_score,
    COUNT(*)                                AS n_orders
FROM payments pay
JOIN reviews r ON r.order_id = pay.order_id
GROUP BY pay.payment_type
ORDER BY avg_review_score;

-- Cuotas agrupadas en rangos
SELECT
    CASE
        WHEN payment_installments = 1 THEN '1 (contado)'
        WHEN payment_installments BETWEEN 2 AND 4 THEN '2-4 cuotas'
        WHEN payment_installments BETWEEN 5 AND 8 THEN '5-8 cuotas'
        ELSE '9+ cuotas'
    END AS installment_bucket,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    COUNT(*)                      AS n_orders
FROM payments pay
JOIN reviews r ON r.order_id = pay.order_id
GROUP BY installment_bucket
ORDER BY avg_review_score;


/* ---------------------------------------------------------------------
   5. VALOR DEL PEDIDO vs REVIEW SCORE
--------------------------------------------------------------------- */
WITH order_value AS (
    SELECT
        order_id,
        SUM(price) AS total_price
    FROM items
    GROUP BY order_id
)
SELECT
    CASE
        WHEN v.total_price < 50  THEN '< R$50'
        WHEN v.total_price < 150 THEN 'R$50-150'
        WHEN v.total_price < 300 THEN 'R$150-300'
        ELSE '> R$300'
    END AS price_bucket,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    COUNT(*)                      AS n_orders
FROM order_value v
JOIN reviews r ON r.order_id = v.order_id
GROUP BY price_bucket
ORDER BY avg_review_score;


/* ---------------------------------------------------------------------
   6. DESEMPEÑO POR VENDEDOR (seller)
   Vendedores con más de 20 ventas, ordenados por peor score promedio.
--------------------------------------------------------------------- */
SELECT
    oi.seller_id,
    COUNT(DISTINCT oi.order_id)   AS n_orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(100.0 * SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) / COUNT(*), 2)
        AS pct_malas_reviews
FROM items oi
JOIN reviews r ON r.order_id = oi.order_id
GROUP BY oi.seller_id
HAVING COUNT(DISTINCT oi.order_id) >= 20
ORDER BY avg_review_score ASC
LIMIT 20;


/* ---------------------------------------------------------------------
   7. DISTANCIA GEOGRÁFICA (estado comprador != estado vendedor)
--------------------------------------------------------------------- */
WITH order_states AS (
    SELECT
        o.order_id,
        CASE WHEN c.customer_state = s.seller_state
             THEN 'Mismo estado'
             ELSE 'Estados distintos'
        END AS route_type
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    JOIN items oi ON oi.order_id = o.order_id
    JOIN sellers s ON s.seller_id = oi.seller_id
)
SELECT
    os.route_type,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    COUNT(DISTINCT os.order_id)   AS n_orders
FROM order_states os
JOIN reviews r ON r.order_id = os.order_id
GROUP BY os.route_type
ORDER BY avg_review_score;


/* ---------------------------------------------------------------------
   8. RESUMEN MULTIFACTOR
   Une los factores más relevantes en una sola tabla por pedido, para
   exportar (.mode csv / .output archivo.csv en la CLI de SQLite) y
   graficar en Python/Tableau/PowerBI.
--------------------------------------------------------------------- */
WITH order_base AS (
    SELECT
        o.order_id,
        CASE
            WHEN julianday(o.order_delivered_customer_date) > julianday(o.order_estimated_delivery_date)
                THEN 1 ELSE 0
        END AS is_late
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
),
order_items_agg AS (
    SELECT
        order_id,
        COUNT(*)                                                          AS n_items,
        SUM(price)                                                        AS total_price,
        SUM(freight_value)                                                AS total_freight,
        ROUND(SUM(freight_value) / NULLIF(CAST(SUM(price) AS REAL), 0), 3) AS freight_ratio
    FROM items
    GROUP BY order_id
)
SELECT
    r.review_score,
    ob.is_late,
    oia.n_items,
    oia.total_price,
    oia.freight_ratio
FROM order_base ob
JOIN order_items_agg oia ON oia.order_id = ob.order_id
JOIN reviews r ON r.order_id = ob.order_id;
-- Tip: en la CLI de SQLite podés exportar esto directo a CSV con:
--   .headers on
--   .mode csv
--   .output resumen_multifactor.csv
--   (pegá aquí el SELECT de arriba)
--   .output stdout

