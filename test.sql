SELECT 
  order_purchase_timestamp,
  JULIANDAY('2018-08-17') AS julian_today,
  JULIANDAY(order_purchase_timestamp) AS julian_purchase,
  JULIANDAY('2018-08-17') - JULIANDAY(order_purchase_timestamp) AS days_diff
FROM orders
LIMIT 10;