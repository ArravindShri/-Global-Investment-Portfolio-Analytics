{{ config(
    materialized='table'
) }}

WITH deduplicated AS (
    SELECT
        currency_pair,
        CAST(trade_date AS DATE) AS trade_date,
        CAST(close_rate AS DECIMAL(18,6)) AS close_rate,
        ROW_NUMBER() OVER (PARTITION BY currency_pair, trade_date ORDER BY api_fetched_at DESC) AS rn
    FROM {{ source('lakehouse_investment_portfolio', 'bronze_forex_rates') }}
)

SELECT
    currency_pair,
    trade_date,
    close_rate,
    CAST(
        (close_rate - LAG(close_rate) OVER (PARTITION BY currency_pair ORDER BY trade_date))
        / NULLIF(LAG(close_rate) OVER (PARTITION BY currency_pair ORDER BY trade_date), 0) * 100
    AS DECIMAL(18,6)) AS daily_change_pct,
    CAST(1 AS BIT) AS is_valid
FROM deduplicated
WHERE rn = 1