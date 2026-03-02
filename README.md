# Marketing KPI Analytics Dashboard

**Consolidating scattered retail KPIs into a unified executive health check platform**

## 📊 Business Challenge

The Marketing team needed to monitor customer acquisition, retention, and channel behavior KPIs but faced significant operational friction:

### The Fragmented Landscape:

* **KPIs scattered across 3-5 different systems** - Board BI screens, on-demand SQL queries, manual Excel reports
* **No unified view** - Executives had to check multiple systems to get complete picture of customer health
* **Time-consuming health checks** - Estimated 30-60 minutes to manually gather all metrics for weekly review
* **Inconsistent time periods** - Different systems used different date ranges, making comparisons difficult
* **No year-over-year tracking** - Manual calculation required to compare current vs prior year performance
* **Limited segment analysis** - Couldn't easily drill into specific customer groups (New, Lost, Reactivated)

### Business Impact:

* Weekly executive reviews delayed while waiting for metric compilation
* Missed early warning signals due to incomplete data visibility
* Decision-making based on partial information
* Significant analyst time spent on manual data gathering vs strategic analysis

## ✨ Solution

Built a comprehensive Power BI dashboard consolidating all critical customer KPIs with automated weekly refresh and multi-period comparative analysis across four standardized time windows.

### Core Capabilities:

* **Unified KPI Dashboard** - All customer metrics in single view with automatic weekly refresh
* **Multi-Period Analysis** - Four standardized time windows (L12M, FYTD, STD, YTD) with automatic boundary calculations
* **Year-over-Year Comparison** - Current Year (CY) vs Prior Year (PY) variance tracking for every KPI
* **Focused Segment Analysis** - Drill into New Customers, Lost/Reactivated, Known Customers cohorts
* **Channel Behavior Tracking** - Online/Offline/Omni customer classification across all time periods
* **Custom Bookmark Navigation** - Sophisticated slicer synchronization ensuring data integrity
* **Automated Data Refresh** - Weekly SQL pre-calculation eliminates manual data gathering

## 📈 Results

| Metric | Before | After | Impact |
|--------|--------|-------|---------|
| **Systems to Check** | 3-5 different tools | 1 unified dashboard | **80% reduction** |
| **Weekly Health Check Time** | 30-60 minutes | <5 minutes | **90% time savings** |
| **KPI Consistency** | Manual reconciliation | Automated calculation | **Eliminated errors** |
| **YoY Comparison** | Manual Excel formulas | Automatic variance % | **Built-in** |
| **Data Freshness** | On-demand queries | Weekly auto-refresh | **Reliable cadence** |
| **Analyst Time Saved** | ~45 min/week × 52 weeks | - | **~40 hours annually** |

## 🎯 Multi-Period Analysis Framework

### Time Period Definitions

The dashboard supports four standardized time windows, each with specific business purposes:

**L12M (Last 12 Months)**
- Rolling 12-month window from today
- Captures full seasonal cycle (Winter + Summer)
- Best for trend analysis and customer lifecycle tracking

**FYTD (Fiscal Year-to-Date)**
- Starts February 1 (aligned with retail fiscal calendar)
- Tracks performance against fiscal year goals
- Why February: Retail seasonality (post-holiday reset)

**STD (Season-to-Date)**
- Starts February 1 (Summer season) or August 1 (Winter season)
- Compares current season performance to prior season
- Critical for seasonal retail planning

**YTD (Year-to-Date)**
- Starts January 1 (calendar year)
- Standard calendar comparison for financial reporting
- Aligns with external benchmarking

### Why Multiple Time Periods?

Retail customer behavior requires different analytical lenses:
- **L12M** answers: "Are we growing our active customer base year-over-year?"
- **FYTD** answers: "Are we on track to hit our fiscal year targets?"
- **STD** answers: "Is this season performing better than last season?"
- **YTD** answers: "How does this calendar year compare to prior year?"

Each period provides unique insights; together they create comprehensive visibility.

## 📊 Key Performance Indicators

### Customer Acquisition & Retention

**Active Customers**
- Customers with purchases in selected time period
- Tracked across all four periods (L12M, FYTD, STD, YTD)
- Variance vs prior year shows growth/decline trends

**Known Customers**
- Customers active in extended 24-month window
- Definition: Active anytime in [Period Start - 12 months] to [Period End]
- Example: FYTD Known = Active from (FYTD_Start - 12M) to Today
- Critical for calculating Loyalty Rate

**Loyalty Rate**
- Formula: Active Customers / Known Customers
- Measures retention: What % of known customers remained active?
- Higher % = better retention, lower % = increased churn

**New Customers**
- First purchase in selected period
- Validated with €20+ transaction threshold (excludes micro-transactions)
- Tracks acquisition effectiveness

