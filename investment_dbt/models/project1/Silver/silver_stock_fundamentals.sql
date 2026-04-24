{{ config(
    materialized='table'
) }}

WITH deduplicated AS (
    SELECT
        ticker,
        CAST(report_date AS DATE) AS report_date,
        market_cap,
        CAST(pe_ratio AS DECIMAL(18,4)) AS pe_ratio,
        CAST(pb_ratio AS DECIMAL(18,4)) AS pb_ratio,
        CAST(dividend_yield AS DECIMAL(18,6)) AS dividend_yield,
        CAST(dividend_per_share AS DECIMAL(18,4)) AS dividend_per_share,
        revenue,
        net_profit,
        CAST(roe AS DECIMAL(18,4)) AS roe,
        CAST(debt_to_equity AS DECIMAL(18,4)) AS debt_to_equity,
        CAST(book_value AS DECIMAL(18,4)) AS book_value,
        shares_outstanding,
        ROW_NUMBER() OVER (PARTITION BY ticker ORDER BY api_fetched_at DESC) AS rn
    FROM {{ source('lakehouse_investment_portfolio', 'bronze_stock_fundamentals') }}
)

SELECT
    ticker,
    report_date,
    market_cap,
    pe_ratio,
    pb_ratio,
    dividend_yield,
    dividend_per_share,
    revenue,
    net_profit,
    roe,
    debt_to_equity,
    book_value,
    shares_outstanding,
    CAST(1 AS BIT) AS is_valid
FROM deduplicated
WHERE rn = 1