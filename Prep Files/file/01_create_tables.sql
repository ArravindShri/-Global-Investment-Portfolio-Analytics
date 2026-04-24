-- =============================================
-- Global Investment Portfolio Analytics
-- 01_create_tables.sql
-- Creates all 15 tables across Bronze, Silver, Gold layers
-- Run this FIRST before any other SQL scripts
-- =============================================

USE master
GO

-- Create database if not exists
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'Global_Portfolio_Analysis')
    CREATE DATABASE Global_Portfolio_Analysis
GO

USE Global_Portfolio_Analysis
GO

-- =============================================
-- BRONZE LAYER (Raw API Data)
-- =============================================

CREATE TABLE bronze_stock_prices (
    ticker VARCHAR(50) NOT NULL,
    trade_date DATE NOT NULL,
    open_price DECIMAL(18,4),
    high_price DECIMAL(18,4),
    low_price DECIMAL(18,4),
    close_price DECIMAL(18,4),
    volume BIGINT,
    exchange VARCHAR(20),
    currency VARCHAR(10),
    api_fetched_at DATETIME DEFAULT GETDATE()
)
GO

CREATE TABLE bronze_stock_fundamentals (
    ticker VARCHAR(50) NOT NULL,
    report_date DATE,
    market_cap BIGINT,
    pe_ratio DECIMAL(18,4),
    pb_ratio DECIMAL(18,4),
    dividend_yield DECIMAL(18,6),
    dividend_per_share DECIMAL(18,4),
    revenue BIGINT,
    net_profit BIGINT,
    roe DECIMAL(18,4),
    debt_to_equity DECIMAL(18,4),
    book_value DECIMAL(18,4),
    shares_outstanding BIGINT,
    api_fetched_at DATETIME DEFAULT GETDATE()
)
GO

CREATE TABLE bronze_forex_rates (
    currency_pair VARCHAR(20) NOT NULL,
    trade_date DATE NOT NULL,
    open_rate DECIMAL(18,6),
    high_rate DECIMAL(18,6),
    low_rate DECIMAL(18,6),
    close_rate DECIMAL(18,6),
    api_fetched_at DATETIME DEFAULT GETDATE()
)
GO

-- =============================================
-- SILVER LAYER (Cleaned + Reference)
-- =============================================

CREATE TABLE silver_stock_prices (
    ticker VARCHAR(50) NOT NULL,
    trade_date DATE NOT NULL,
    open_price DECIMAL(18,4),
    high_price DECIMAL(18,4),
    low_price DECIMAL(18,4),
    close_price DECIMAL(18,4),
    volume BIGINT,
    daily_return_pct DECIMAL(18,4),
    is_valid BIT DEFAULT 1,
    PRIMARY KEY (ticker, trade_date)
)
GO

CREATE TABLE silver_stock_fundamentals (
    ticker VARCHAR(50) NOT NULL PRIMARY KEY,
    report_date DATE,
    market_cap BIGINT,
    pe_ratio DECIMAL(18,4),
    pb_ratio DECIMAL(18,4),
    dividend_yield DECIMAL(18,6),
    dividend_per_share DECIMAL(18,4),
    revenue BIGINT,
    net_profit BIGINT,
    roe DECIMAL(18,4),
    debt_to_equity DECIMAL(18,4),
    book_value DECIMAL(18,4),
    shares_outstanding BIGINT,
    is_valid BIT DEFAULT 1
)
GO

CREATE TABLE silver_forex_rates (
    currency_pair VARCHAR(20) NOT NULL,
    trade_date DATE NOT NULL,
    close_rate DECIMAL(18,6),
    daily_change_pct DECIMAL(18,6),
    is_valid BIT DEFAULT 1,
    PRIMARY KEY (currency_pair, trade_date)
)
GO

CREATE TABLE silver_companies (
    ticker VARCHAR(50) PRIMARY KEY,
    company_name VARCHAR(200),
    country VARCHAR(50),
    exchange VARCHAR(20),
    currency VARCHAR(10),
    category VARCHAR(50),
    region VARCHAR(50)
)
GO

CREATE TABLE silver_currency_map (
    currency_code VARCHAR(10) PRIMARY KEY,
    currency_name VARCHAR(50),
    currency_country VARCHAR(50),
    forex_pair VARCHAR(20)
)
GO

