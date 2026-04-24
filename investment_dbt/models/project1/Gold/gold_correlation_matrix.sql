{{ config(
    materialized='table'
) }}

WITH daily_returns AS (
    SELECT
        ssp.ticker,
        ssp.trade_date,
        ssp.daily_return_pct
    FROM {{ ref('silver_stock_prices') }} ssp
    WHERE ssp.daily_return_pct IS NOT NULL
),

paired AS (
    SELECT
        s1.ticker AS stock_1,
        s2.ticker AS stock_2,
        s1.daily_return_pct AS r1,
        s2.daily_return_pct AS r2
    FROM daily_returns s1
    INNER JOIN daily_returns s2
        ON s1.trade_date = s2.trade_date
        AND s1.ticker < s2.ticker
),

correlations AS (
    SELECT
        stock_1,
        stock_2,
        CAST(
            (COUNT(*) * SUM(r1 * r2) - SUM(r1) * SUM(r2))
            / NULLIF(SQRT(
                (COUNT(*) * SUM(r1 * r1) - SUM(r1) * SUM(r1)) *
                (COUNT(*) * SUM(r2 * r2) - SUM(r2) * SUM(r2))
            ), 0)
        AS DECIMAL(18,4)) AS correlation_coefficient
    FROM paired
    GROUP BY stock_1, stock_2
)

SELECT
    c.stock_1,
    c.stock_2,
    sc1.category AS stock_1_category,
    sc2.category AS stock_2_category,
    sc1.region AS stock_1_region,
    sc2.region AS stock_2_region,
    c.correlation_coefficient,
    CAST(
        CASE
            WHEN c.correlation_coefficient >= 0.7 THEN 'Strong Positive'
            WHEN c.correlation_coefficient >= 0.3 THEN 'Weak Positive'
            WHEN c.correlation_coefficient >= -0.3 THEN 'Uncorrelated'
            ELSE 'Negative'
        END
    AS VARCHAR(50)) AS relationship
FROM correlations c
LEFT JOIN {{ ref('silver_companies') }} sc1 ON c.stock_1 = sc1.ticker
LEFT JOIN {{ ref('silver_companies') }} sc2 ON c.stock_2 = sc2.ticker