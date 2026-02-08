/* 
Project: Market Trend and KPI Reporting
Purpose: Analytical SQL queries to evaluate sales trends and key performance indicators (KPIs).
Database: SH 
Description: This script analyzes sales performance over time, identifies trends,
and computes key metrics used in business reporting.
*/



/* 

-- Task 1: Top Customers by Channel and Sales Percentage
-- Ranks customers within each channel and calculates their sales share.


ROW_NUMBER() OVER (PARTITION BY channel_desc ORDER BY SUM(amount_sold) DESC)
is used to rank customers independently within each sales channel.
We need sales_percentage = customer_sales / total_channel_sales.
The cleanest way is a window SUM over the same partition:
SUM(customer_sales) OVER (PARTITION BY channel_desc) (implemented as SUM(SUM(amount_sold)) OVER (...) after the GROUP BY).
I use a CTE because window function results cannot be filtered in the same SELECT’s WHERE clause;
it is ranked inside the CTE, then filtered rn <= 5 outside.
*/


WITH customer_channel_sales AS (
    --Aggregated amount_sold per customer within each channel first
    SELECT
        ch.channel_desc,
        c.cust_id,
        c.cust_last_name,
        c.cust_first_name,
        SUM(s.amount_sold) AS customer_sales
    FROM sh.sales s
    INNER JOIN sh.customers c ON c.cust_id = s.cust_id
    INNER JOIN sh.channels ch ON ch.channel_id = s.channel_id
    GROUP BY 
        ch.channel_desc, 
        c.cust_id, 
        c.cust_last_name, 
        c.cust_first_name
),
ranked_customers AS (
    -- Used window functions for total channel sales and ranking
    SELECT
        channel_desc,
        cust_last_name,
        cust_first_name,
        customer_sales,
        --total sales per channel for percentage calculation
        SUM(customer_sales) OVER (
            PARTITION BY channel_desc
        ) AS channel_total_sales,
        -- Ranking customers inside each channel by their total aggregated sales
        ROW_NUMBER() OVER (
            PARTITION BY channel_desc 
            ORDER BY customer_sales DESC
        ) AS rn
    FROM customer_channel_sales
)
--Final selection, KPI formatting, and filtering for top 5
SELECT
    channel_desc,
    cust_last_name,
    cust_first_name,
    -- Displaying total sales
    ROUND(customer_sales, 2) AS amount_sold,
    ROUND((customer_sales / channel_total_sales) * 100, 2)::text || '%' AS sales_percentage
FROM ranked_customers
WHERE rn <= 5
ORDER BY 
    channel_desc ASC, 
    customer_sales DESC;


/*

-- Task 2: Monthly Sales Pivot and Yearly KPI Calculation
-- Uses crosstab to pivot monthly sales and computes yearly totals.


- crosstab() is used to pivot month-by-month sales into columns (Jan..Dec) per product.
- Filtering is applied in the source query to ensure correctness.
- YEAR_SUM is calculated as the sum of the 12 monthly columns, then displayed with two decimal places.
*/

WITH pivoted AS (
  SELECT *
  FROM crosstab(
    $$
      SELECT
          UPPER(p.prod_name)                AS row_name,
          t.calendar_month_number           AS category,
          SUM(s.amount_sold)::numeric       AS value
      FROM sh.sales s
      INNER JOIN sh.products p   ON p.prod_id  = s.prod_id
      INNER JOIN sh.times t      ON t.time_id  = s.time_id
      INNER JOIN sh.customers cu ON cu.cust_id = s.cust_id
      INNER JOIN sh.countries co ON co.country_id = cu.country_id
      WHERE p.prod_category = 'Photo'
        AND co.country_region = 'Asia'
        AND t.calendar_year = 2000
      GROUP BY p.prod_name, t.calendar_month_number
      ORDER BY p.prod_name, t.calendar_month_number
    $$,
    $$
      SELECT gs
      FROM generate_series(1,12) AS gs
    $$
  ) AS ct (
      prod_name text,
      m01 numeric, m02 numeric, m03 numeric, m04 numeric, m05 numeric, m06 numeric,
      m07 numeric, m08 numeric, m09 numeric, m10 numeric, m11 numeric, m12 numeric
  )
)
SELECT
  prod_name,

  -- Display each month with two decimals
  ROUND(COALESCE(m01,0),2) AS m01,
  ROUND(COALESCE(m02,0),2) AS m02,
  ROUND(COALESCE(m03,0),2) AS m03,
  ROUND(COALESCE(m04,0),2) AS m04,
  ROUND(COALESCE(m05,0),2) AS m05,
  ROUND(COALESCE(m06,0),2) AS m06,
  ROUND(COALESCE(m07,0),2) AS m07,
  ROUND(COALESCE(m08,0),2) AS m08,
  ROUND(COALESCE(m09,0),2) AS m09,
  ROUND(COALESCE(m10,0),2) AS m10,
  ROUND(COALESCE(m11,0),2) AS m11,
  ROUND(COALESCE(m12,0),2) AS m12,

  -- YEAR_SUM = overall total for the report row 
  ROUND(
    COALESCE(m01,0)+COALESCE(m02,0)+COALESCE(m03,0)+COALESCE(m04,0)+COALESCE(m05,0)+COALESCE(m06,0)+
    COALESCE(m07,0)+COALESCE(m08,0)+COALESCE(m09,0)+COALESCE(m10,0)+COALESCE(m11,0)+COALESCE(m12,0)
  , 2) AS year_sum

