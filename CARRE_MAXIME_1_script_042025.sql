-- Identify orders during the last 3 months (considering today is the 17th of July 2018, date of the last purchase) which were delivered at least 3 days after the estimated delivery date.
WITH add_min_date AS (
    SELECT *,
        DATE(
            MAX(order_purchase_timestamp) OVER (),
            '-3 months'
        ) AS min_date
    FROM orders
)
SELECT order_id,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM add_min_date
WHERE order_delivered_customer_date IS NOT NULL
    AND min_date <= DATE(order_purchase_timestamp)
    AND JULIANDAY(order_delivered_customer_date) - JULIANDAY(order_estimated_delivery_date) >= 3
ORDER BY order_purchase_timestamp DESC;
--
--
-- Identify sellers who made more than 100 000 Real in sales revenue with Olist
WITH add_sales_revenue AS (
    SELECT seller_id,
        SUM(price) AS sales_revenue
    FROM order_items
        INNER JOIN orders ON orders.order_id = order_items.order_id
    WHERE orders.order_status = "delivered"
    GROUP BY seller_id
)
SELECT *
FROM add_sales_revenue
WHERE sales_revenue > 100000
ORDER BY sales_revenue DESC;
--
--
-- Identify sellers who started less than 3 months ago but already sold more than 30 products
WITH orders_with_min_date AS (
    SELECT *,
        DATE(
            MAX(order_purchase_timestamp) OVER (),
            '-3 months'
        ) AS min_date
    FROM orders
),
add_seller_info AS (
    SELECT order_items.seller_id,
        COUNT(*) AS product_count,
        MIN(orders_with_min_date.order_purchase_timestamp) AS first_order_date,
        -- We approximate the day at which the seller started using Olist to the day of their first order
        MIN(min_date) AS min_date -- it is constant anyway, we just do that to have it in the next step
    FROM order_items
        LEFT JOIN orders_with_min_date ON orders_with_min_date.order_id = order_items.order_id
    WHERE orders_with_min_date.order_status = "delivered"
    GROUP BY seller_id
)
SELECT seller_id,
    first_order_date,
    product_count
FROM add_seller_info
WHERE product_count > 30
    AND first_order_date > min_date;
--
--
-- Identify the 5 zipcodes with more than 30 reviews which had the worst mean score over the last 12 months
WITH orders_with_min_date AS (
    SELECT *,
        DATE(
            MAX(order_purchase_timestamp) OVER (),
            '-12 months'
        ) AS min_date
    FROM orders
),
filtered_reviews AS (
    SELECT review_id,
        order_id,
        review_score,
        review_creation_date
    FROM (
            SELECT review_id,
                order_id,
                review_score,
                review_creation_date,
                ROW_NUMBER() OVER(
                    PARTITION BY review_id
                    ORDER BY review_id
                ) AS row_n
            FROM order_reviews
        )
    WHERE row_n = 1
)
SELECT customers.customer_zip_code_prefix,
    COUNT(reviews.review_id) AS review_count,
    AVG(reviews.review_score) AS mean_score
FROM filtered_reviews AS reviews
    LEFT JOIN orders_with_min_date AS orders ON orders.order_id = reviews.order_id
    LEFT JOIN customers ON orders.customer_id = customers.customer_id -- I think I should use customer_unique_id here instead (which can appear several times in the table)
WHERE reviews.review_creation_date > orders.min_date
    AND orders.order_status != "canceled"
GROUP BY customers.customer_zip_code_prefix
HAVING review_count > 30
ORDER BY mean_score ASC
LIMIT 5;