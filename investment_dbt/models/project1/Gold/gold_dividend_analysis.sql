{{ config(
    materialized='table'
) }}

WITH latest_forex AS (
    SELECT currency_pair, close_rate,
        ROW_NUMBER() OVER (PARTITION BY currency_pair ORDER BY trade_date DESC) AS rn
    FROM {{ ref('silver_forex_rates') }}
),

current_prices AS (
    SELECT ticker, close_price,
        ROW_NUMBER() OVER (PARTITION BY ticker ORDER BY trade_date DESC) AS rn
    FROM {{ ref('silver_stock_prices') }}
)

SELECT
    sc.ticker,
    sc.company_name,
    sc.category,
    sc.region,
    CAST(cp.close_price AS DECIMAL(18,4)) AS stock_price,
    CAST(sf.dividend_per_share AS DECIMAL(18,4)) AS annual_dividend,
    CAST(sf.dividend_yield AS DECIMAL(18,6)) AS dividend_yield_pct,
    CAST(
        CASE WHEN sf.net_profit IS NOT NULL AND sf.shares_outstanding IS NOT NULL AND sf.shares_outstanding > 0
        THEN sf.dividend_per_share / NULLIF(CAST(sf.net_profit AS DECIMAL(18,4)) / sf.shares_outstanding, 0)
        ELSE NULL END
    AS DECIMAL(18,4)) AS payout_ratio,
    CAST(
        COALESCE(sf.dividend_per_share, 0) * COALESCE(lf.close_rate, 1)
    AS DECIMAL(18,4)) AS dividend_in_inr,
    CASE WHEN sf.dividend_yield IS NOT NULL AND sf.dividend_yield > 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS pays_dividend
FROM {{ ref('silver_companies') }} sc
LEFT JOIN current_prices cp ON sc.ticker = cp.ticker AND cp.rn = 1
LEFT JOIN {{ ref('silver_stock_fundamentals') }} sf ON sc.ticker = sf.ticker
LEFT JOIN {{ ref('silver_currency_map') }} scm ON sc.currency = scm.currency_code
LEFT JOIN latest_forex lf ON scm.forex_pair = lf.currency_pair AND lf.rn = 1