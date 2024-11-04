-- What were the order counts, sales, and AOV for Macbooks sold in North America for each quarter across all years?

SELECT
  EXTRACT(YEAR from orders.purchase_ts) AS purchase_year
  , EXTRACT(QUARTER from orders.purchase_ts) AS purchase_quarter
  , COUNT(distinct orders.id) AS order_count
  , ROUND(SUM(orders.usd_price)) AS total_sales
  , ROUND(AVG(orders.usd_price)) AS aov
FROM core.orders AS orders
JOIN core.customers AS customers ON
orders.customer_id = customers.id
JOIN core.geo_lookup AS geo ON
customers.country_code = geo.country_code
WHERE
  orders.product_name LIKE '%Macbook%'
  AND geo.region = 'NA'
GROUP BY 1, 2
ORDER BY 1, 2
;


-- How many Macbooks were ordered in USD each month in 2019 through 2020, sorted from oldest to most recent month?

SELECT
  DATE_TRUNC(orders.purchase_ts,month) AS purchase_month
  , COUNT(distinct orders.id) AS order_count
FROM core.orders AS orders
WHERE
  orders.product_name LIKE '%Macbook%'
  AND orders.currency = 'USD'
  AND EXTRACT(YEAR from orders.purchase_ts) IN (2019,2020)
GROUP BY purchase_month
ORDER BY purchase_month
;


-- Return the unique combinations of product IDs and product names of all Apple and Bose products.

SELECT
  DISTINCT product_id
  , product_name
FROM core.orders
WHERE
  product_name LIKE '%Apple%'
  OR product_name LIKE '%Macbook%'
  OR product_name LIKE '%bose%'
ORDER BY product_name
;


-- Return the purchase month, shipping month, time to ship (in days), and product name for each order placed in 2020. Show at least 2 ways of filtering on the date.

SELECT
  EXTRACT(MONTH FROM status.purchase_ts) AS purchase_month
  , EXTRACT(MONTH FROM status.ship_ts) AS ship_month
  , DATE_DIFF(status.ship_ts, status.purchase_ts, day) AS time_to_ship_days
  , orders.product_name AS product_name
FROM core.orders AS orders
JOIN core.order_status AS status
ON orders.id = status.order_id
WHERE EXTRACT(YEAR FROM status.purchase_ts) = 2020
  -- Alternate way:
  -- status.purchase_ts BETWEEN '2020-01-01' AND '2020-12-31'
;


-- What is the average time-to-purchase between loyalty customers vs. non-loyalty customers? Return your results in one query.

SELECT
  customers.loyalty_program
  , ROUND(
      AVG(
        DATE_DIFF(orders.purchase_ts, customers.created_on, day)
        )
    ) AS avg_time_to_purchase_days
  , COUNT(customers.id) AS customer_count
FROM core.orders AS orders
JOIN core.customers AS customers ON orders.customer_id = customers.id
GROUP BY customers.loyalty_program
;


-- What is the average order value per year for products that are either laptops or headphones? Round this to 2 decimals.

SELECT
  EXTRACT(YEAR FROM status.purchase_ts) AS year
  , ROUND(AVG(orders.usd_price)) AS AOV
  , COUNT(orders.id) AS total_orders
FROM core.orders AS orders
JOIN core.order_status AS status ON orders.id = status.order_id
WHERE orders.product_name LIKE '%Macbook%'
  OR orders.product_name LIKE '%Laptop%'
  OR orders.product_name LIKE '%Headphones%'
GROUP BY year
ORDER BY year
;


-- How many customers either came through an email marketing channel and created an account on mobile, or came through an affiliate marketing campaign and created an account on desktop?

SELECT
  COUNT(CASE 
          WHEN customers.marketing_channel = 'email' 
            AND customers.account_creation_method = 'mobile' 
          THEN customers.id 
        END) AS email_mobile_count # email and mobile form an exclusive pairing
  , COUNT(CASE 
            WHEN customers.marketing_channel = 'affiliate' 
              AND customers.account_creation_method = 'desktop' 
            THEN customers.id 
          END) AS affiliate_desktop_count # all affiliate = unknown method; all desktop = direct channel
  , COUNT(customers.id) AS total_count
FROM core.customers AS customers
;

