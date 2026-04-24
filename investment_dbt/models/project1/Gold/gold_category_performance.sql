{{ config(
    materialized='table'
) }}

WITH ranked AS (
    SELECT
        category,
        ticker,
        company_name,
        yoy_return_pct,
        volatility,
        pe_ratio,
        market_cap,
        dividend_yield,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY yoy_return_pct DESC) AS best_rn,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY yoy_return_pct ASC) AS worst_rn
    FROM {{ ref('gold_stock_performance') }}
)

SELECT
    r.category,
    CAST(AVG(r.yoy_return_pct) AS DECIMAL(18,4)) AS average_yoy_return_pct,
    CAST(AVG(r.volatility) AS DECIMAL(18,4)) AS avg_volatility,
    CAST(MAX(CASE WHEN r.best_rn = 1 THEN r.ticker END) AS VARCHAR(50)) AS best_stock,
    CAST(MAX(CASE WHEN r.worst_rn = 1 THEN r.ticker END) AS VARCHAR(50)) AS worst_stock,
    CAST(AVG(r.pe_ratio) AS DECIMAL(18,4)) AS avg_pe_ratio,
    SUM(r.market_cap) AS total_market_cap,
    CAST(AVG(r.dividend_yield) AS DECIMAL(18,6)) AS avg_dividend_yield
FROM ranked r
GROUP BY r.category