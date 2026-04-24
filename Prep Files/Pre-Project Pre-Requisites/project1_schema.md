# Project #1: Global Investment Portfolio Analytics — Database Schema

---

## Architecture: Medallion (Bronze → Silver → Gold)
**Total Tables: 15**
- Bronze: 3 tables (raw API data)
- Silver: 6 tables (cleaned + reference)
- Gold: 6 tables (analytics-ready for Power BI)

---

## BRONZE LAYER (Raw API Data — Untouched)

### bronze_stock_prices
Source: Twelve Data `/time_series` endpoint  
Refresh: Daily (end of trading day via SQL Server Agent)  
Row count: ~6,000 (12 stocks × ~250 trading days × 2 years)

| Column | Type | Description |
|---|---|---|
| ticker | VARCHAR | Stock ticker symbol (e.g., ONGC, F, VOW) |
| trade_date | DATE | Trading date |
| open_price | DECIMAL | Opening price |
| high_price | DECIMAL | Day's highest price |
| low_price | DECIMAL | Day's lowest price |
| close_price | DECIMAL | Closing price |
| volume | BIGINT | Number of shares traded |
| exchange | VARCHAR | Exchange code (NYSE, LSE, NSE, KRX, XETRA) |
| currency | VARCHAR | Trading currency (USD, GBP, INR, KRW, EUR) |
| api_fetched_at | DATETIME | Timestamp when data was pulled from API |

### bronze_stock_fundamentals
Source: Twelve Data fundamentals/statistics endpoint  
Refresh: Quarterly  
Row count: ~96 (12 stocks × 8 quarters over 2 years)

| Column | Type | Description |
|---|---|---|
| ticker | VARCHAR | Stock ticker symbol |
| report_date | DATE | Quarter end date |
| market_cap | BIGINT | Total market capitalization |
| pe_ratio | DECIMAL | Price-to-Earnings ratio |
| pb_ratio | DECIMAL | Price-to-Book ratio |
| dividend_yield | DECIMAL | Annual dividend yield % |
| dividend_per_share | DECIMAL | Annual dividend per share |
| revenue | BIGINT | Quarterly revenue |
| net_profit | BIGINT | Quarterly net profit |
| roe | DECIMAL | Return on Equity % |
| debt_to_equity | DECIMAL | Debt-to-Equity ratio |
| book_value | DECIMAL | Book value per share |
| face_value | DECIMAL | Face value per share |
| shares_outstanding | BIGINT | Total shares outstanding |
| api_fetched_at | DATETIME | Timestamp when data was pulled |

### bronze_forex_rates
Source: Twelve Data forex endpoint  
Refresh: Daily  
Row count: ~2,000 (4 currency pairs × ~500 trading days)

| Column | Type | Description |
|---|---|---|
| currency_pair | VARCHAR | Pair identifier (e.g., USD/INR, GBP/INR, EUR/INR, KRW/INR) |
| trade_date | DATE | Trading date |
| open_rate | DECIMAL | Opening exchange rate |
| high_rate | DECIMAL | Day's highest rate |
| low_rate | DECIMAL | Day's lowest rate |
| close_rate | DECIMAL | Closing exchange rate |
| api_fetched_at | DATETIME | Timestamp when data was pulled |

---

## SILVER LAYER (Cleaned + Reference Tables)

### silver_stock_prices
Source: Cleaned from `bronze_stock_prices`  
Transformations: Duplicates removed, nulls handled (forward-fill), data types validated, daily return calculated.

| Column | Type | Description |
|---|---|---|
| ticker | VARCHAR | Stock ticker symbol |
| trade_date | DATE | Trading date |
| open_price | DECIMAL | Opening price (validated) |
| high_price | DECIMAL | Day's high (validated) |
| low_price | DECIMAL | Day's low (validated) |
| close_price | DECIMAL | Closing price (validated) |
| volume | BIGINT | Volume (validated) |
| daily_return_pct | DECIMAL | Daily return % = (today close - yesterday close) / yesterday close × 100 |
| is_valid | BIT | Data quality flag (1 = clean, 0 = imputed or flagged) |

### silver_stock_fundamentals
Source: Cleaned from `bronze_stock_fundamentals`  
Transformations: Duplicates removed, nulls flagged, quarterly dates standardized.

