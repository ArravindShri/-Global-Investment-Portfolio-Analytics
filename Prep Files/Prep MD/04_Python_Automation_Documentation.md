# Python Automation & Scheduling Documentation
## Global Investment Portfolio Analytics

**Last Updated:** April 4, 2026  
**Author:** Arravind Shri  
**Environment:** Windows 11, SQL Server 17.0, Python 3.x

---

## Overview

The project uses a two-stage daily automation pipeline:
1. **Stage 1 (2:30 AM IST):** Python scripts fetch new data from APIs → Bronze tables
2. **Stage 2 (3:00 AM IST):** SQL Server Agent runs stored procedures → Silver → Gold tables

This 30-minute gap ensures Bronze data is fully loaded before Silver/Gold transformations begin.

---

## Stage 1: Python Ingestion (Windows Task Scheduler)

### Task Configuration

| Property | Value |
|----------|-------|
| Task Name | Daily Bronze Ingestion |
| Trigger | Daily at 2:30 AM IST |
| Action | Run .bat file |
| Run As | shri-16088 |
| Security | Run whether user is logged on or not |
| Password Storage | "Do not store password" checked (local access only) |

### .bat File

**Location:** Path to your `.bat` file on disk

```batch
@echo off
"C:\Users\shri-16088\AppData\Local\Programs\Python\Python3x\python.exe" "C:\path\to\Bronze_stock_ingestionrealtimedata.py"
"C:\Users\shri-16088\AppData\Local\Programs\Python\Python3x\python.exe" "C:\path\to\Bronze_forex_ingestion.py"
```

**Critical:** Task Scheduler requires **full Python executable paths**, not just `python`. The PATH environment variable is not available in the Task Scheduler execution context.

### Python Script: Bronze_stock_ingestionrealtimedata.py

**Purpose:** Fetch daily stock prices for 12 stocks from Twelve Data API and insert into `bronze_stock_prices`.

**Key Components:**

```python
# Exchange mapping — REQUIRED for non-US stocks
exchange_map = {
    'CEG': 'NASDAQ', 'MP': 'NYSE', 'XOM': 'NYSE', 'F': 'NYSE',
    'RR': 'LSE', 'RBW': 'LSE', 'SHEL': 'LSE',
    'BHEL': 'NSE', 'GMDCLTD': 'NSE', 'ONGC': 'NSE', 'TMPV': 'NSE',
    'VOW': 'XETR'
}

# API symbol mapping — Twelve Data uses different symbols for some stocks
api_symbol_map = {'VOW': 'VOW3'}

# Dynamic date logic — uses lookback window, never hardcoded dates
# Fetches last N trading days and uses duplicate-check before inserting
```

**API Call Pattern:**

```python
import requests

url = "https://api.twelvedata.com/time_series"
params = {
    "symbol": api_symbol,        # e.g., "VOW3" for Volkswagen
    "exchange": exchange,         # e.g., "XETR"
    "interval": "1day",
    "outputsize": lookback_days,  # Dynamic
    "apikey": API_KEY
}
response = requests.get(url, params=params)
```

**Duplicate Prevention:**

```python
# Check latest date already in bronze for each ticker
# Only insert rows with trade_date > latest existing date
```

### Python Script: Bronze_forex_ingestion.py

**Purpose:** Fetch daily forex rates for USD/INR, GBP/INR, EUR/INR.

**Currency Pairs:**
```python
forex_pairs = ['USD/INR', 'GBP/INR', 'EUR/INR']
```

### Python Script: Bronze_fundamentals_ingestion.py

**Purpose:** Fetch quarterly fundamentals via Yahoo Finance `yfinance` library.  
**Frequency:** Manual (quarterly), not automated.

```python
import yfinance as yf

# Yahoo Finance ticker mapping
yahoo_tickers = {
    'CEG': 'CEG', 'MP': 'MP', 'XOM': 'XOM', 'F': 'F',
    'RR': 'RR.L', 'RBW': 'RBW.L', 'SHEL': 'SHEL.L',
    'BHEL': 'BHEL.NS', 'GMDCLTD': 'GMDCLTD.NS', 'ONGC': 'ONGC.NS',
    'VOW': 'VOW3.DE', 'TMPV': 'TMPV.NS'
}
```

---

## Stage 2: SQL Server Agent

### Job Configuration

| Property | Value |
|----------|-------|
| Job Name | Daily Gold Refresh (or similar) |
| Schedule | Daily at 3:00 AM IST |
| Step 1 | EXEC sp_daily_refresh |
| Service Account | NT Service\SQLSERVERAGENT |
| Start Mode | Automatic |

### Master Stored Procedure: sp_daily_refresh

