-- =============================================
-- Global Investment Portfolio Analytics
-- 04_indexes.sql
-- Creates non-clustered indexes for performance optimization
-- Run AFTER all tables are created and populated
-- =============================================

USE Global_Portfolio_Analysis
GO

-- Index on trade_date for silver_stock_prices
-- Speeds up date-range queries: 52-week calculations, YoY returns,
-- LAG window functions, Power BI DirectQuery date-axis charts
CREATE NONCLUSTERED INDEX IX_silver_stock_prices_trade_date
ON silver_stock_prices (trade_date)
GO

-- Index on trade_date for silver_forex_rates
-- Speeds up date-range joins between stock prices and forex rates
-- Used heavily in gold_daily_inr_returns calculation
CREATE NONCLUSTERED INDEX IX_silver_forex_rates_trade_date
ON silver_forex_rates (trade_date)
GO

PRINT 'All indexes created successfully.'