| Column | Type | Description |
|---|---|---|
| ticker | VARCHAR | Stock ticker symbol |
| report_date | DATE | Standardized quarter end date |
| market_cap | BIGINT | Market capitalization (validated) |
| pe_ratio | DECIMAL | P/E ratio (validated) |
| pb_ratio | DECIMAL | P/B ratio (validated) |
| dividend_yield | DECIMAL | Dividend yield % (validated) |
| dividend_per_share | DECIMAL | Dividend per share (validated) |
| revenue | BIGINT | Revenue (validated) |
| net_profit | BIGINT | Net profit (validated) |
| roe | DECIMAL | ROE % (validated) |
| debt_to_equity | DECIMAL | Debt-to-Equity (validated) |
| book_value | DECIMAL | Book value per share (validated) |
| face_value | DECIMAL | Face value per share (validated) |
| shares_outstanding | BIGINT | Shares outstanding (validated) |
| is_valid | BIT | Data quality flag |

### silver_forex_rates
Source: Cleaned from `bronze_forex_rates`  
Transformations: Duplicates removed, all rates normalized to INR base, daily change calculated.

| Column | Type | Description |
|---|---|---|
| currency_pair | VARCHAR | Pair identifier (normalized to X/INR) |
| trade_date | DATE | Trading date |
| close_rate | DECIMAL | Closing rate (validated) |
| daily_change_pct | DECIMAL | Daily forex change % |
| is_valid | BIT | Data quality flag |

### silver_companies (Reference — Manually Defined)
Size: 12 rows

| Column | Type | Description |
|---|---|---|
| ticker | VARCHAR | Stock ticker symbol (PK) |
| company_name | VARCHAR | Full company name |
| country | VARCHAR | Country of exchange |
| exchange | VARCHAR | Exchange code |
| currency | VARCHAR | Trading currency |
| category | VARCHAR | Nuclear / Rare Earth / Oil / Automotive |
| region | VARCHAR | North America / Europe / Asia |

### silver_currency_map (Reference — Manually Defined)
Size: 5 rows

| Column | Type | Description |
|---|---|---|
| currency_code | VARCHAR | Currency code — USD, GBP, EUR, INR, KRW (PK) |
| currency_name | VARCHAR | Full name — US Dollar, British Pound, etc. |
| country | VARCHAR | Primary country |
| forex_pair | VARCHAR | Twelve Data pair format for INR conversion |

### silver_calendar (Date Dimension — Generated)
Size: ~730 rows (2 years)

| Column | Type | Description |
|---|---|---|
| date_key | DATE | Calendar date (PK) |
| day_of_week | INT | 1-7 (Monday-Sunday) |
| day_name | VARCHAR | Monday, Tuesday, etc. |
| week_number | INT | Week of year (1-52) |
| month_number | INT | Month (1-12) |
| month_name | VARCHAR | January, February, etc. |
| quarter | INT | Quarter (1-4) |
| quarter_name | VARCHAR | Q1, Q2, Q3, Q4 |
| year | INT | Year |
| is_weekend | BIT | 1 if Saturday/Sunday |
| is_trading_day | BIT | 1 if markets were open |

---

## GOLD LAYER (Analytics-Ready for Power BI)

### gold_stock_performance
Serves: 4 Category dashboard pages  
Size: 12 rows (one per stock, refreshed daily)

| Column | Type | Description |
|---|---|---|
| ticker | VARCHAR | Stock ticker symbol |
| company_name | VARCHAR | Full company name |
| category | VARCHAR | Industry category |
| region | VARCHAR | Geographic region |
| currency | VARCHAR | Trading currency |
| current_price | DECIMAL | Latest closing price |
| yoy_return_pct | DECIMAL | Year-over-year return % |
| week_52_high | DECIMAL | 52-week highest price |
| week_52_low | DECIMAL | 52-week lowest price |
| volatility | DECIMAL | Standard deviation of daily returns |
| sharpe_ratio | DECIMAL | Risk-adjusted return (return / volatility) |
| pe_ratio | DECIMAL | Latest P/E ratio |
| market_cap | BIGINT | Latest market cap |
| roe | DECIMAL | Latest ROE |
| debt_to_equity | DECIMAL | Latest D/E ratio |
| dividend_yield | DECIMAL | Latest dividend yield % |