**Reactivated Customers**
- Purchased previously, went dormant, came back in current period
- Measures win-back campaign success
- High-value segment (proven willingness to return)

### Revenue & Transaction Metrics

**Total Revenue**
- Revenue from all active customers in period
- Split by channel (Online/Offline/Omni)
- Variance vs prior year tracks growth

**Revenue per Active Customer**
- Average revenue generated per active customer
- Measures customer value efficiency
- Declining metric may indicate need for upsell strategies

**Tickets per Active Customer**
- Average number of shopping trips per customer
- Measures engagement frequency
- Declining metric signals reduced loyalty

**Revenue per Ticket**
- Average transaction value
- Measures basket size and upsell effectiveness

**Items per Ticket**
- Average number of items purchased per transaction
- Indicates cross-sell effectiveness

**Revenue per Item**
- Average revenue per individual item
- Tracks pricing and product mix trends

### Channel Behavior Analysis

**Channel Classification:**
- **Online** - Purchases only through e-commerce stores (Store IDs: 801, 802, 803)
- **Offline** - Purchases only through physical retail locations
- **Omni** - Purchases across both channels (omnichannel customers)

**Why Track Channel by Period:**
- Customer channel preference changes over time
- Omni customers are typically highest-value segment
- Enables targeted channel-specific marketing strategies

**Dual Channel Tracking:**
- **Regular Channel** - Based on selected period only (L12M, FYTD, STD, YTD)
- **Known Channel** - Based on extended 24-month window
- Why both: Known Customers need longer lookback for accurate classification

## 🏗️ Technical Architecture

### System Design

```
Azure SQL Database → Weekly Pre-Calculation → Power BI Service → Executive Dashboard
        ↓                      ↓                       ↓
  Multi-Period Logic     Microsoft Fabric       4 Time Period Views
  Channel Classification    Notebook           Bookmark Navigation
  CY/PY Variance Calc     Orchestration         Automated Refresh
```

### Data Model

The dashboard uses a **shared fact table** architecture with the RFM segmentation project:

**Shared Tables:**
- **FactSales** - Transaction-level data (daily refresh for current-period metrics)
- **DimCustomer** - Customer master data
- **DimProduct** - Product categories and attributes
- **DimStore** - Store locations and channel classification
- **DateTable** - Date dimension with fiscal periods

**KPI-Specific Tables:**
- **Customers_KPI** - Pre-calculated customer metrics (weekly refresh)
- **CustomerActivityHistory** - Historical activity for cohort classification
- **DimChannel** - Channel slicer table (disconnected)
- **Time Calculation Slicer** - Period selection control

### The Bookmark Navigator Challenge

**The Technical Problem:**

The dashboard required tracking channel behavior across:
1. Four time periods (L12M, FYTD, STD, YTD)
2. Two customer definitions (Regular vs Known - 24M window)
3. Two years (Current Year vs Prior Year for variance)

This created a **slicer architecture challenge:**

**Initial approach:**
- Regular customers: `Channel_L12M`, `Channel_FYTD`, `Channel_STD`, `Channel_YTD` (4 slicers)
- Known customers: `Known_Channel_L12M`, `Known_Channel_FYTD`, etc. (4 more slicers)
- Result: **8 slicers total** for CY alone

**Adding Prior Year variance:**
- PY Regular: `PY_Channel_L12M`, `PY_Channel_FYTD`, etc. (4 slicers)
- PY Known: `PY_Known_Channel_L12M`, etc. (4 slicers)
- **Total: 16 slicers across CY and PY**

**Variance calculation complexity:**
- Variance KPIs (e.g., Active Customers % change) required specific CY/PY slicer combinations
- Visual-level filter interactions needed manual configuration for each variance metric
- Dynamic year selection broke variance calculations

**Final slicer count: 4 synchronized slicers**
- `Channel` (Regular - CY)
- `Known_Channel` (Known - CY)  
- `PY_Channel` (Regular - PY)
- `PY_Known_Channel` (Known - PY)

**The Core Problem:**

Users **must select matching values** across all 4 slicers to get valid results:
- ✅ Correct: Online, Online, Online, Online
- ❌ Invalid: Online, Offline, Online, Online (produces nonsensical variance)

**Exposing 4 slicers = guaranteed user error** and invalid analysis.

### The Bookmark Navigator Solution

**Design Approach:**

1. **Hide all 4 slicers** from view (users cannot interact directly)
2. **Create synchronized bookmark presets** for each channel combination:
   - "Online" bookmark → sets all 4 slicers to "Online"
   - "Offline" bookmark → sets all 4 slicers to "Offline"
   - "Omni" bookmark → sets all 4 slicers to "Omni"
   - "All Channels" bookmark → clears all 4 slicers