/*
This query revealed a deterministic relationship between marketing_channel and account_creation_method,
meaning each marketing channel is consistently associated with a specific account creation method.
There are no variations or overlaps in these pairings.
*/

SELECT 
  customers.marketing_channel
  , customers.account_creation_method
  , COUNT(customers.id) AS combination_count
FROM core.customers AS customers
GROUP BY customers.marketing_channel, customers.account_creation_method
ORDER BY customers.marketing_channel, customers.account_creation_method
;


-- What is the total number of orders per year for each product? Clean up product names when grouping and return in alphabetical order after sorting by months.

SELECT
  EXTRACT(YEAR FROM status.purchase_ts) AS purchase_year
  , EXTRACT(MONTH FROM status.purchase_ts) AS purchase_month
  , TRIM(
      CASE 
      WHEN orders.product_name LIKE '%27in%4k gaming monitor%' THEN '27in 4K gaming monitor'
      ELSE orders.product_name
    END
  ) AS product_name_clean
  , COUNT(orders.id) AS total_orders
FROM core.orders AS orders
JOIN core.order_status AS status
  ON orders.id = status.order_id
GROUP BY purchase_year, purchase_month, product_name_clean
ORDER BY purchase_month, product_name_clean, purchase_year
;


-- For products purchased in 2022 on the website or products purchased on mobile in any year, which region has the average highest time to deliver?

SELECT
  geo.region
  , ROUND(AVG(DATE_DIFF(status.delivery_ts,status.purchase_ts,day)),2) days_to_deliver
FROM core.orders
LEFT JOIN core.order_status status ON orders.id = status.order_id
LEFT JOIN core.customers ON orders.customer_id = customers.id
LEFT JOIN core.geo_lookup geo ON customers.country_code = geo.country_code
WHERE
  (EXTRACT(YEAR from status.purchase_ts) = 2022 AND orders.purchase_platform = 'website')
  OR orders.purchase_platform = 'mobile'
GROUP BY geo.region
ORDER BY days_to_deliver desc
;


-- What was the refund rate and refund count for each product overall?

SELECT
  orders.product_name
  , ROUND(COUNT(status.refund_ts)/COUNT(orders.id)*100,2) refund_rate
  , COUNT(status.refund_ts) refund_count
  , COUNT(orders.id) order_count
FROM core.orders
LEFT JOIN core.order_status status ON orders.id = status.order_id
GROUP BY 1
ORDER BY 2 desc
;


-- Within each region, what is the most popular product?

WITH region_sales AS (
  SELECT
    geo.region
    , orders.product_name
    , COUNT(orders.id) order_count
  FROM core.orders
  LEFT JOIN core.customers ON orders.customer_id = customers.id
  LEFT JOIN core.geo_lookup geo ON customers.country_code = geo.country_code
  GROUP BY region, product_name
)
SELECT region, product_name, order_count
FROM region_sales
QUALIFY ROW_NUMBER() OVER (PARTITION BY region ORDER BY order_count desc) = 1
ORDER BY order_count desc
;

/*
-- One could also do another CTE since QUALIFY is not supported in every sql server

WITH region_sales AS (
  SELECT
    geo.region
    , orders.product_name
    , COUNT(orders.id) order_count
  FROM core.orders
  LEFT JOIN core.customers ON orders.customer_id = customers.id
  LEFT JOIN core.geo_lookup geo ON customers.country_code = geo.country_code
  GROUP BY region, product_name
),
ranked_sales AS(
  SELECT
      region
      , product_name
      , order_count
      , ROW_NUMBER() OVER (PARTITION BY region ORDER BY order_count DESC) AS row_num
  FROM region_sales
)
SELECT region, product_name, order_count
FROM ranked_sales
WHERE row_num = 1
ORDER BY order_count desc
;

*/

-- What is the average total sales over the entire range of 2019-2022?

WITH yearly_sales AS (
  SELECT 
    EXTRACT(YEAR FROM purchase_ts) AS year
    , SUM(usd_price) AS total_sales
  FROM core.orders
  WHERE EXTRACT(YEAR FROM purchase_ts) IS NOT null
  GROUP BY year
)

SELECT 
  ROUND(AVG(total_sales), 2) AS avg_sales_across_years
FROM yearly_sales
;


-- Is there a correlation with product refund rates and loyalty status?

