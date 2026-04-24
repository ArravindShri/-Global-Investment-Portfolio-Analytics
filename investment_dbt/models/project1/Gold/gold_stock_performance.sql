{{ config(
    materialized='table'
) }}

WITH current_prices AS (
    SELECT
        ticker,
        close_price,
        trade_date,
        ROW_NUMBER() OVER (PARTITION BY ticker ORDER BY trade_date DESC) AS rn
    FROM {{ ref('silver_stock_prices') }}
),

year_ago_prices AS (
    SELECT
        ticker,
        close_price AS year_ago_price,
        ROW_NUMBER() OVER (PARTITION BY ticker ORDER BY ABS(DATEDIFF(DAY, trade_date, DATEADD(YEAR, -1, GETDATE())))) AS rn
    FROM {{ ref('silver_stock_prices') }}
    WHERE trade_date <= DATEADD(YEAR, -1, GETDATE())
),

earliest_prices AS (
    SELECT
        ticker,
        close_price AS earliest_price,
        ROW_NUMBER() OVER (PARTITION BY ticker ORDER BY trade_date ASC) AS rn
    FROM {{ ref('silver_stock_prices') }}
),

week_52 AS (
    SELECT
        ticker,
        MAX(high_price) AS week_52_high,
        MIN(low_price) AS week_52_low
    FROM {{ ref('silver_stock_prices') }}
    WHERE trade_date >= DATEADD(DAY, -365, GETDATE())
    GROUP BY ticker
),

volatility AS (
    SELECT
        ticker,
        CAST(STDEV(daily_return_pct) AS DECIMAL(18,4)) AS volatility
    FROM {{ ref('silver_stock_prices') }}
    WHERE trade_date >= DATEADD(DAY, -365, GETDATE())
      AND daily_return_pct IS NOT NULL
    GROUP BY ticker
),

stock_factors AS (
    SELECT
        sf.ticker,
        sf.pe_ratio,
        sf.market_cap,
        sf.roe,
        sf.debt_to_equity,
        sf.dividend_yield
    FROM {{ ref('silver_stock_fundamentals') }} sf
)

SELECT
    sc.ticker,
    sc.company_name,
    sc.category,
    sc.region,
    sc.currency,
    CAST(cp.close_price AS DECIMAL(18,4)) AS current_price,
    CAST(
        (cp.close_price - COALESCE(yap.year_ago_price, ep.earliest_price))
        / NULLIF(COALESCE(yap.year_ago_price, ep.earliest_price), 0) * 100
    AS DECIMAL(18,4)) AS yoy_return_pct,
    CAST(w52.week_52_high AS DECIMAL(18,4)) AS week_52_high,
    CAST(w52.week_52_low AS DECIMAL(18,4)) AS week_52_low,
    v.volatility,
    CAST(
        CASE WHEN v.volatility = 0 OR v.volatility IS NULL THEN NULL
        ELSE (cp.close_price - COALESCE(yap.year_ago_price, ep.earliest_price))
             / NULLIF(COALESCE(yap.year_ago_price, ep.earliest_price), 0) * 100
             / v.volatility
        END
    AS DECIMAL(18,4)) AS sharpe_ratio,
    sf.pe_ratio,
    sf.market_cap,
    sf.roe,
    sf.debt_to_equity,
    sf.dividend_yield
FROM {{ ref('silver_companies') }} sc
LEFT JOIN current_prices cp ON sc.ticker = cp.ticker AND cp.rn = 1
LEFT JOIN year_ago_prices yap ON sc.ticker = yap.ticker AND yap.rn = 1
LEFT JOIN earliest_prices ep ON sc.ticker = ep.ticker AND ep.rn = 1
LEFT JOIN week_52 w52 ON sc.ticker = w52.ticker
LEFT JOIN volatility v ON sc.ticker = v.ticker
LEFT JOIN stock_factors sf ON sc.ticker = sf.ticker