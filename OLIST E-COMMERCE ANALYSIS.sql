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

-- ============================================================
-- 3 - DATA ANALYSIS
-- ============================================================

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
   3.1- TIEMPO DE ENTREGA vs REVIEW SCORE
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
   3.1.2 LLEGÓ TARDE vs A TIEMPO — comparación directa
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
   3.2 - COSTO DE FLETE (freight_value) vs REVIEW SCORE
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
   3.3 - CATEGORÍA DE PRODUCTO vs REVIEW SCORE
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
   3.4 - MÉTODO DE PAGO Y CUOTAS vs REVIEW SCORE
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
   3.5 - VALOR DEL PEDIDO vs REVIEW SCORE
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
   3.6 - DESEMPEÑO POR VENDEDOR (seller)
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
   3.7 - DISTANCIA GEOGRÁFICA (estado comprador != estado vendedor)
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
   3.8 - % DE ENTREGAS TARDÍAS SOBRE EL TOTAL
   Base: todos los pedidos con status 'delivered' y fecha de entrega
   registrada.
--------------------------------------------------------------------- */
SELECT
    COUNT(*) AS total_pedidos_entregados,
    SUM(CASE
            WHEN julianday(order_delivered_customer_date) > julianday(order_estimated_delivery_date)
            THEN 1 ELSE 0
        END) AS pedidos_tardios,
    ROUND(100.0 * SUM(CASE
            WHEN julianday(order_delivered_customer_date) > julianday(order_estimated_delivery_date)
            THEN 1 ELSE 0
        END) / COUNT(*), 2) AS pct_entregas_tardias
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;

/* ---------------------------------------------------------------------
   3.9 - % DE MALAS RESEÑAS (score 1 o 2) POR CATEGORÍA DE PRODUCTO
   Mínimo 30 reseñas por categoría para evitar ruido de categorías
   con pocos casos.
--------------------------------------------------------------------- */
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name) AS categoria,
    COUNT(*) AS total_reviews,
    SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) AS malas_reviews,
    ROUND(100.0 * SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) / COUNT(*), 2)
        AS pct_malas_reviews
FROM items i
JOIN products p
    ON p.product_id = i.product_id
LEFT JOIN product_category_name_translation t
    ON t.product_category_name = p.product_category_name
JOIN reviews r
    ON r.order_id = i.order_id
GROUP BY categoria
HAVING COUNT(*) >= 30
ORDER BY pct_malas_reviews DESC;

/* ---------------------------------------------------------------------
   3.10 - DE LAS RESEÑAS NEGATIVAS (score 1 o 2), ¿QUÉ % TUVO UN TIEMPO DE
   ENTREGA MAYOR AL TIEMPO DE ENTREGA PROMEDIO?
   Definición: "tiempo de entrega" = días entre la compra
   (order_purchase_timestamp) y la entrega real al cliente
   (order_delivered_customer_date). NO es contra la fecha estimada,
   es el tiempo real que tardó en llegar.
   El promedio se calcula sobre TODOS los pedidos entregados (no solo
   los negativos), para tener un benchmark general contra el cual
   comparar.
--------------------------------------------------------------------- */
WITH tiempos_entrega AS (
    SELECT
        o.order_id,
        julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp)
            AS delivery_days
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
),
promedio_general AS (
    SELECT AVG(delivery_days) AS avg_delivery_days FROM tiempos_entrega
)
SELECT
    (SELECT ROUND(avg_delivery_days, 2) FROM promedio_general) AS tiempo_entrega_promedio_dias,
    COUNT(*) AS total_reseñas_negativas,
    SUM(CASE WHEN te.delivery_days > (SELECT avg_delivery_days FROM promedio_general) THEN 1 ELSE 0 END)
        AS negativas_con_demora_mayor_al_promedio,
    ROUND(100.0 * SUM(CASE WHEN te.delivery_days > (SELECT avg_delivery_days FROM promedio_general) THEN 1 ELSE 0 END)
          / COUNT(*), 2) AS pct_negativas_con_demora_mayor
FROM tiempos_entrega te
JOIN reviews r ON r.order_id = te.order_id
WHERE r.review_score <= 2;
 
-- 3.10.b) Mismo cálculo pero desagregado por cada score (1 a 5), para
-- ver la tendencia completa y no solo el bloque "negativas".