SELECT
  orders.product_name
  , CASE
      WHEN customers.loyalty_program = 0 THEN 'nonloyalty'
      WHEN customers.loyalty_program = 1 THEN 'loyalty' END
  , ROUND(COUNT(status.refund_ts)/COUNT(orders.id)*100,2) refund_rate
  , COUNT(status.refund_ts) refund_count
  , COUNT(orders.id) order_count
FROM core.orders
LEFT JOIN core.order_status status ON orders.id = status.order_id
LEFT JOIN core.customers ON orders.customer_id = customers.id
WHERE loyalty_program IS NOT null
GROUP BY 1,2
ORDER BY 1,2
;


-- Is there a correlation with annual refund rates and loyalty status?

# following query I tried to validate in Excel as well
SELECT
  EXTRACT(YEAR from orders.purchase_ts) year
  , CASE
      WHEN customers.loyalty_program = 0 THEN 'nonloyalty'
      WHEN customers.loyalty_program = 1 THEN 'loyalty' END AS loyalty_status
  , ROUND(COUNT(status.refund_ts)/COUNT(orders.id)*100,2) refund_rate
  , COUNT(status.refund_ts) refund_count
  , COUNT(orders.id) order_count
FROM core.orders
LEFT JOIN core.customers ON orders.customer_id = customers.id # problem lies in table joining i think
LEFT JOIN core.order_status status ON orders.id = status.order_id # frustrated
-- WHERE loyalty_program IS NOT null # if commented, it'll show nulls in loyalty_status. investigate.
GROUP BY 1,2
ORDER BY 1,2
;

SELECT COUNT(DISTINCT customers.id)
FROM core.customers
;

# above returns 74904 while =COUNTA(UNIQUE(orders[USER_ID])) in excel returns 87628. why?

SELECT COUNT(DISTINCT orders.customer_id)
FROM core.orders
; # this one also returns 87628 same as excel table

# confirming that there are customer_ids in the orders table that ARE NOT in the customers table

SELECT COUNT(*) AS unmatched_orders
FROM core.orders
LEFT JOIN core.customers ON orders.customer_id = customers.id
WHERE customers.id IS NULL
;

SELECT # seeing distribution of unmatched customer ids by year
  EXTRACT(YEAR from orders.purchase_ts) year
  , COUNT(*) AS unmatched_orders
FROM core.orders
LEFT JOIN core.customers ON orders.customer_id = customers.id
WHERE customers.id IS NULL
GROUP BY 1
;

/*
27k records that had no customers.id in final table after joining, which meant that there is a 25% severity
affecting analysis accuracy for any essential loyalty_program (or any other attributes in customers table) insights
(if we're joining separate tables as is the schema of the dataset in sql, unlike in excel where it is all in one table)
# wanted to confirm first if this is a valid concern or if I was just missing something

Either way, in both cases loyalty purchases had the same trend of having a higher refund rate than nonloyalty purchases
Which is interesting! I'd dive deeper into the specifics of the loyalty program, if there is a
longer valid refund window for loyalty members. This could be an influencing factor.
*/

/*
Qs:
1. Is this investigation into a discrepancy valid or is there potentially a mistake in my queries that I missed?
2. How would you proceed in a real-life situation?
3. Would this invalidate any previous queries where we had to look into the loyalty_program column and joining orders and customers?
(25% (27k/108k) records had unmatched customers)
*/

-- What percentage of customers made more than one purchase in a year? Break it down by year.

WITH customer_orders AS (
  SELECT
    orders.customer_id
    , EXTRACT(YEAR from orders.purchase_ts) purchase_year
    , COUNT(orders.id) order_count
  FROM core.orders
  GROUP BY 1,2
)
SELECT
  purchase_year
  , COUNT(DISTINCT customer_id) unique_customers
  , COUNT(CASE WHEN order_count >= 2 THEN customer_id END) repeat_customers
  , ROUND((COUNT(CASE WHEN order_count >= 2 THEN customer_id END) * 1.0 / COUNT(DISTINCT customer_id))*100,2) repeat_rate
FROM customer_orders
WHERE purchase_year IS NOT null
GROUP BY 1
ORDER BY 1
;


-- How many refunds were there for each month in 2021? What about each quarter and week?

