WITH orders_with_customer_id AS (
    SELECT
        orders.order_id,
        orders.customer_id,
        customers.customer_unique_id,
        orders.order_purchase_timestamp,
        JULIANDAY('2018-08-17') AS julian_today
    FROM orderss
    INNER JOIN customers ON orders.customer_id = customers.customer_id
), unique_customers AS (
    SELECT DISTINCT customers.customer_unique_id
    FROM customers
), filtered_reviews AS (
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
), unique_order_pymts AS (
SELECT
  order_id,
  SUM(payment_value) AS total_payment_value
FROM
  order_pymts
GROUP BY
  order_id
)
SELECT
    orders_with_customer_id.customer_unique_id,
    MIN(julian_today-JULIANDAY(orders_with_customer_id.order_purchase_timestamp)) AS recency, -- number of days since the last 
    COUNT(orders_with_customer_id.order_id) AS frequency, -- total count of orders made
    SUM(unique_order_pymts.total_payment_value) AS amount, -- total expenses
    AVG(filtered_reviews.review_score) AS avg_satisfaction
FROM unique_customers
INNER JOIN orders_with_customer_id ON orders_with_customer_id.customer_unique_id = unique_customers.customer_unique_id
INNER JOIN filtered_reviews ON filtered_reviews.order_id = orders_with_customer_id.order_id
INNER JOIN unique_order_pymts ON unique_order_pymts.order_id = orders_with_customer_id.order_id
GROUP BY orders_with_customer_id.customer_unique_id