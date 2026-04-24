{{ config(
    materialized='table'
) }}

WITH base AS (
    SELECT
        ssp.ticker,
        ssp.trade_date,
        ssp.close_price,
        ssp.daily_return_pct AS daily_return_local_pct,
        scm.forex_pair,
        COALESCE(sfr.close_rate, 1) AS forex_rate
    FROM {{ ref('silver_stock_prices') }} ssp
    INNER JOIN {{ ref('silver_companies') }} sc ON ssp.ticker = sc.ticker
    INNER JOIN {{ ref('silver_currency_map') }} scm ON sc.currency = scm.currency_code
    LEFT JOIN {{ ref('silver_forex_rates') }} sfr
        ON scm.forex_pair = sfr.currency_pair
        AND ssp.trade_date = sfr.trade_date
)

SELECT
    ticker,
    trade_date,
    CAST(close_price AS DECIMAL(10,2)) AS close_price,
    CAST(close_price * forex_rate AS DECIMAL(10,2)) AS close_price_inr,
    CAST(daily_return_local_pct AS DECIMAL(10,2)) AS daily_return_local_pct,
    CAST(
        (close_price * forex_rate - LAG(close_price * forex_rate) OVER (PARTITION BY ticker ORDER BY trade_date))
        / NULLIF(LAG(close_price * forex_rate) OVER (PARTITION BY ticker ORDER BY trade_date), 0) * 100
    AS DECIMAL(10,2)) AS daily_return_inr_pct,
    CAST(forex_rate AS DECIMAL(10,2)) AS forex_rate,
    CAST(forex_pair AS VARCHAR(50)) AS currency_pair
FROM base