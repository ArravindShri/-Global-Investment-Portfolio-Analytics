{{ config(
    materialized='table'
) }}

WITH numbers AS (
    SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
),
thousands AS (
    SELECT a.n * 1000 + b.n * 100 + c.n * 10 + d.n AS num
    FROM numbers a
    CROSS JOIN numbers b
    CROSS JOIN numbers c
    CROSS JOIN numbers d
),
date_spine AS (
    SELECT DATEADD(DAY, num, CAST('2023-01-01' AS DATE)) AS date_key
    FROM thousands
    WHERE DATEADD(DAY, num, CAST('2023-01-01' AS DATE)) <= CAST('2026-12-31' AS DATE)
)

SELECT
    date_key,
    DATEPART(WEEKDAY, date_key) AS day_of_week,
    CAST(DATENAME(WEEKDAY, date_key) AS VARCHAR(20)) AS day_name,
    DATEPART(WEEK, date_key) AS week_number,
    MONTH(date_key) AS month_number,
    CAST(DATENAME(MONTH, date_key) AS VARCHAR(20)) AS month_name,
    DATEPART(QUARTER, date_key) AS quarter,
    CAST(CONCAT('Q', DATEPART(QUARTER, date_key)) AS VARCHAR(5)) AS quarter_name,
    YEAR(date_key) AS year,
    CASE WHEN DATEPART(WEEKDAY, date_key) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend,
    CASE WHEN DATEPART(WEEKDAY, date_key) NOT IN (1, 7) THEN 1 ELSE 0 END AS is_trading_day
FROM date_spine