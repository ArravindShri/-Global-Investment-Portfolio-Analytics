{{ config(
    materialized='table'
) }}

WITH current_prices AS (
    SELECT ticker, close_price, trade_date,
        ROW_NUMBER() OVER (PARTITION BY ticker ORDER BY trade_date DESC) AS rn
    FROM {{ ref('silver_stock_prices') }}
),

earliest_prices AS (
    SELECT ticker, close_price AS earliest_price, trade_date AS earliest_date,
        ROW_NUMBER() OVER (PARTITION BY ticker ORDER BY trade_date ASC) AS rn
    FROM {{ ref('silver_stock_prices') }}
),

year_ago_prices AS (
    SELECT ticker, close_price AS year_ago_price, trade_date AS year_ago_date,
        ROW_NUMBER() OVER (PARTITION BY ticker ORDER BY ABS(DATEDIFF(DAY, trade_date, DATEADD(YEAR, -1, GETDATE())))) AS rn
    FROM {{ ref('silver_stock_prices') }}
    WHERE trade_date <= DATEADD(YEAR, -1, GETDATE())
),

latest_forex AS (
    SELECT currency_pair, close_rate AS end_rate,
        ROW_NUMBER() OVER (PARTITION BY currency_pair ORDER BY trade_date DESC) AS rn
    FROM {{ ref('silver_forex_rates') }}
),

start_forex AS (
    SELECT sfr.currency_pair, sfr.close_rate AS start_rate,
        ROW_NUMBER() OVER (PARTITION BY sfr.currency_pair ORDER BY ABS(DATEDIFF(DAY, sfr.trade_date, DATEADD(YEAR, -1, GETDATE())))) AS rn
    FROM {{ ref('silver_forex_rates') }} sfr
    WHERE sfr.trade_date <= DATEADD(YEAR, -1, GETDATE())
),

stock_returns AS (
    SELECT
        sc.ticker,
        sc.company_name,
        sc.category,
        sc.region,
        sc.currency AS original_currency,
        CAST(
            (cp.close_price - COALESCE(yap.year_ago_price, ep.earliest_price))
            / NULLIF(COALESCE(yap.year_ago_price, ep.earliest_price), 0) * 100
        AS DECIMAL(18,4)) AS return_local_pct,
        COALESCE(sf.start_rate, 1) AS inr_start_rate,
        COALESCE(lf.end_rate, 1) AS inr_end_rate,
        scm.forex_pair
    FROM {{ ref('silver_companies') }} sc
    LEFT JOIN current_prices cp ON sc.ticker = cp.ticker AND cp.rn = 1
    LEFT JOIN year_ago_prices yap ON sc.ticker = yap.ticker AND yap.rn = 1
    LEFT JOIN earliest_prices ep ON sc.ticker = ep.ticker AND ep.rn = 1
    LEFT JOIN {{ ref('silver_currency_map') }} scm ON sc.currency = scm.currency_code
    LEFT JOIN latest_forex lf ON scm.forex_pair = lf.currency_pair AND lf.rn = 1
    LEFT JOIN start_forex sf ON scm.forex_pair = sf.currency_pair AND sf.rn = 1
)

SELECT
    ticker,
    company_name,
    category,
    region,
    original_currency,
    return_local_pct,
    CAST(inr_start_rate AS DECIMAL(18,6)) AS inr_start_rate,
    CAST(inr_end_rate AS DECIMAL(18,6)) AS inr_end_rate,
    CAST(
        CASE WHEN forex_pair IS NULL THEN return_local_pct
        ELSE ((1 + return_local_pct / 100.0) * (inr_end_rate / NULLIF(inr_start_rate, 0)) - 1) * 100
        END
    AS DECIMAL(18,4)) AS return_inr_pct,
    CAST(
        CASE WHEN forex_pair IS NULL THEN 0
        ELSE ((1 + return_local_pct / 100.0) * (inr_end_rate / NULLIF(inr_start_rate, 0)) - 1) * 100 - return_local_pct
        END
    AS DECIMAL(18,4)) AS currency_impact_pct
FROM stock_returns