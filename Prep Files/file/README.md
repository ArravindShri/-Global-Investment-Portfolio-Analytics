# Global Investment Portfolio Analytics

A live, end-to-end data analytics platform tracking 12 government-backed stocks across 4 sectors and 3 regions, with INR-adjusted currency returns for Indian investors.

**🔗 [Live Dashboard](https://app.powerbi.com)** *(Power BI Pro required to view)*

---

## Dashboard Preview

| Nuclear Energy | Currency Appreciation |
|:-:|:-:|
| ![Nuclear](screenshots/dashboard_nuclear.png) | ![Currency](screenshots/dashboard_currency.png) |

| Overall Category Performance | Portfolio Diversification |
|:-:|:-:|
| ![Category](screenshots/dashboard_category.png) | ![Diversification](screenshots/dashboard_diversification.png) |

---

## Business Problem

A young Indian investor wants to diversify globally across 4 high-conviction sectors — Nuclear Energy, Rare Earth Minerals, Oil, and Automotive — spanning 3 regions (North America, Europe, Asia). But stock returns in USD, GBP, or EUR don't tell the real story. If a US stock gains 20% but the rupee weakens from ₹83 to ₹86 per dollar, the actual INR return is 24.3%, not 20%.

**This dashboard solves that problem** — it shows true returns after currency conversion, identifies the best risk-adjusted investments, and reveals which stock combinations actually provide diversification.

---

## Key Features

- **Live Data Pipeline** — Automated daily ingestion from Twelve Data API + Yahoo Finance, refreshed at 2:30 AM IST
- **INR-Adjusted Returns** — Every stock's return converted to Indian Rupees, showing real investor returns after forex impact
- **Medallion Architecture** — Bronze (raw) → Silver (cleaned) → Gold (analytics-ready), 15 tables across 3 layers
- **DirectQuery Dashboard** — Published Power BI dashboard queries SQL Server in real-time via On-premises Data Gateway
- **7 Gold Tables** — Pre-calculated metrics including Pearson correlation matrix (66 stock pairs), Sharpe ratios, dividend analysis
- **Dynamic DAX Measures** — Year-filtered calculations using CALCULATE, FIRSTDATE/LASTDATE, AVERAGEX patterns
- **Investment Calculator** — What-if parameter page for simulating returns with custom tax rates

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATA INGESTION (2:30 AM IST)                 │
│                                                                 │
│  Twelve Data API ──→ Python Scripts ──→ Bronze Tables            │
│  Yahoo Finance   ──→ (Task Scheduler)                           │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                 TRANSFORMATION (3:00 AM IST)                    │
│                                                                 │
│  Bronze ──→ sp_refresh_silver ──→ Silver Tables                 │
│  Silver ──→ sp_refresh_gold   ──→ Gold Tables                   │
│              (SQL Server Agent)                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    VISUALIZATION (24/7)                          │
│                                                                 │
│  Gold Tables ──→ DirectQuery ──→ On-premises Gateway            │
│                                 ──→ Power BI Service            │
│                                 ──→ Published Dashboard         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Stocks Tracked (12)

| Sector | North America | Europe | Asia |
|--------|:---:|:---:|:---:|
| **Nuclear Energy** | CEG (Constellation) | RR (Rolls-Royce) | BHEL |
| **Rare Earth Minerals** | MP (MP Materials) | RBW (Rainbow) | GMDCLTD |
| **Oil** | XOM (ExxonMobil) | SHEL (Shell) | ONGC |
| **Automotive** | F (Ford) | VOW (Volkswagen) | TMPV (Tata Motors) |

**Currencies:** USD, GBP, EUR, INR | **Exchanges:** NYSE, NASDAQ, LSE, XETRA, NSE

---

## Dashboard Pages (10)

| # | Page | Description |
|---|------|-------------|
| 1 | Nuclear Energy | Single-stock metrics, 52-week gauge, price+volume chart, YoY comparison |
| 2 | Rare Earth Minerals | Same layout, filtered to Rare Earth category |
| 3 | Oil | Same layout, filtered to Oil category |
| 4 | Automotive | Same layout, filtered to Automotive category |
| 5 | Currency Appreciation | INR-adjusted returns, forex trends, currency impact comparison |
| 6 | Overall Category Performance | Sector comparison with dynamic year filtering (DAX) |
| 7 | Highest Dividend | Dividend yield ranking, payout ratios, INR-converted dividends |
| 8 | Portfolio Diversification | Sharpe ratios, regional performance, 66-pair correlation matrix |
| 9 | FAQ / Glossary | Financial terminology definitions and dashboard purpose |
| 10 | Investment Calculator | What-if parameters for investment amount and tax rate simulation |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Data Sources** | Twelve Data API (Grow tier), Yahoo Finance (yfinance) |
| **Database** | Microsoft SQL Server 17.0 |
| **ETL** | Python 3.x, Windows Task Scheduler |
| **Transformations** | T-SQL Stored Procedures, SQL Server Agent |
| **Visualization** | Power BI Desktop + Power BI Service (DirectQuery) |
| **Gateway** | On-premises Data Gateway |
| **Version Control** | Git + GitHub |

---

## Database Schema

**15 tables across 3 layers:**

### Bronze (Raw API Data)
- `bronze_stock_prices` — Daily OHLCV for 12 stocks (~6,000 rows)
- `bronze_stock_fundamentals` — Quarterly metrics (12 rows)
- `bronze_forex_rates` — Daily forex rates for USD/INR, GBP/INR, EUR/INR (~2,000 rows)

### Silver (Cleaned + Reference)
- `silver_stock_prices` — GBp→GBP converted, daily returns calculated
- `silver_stock_fundamentals` — Deduplicated, validated
- `silver_forex_rates` — Deduplicated, daily change calculated
- `silver_companies` — 12-row lookup table (central dimension)
- `silver_currency_map` — Currency-to-forex-pair mapping
- `silver_calendar` — Date dimension (~730 rows)

### Gold (Analytics-Ready)
- `gold_stock_performance` — 12 rows, current metrics per stock
- `gold_currency_adjusted_returns` — 12 rows, INR-adjusted summary
- `gold_category_performance` — 4 rows, sector averages
- `gold_region_performance` — 3 rows, regional averages
- `gold_dividend_analysis` — 12 rows, dividend metrics
- `gold_correlation_matrix` — 66 rows, Pearson correlation pairs
- `gold_daily_inr_returns` — ~5,658 rows, daily INR-adjusted prices

---

## SQL Highlights

- **25+ analytical queries** across Bronze→Silver→Gold transformations
- **Window Functions:** LAG for daily returns, ROW_NUMBER for latest/earliest prices, STDEV for volatility
- **CTEs:** Multi-step calculations for YoY returns, Sharpe ratios, COALESCE fallbacks
- **Pearson Correlation:** Full SQL implementation across 66 stock pairs
- **3 Stored Procedures:** `sp_refresh_silver`, `sp_refresh_gold`, `sp_daily_refresh`
- **Performance:** Non-clustered indexes on trade_date columns, TRUNCATE+INSERT refresh pattern

---

## DAX Measures

Dynamic measures built in Power BI for year-filtered calculations:

- `Local Return %` — CALCULATE + FIRSTDATE/LASTDATE pattern
- `INR Return %` — Same pattern on close_price_inr
- `Currency Impact %` — INR Return minus Local Return
- `Category Avg Return %` — AVERAGEX over VALUES(ticker)
- `Category Avg Volatility` — AVERAGEX + STDEVX.P
- `Best Stock / Worst Stock` — TOPN + ADDCOLUMNS
- `Dynamic Dividend Yield` — Cross-table calculation
- `Gross Return INR` — What-if parameter integration
- `Tax Amount / Net Return / Final Value` — Investment calculator chain

---

## Project Structure

```
Global-Investment-Portfolio-Analytics/
├── README.md
├── sql/
│   ├── 01_create_tables.sql
│   ├── 02_reference_data.sql
│   ├── 03_stored_procedures.sql
│   └── 04_indexes.sql
├── python/
│   ├── Bronze_stock_ingestionrealtimedata.py
│   ├── Bronze_forex_ingestion.py
│   └── Bronze_fundamentals_ingestion.py
├── docs/
│   ├── 01_Bronze_Layer_Documentation.md
│   ├── 02_Silver_Layer_Documentation.md
│   ├── 03_Gold_Layer_Documentation.md
│   ├── 04_Python_Automation_Documentation.md
│   ├── 05_Indexes_Documentation.md
│   └── 06_PowerBI_Publishing_Documentation.md
├── screenshots/
│   ├── dashboard_nuclear.png
│   ├── dashboard_currency.png
│   ├── dashboard_category.png
│   └── dashboard_diversification.png
└── theme/
    └── GlobalPortfolioTheme.json
```

---

## Setup & Replication

### Prerequisites
- SQL Server 2017+
- Python 3.x with `requests`, `pyodbc`, `yfinance` packages
- Power BI Desktop
- Twelve Data API key (Grow tier: $29/month)

### Steps
1. Run `sql/01_create_tables.sql` to create all 15 tables
2. Run `sql/02_reference_data.sql` to populate silver_companies, silver_currency_map, silver_calendar
3. Update API keys in Python scripts, then run all 3 scripts in `python/`
4. Run `sql/03_stored_procedures.sql` to create stored procedures
5. Execute `EXEC sp_daily_refresh` to populate Silver and Gold layers
6. Run `sql/04_indexes.sql` to create performance indexes
7. Open Power BI Desktop → Get Data → SQL Server → DirectQuery → localhost → Global_Portfolio_Analysis
8. See `docs/06_PowerBI_Publishing_Documentation.md` for gateway and publishing setup

---

## Key Data Insights

- **Rare Earth Minerals** averaged the highest YoY return across the portfolio
- **Automotive** sector dragged by TMPV's post-demerger decline
- **North America** led regional performance
- **USD/INR movement** (85→95 range) added ~10-15 percentage points to US stock returns for Indian investors
- **Most stock pairs** showed uncorrelated relationships — genuine portfolio diversification achieved
- **7 of 12 stocks** pay dividends — dividend yields range from 0.2% to 6%+

---

## Automation Schedule

| Time (IST) | Component | Action |
|------------|-----------|--------|
| 2:30 AM | Task Scheduler → Python | Fetch new stock prices + forex rates → Bronze |
| 3:00 AM | SQL Server Agent → SPs | Transform Bronze → Silver → Gold |
| 24/7 | Gateway + DirectQuery | Live dashboard on Power BI Service |

---

## Edge Cases Handled

- **GBp vs GBP:** LSE stocks return prices in pence — converted to pounds in Silver layer
- **TMPV insufficient history:** Post-demerger (Oct 2025) stock uses COALESCE fallback to earliest available price
- **VOW3 symbol mapping:** Volkswagen uses VOW3 on Twelve Data, mapped to VOW internally
- **INR stocks forex:** COALESCE(forex_rate, 1) ensures INR stocks don't break currency calculations
- **Missing exchange parameter:** Non-US stocks require explicit exchange in API calls to avoid wrong data

---

## Author

**Arravind Shri**  
Data Analytics Professional | [LinkedIn](https://linkedin.com/in/arravindshri) | [Portfolio](https://arravindportfolio.tech)

---

## License

MIT License — see [LICENSE](LICENSE) for details.