FROM pivoted
ORDER BY year_sum DESC;

SELECT * 
FROM pg_extension
WHERE extname = 'tablefunc';

/*
-- Task 3: Identifying Customers Consistently in Top 300
-- Uses DENSE_RANK and window functions to find customers
-- who ranked in the top 300 across multiple years.


- I have replaced ROW_NUMBER() with DENSE_RANK() to handle tie-breaks 
  appropriately and included NULLS LAST in ordering.
- The task requires customers to be in the top 300 in EACH of the 
  three years (1998, 1999, 2001).
- Used a window function COUNT() to identify customers appearing 
  in the top 300 three times across the specified period.
*/

WITH customer_yearly_ranking AS (
    --Calculated total sales and rank per year/channel
    SELECT
        t.calendar_year,
        ch.channel_desc,
        c.cust_id,
        c.cust_last_name,
        c.cust_first_name,
        SUM(s.amount_sold) AS total_sales,
        -- Used DENSE_RANK as suggested on the feedback
        DENSE_RANK() OVER (
            PARTITION BY t.calendar_year, ch.channel_desc 
            ORDER BY SUM(s.amount_sold) DESC NULLS LAST
        ) AS rn
    FROM sh.sales s
    INNER JOIN sh.times t      ON t.time_id = s.time_id
    INNER JOIN sh.customers c  ON c.cust_id = s.cust_id
    INNER JOIN sh.channels ch ON ch.channel_id = s.channel_id
    WHERE t.calendar_year IN (1998, 1999, 2001)
    GROUP BY t.calendar_year, ch.channel_desc, c.cust_id, c.cust_last_name, c.cust_first_name
),
common_top_customers AS (
    --Filter top 300 and count how many of the 3 years they qualify
    SELECT 
        *,
        -- Count occurrences of each customer
        COUNT(*) OVER (PARTITION BY cust_id, channel_desc) as years_in_top
    FROM customer_yearly_ranking
    WHERE rn <= 300
)
--Return only those who were in the top 300 for all three years
SELECT
    calendar_year,
    channel_desc,
    cust_last_name,
    cust_first_name,
    ROUND(total_sales, 2) AS total_sales
FROM common_top_customers
WHERE years_in_top = 3
ORDER BY 
    calendar_year ASC, 
    channel_desc ASC, 
    total_sales DESC;


/*

-- Task 4: Regional Sales Analysis Using Window Functions
-- Calculates category-level sales by region and month.


- Incorporated a window function (SUM OVER) to calculate 
  regional sales per category, meeting the module requirements.
- The query now separates sales for 'Europe' and 'Americas' 
  instead of aggregating them together.
- I removed redundant groupings and used DISTINCT with a window function.
*/

SELECT DISTINCT
    t.calendar_year,
    t.calendar_month_number,
    t.calendar_month_name,
    co.country_region,
    p.prod_category,
    ROUND(SUM(s.amount_sold) OVER (
        PARTITION BY 
            t.calendar_month_number, 
            co.country_region, 
            p.prod_category
    ), 2) AS total_sales_by_region
FROM sh.sales s
INNER JOIN sh.times t      ON t.time_id = s.time_id
INNER JOIN sh.products p   ON p.prod_id = s.prod_id
INNER JOIN sh.customers cu ON cu.cust_id = s.cust_id
INNER JOIN sh.countries co ON co.country_id = cu.country_id
WHERE t.calendar_year = 2000
  AND t.calendar_month_number IN (1, 2, 3)
  AND co.country_region IN ('Europe', 'Americas')
ORDER BY 
    t.calendar_month_number, 
    co.country_region, 
    p.prod_category;


