-- =============================================
-- Global Investment Portfolio Analytics
-- 03_stored_procedures.sql
-- Creates sp_refresh_silver, sp_refresh_gold, sp_daily_refresh
-- Run AFTER 01_create_tables.sql and 02_reference_data.sql
-- =============================================

USE Global_Portfolio_Analysis
GO

-- =============================================
-- sp_refresh_silver
-- Transforms Bronze → Silver (3 steps)
-- =============================================

CREATE PROCEDURE sp_refresh_silver
AS
BEGIN
    BEGIN TRY

        -- Step 1: silver_stock_prices
        TRUNCATE TABLE silver_stock_prices

        ;WITH deduped AS (
            SELECT ticker, trade_date, open_price, high_price, low_price, close_price,
                volume, currency,
                ROW_NUMBER() OVER (PARTITION BY ticker, trade_date ORDER BY api_fetched_at DESC) AS rn
            FROM bronze_stock_prices
        )
        INSERT INTO silver_stock_prices (ticker, trade_date, open_price, high_price, low_price, close_price, volume, daily_return_pct, is_valid)
        SELECT 
            ticker, trade_date,
            CASE WHEN currency = 'GBp' THEN open_price / 100.0 ELSE open_price END,
            CASE WHEN currency = 'GBp' THEN high_price / 100.0 ELSE high_price END,
            CASE WHEN currency = 'GBp' THEN low_price / 100.0 ELSE low_price END,
            CASE WHEN currency = 'GBp' THEN close_price / 100.0 ELSE close_price END,
            volume,
            (CASE WHEN currency = 'GBp' THEN close_price / 100.0 ELSE close_price END - 
             LAG(CASE WHEN currency = 'GBp' THEN close_price / 100.0 ELSE close_price END) 
             OVER (PARTITION BY ticker ORDER BY trade_date)) /
            NULLIF(LAG(CASE WHEN currency = 'GBp' THEN close_price / 100.0 ELSE close_price END) 
             OVER (PARTITION BY ticker ORDER BY trade_date), 0) * 100,
            1
        FROM deduped
        WHERE rn = 1

        PRINT 'silver_stock_prices refreshed.'

        -- Step 2: silver_stock_fundamentals
        TRUNCATE TABLE silver_stock_fundamentals

        ;WITH deduped AS (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY ticker ORDER BY api_fetched_at DESC) AS rn
            FROM bronze_stock_fundamentals
        )
        INSERT INTO silver_stock_fundamentals (ticker, report_date, market_cap, pe_ratio, pb_ratio, dividend_yield, dividend_per_share, revenue, net_profit, roe, debt_to_equity, book_value, shares_outstanding, is_valid)
        SELECT ticker, report_date, market_cap, pe_ratio, pb_ratio, dividend_yield, dividend_per_share, revenue, net_profit, roe, debt_to_equity, book_value, shares_outstanding, 1
        FROM deduped
        WHERE rn = 1

        PRINT 'silver_stock_fundamentals refreshed.'

        -- Step 3: silver_forex_rates
        TRUNCATE TABLE silver_forex_rates

        ;WITH deduped AS (
            SELECT currency_pair, trade_date, close_rate,
                ROW_NUMBER() OVER (PARTITION BY currency_pair, trade_date ORDER BY api_fetched_at DESC) AS rn
            FROM bronze_forex_rates
        )
        INSERT INTO silver_forex_rates (currency_pair, trade_date, close_rate, daily_change_pct, is_valid)
        SELECT 
            currency_pair, trade_date, close_rate,
            (close_rate - LAG(close_rate) OVER (PARTITION BY currency_pair ORDER BY trade_date)) /
            NULLIF(LAG(close_rate) OVER (PARTITION BY currency_pair ORDER BY trade_date), 0) * 100,
            1
        FROM deduped
        WHERE rn = 1

        PRINT 'silver_forex_rates refreshed.'
        PRINT 'Silver layer refresh complete.'

    END TRY
    BEGIN CATCH
        PRINT 'Error refreshing Silver layer: ' + ERROR_MESSAGE()
    END CATCH
END
GO

-- =============================================
-- sp_refresh_gold
-- Transforms Silver → Gold (7 steps)
-- =============================================