CREATE TABLE silver_calendar (
    date_key DATE PRIMARY KEY,
    day_of_week INT,
    day_name VARCHAR(20),
    week_number INT,
    month_number INT,
    month_name VARCHAR(20),
    quarter INT,
    quarter_name VARCHAR(5),
    year INT,
    is_weekend BIT,
    is_trading_day BIT
)
GO

-- =============================================
-- GOLD LAYER (Analytics-Ready)
-- =============================================

CREATE TABLE gold_stock_performance (
    ticker VARCHAR(50) NOT NULL PRIMARY KEY,
    company_name VARCHAR(200),
    category VARCHAR(50),
    region VARCHAR(50),
    currency VARCHAR(10),
    current_price DECIMAL(18,4),
    yoy_return_pct DECIMAL(18,4),
    week_52_high DECIMAL(18,4),
    week_52_low DECIMAL(18,4),
    volatility DECIMAL(18,4),
    sharpe_ratio DECIMAL(18,4),
    pe_ratio DECIMAL(18,4),
    market_cap BIGINT,
    roe DECIMAL(18,4),
    debt_to_equity DECIMAL(18,4),
    dividend_yield DECIMAL(18,6)
)
GO

CREATE TABLE gold_currency_adjusted_returns (
    ticker VARCHAR(50) NOT NULL PRIMARY KEY,
    company_name VARCHAR(200),
    category VARCHAR(50),
    region VARCHAR(50),
    original_currency VARCHAR(10),
    return_local_pct DECIMAL(18,4),
    inr_start_rate DECIMAL(18,6),
    inr_end_rate DECIMAL(18,6),
    return_inr_pct DECIMAL(18,4),
    currency_impact_pct DECIMAL(18,4)
)
GO

CREATE TABLE gold_category_performance (
    category VARCHAR(50) NOT NULL PRIMARY KEY,
    average_yoy_return_pct DECIMAL(18,4),
    avg_volatility DECIMAL(18,4),
    best_stock VARCHAR(50),
    worst_stock VARCHAR(50),
    avg_pe_ratio DECIMAL(18,4),
    total_market_cap BIGINT,
    avg_dividend_yield DECIMAL(18,6)
)
GO

CREATE TABLE gold_region_performance (
    region VARCHAR(50) NOT NULL PRIMARY KEY,
    avg_yoy_return_pct DECIMAL(18,4),
    avg_volatility DECIMAL(18,4),
    avg_sharpe_ratio DECIMAL(18,4),
    stock_count INT,
    best_category VARCHAR(50),
    avg_currency_impact_pct DECIMAL(18,4)
)
GO

CREATE TABLE gold_dividend_analysis (
    ticker VARCHAR(50) NOT NULL PRIMARY KEY,
    company_name VARCHAR(200),
    category VARCHAR(50),
    region VARCHAR(50),
    stock_price DECIMAL(18,4),
    annual_dividend DECIMAL(18,4),
    dividend_yield_pct DECIMAL(18,6),
    payout_ratio DECIMAL(18,4),
    dividend_in_inr DECIMAL(18,4),
    pays_dividend BIT
)
GO

CREATE TABLE gold_correlation_matrix (
    stock_1 VARCHAR(50) NOT NULL,
    stock_2 VARCHAR(50) NOT NULL,
    stock_1_category VARCHAR(50),
    stock_2_category VARCHAR(50),
    stock_1_region VARCHAR(50),
    stock_2_region VARCHAR(50),
    correlation_coefficient DECIMAL(18,4),
    relationship VARCHAR(50),
    PRIMARY KEY (stock_1, stock_2)
)
GO

CREATE TABLE gold_daily_inr_returns (
    ticker VARCHAR(50) NOT NULL,
    trade_date DATE NOT NULL,
    close_price DECIMAL(10,2) NOT NULL,
    close_price_inr DECIMAL(10,2) NOT NULL,
    daily_return_local_pct DECIMAL(10,2),
    daily_return_inr_pct DECIMAL(10,2),
    forex_rate DECIMAL(10,2) NOT NULL,
    currency_pair VARCHAR(50),
    PRIMARY KEY (ticker, trade_date)
)
GO

PRINT 'All 15 tables created successfully.'