WITH tiempos_entrega AS (
    SELECT
        o.order_id,
        julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp)
            AS delivery_days
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
),
promedio_general AS (
    SELECT AVG(delivery_days) AS avg_delivery_days FROM tiempos_entrega
)
SELECT
    r.review_score,
    COUNT(*) AS total_pedidos,
    ROUND(AVG(te.delivery_days), 2) AS tiempo_entrega_promedio_del_score,
    SUM(CASE WHEN te.delivery_days > (SELECT avg_delivery_days FROM promedio_general) THEN 1 ELSE 0 END)
        AS pedidos_sobre_el_promedio,
    ROUND(100.0 * SUM(CASE WHEN te.delivery_days > (SELECT avg_delivery_days FROM promedio_general) THEN 1 ELSE 0 END)
          / COUNT(*), 2) AS pct_sobre_el_promedio
FROM tiempos_entrega te
JOIN reviews r ON r.order_id = te.order_id
GROUP BY r.review_score
ORDER BY r.review_score;

/* ---------------------------------------------------------------------
   3.11 - DEL TOTAL DE ENTREGAS TARDÍAS (fecha real > fecha estimada),
   ¿QUÉ % LE CORRESPONDE A CADA CALIFICACIÓN (1 a 5 estrellas)?
   Acá la base 100% es el total de entregas tardías, y repartimos
   ese 100% entre los distintos review_score.
--------------------------------------------------------------------- */
WITH entregas_tardias AS (
    SELECT o.order_id
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
      AND julianday(o.order_delivered_customer_date) > julianday(o.order_estimated_delivery_date)
)
SELECT
    r.review_score,
    COUNT(*) AS cantidad_entregas_tardias,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM entregas_tardias), 2)
        AS pct_sobre_total_entregas_tardias
FROM entregas_tardias et
JOIN reviews r ON r.order_id = et.order_id
GROUP BY r.review_score
ORDER BY r.review_score;


/* ============================================================
   3 - DATA ANALYSIS — KEY FINDINGS
   ============================================================

   The analysis evaluated several factors that could be associated
   with poor customer reviews, distinguishing between factors that
   are within Olist's influence and those that depend primarily on
   the characteristics of the product, seller, or customer.

   Among the factors outside Olist's direct control, some product
   categories and sellers show relatively high proportions of poor
   ratings. For example, certain categories, such as office products
   and men's clothing, have poor-rating shares of approximately
   26-27%. However, neither individual categories nor sellers
   represent a sufficiently large share of total orders to have a
   significant impact on the overall rate of negative reviews.

   Product price shows a weak association with customer satisfaction,
   as higher-priced products tend to receive lower average ratings.
   Purchases above $300 have an average rating of 3.96, compared
   with 4.17 for purchases below $50. This may reflect higher customer
   expectations associated with more expensive purchases, making
   dissatisfaction more pronounced when the product does not meet
   those expectations.

   Geographical distance between the seller and the customer also
   shows a negative association with ratings, although the difference
   is relatively small. A possible explanation is that greater
   distances tend to increase delivery times. However, distance itself
   does not appear to be a major driver of poor reviews.

   Among the factors more directly influenced by Olist, freight costs
   and payment methods show little association with review scores.
   The number of installments presents a counterintuitive negative
   relationship with ratings: purchases made in more installments
   tend to receive lower scores. However, this relationship is likely
   partly explained by the higher prices of products purchased through
   installments rather than by the payment method itself.


   ------------------------------------------------------------
   DELIVERY TIME AS A KEY FACTOR
   ------------------------------------------------------------

   Delivery performance emerges as the most relevant factor
   identified in the analysis.

   Approximately 8.11% of deliveries occurred after the estimated
   delivery date, and only 34% of these late deliveries received a
   4- or 5-star rating. However, because late deliveries represent
   a relatively small proportion of total orders, they do not
   explain the majority of poor reviews by themselves.

   An even more important finding is that approximately 60% of
   negative reviews were associated with deliveries that took longer
   than the average delivery time. This suggests that customer
   dissatisfaction is not limited to deliveries that formally exceed
   the estimated deadline.

   Longer delivery times appear to affect customer satisfaction even
   when the order is technically delivered within the promised
   timeframe.

   ------------------------------------------------------------
   CONCLUSION
   ------------------------------------------------------------

   Overall, the analysis suggests that several factors are associated
   with customer satisfaction, but most have either a relatively small
   effect or are outside Olist's direct control.

   Among the factors Olist can influence, delivery time stands out
   as the clearest opportunity for improvement. Reducing average
   delivery times could improve customer satisfaction even without
   focusing exclusively on eliminating deliveries that exceed the
   estimated deadline.

   This is particularly relevant to Olist's business model, which
   coordinates transactions and logistics between a large number of
   independent sellers and customers across a geographically extensive
   market.

   Therefore, improving logistics efficiency and reducing delivery
   times may be one of the most effective ways for Olist to improve
   the customer experience and, consequently, review scores.
*/
