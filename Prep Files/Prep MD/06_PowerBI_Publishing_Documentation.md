# Power BI Publishing & Gateway Documentation
## Global Investment Portfolio Analytics

**Last Updated:** April 4, 2026  
**Author:** Arravind Shri  
**Power BI Account:** shri@arravindportfolio.tech

---

## Overview

The Power BI dashboard connects to SQL Server via DirectQuery and is published to Power BI Service (app.powerbi.com) using an On-premises Data Gateway. This enables live data — every interaction with the published dashboard queries the local SQL Server in real time.

---

## Architecture

```
User (Browser/Mobile)
    │
    ▼
Power BI Service (app.powerbi.com)
    │
    ▼ (DirectQuery request)
On-premises Data Gateway (Portfolio_Gateway)
    │
    ▼ (TCP/IP connection)
SQL Server (localhost / SHRIARRAVIN0BA7)
    │
    ▼
Global_Portfolio_Analysis database
```

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| Power BI Pro License | $14/user/month (or 60-day free trial) |
| On-premises Data Gateway | Free download from Microsoft |
| SQL Server TCP/IP | Must be enabled in SQL Server Configuration Manager |
| Windows Password | Required for gateway authentication |
| VM Always On | Sleep, hibernate, lid-close all set to "Do nothing" / "Never" |

---

## Step 1: Power BI Pro License

1. Go to **app.powerbi.com**
2. Sign in with Microsoft account
3. Activate **Power BI Pro free trial** (60 days) or purchase ($14/month)
4. Verify: top-right of Power BI Service should show "Trials activated: XX days left"

---

## Step 2: Install On-premises Data Gateway

1. Download from: **https://aka.ms/gateway** (or search "Power BI on-premises data gateway download")
2. Run installer
3. Select **"On-premises data gateway (recommended)"** — NOT personal mode
4. Sign in with the same Microsoft account used for Power BI Service
5. Select **"Register a new gateway on this computer"**
6. Name: `Portfolio_Gateway`
7. Set a **recovery key** — save it securely
8. Verify: gateway app shows **green status = "Ready"**

**Gateway Service:** Runs as `NT SERVICE\PBIEgwService` — starts automatically with Windows.

---

## Step 3: Enable SQL Server TCP/IP

The gateway connects via TCP/IP, not shared memory. This must be enabled:

