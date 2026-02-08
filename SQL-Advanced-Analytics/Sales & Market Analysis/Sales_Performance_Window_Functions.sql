/* Project: Sales Performance - Window Functions
   Purpose: Analytical queries using window functions (ranking, running totals, comparisons).
   DB: sh 
*/



            /*Task 1: Channel Sales Ratios and Year-over-Year Comparison
            Calculates sales distribution by channel within each region
            and compares percentages with the previous year using LAG*/
WITH SalesData AS (
    -- raw sales data by region, year, and channel
    SELECT 
        r.country_region,
        t.calendar_year,
        c.channel_desc,
        SUM(s.amount_sold) AS amount_sold
    FROM sh.sales s
    INNER JOIN sh.times     t    ON s.time_id    = t.time_id
    INNER JOIN sh.customers cust ON s.cust_id    = cust.cust_id
    INNER JOIN sh.countries r    ON cust.country_id = r.country_id
    INNER JOIN sh.channels  c    ON s.channel_id = c.channel_id
    GROUP BY r.country_region, t.calendar_year, c.channel_desc
),
CalculatedRatios AS (
    -- percentage of sales for each channel within its region and year
    SELECT 
        country_region,
        calendar_year,
        channel_desc,
        amount_sold,
        ROUND(
            100.0 * amount_sold
            / SUM(amount_sold) OVER (PARTITION BY country_region, calendar_year)
        , 2) AS by_channels
    FROM SalesData
),
Filtered AS (
    --filter BEFORE lag to make 1999 previous period = N/A
    SELECT *
    FROM CalculatedRatios
    WHERE calendar_year BETWEEN 1999 AND 2001
)
SELECT
    country_region,
    calendar_year,
    channel_desc,
    ROUND(amount_sold, 2) AS amount_sold,
    (ROUND(by_channels, 2))::text || '%' AS "% BY CHANNELS",
    CASE
        WHEN LAG(by_channels) OVER (PARTITION BY country_region, channel_desc ORDER BY calendar_year) IS NULL
            THEN 'N/A'
        ELSE (ROUND(LAG(by_channels) OVER (PARTITION BY country_region, channel_desc ORDER BY calendar_year), 2))::text || '%'
    END AS "% PREVIOUS PERIOD",
    CASE
        WHEN LAG(by_channels) OVER (PARTITION BY country_region, channel_desc ORDER BY calendar_year) IS NULL
            THEN 'N/A'
        ELSE (ROUND(
            by_channels - LAG(by_channels) OVER (PARTITION BY country_region, channel_desc ORDER BY calendar_year)
        , 2))::text || '%'
    END AS "% DIFF"
FROM Filtered
ORDER BY country_region, channel_desc, calendar_year;


/*Task 2: Weekly Sales Analysis with Running Totals and Centered Moving Average
Computes cumulative weekly sales and a centered 3-day moving average
to observe short-term sales trends.*/
WITH DailySales AS (
    SELECT
        t.calendar_year,
        t.calendar_week_number,
        t.time_id::date AS sales_date,
        EXTRACT(ISODOW FROM t.time_id)::int AS iso_dow,  -- Mon=1 ... Sun=7
        TRIM(TO_CHAR(t.time_id, 'Day')) AS day_name,
        SUM(s.amount_sold) AS sales
    FROM sh.sales s
    INNER JOIN sh.times t ON s.time_id = t.time_id
    GROUP BY
        t.calendar_year,
        t.calendar_week_number,
        t.time_id::date,
        EXTRACT(ISODOW FROM t.time_id),
        TO_CHAR(t.time_id, 'Day')
),
WithWindows AS (
    SELECT
        calendar_year,
        calendar_week_number,
        sales_date,
        day_name,
        ROUND(sales, 2) AS sales,
        ROUND(
            SUM(sales) OVER (
                PARTITION BY calendar_year, calendar_week_number
                ORDER BY sales_date
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            )
        , 2) AS cum_sum,
        ROUND(
            CASE
                WHEN iso_dow = 1 THEN  -- Monday: Sat+Sun+Mon+Tue
                    AVG(sales) OVER (ORDER BY sales_date ROWS BETWEEN 2 PRECEDING AND 1 FOLLOWING)
                WHEN iso_dow = 5 THEN  -- Friday: Thu+Fri+Sat+Sun
                    AVG(sales) OVER (ORDER BY sales_date ROWS BETWEEN 1 PRECEDING AND 2 FOLLOWING)
                ELSE
                    AVG(sales) OVER (ORDER BY sales_date ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING)
            END
        , 2) AS centered_avg
    FROM DailySales
    WHERE calendar_year = 1999 
)
SELECT
    calendar_week_number,
    sales_date AS time_id,
    day_name,
    sales,
    cum_sum,
    centered_avg AS centered_3_day_avg
FROM WithWindows
WHERE calendar_week_number BETWEEN 49 AND 51
ORDER BY sales_date;

/*Task 3: Window Frame Modes Comparison (ROWS, RANGE, GROUPS)
Demonstrates how different window frame definitions affect
moving averages and cumulative calculations.*/

--3.1 ROWS Mode
--calculating 3-day centered moving average of sales
SELECT 
    channel_id,
    time_id,
    ROUND(amount_sold, 2) AS amount_sold,
    ROUND(
        AVG(amount_sold) OVER (
            PARTITION BY channel_id
            ORDER BY time_id
            ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
        )
    , 2) AS centered_3day_avg
FROM sh.sales;

--Reason for choosing ROWS: Iused this mode because we want a strict physical count of rows.
---It includes exactly one row physically before and one row physically after the current row,
---regardless of whether the dates are identical or if there are gaps in the timeline.

--3.2 RANGE Mode
--Calculating a Running Total where rows with the same date are treated as a single unit.
SELECT 
    prod_id,
    channel_id,
    time_id,
    ROUND(amount_sold, 2) AS amount_sold,
    ROUND(
        SUM(amount_sold) OVER (
            PARTITION BY prod_id, channel_id
            ORDER BY time_id
            RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )
    , 2) AS cumulative_sales
FROM sh.sales;

--Reason for choosing RANGE:In window functions, RANGE is the default when ORDER BY is present. It is ideal for peer logic.
--If multiple sales occurred on the same time_id, RANGE ensures that the CURRENT ROW boundary includes all those peers in the sum simultaneously.

--3.3 GROUPS Mode
--Calculating the average sales of the previous, current, and next sets of dates, regardless of how many sales records exist for each date.
SELECT 
    channel_id,
    time_id,
    ROUND(amount_sold, 2) AS amount_sold,
    ROUND(
        AVG(amount_sold) OVER (
            PARTITION BY channel_id
            ORDER BY time_id
            GROUPS BETWEEN 1 PRECEDING AND 1 FOLLOWING
        )
    , 2) AS grouped_date_avg
FROM sh.sales;

--Reason for choosing GROUPS: I used the GROUPS mode because it allows the window frame to navigate through the data in steps of distinct value blocks.
--It treats all rows sharing the same sort value as a single group, so an offset like 1 PRECEDING includes the entire preceding block of rows regardless of how many individual records it contains.
--I think it is the most suitable way to calculate across distinct sets of values (like comparing the current day's total against the previous day's total) while keeping each logical group intact.
