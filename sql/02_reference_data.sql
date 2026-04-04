-- =============================================
-- Global Investment Portfolio Analytics
-- 02_reference_data.sql
-- Populates silver_companies, silver_currency_map, silver_calendar
-- Run AFTER 01_create_tables.sql
-- =============================================

USE Global_Portfolio_Analysis
GO

-- =============================================
-- silver_companies (12 rows)
-- =============================================

INSERT INTO silver_companies (ticker, company_name, country, exchange, currency, category, region) VALUES
('CEG', 'Constellation Energy Corporation', 'USA', 'NASDAQ', 'USD', 'Nuclear', 'North America'),
('RR', 'Rolls-Royce', 'United Kingdom', 'LSE', 'GBP', 'Nuclear', 'Europe'),
('BHEL', 'Bharat Heavy Electricals Limited', 'India', 'NSE', 'INR', 'Nuclear', 'Asia'),
('MP', 'MP Materials Corp', 'USA', 'NYSE', 'USD', 'Rare Earth Minerals', 'North America'),
('RBW', 'Rainbow Rare Earths Limited', 'United Kingdom', 'LSE', 'GBP', 'Rare Earth Minerals', 'Europe'),
('GMDCLTD', 'Gujarat Mineral Development Corporation', 'India', 'NSE', 'INR', 'Rare Earth Minerals', 'Asia'),
('XOM', 'Exxon Mobil Corporation', 'USA', 'NYSE', 'USD', 'Oil', 'North America'),
('SHEL', 'Shell PLC', 'United Kingdom', 'LSE', 'GBP', 'Oil', 'Europe'),
('ONGC', 'Oil and Natural Gas Corporation', 'India', 'NSE', 'INR', 'Oil', 'Asia'),
('F', 'Ford Motor Company', 'USA', 'NYSE', 'USD', 'Automotive', 'North America'),
('VOW', 'Volkswagen AG', 'Germany', 'XETRA', 'EUR', 'Automotive', 'Europe'),
('TMPV', 'Tata Motors Passenger Vehicles Limited', 'India', 'NSE', 'INR', 'Automotive', 'Asia')
GO

PRINT 'silver_companies populated: 12 rows.'

-- =============================================
-- silver_currency_map (5 rows)
-- =============================================

INSERT INTO silver_currency_map (currency_code, currency_name, currency_country, forex_pair) VALUES
('USD', 'US Dollar', 'USA', 'USD/INR'),
('GBP', 'British Pound', 'United Kingdom', 'GBP/INR'),
('EUR', 'Euro', 'Germany', 'EUR/INR'),
('INR', 'Indian Rupee', 'India', NULL),
('KRW', 'South Korean Won', 'South Korea', NULL)
GO

PRINT 'silver_currency_map populated: 5 rows.'

-- =============================================
-- silver_calendar (generate 2+ years of dates)
-- =============================================

;WITH DateRange AS (
    SELECT CAST('2024-01-01' AS DATE) AS date_key
    UNION ALL
    SELECT DATEADD(DAY, 1, date_key) FROM DateRange WHERE date_key < '2026-12-31'
)
INSERT INTO silver_calendar (date_key, day_of_week, day_name, week_number, month_number, month_name, quarter, quarter_name, year, is_weekend, is_trading_day)
SELECT 
    date_key,
    DATEPART(WEEKDAY, date_key),
    DATENAME(WEEKDAY, date_key),
    DATEPART(WEEK, date_key),
    MONTH(date_key),
    DATENAME(MONTH, date_key),
    DATEPART(QUARTER, date_key),
    'Q' + CAST(DATEPART(QUARTER, date_key) AS VARCHAR),
    YEAR(date_key),
    CASE WHEN DATEPART(WEEKDAY, date_key) IN (1, 7) THEN 1 ELSE 0 END,
    CASE WHEN DATEPART(WEEKDAY, date_key) IN (1, 7) THEN 0 ELSE 1 END
FROM DateRange
OPTION (MAXRECURSION 1100)
GO

PRINT 'silver_calendar populated.'
PRINT 'All reference data loaded successfully.'
