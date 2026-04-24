{{ config(
    materialized='table'
) }}

WITH deduplicated AS (
    SELECT
        ticker,
        CAST(trade_date AS DATE) AS trade_date,
        open_price,
        high_price,
        low_price,
        close_price,
        volume,
        currency,
        ROW_NUMBER() OVER (PARTITION BY ticker, trade_date ORDER BY api_fetched_at DESC) AS rn
    FROM {{ source('lakehouse_investment_portfolio', 'bronze_stock_prices') }}
),

cleaned AS (
    SELECT
        ticker,
        trade_date,
        CASE WHEN ticker IN ('RR', 'RBW', 'SHEL') THEN open_price / 100.0 ELSE open_price END AS open_price,
        CASE WHEN ticker IN ('RR', 'RBW', 'SHEL') THEN high_price / 100.0 ELSE high_price END AS high_price,
        CASE WHEN ticker IN ('RR', 'RBW', 'SHEL') THEN low_price / 100.0 ELSE low_price END AS low_price,
        CASE WHEN ticker IN ('RR', 'RBW', 'SHEL') THEN close_price / 100.0 ELSE close_price END AS close_price,
        volume
    FROM deduplicated
    WHERE rn = 1
)

SELECT
    ticker,
    trade_date,
    CAST(open_price AS DECIMAL(18,4)) AS open_price,
    CAST(high_price AS DECIMAL(18,4)) AS high_price,
    CAST(low_price AS DECIMAL(18,4)) AS low_price,
    CAST(close_price AS DECIMAL(18,4)) AS close_price,
    volume,
    CAST(
        (close_price - LAG(close_price) OVER (PARTITION BY ticker ORDER BY trade_date))
        / NULLIF(LAG(close_price) OVER (PARTITION BY ticker ORDER BY trade_date), 0) * 100
    AS DECIMAL(18,4)) AS daily_return_pct,
    CAST(1 AS BIT) AS is_valid
FROM cleaned