SELECT
  DATE_TRUNC(refund_ts,month) AS month
  -- , DATE_TRUNC(refund_ts,week) AS week
  -- , DATE_TRUNC(refund_ts,quarter) AS quarter
  , COUNT(refund_ts) AS refunds
FROM core.order_status
WHERE EXTRACT(YEAR from refund_ts) = 2021
GROUP BY 1
ORDER BY 1
;


-- For each region, what's the total number of customers and the total number of orders? Sort alphabetically by region.

SELECT
  geo.region
  , COUNT(DISTINCT customers.id) customer_count
  , COUNT(DISTINCT orders.id) orders_count
FROM core.orders
LEFT JOIN core.customers ON orders.customer_id = customers.id
LEFT JOIN core.geo_lookup AS geo ON customers.country_code = geo.country_code
GROUP BY 1
ORDER BY 1
;


-- What's the average time to deliver for each purchase platform?

SELECT
  orders.purchase_platform
  , ROUND(AVG(DATE_DIFF(status.delivery_ts, status.purchase_ts, day)),4) AS avg_time_to_deliver
FROM core.orders
LEFT JOIN core.order_status status ON orders.id = status.order_id
GROUP BY 1
;


-- What were the top 2 regions for Macbook sales in 2020?

SELECT
  geo.region
  , ROUND(SUM(orders.usd_price),2) macbook_sales
FROM core.orders
LEFT JOIN core.customers ON orders.customer_id = customers.id
LEFT JOIN core.geo_lookup geo ON customers.country_code = geo.country_code
WHERE
  orders.product_name LIKE '%Macbook%'
  AND EXTRACT(YEAR from orders.purchase_ts) = 2020
GROUP BY 1
ORDER BY 2 desc
LIMIT 2
;


-- For each purchase platform, return the top 3 customers by the number of purchases and order them within that platform. If there is a tie, break the tie using any order.

WITH customer_purchases AS (
  SELECT
    purchase_platform
    , customer_id
    , COUNT(distinct id) AS order_count
  FROM core.orders
  GROUP BY 1,2
)
SELECT
  purchase_platform
  , customer_id
  , order_count
  , ROW_NUMBER() OVER (PARTITION BY purchase_platform ORDER BY order_count desc) AS order_ranking
FROM customer_purchases
QUALIFY ROW_NUMBER() OVER (PARTITION BY purchase_platform ORDER BY order_count desc) <= 3
;


-- What was the most-purchased brand in the APAC region?

SELECT
  case when product_name like 'Apple%' or product_name like 'Macbook%' then 'Apple'
  when product_name like 'Samsung%' then 'Samsung'
  when product_name like 'ThinkPad%' then 'ThinkPad'
  when product_name like 'bose%' then 'Bose'
  else 'Unknown' end as brand
  , COUNT(orders.id) order_count
FROM core.orders
LEFT JOIN core.customers ON orders.customer_id = customers.id
LEFT JOIN core.geo_lookup geo ON customers.country_code = geo.country_code
WHERE region = 'APAC'
GROUP BY 1
ORDER BY 2 desc
LIMIT 1
;


-- Of people who bought Apple products, which 5 customers have the top average order value, ranked from highest AOV to lowest AOV?

WITH customer_aov_apple AS (
  SELECT orders.customer_id id
  , AVG(usd_price) aov
  FROM core.orders
  WHERE product_name LIKE 'Apple%' OR product_name LIKE 'Macbook%'
  GROUP BY 1
)
SELECT id
  , aov
  , ROW_NUMBER() OVER (ORDER BY aov DESC) AS customer_ranking
FROM customer_aov_apple
QUALIFY customer_ranking <= 5
ORDER BY aov desc
;


-- Within each purchase platform, what are the top two marketing channels ranked by average order value?

WITH marketing_sales AS (
  SELECT
    orders.purchase_platform
    , customers.marketing_channel
    , ROUND(AVG(usd_price),2) aov
  FROM core.orders
  LEFT JOIN core.customers ON orders.customer_id = customers.id
  GROUP BY 1,2
)
SELECT
  *
  , ROW_NUMBER() OVER (PARTITION BY purchase_platform ORDER BY aov desc) AS ranking
FROM marketing_sales
QUALIFY ROW_NUMBER() OVER (PARTITION BY purchase_platform ORDER BY aov desc) <= 2
ORDER BY purchase_platform
;