```sql
CREATE PROCEDURE sp_daily_refresh
AS
BEGIN
    EXEC sp_refresh_silver
    EXEC sp_refresh_gold
END
```

**Execution Chain:**
```
sp_daily_refresh
    ├── sp_refresh_silver (Steps 1-3)
    │   ├── TRUNCATE + INSERT silver_stock_prices
    │   ├── TRUNCATE + INSERT silver_stock_fundamentals
    │   └── TRUNCATE + INSERT silver_forex_rates
    │
    └── sp_refresh_gold (Steps 1-7)
        ├── TRUNCATE + INSERT gold_stock_performance
        ├── TRUNCATE + INSERT gold_currency_adjusted_returns
        ├── TRUNCATE + INSERT gold_category_performance
        ├── TRUNCATE + INSERT gold_region_performance
        ├── TRUNCATE + INSERT gold_dividend_analysis
        ├── TRUNCATE + INSERT gold_correlation_matrix
        └── TRUNCATE + INSERT gold_daily_inr_returns
```

### SQL Server Agent Setup Notes

1. **Enable SQL Server Agent:** Must be enabled manually after SQL Server installation:
```sql
EXEC sp_configure 'show advanced options', 1
RECONFIGURE
EXEC sp_configure 'Agent XPs', 1
RECONFIGURE
```

2. **Start Mode:** Must be set to **Automatic** in SQL Server Configuration Manager. After VM restart, the Agent service does not auto-start unless configured.

3. **Verification:**
```sql
-- Check if Agent is running
EXEC xp_servicecontrol 'querystate', 'SQLServerAgent'

-- View job history
SELECT job_name, run_date, run_time, run_status 
FROM msdb.dbo.sysjobhistory 
ORDER BY run_date DESC, run_time DESC
```

---

## End-to-End Pipeline Flow

```
2:30 AM IST ─── Task Scheduler ─── .bat file ─── Python scripts ─── Bronze tables
                                                                          │
                        (30 min gap for API data to fully load)           │
                                                                          ▼
3:00 AM IST ─── SQL Server Agent ─── sp_daily_refresh ─── Silver tables ─── Gold tables
                                                                                │
                                                                                ▼
24/7 ────────── Power BI Gateway ─── DirectQuery ─── Published Dashboard (app.powerbi.com)
```

---

## Troubleshooting

### Task Scheduler Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Task shows "0x1" result | Python path wrong | Use full path to python.exe |
| Task doesn't run at scheduled time | "Run only when user is logged on" | Change to "Run whether user is logged on or not" |
| Task runs but no new data | API rate limit hit | Check Twelve Data dashboard for remaining calls |
| Script error: module not found | Wrong Python environment | Verify pip install location matches python.exe path |

### SQL Server Agent Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Agent not running after VM restart | Start mode set to Manual | Change to Automatic in Configuration Manager |
| Job fails with "Login failed" | Service account permissions | Ensure SQLSERVERAGENT account has db_owner on Global_Portfolio_Analysis |
| sp_refresh_gold errors | Upstream Silver data missing | Run sp_refresh_silver first, verify Silver tables populated |

### Gateway Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Dashboard shows "on premise service issue" | Gateway offline | Check VM is running, gateway app shows green |
| Gateway can't connect to SQL Server | TCP/IP disabled | Enable TCP/IP in SQL Server Configuration Manager → restart SQL Server |
| Authentication failed | Wrong credentials | Update gateway connection with correct Windows username/password |

---

## System Requirements

- **VM must run 24/7** — gateway goes offline if VM sleeps/shuts down
- **Sleep/Hibernate disabled** — Settings → System → Power & Sleep → all set to "Never"
- **Lid close action:** "Do nothing" (Control Panel → Power Options)
- **Power BI Pro license:** Required for gateway + published DirectQuery ($14/user/month)
- **Twelve Data API:** Grow tier ($29/month, 55 calls/day)

---

## Manual Execution (For Testing/Recovery)

```bash
# Step 1: Run Python scripts manually
python Bronze_stock_ingestionrealtimedata.py
python Bronze_forex_ingestion.py

# Step 2: Verify Bronze
# In SSMS:
SELECT TOP 5 * FROM bronze_stock_prices ORDER BY trade_date DESC
SELECT TOP 5 * FROM bronze_forex_rates ORDER BY trade_date DESC
```

```sql
-- Step 3: Run stored procedures
EXEC sp_refresh_silver
EXEC sp_refresh_gold

-- Step 4: Verify Gold
SELECT 'gold_stock_performance' as tbl, COUNT(*) FROM gold_stock_performance
UNION ALL SELECT 'gold_daily_inr_returns', COUNT(*) FROM gold_daily_inr_returns
```

```
Step 5: Refresh published Power BI report in browser
```
