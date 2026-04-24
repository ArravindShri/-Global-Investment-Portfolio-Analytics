{{ config(
    materialized='table'
) }}

WITH region_stats AS (
    SELECT
        gsp.region,
        CAST(AVG(gsp.yoy_return_pct) AS DECIMAL(18,4)) AS avg_yoy_return_pct,
        CAST(AVG(gsp.volatility) AS DECIMAL(18,4)) AS avg_volatility,
        CAST(AVG(gsp.sharpe_ratio) AS DECIMAL(18,4)) AS avg_sharpe_ratio,
        COUNT(*) AS stock_count
    FROM {{ ref('gold_stock_performance') }} gsp
    GROUP BY gsp.region
),

best_cat AS (
    SELECT
        gsp.region,
        gsp.category,
        AVG(gsp.yoy_return_pct) AS cat_return,
        ROW_NUMBER() OVER (PARTITION BY gsp.region ORDER BY AVG(gsp.yoy_return_pct) DESC) AS rn
    FROM {{ ref('gold_stock_performance') }} gsp
    GROUP BY gsp.region, gsp.category
),

currency_impact AS (
    SELECT
        region,
        CAST(AVG(currency_impact_pct) AS DECIMAL(18,4)) AS avg_currency_impact_pct
    FROM {{ ref('gold_currency_adjusted_returns') }}
    GROUP BY region
)

SELECT
    rs.region,
    rs.avg_yoy_return_pct,
    rs.avg_volatility,
    rs.avg_sharpe_ratio,
    rs.stock_count,
    CAST(bc.category AS VARCHAR(50)) AS best_category,
    COALESCE(ci.avg_currency_impact_pct, 0) AS avg_currency_impact_pct
FROM region_stats rs
LEFT JOIN best_cat bc ON rs.region = bc.region AND bc.rn = 1
LEFT JOIN currency_impact ci ON rs.region = ci.region