CREATE PROCEDURE sp_refresh_gold
AS
BEGIN
    BEGIN TRY

        -- Step 1: gold_stock_performance
        TRUNCATE TABLE gold_stock_performance

        ;WITH stock_factors AS (
            SELECT ticker, MAX(high_price) AS week_52_high, MIN(low_price) AS week_52_low,
                STDEV(daily_return_pct) AS volatility
            FROM silver_stock_prices
            WHERE trade_date >= DATEADD(YEAR, -1, GETDATE())
            GROUP BY ticker
        ),
        current_prices AS (
            SELECT ticker, close_price AS current_price,
                ROW_NUMBER() OVER(PARTITION BY ticker ORDER BY trade_date DESC) AS rn
            FROM silver_stock_prices
        ),
        year_ago_prices AS (
            SELECT ticker, close_price AS year_ago_price,
                ROW_NUMBER() OVER(PARTITION BY ticker ORDER BY trade_date DESC) AS rn
            FROM silver_stock_prices
            WHERE trade_date <= DATEADD(YEAR, -1, GETDATE())
        ),
        earliest_prices AS (
            SELECT ticker, close_price AS earliest_price,
                ROW_NUMBER() OVER(PARTITION BY ticker ORDER BY trade_date ASC) AS rn
            FROM silver_stock_prices
        )
        INSERT INTO gold_stock_performance (ticker, company_name, category, region, currency, current_price, yoy_return_pct, week_52_high, week_52_low, volatility, sharpe_ratio, pe_ratio, market_cap, roe, debt_to_equity, dividend_yield)
        SELECT sf.ticker, sc.company_name, sc.category, sc.region, sc.currency, cp.current_price,
            (cp.current_price - COALESCE(yap.year_ago_price, ep.earliest_price)) / COALESCE(yap.year_ago_price, ep.earliest_price) * 100,
            sf.week_52_high, sf.week_52_low, sf.volatility,
            ((cp.current_price - COALESCE(yap.year_ago_price, ep.earliest_price)) / COALESCE(yap.year_ago_price, ep.earliest_price) * 100) / sf.volatility,
            ssf.pe_ratio, ssf.market_cap, ssf.roe, ssf.debt_to_equity, ssf.dividend_yield
        FROM silver_companies sc
        JOIN stock_factors sf ON sc.ticker = sf.ticker
        JOIN current_prices cp ON cp.ticker = sc.ticker
        LEFT JOIN year_ago_prices yap ON yap.ticker = sc.ticker AND yap.rn = 1
        JOIN earliest_prices ep ON ep.ticker = sc.ticker AND ep.rn = 1
        JOIN silver_stock_fundamentals ssf ON ssf.ticker = sc.ticker
        WHERE cp.rn = 1

        PRINT 'gold_stock_performance refreshed.'

        -- Step 2: gold_currency_adjusted_returns
        TRUNCATE TABLE gold_currency_adjusted_returns

        ;WITH current_forex_rate AS (
            SELECT currency_pair, close_rate,
                ROW_NUMBER() OVER(PARTITION BY currency_pair ORDER BY trade_date DESC) AS rn
            FROM silver_forex_rates
        ),
        year_ago_forex AS (
            SELECT currency_pair, close_rate,
                ROW_NUMBER() OVER(PARTITION BY currency_pair ORDER BY trade_date DESC) AS rn
            FROM silver_forex_rates
            WHERE trade_date <= DATEADD(YEAR, -1, GETDATE())
        )
        INSERT INTO gold_currency_adjusted_returns (ticker, company_name, category, region, original_currency, return_local_pct, inr_start_rate, inr_end_rate, return_inr_pct, currency_impact_pct)
        SELECT sc.ticker, sc.company_name, sc.category, sc.region, sc.currency, gsp.yoy_return_pct,
            CASE WHEN sc.currency = 'INR' THEN 1 ELSE yap.close_rate END,
            CASE WHEN sc.currency = 'INR' THEN 1 ELSE cfx.close_rate END,
            CASE WHEN sc.currency = 'INR' THEN gsp.yoy_return_pct ELSE ((1 + gsp.yoy_return_pct/100) * (cfx.close_rate/yap.close_rate) - 1) * 100 END,
            CASE WHEN sc.currency = 'INR' THEN 0 ELSE ((1 + gsp.yoy_return_pct/100) * (cfx.close_rate/yap.close_rate) - 1) * 100 - gsp.yoy_return_pct END
        FROM silver_companies sc
        LEFT JOIN silver_currency_map scm ON sc.currency = scm.currency_code
        LEFT JOIN current_forex_rate cfx ON scm.forex_pair = cfx.currency_pair
        LEFT JOIN year_ago_forex yap ON scm.forex_pair = yap.currency_pair
        JOIN gold_stock_performance gsp ON sc.ticker = gsp.ticker
        WHERE (cfx.rn = 1 OR cfx.rn IS NULL) AND (yap.rn = 1 OR yap.rn IS NULL)

        PRINT 'gold_currency_adjusted_returns refreshed.'

        -- Step 3: gold_category_performance
        TRUNCATE TABLE gold_category_performance

        ;WITH best_performance AS (
            SELECT ticker, category,
                ROW_NUMBER() OVER(PARTITION BY category ORDER BY yoy_return_pct DESC) AS rn
            FROM gold_stock_performance
        ),
        worst_performance AS (
            SELECT ticker, category,
                ROW_NUMBER() OVER(PARTITION BY category ORDER BY yoy_return_pct ASC) AS rn
            FROM gold_stock_performance
        )
        INSERT INTO gold_category_performance (category, average_yoy_return_pct, avg_volatility, best_stock, worst_stock, avg_pe_ratio, total_market_cap, avg_dividend_yield)
        SELECT gsp.category, AVG(gsp.yoy_return_pct), AVG(gsp.volatility),
            bp.ticker, wp.ticker, AVG(gsp.pe_ratio), SUM(gsp.market_cap), AVG(gsp.dividend_yield)
        FROM gold_stock_performance gsp
        JOIN best_performance bp ON gsp.category = bp.category AND bp.rn = 1
        JOIN worst_performance wp ON gsp.category = wp.category AND wp.rn = 1
        GROUP BY gsp.category, bp.ticker, wp.ticker

        PRINT 'gold_category_performance refreshed.'

        -- Step 4: gold_region_performance
        TRUNCATE TABLE gold_region_performance

        ;WITH best_category_cte AS (
            SELECT region, category,
                ROW_NUMBER() OVER(PARTITION BY region ORDER BY yoy_return_pct DESC) AS rn
            FROM gold_stock_performance
        )
        INSERT INTO gold_region_performance (region, avg_yoy_return_pct, avg_volatility, avg_sharpe_ratio, stock_count, best_category, avg_currency_impact_pct)
        SELECT gsp.region, AVG(gsp.yoy_return_pct), AVG(gsp.volatility), AVG(gsp.sharpe_ratio),
            COUNT(gsp.ticker), bcc.category, AVG(gcar.currency_impact_pct)
        FROM gold_stock_performance gsp
        JOIN best_category_cte bcc ON bcc.region = gsp.region AND bcc.rn = 1
        JOIN gold_currency_adjusted_returns gcar ON gsp.ticker = gcar.ticker
        GROUP BY gsp.region, bcc.category

        PRINT 'gold_region_performance refreshed.'

        -- Step 5: gold_dividend_analysis
        TRUNCATE TABLE gold_dividend_analysis

        ;WITH current_forex_rate AS (
            SELECT currency_pair, close_rate,
                ROW_NUMBER() OVER(PARTITION BY currency_pair ORDER BY trade_date DESC) AS rn
            FROM silver_forex_rates
        )
        INSERT INTO gold_dividend_analysis (ticker, company_name, category, region, stock_price, annual_dividend, dividend_yield_pct, payout_ratio, dividend_in_inr, pays_dividend)
        SELECT gsp.ticker, gsp.company_name, gsp.category, gsp.region, gsp.current_price,
            ssf.dividend_per_share, ssf.dividend_yield,
            ssf.dividend_per_share / NULLIF(ssf.net_profit / NULLIF(ssf.shares_outstanding, 0), 0),
            CASE WHEN sc.currency = 'INR' THEN ssf.dividend_per_share ELSE ssf.dividend_per_share * cfx.close_rate END,
            CASE WHEN ssf.dividend_yield IS NULL THEN 0 ELSE 1 END
        FROM silver_companies sc
        LEFT JOIN silver_currency_map scm ON sc.currency = scm.currency_code
        LEFT JOIN current_forex_rate cfx ON scm.forex_pair = cfx.currency_pair
        JOIN gold_stock_performance gsp ON sc.ticker = gsp.ticker
        JOIN silver_stock_fundamentals ssf ON sc.ticker = ssf.ticker
        WHERE (cfx.rn = 1 OR cfx.rn IS NULL)

        PRINT 'gold_dividend_analysis refreshed.'

        -- Step 6: gold_correlation_matrix
        TRUNCATE TABLE gold_correlation_matrix

        ;WITH paired_returns AS (
            SELECT s1.ticker AS stock_1, s2.ticker AS stock_2,
                s1.daily_return_pct AS return_1, s2.daily_return_pct AS return_2
            FROM silver_stock_prices s1
            JOIN silver_stock_prices s2 ON s1.trade_date = s2.trade_date
            WHERE s1.ticker < s2.ticker
                AND s1.daily_return_pct IS NOT NULL
                AND s2.daily_return_pct IS NOT NULL
        ),
        correlation_calc AS (
            SELECT stock_1, stock_2,
                (COUNT(*) * SUM(return_1 * return_2) - SUM(return_1) * SUM(return_2)) /
                NULLIF(SQRT(
                    (COUNT(*) * SUM(return_1 * return_1) - SUM(return_1) * SUM(return_1)) *
                    (COUNT(*) * SUM(return_2 * return_2) - SUM(return_2) * SUM(return_2))
                ), 0) AS correlation_coefficient
            FROM paired_returns
            GROUP BY stock_1, stock_2
        )
        INSERT INTO gold_correlation_matrix (stock_1, stock_2, stock_1_category, stock_2_category, stock_1_region, stock_2_region, correlation_coefficient, relationship)
        SELECT cc.stock_1, cc.stock_2, sc1.category, sc2.category, sc1.region, sc2.region,
            cc.correlation_coefficient,
            CASE
                WHEN cc.correlation_coefficient >= 0.7 THEN 'Strong Positive'
                WHEN cc.correlation_coefficient >= 0.3 THEN 'Weak Positive'
                WHEN cc.correlation_coefficient >= -0.3 THEN 'Uncorrelated'
                ELSE 'Negative'
            END
        FROM correlation_calc cc
        JOIN silver_companies sc1 ON cc.stock_1 = sc1.ticker
        JOIN silver_companies sc2 ON cc.stock_2 = sc2.ticker

        PRINT 'gold_correlation_matrix refreshed.'

        -- Step 7: gold_daily_inr_returns
        TRUNCATE TABLE gold_daily_inr_returns

        INSERT INTO gold_daily_inr_returns (ticker, trade_date, close_price, close_price_inr, daily_return_local_pct, daily_return_inr_pct, forex_rate, currency_pair)
        SELECT
            ssp.ticker,
            ssp.trade_date,
            ssp.close_price,
            ssp.close_price * COALESCE(sfr.close_rate, 1) AS close_price_inr,
            ssp.daily_return_pct,
            (ssp.close_price * COALESCE(sfr.close_rate, 1) - LAG(ssp.close_price * COALESCE(sfr.close_rate, 1)) OVER (PARTITION BY ssp.ticker ORDER BY ssp.trade_date)) / LAG(ssp.close_price * COALESCE(sfr.close_rate, 1)) OVER (PARTITION BY ssp.ticker ORDER BY ssp.trade_date) * 100 AS daily_return_inr_pct,
            COALESCE(sfr.close_rate, 1),
            sfr.currency_pair
        FROM silver_stock_prices ssp
        JOIN silver_companies sc ON ssp.ticker = sc.ticker
        JOIN silver_currency_map scm ON sc.currency = scm.currency_code
        LEFT JOIN silver_forex_rates sfr ON scm.forex_pair = sfr.currency_pair AND ssp.trade_date = sfr.trade_date

        PRINT 'gold_daily_inr_returns refreshed.'

        PRINT 'Gold layer refresh complete.'

    END TRY
    BEGIN CATCH
        PRINT 'Error refreshing Gold layer: ' + ERROR_MESSAGE()
    END CATCH
END
GO

-- =============================================
-- sp_daily_refresh
-- Master procedure called by SQL Server Agent at 3:00 AM IST
-- =============================================

CREATE PROCEDURE sp_daily_refresh
AS
BEGIN
    EXEC sp_refresh_silver
    EXEC sp_refresh_gold
END
GO

PRINT 'All stored procedures created successfully.'