1. Open **SQL Server Configuration Manager**
   - Search Windows Start menu for "SQL Server Configuration Manager"
   - Or run: `SQLServerManager14.msc` (from `C:\Windows\SysWOW64\`)
2. Navigate to: **SQL Server Network Configuration → Protocols for MSSQLSERVER**
3. Right-click **TCP/IP** → **Enable**
4. **Restart SQL Server service** (right-click SQL Server in Services → Restart)

---

## Step 4: Configure Gateway Connection

1. Go to **app.powerbi.com** → **Settings (gear icon)** → **Manage Connections and Gateways**
2. Click **"+ New"**
3. Configure:

| Field | Value |
|-------|-------|
| Connection type | On-premises |
| Gateway cluster | Portfolio_Gateway |
| Connection name | Global Portfolio Analysis |
| Connection type | SQL Server |
| Server | localhost |
| Database | Global_Portfolio_Analysis |
| Authentication | Windows |
| Username | SHRIARRAVIN0BA7\shri-16088 |
| Password | [Your Windows password] |

4. Click **Create**
5. Verify: connection shows **green checkmark** in the Connections list

**Note on Server Name:** If `localhost` doesn't work, try the machine name `SHRIARRAVIN0BA7`. The gateway resolves names differently than local applications.

---

## Step 5: Publish from Power BI Desktop

1. Open your `.pbix` file in Power BI Desktop
2. **File → Publish**
3. Select **"My workspace"**
4. Wait for upload to complete
5. You'll see: "Your file was published, but disconnected" — this is normal for DirectQuery

---

## Step 6: Map Gateway to Dataset

1. Go to **app.powerbi.com** → **My workspace**
2. Find your dataset (Semantic model) — click the **three dots (...)** → **Settings**
3. Scroll to **"Gateway and cloud connections"**
4. Toggle ON: **"Use an On-premises or VNet data gateway"**
5. Select **Portfolio_Gateway** (should show "Running on SHRIARRAVIN0BA7")
6. Under "Data sources included in this semantic model":
   - Verify it shows: `SqlServer{"server":"localhost","database":"global_portfolio_analysis"}`
   - "Maps to" dropdown: select **Global Portfolio Analysis**
7. Click **Apply**

---

## Step 7: Verify Published Dashboard

1. Go to **My workspace** → click on the **Report** (not Semantic model)
2. All pages should load with live data from SQL Server
3. Click through slicers, change years — every interaction should return data
4. If errors appear, check:
   - Gateway app is running (green status)
   - VM is on and not sleeping
   - SQL Server service is running

---

## Sharing the Dashboard

### Generate Public URL

1. In the published report, click **File → Embed report → Website or portal**
2. Copy the embed URL
3. Or use **Share** button → enter email addresses of recipients (they need Power BI Pro too)

### Share Without Pro License (Viewers)

Free viewers can only access reports if you have **Power BI Premium capacity** or **Microsoft Fabric F64+**. With Pro-only licensing, both creator and viewer need Pro licenses.

**Alternative for portfolio sharing:** Use **"Publish to web"** (File → Embed → Publish to web) — this creates a public URL anyone can access without a license. Note: this makes the data publicly accessible.

---

## Re-publishing After Changes

When you modify the dashboard in Power BI Desktop:

1. Make changes in Power BI Desktop
2. **File → Publish → My workspace**
3. When prompted "Replace existing dataset?", click **Replace**
4. The gateway mapping persists — no need to reconfigure
5. Refresh the published report in browser to see changes

---

## Monitoring & Maintenance

### Daily Checks (Optional)

```
1. Open gateway app → confirm green status
2. Open published report → verify data loads
3. Check SSMS → SELECT MAX(trade_date) FROM bronze_stock_prices
   (should show previous trading day)
```

### Gateway Logs

Gateway app → **Diagnostics** tab → **Export logs**. Useful for troubleshooting connection failures.

### Refresh History

In Power BI Service: dataset Settings → **Refresh history**. Shows timestamps and success/failure of any scheduled refreshes. For DirectQuery, this is less relevant since data is live.

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| "On premise service issue" on all visuals | Gateway offline | Open gateway app on VM, ensure green status |
| Gateway shows offline | VM is sleeping or shut down | Wake VM, check power settings |
| "RuntimeCheckFailedError" | Server name mismatch | Gateway connection server must match Power BI Desktop connection (both use `localhost` or both use machine name) |
| Report loads but data is stale | sp_daily_refresh didn't run | Check SQL Server Agent job history; run EXEC sp_daily_refresh manually |
| "Cannot connect to data source" | TCP/IP disabled on SQL Server | Enable in SQL Server Configuration Manager → restart SQL Server |
| Gateway auth fails | Wrong password | Update credentials in Manage Connections and Gateways |
| Published report shows errors after republish | Gateway mapping lost | Rare — go to dataset Settings and re-map gateway |

---

## Key Configuration Summary

| Component | Configuration |
|-----------|--------------|
| Power BI Desktop connection | DirectQuery, localhost, Global_Portfolio_Analysis, Windows Auth |
| Gateway name | Portfolio_Gateway |
| Gateway connection name | Global Portfolio Analysis |
| Gateway server | localhost (or SHRIARRAVIN0BA7) |
| Gateway database | Global_Portfolio_Analysis |
| Gateway auth | Windows (SHRIARRAVIN0BA7\shri-16088) |
| Published workspace | My workspace |
| Report name | Global Portfolio Analysis- Real Project-1 |
| VM power settings | Sleep: Never, Lid close: Do nothing |
| SQL Server TCP/IP | Enabled |
| SQL Server Agent | Automatic start mode |