3. **Build custom bookmark navigator button** instead of traditional bookmark buttons
4. **User clicks single control** → all 4 slicers synchronized automatically

**Why This Works:**

* **Eliminates user error** - Impossible to create invalid slicer combinations
* **Preserves data integrity** - Variance calculations always use matching CY/PY filters
* **Clean UX** - Users see one intuitive control instead of confusing slicer bank
* **Scalable** - Can add new bookmark states without increasing UI complexity

**Alternative Approaches Considered:**

* **Dynamic year slicer** - Broke variance calculations (requires independent CY/PY columns)
* **DAX-based filter logic** - Too complex, performance issues with multiple CALCULATE layers
* **Traditional bookmark buttons** - Cluttered interface, didn't scale well across 4 time period tabs
* **Slicer panel with instructions** - Users reliably ignored instructions, created invalid states

**Why Sophisticated:**

Traditional approach:
- Expose slicers with instructions ("Please match all values")
- Accept that users will make mistakes
- Fix issues reactively when executives report wrong numbers

This solution:
- Recognizes users won't follow complex instructions
- Prevents errors through interface design
- Ensures data integrity is structurally impossible to break

Shows understanding of both **technical constraints** (variance requires independent filters) **AND** human behavior (users won't maintain 4-slicer synchronization manually).

## 💻 Technical Implementation

### Technologies Used

* **Azure SQL Database** - Data warehouse and pre-calculation engine
* **Microsoft Fabric Notebooks** - Orchestration and job scheduling
* **Power BI Service** - Interactive dashboard and data refresh
* **DAX** - Time intelligence calculations and variance logic
* **SQL** - Complex multi-period aggregations

### Key Technical Features

**1. Automated Time Period Boundaries**

SQL calculates period start dates dynamically based on current date:

```sql
-- Fiscal YTD starts February 1
DECLARE @FYTD_Start DATE = CASE 
    WHEN MONTH(@Today) >= 2 THEN DATEFROMPARTS(YEAR(@Today), 2, 1)
    ELSE DATEFROMPARTS(YEAR(@Today) - 1, 2, 1)
END;

-- Season-to-Date: Feb 1 (Summer) or Aug 1 (Winter)
DECLARE @STD_Start DATE = CASE 
    WHEN MONTH(@Today) >= 8 THEN DATEFROMPARTS(YEAR(@Today), 8, 1)
    WHEN MONTH(@Today) >= 2 THEN DATEFROMPARTS(YEAR(@Today), 2, 1)
    ELSE DATEFROMPARTS(YEAR(@Today) - 1, 8, 1)
END;
```

No manual date updates required - periods automatically adjust with each refresh.

**2. Known Customer 24-Month Lookback**

"Known Customers" use extended time window (current period + prior 12 months):

```sql
-- Known L12M uses 24M lookback
DATEADD(MONTH, -24, @Today)

-- Known FYTD uses FYTD start - 12M
DATEADD(MONTH, -12, @FYTD_Start)
```

This enables accurate loyalty rate calculation (Active / Known).

**3. Channel Classification Logic**

Determines Online/Offline/Omni based on store IDs:

```sql
CASE 
    WHEN SUM(CASE WHEN STORE_ID IN ('801', '802', '803') THEN REVENUE ELSE 0 END) > 0
    AND SUM(CASE WHEN STORE_ID NOT IN ('801', '802', '803') THEN REVENUE ELSE 0 END) > 0 
    THEN 'Omni'
    WHEN SUM(CASE WHEN STORE_ID IN ('801', '802', '803') THEN REVENUE ELSE 0 END) > 0 
    THEN 'Online'
    WHEN SUM(CASE WHEN STORE_ID NOT IN ('801', '802', '803') THEN REVENUE ELSE 0 END) > 0 
    THEN 'Offline'
END
```

Calculated independently for each period × customer definition × year combination.

**4. New Customer Validation**

Ensures quality threshold for "New Customer" classification:

```sql
WITH QualifyingNewCustomers AS (
    SELECT DISTINCT CUSTOMER_ID
    FROM (
        SELECT CUSTOMER_ID, TRANSACTION_ID, SUM(NET_AMOUNT) as Total
        FROM Sales
        WHERE SEASON_ID = FIRST_PURCHASE_SEASON
        GROUP BY CUSTOMER_ID, TRANSACTION_ID
        HAVING SUM(NET_AMOUNT) >= 20  -- Minimum €20 transaction
    )
)
```

Excludes customers whose first purchase was only micro-transactions or promotional items.

See [sql/kpi_weekly_refresh.sql](sql/kpi_weekly_refresh.sql) for complete query logic.

## 🎓 Skills Demonstrated

### Business Analysis & Requirements Translation

* Identified pain points in fragmented KPI landscape
* Defined standardized time period framework aligned with business needs
* Balanced multiple stakeholder requirements (Finance fiscal calendar, Marketing seasonal planning, Executive calendar reporting)

### Advanced Power BI Development

* **Bookmark navigation architecture** - Solved complex slicer synchronization challenge
* **Time intelligence** - Four independent period calculations with automatic boundary detection
* **Variance calculations** - Year-over-year comparison requiring independent CY/PY filter context
* **Performance optimization** - Pre-calculated SQL tables prevent dashboard timeout

### SQL Development

* **Multi-period aggregations** - Parallel calculations across L12M/FYTD/STD/YTD in single query
* **Window functions** - Channel classification across varying time windows
* **Complex business logic** - Known Customer 24M lookback, New Customer validation
* **Query optimization** - Processes hundreds of thousands of customers in <10 minutes

### Data Architecture

* **Shared fact table design** - Reused Sales fact across RFM and KPI projects
* **Pre-calculation strategy** - Offloaded heavy computation to SQL for Power BI performance
* **Dual-refresh cadence** - Weekly KPI table, daily Sales fact for current metrics

### UX & Product Thinking

* **Recognized human behavior patterns** - Users won't maintain manual slicer synchronization
* **Designed for error prevention** - Made invalid states impossible vs relying on user compliance
* **Simplified complex requirements** - Four time periods × dual customer definitions → clean single-control interface

## 📁 Repository Structure

```
marketing-kpi-analytics/
├── README.md                          # This file
├── screenshots/                       # Dashboard views (censored)
│   ├── Sales_KPI.png                  # Main KPI overview (L12M)
│   ├── L12M_KPI.png                   # Last 12 Months view
│   ├── FYTD_KPI.png                   # Fiscal YTD view
│   ├── STD_KPI.png                    # Season-to-Date view
│   ├── YTD_KPI.png                    # Year-to-Date view
│   └── Model_KPI.png                  # Power BI data model
├── sql/
│   └── kpi_weekly_refresh.sql        # Weekly refresh query (sanitized)
├── documentation/
│   └── technical_approach.md         # Detailed implementation notes
└── LICENSE                           # MIT License
```

## 🔐 Privacy & Data Sanitization

* **Company identifiers** removed (database names, table prefixes anonymized as "Company A")
* **Store IDs** generalized (actual store numbers replaced with examples)
* **Screenshots** fully censored (all KPI values and company branding removed)
* **Business thresholds** not disclosed (€20 validation mentioned as example, actual values may differ)
* **No production data** included in repository
* **SQL/DAX logic** sanitized but functionally identical to production code

This portfolio demonstrates the methodology, architecture, and problem-solving approach without exposing proprietary business information.

## 💡 Key Takeaways & Impact

### What Worked Well

✅ **Multi-period framework** - Standardized time windows eliminated inconsistency across teams  
✅ **Bookmark navigator** - Elegant solution to complex UX challenge, prevented user errors  
✅ **Weekly automation** - Executives always have current data without manual requests  
✅ **System consolidation** - Single source of truth replaced fragmented tooling  
✅ **YoY variance** - Built-in comparison enabled faster trend identification  

### Business Value Delivered

* **Executive efficiency** - Weekly health checks reduced from 60 minutes to 5 minutes
* **Data consistency** - Automated calculations eliminated manual reconciliation errors
* **Decision speed** - Real-time KPI access accelerated strategic responses
* **Analyst time freed** - 40+ hours annually reallocated from manual reporting to strategic analysis
* **Scalable foundation** - Framework supports adding new KPIs without architectural changes

### Technical Lessons Learned

* **UX design prevents errors better than instructions** - Make invalid states impossible vs hoping users follow rules
* **Pre-calculation enables interactivity** - Heavy SQL computation allows snappy Power BI performance
* **Time intelligence requires careful planning** - Multiple period definitions demand clear business logic documentation
* **Variance calculations need independent filters** - Dynamic year selection incompatible with CY/PY comparison metrics

## 📞 Contact

**Mehmet Cetin**  
Business Intelligence Analyst | Data Analytics Professional

* LinkedIn: https://www.linkedin.com/in/mehmet-cetin-461674a4/
* Email: mcetin11@gmail.com
* GitHub: https://github.com/mcetin-data

---

*This project demonstrates advanced Power BI development, SQL optimization, and user-centric design for executive analytics. Available for discussion in technical interviews.*

## About

Consolidated marketing KPI dashboard with multi-period analysis, automated refresh, and sophisticated bookmark navigation for retail customer metrics

### License

MIT License

### Topics

`power-bi` `data-analytics` `kpi-dashboard` `retail-analytics` `sql-server` `azure-sql` `microsoft-fabric` `business-intelligence` `executive-dashboard` `time-intelligence` `bookmark-navigation` `multi-period-analysis`