### gold_currency_adjusted_returns
Serves: Currency Appreciation page  
Size: 12 rows (one per stock, refreshed daily)

| Column | Type | Description |
|---|---|---|
| ticker | VARCHAR | Stock ticker symbol |
| company_name | VARCHAR | Full company name |
| category | VARCHAR | Industry category |
| region | VARCHAR | Geographic region |
| original_currency | VARCHAR | Stock's trading currency |
| return_local_pct | DECIMAL | Return in local currency % |
| inr_rate_start | DECIMAL | INR exchange rate at period start |
| inr_rate_end | DECIMAL | INR exchange rate at period end |
| return_inr_pct | DECIMAL | Actual return in INR % |
| currency_impact_pct | DECIMAL | Difference: INR return - local return (positive = rupee weakness helped) |

### gold_category_performance
Serves: Overall Category Performance page  
Size: 4 rows (one per category)

| Column | Type | Description |
|---|---|---|
| category | VARCHAR | Nuclear / Rare Earth / Oil / Automotive |
| avg_yoy_return_pct | DECIMAL | Average YoY return across 3 stocks |
| avg_volatility | DECIMAL | Average volatility across 3 stocks |
| best_stock | VARCHAR | Highest return stock in category |
| worst_stock | VARCHAR | Lowest return stock in category |
| avg_pe_ratio | DECIMAL | Average P/E in category |
| total_market_cap | BIGINT | Combined market cap |
| avg_dividend_yield | DECIMAL | Average dividend yield |

### gold_region_performance
Serves: Portfolio Diversification Analysis page  
Size: 3 rows (one per region)

| Column | Type | Description |
|---|---|---|
| region | VARCHAR | North America / Europe / Asia |
| avg_yoy_return_pct | DECIMAL | Average YoY return across 4 stocks |
| avg_volatility | DECIMAL | Average volatility |
| avg_sharpe_ratio | DECIMAL | Average risk-adjusted return |
| stock_count | INT | Number of stocks in region (4) |
| best_category | VARCHAR | Best performing category in this region |
| avg_currency_impact_pct | DECIMAL | Average currency impact on INR returns |

### gold_dividend_analysis
Serves: Highest Dividend page  
Size: 12 rows

| Column | Type | Description |
|---|---|---|
| ticker | VARCHAR | Stock ticker symbol |
| company_name | VARCHAR | Full company name |
| category | VARCHAR | Industry category |
| region | VARCHAR | Geographic region |
| stock_price | DECIMAL | Current stock price |
| annual_dividend | DECIMAL | Annual dividend per share |
| dividend_yield_pct | DECIMAL | Dividend yield % |
| payout_ratio | DECIMAL | Dividends as % of earnings |
| dividend_in_inr | DECIMAL | Dividend converted to INR |
| pays_dividend | BIT | 1 = yes, 0 = no |

### gold_correlation_matrix
Serves: Portfolio Diversification Analysis page  
Size: 66 rows (12 stocks × 11 / 2 = 66 unique pairs)

| Column | Type | Description |
|---|---|---|
| stock_1 | VARCHAR | First stock ticker |
| stock_2 | VARCHAR | Second stock ticker |
| stock_1_category | VARCHAR | First stock's category |
| stock_2_category | VARCHAR | Second stock's category |
| stock_1_region | VARCHAR | First stock's region |
| stock_2_region | VARCHAR | Second stock's region |
| correlation_coefficient | DECIMAL | -1 to +1 correlation value |
| relationship | VARCHAR | Strong positive / Weak positive / Uncorrelated / Negative |

---

## Data Flow Summary

```
Twelve Data API
    ├── /time_series    →  bronze_stock_prices    →  silver_stock_prices    →  gold_stock_performance
    ├── /fundamentals   →  bronze_stock_fundamentals →  silver_stock_fundamentals →  gold_dividend_analysis
    └── /forex          →  bronze_forex_rates     →  silver_forex_rates     →  gold_currency_adjusted_returns
                                                                            →  gold_category_performance
Manually Defined:                                                           →  gold_region_performance
    ├── silver_companies (12 rows)                                          →  gold_correlation_matrix
    ├── silver_currency_map (5 rows)
    └── silver_calendar (~730 rows)

All Gold tables → Power BI (8 dashboard pages)
```

---

*Last updated: March 24, 2026*
