-- ========================================
-- Marketing KPI Dashboard - Weekly Data Refresh
-- Consolidates customer metrics across multiple time periods
-- Run frequency: Weekly (automated via Microsoft Fabric notebook)
-- ========================================

USE BI_Sandbox;
GO

DECLARE @StartTime DATETIME = GETDATE();
DECLARE @Today DATE = CAST(GETDATE() AS DATE);

PRINT '========================================';
PRINT 'Starting weekly KPI refresh...';
PRINT 'Started at: ' + CONVERT(VARCHAR, @StartTime, 120);
PRINT '========================================';

PRINT 'Truncating existing data...';
TRUNCATE TABLE DW.Customers_KPI;
PRINT 'Table truncated. Recalculating fresh data...';
PRINT '';

-- Calculate time period boundaries
-- Current Year (CY) periods
DECLARE @CY_L12M_Start DATE = DATEADD(MONTH, -12, @Today);
DECLARE @CY_FYTD_Start DATE = CASE 
    WHEN MONTH(@Today) >= 2 THEN DATEFROMPARTS(YEAR(@Today), 2, 1)
    ELSE DATEFROMPARTS(YEAR(@Today) - 1, 2, 1)
END;
DECLARE @CY_STD_Start DATE = CASE 
    WHEN MONTH(@Today) >= 8 THEN DATEFROMPARTS(YEAR(@Today), 8, 1)
    WHEN MONTH(@Today) >= 2 THEN DATEFROMPARTS(YEAR(@Today), 2, 1)
    ELSE DATEFROMPARTS(YEAR(@Today) - 1, 8, 1)
END;
DECLARE @CY_YTD_Start DATE = DATEFROMPARTS(YEAR(@Today), 1, 1);

-- Prior Year (PY) periods for variance calculations
DECLARE @PY_Today DATE = DATEADD(YEAR, -1, @Today);
DECLARE @PY_L12M_Start DATE = DATEADD(MONTH, -12, @PY_Today);
DECLARE @PY_FYTD_Start DATE = CASE 
    WHEN MONTH(@PY_Today) >= 2 THEN DATEFROMPARTS(YEAR(@PY_Today), 2, 1)
    ELSE DATEFROMPARTS(YEAR(@PY_Today) - 1, 2, 1)
END;
DECLARE @PY_STD_Start DATE = CASE 
    WHEN MONTH(@PY_Today) >= 8 THEN DATEFROMPARTS(YEAR(@PY_Today), 8, 1)
    WHEN MONTH(@PY_Today) >= 2 THEN DATEFROMPARTS(YEAR(@PY_Today), 2, 1)
    ELSE DATEFROMPARTS(YEAR(@PY_Today) - 1, 8, 1)
END;
DECLARE @PY_YTD_Start DATE = DATEFROMPARTS(YEAR(@PY_Today), 1, 1);

PRINT 'Period boundaries calculated:';
PRINT '  CY L12M: ' + CONVERT(VARCHAR, @CY_L12M_Start, 23) + ' to ' + CONVERT(VARCHAR, @Today, 23);
PRINT '  CY FYTD: ' + CONVERT(VARCHAR, @CY_FYTD_Start, 23) + ' to ' + CONVERT(VARCHAR, @Today, 23);
PRINT '  CY STD:  ' + CONVERT(VARCHAR, @CY_STD_Start, 23) + ' to ' + CONVERT(VARCHAR, @Today, 23);
PRINT '  CY YTD:  ' + CONVERT(VARCHAR, @CY_YTD_Start, 23) + ' to ' + CONVERT(VARCHAR, @Today, 23);
PRINT '';

-- Identify duplicate card users (data quality check)
WITH CardDuplicates AS (
    SELECT CARD_NUMBER, MAX(CUSTOMER_ID) AS DEDUPE_ID, COUNT(*) AS DUPLICATE_COUNT
    FROM DW_Sources.HST.Customer_Cards
    GROUP BY CARD_NUMBER
    HAVING COUNT(*) > 1
),

-- Identify qualifying new customers (€20+ first season threshold)
QualifyingNewCustomers AS (
    SELECT DISTINCT CUSTOMER_ID
    FROM (
        SELECT 
            s.CUSTOMER_ID, 
            s.TRANSACTION_ID, 
            c.FIRST_PURCHASE_DATE_KEY, 
            nd.SEASON_ID as FirstSeasonID, 
            d.SEASON_ID as TransactionSeasonID, 
            SUM(s.NET_AMOUNT) as NetTransactionAmount
        FROM DW.FACT.Sales s
        INNER JOIN DW.DIM.Customer c ON c.CUSTOMER_ID = s.CUSTOMER_ID
        INNER JOIN DW.DIM.Date nd ON nd.DATE_KEY = c.FIRST_PURCHASE_DATE_KEY
        INNER JOIN DW.DIM.Date d ON d.DATE_KEY = s.TRANSACTION_DATE_KEY
        WHERE s.CUSTOMER_ID > 0 
            AND c.DATA_SOURCE = 'MAIN' 
            AND d.SEASON_ID = nd.SEASON_ID 
            AND nd.SEASON_ID >= 201601
        GROUP BY s.CUSTOMER_ID, s.TRANSACTION_ID, c.FIRST_PURCHASE_DATE_KEY, nd.SEASON_ID, d.SEASON_ID
        HAVING SUM(s.NET_AMOUNT) >= 20
    ) AS TransactionCheck
),

-- Calculate first season activity metrics
FirstSeasonActivity AS (
    SELECT 
        s.CUSTOMER_ID, 
        s.CUSTOMER_CODE, 
        c.FIRST_PURCHASE_DATE_KEY, 
        nd.SEASON_ID AS First_Purchase_Season,
        MIN(s.TRANSACTION_DATE_KEY) AS First_Season_Purchase_Key, 
        MAX(s.TRANSACTION_DATE_KEY) AS Last_Season_Purchase_Key,
        SUM(s.NET_AMOUNT) AS First_Season_Revenue,
        SUM(CASE WHEN LEFT(st.STORE_ID, 1) = '8' THEN s.NET_AMOUNT ELSE 0.0 END) AS Revenue_Online,
        SUM(CASE WHEN LEFT(st.STORE_ID, 1) != '8' THEN s.NET_AMOUNT ELSE 0.0 END) AS Revenue_Offline,
        SUM(CASE WHEN p.CATEGORY_AGE_DESC LIKE '%BABY%' THEN s.NET_AMOUNT ELSE 0.0 END) AS Baby_Revenue,
        SUM(CASE WHEN p.DEPARTMENT_CODE = 'K' THEN s.NET_AMOUNT ELSE 0.0 END) AS Kids_Revenue,
        SUM(CASE WHEN p.DEPARTMENT_CODE = 'W' THEN s.NET_AMOUNT ELSE 0.0 END) AS Womens_Revenue,
        SUM(CASE WHEN p.DEPARTMENT_CODE = 'M' THEN s.NET_AMOUNT ELSE 0.0 END) AS Mens_Revenue
    FROM DW.FACT.Sales s
    INNER JOIN DW.DIM.Customer c ON c.CUSTOMER_ID = s.CUSTOMER_ID
    INNER JOIN DW.DIM.Date nd ON nd.DATE_KEY = c.FIRST_PURCHASE_DATE_KEY
    INNER JOIN DW.DIM.Store st ON st.STORE_ID = s.STORE_ID
    INNER JOIN DW.DIM.Date d ON d.DATE_KEY = s.TRANSACTION_DATE_KEY
    INNER JOIN DW.DIM.Product p ON p.PRODUCT_ID = s.PRODUCT_ID
    LEFT JOIN CardDuplicates cd ON cd.DEDUPE_ID = s.CUSTOMER_CODE
    WHERE s.CUSTOMER_ID IN (SELECT CUSTOMER_ID FROM QualifyingNewCustomers)
        AND cd.DEDUPE_ID IS NULL 
        AND c.DATA_SOURCE = 'MAIN' 
        AND st.DATA_SOURCE = 'MAIN' 
        AND d.SEASON_ID = nd.SEASON_ID 
        AND nd.SEASON_ID >= 201601
    GROUP BY s.CUSTOMER_ID, s.CUSTOMER_CODE, c.FIRST_PURCHASE_DATE_KEY, nd.SEASON_ID
    HAVING SUM(s.NET_AMOUNT) > 0
),

-- Classify customers by purchase patterns (Kids/Women's/Men's/Mixed)
CustomerSegments AS (
    SELECT *,
        CASE
            WHEN Kids_Revenue > 0 AND Womens_Revenue <= 0 AND Mens_Revenue <= 0 THEN 'K'
            WHEN Kids_Revenue <= 0 AND Womens_Revenue > 0 AND Mens_Revenue <= 0 THEN 'W'
            WHEN Kids_Revenue <= 0 AND Womens_Revenue <= 0 AND Mens_Revenue > 0 THEN 'M'
            WHEN Kids_Revenue > 0 AND Womens_Revenue > 0 AND Mens_Revenue <= 0 THEN 'KW'
            WHEN Kids_Revenue > 0 AND Womens_Revenue <= 0 AND Mens_Revenue > 0 THEN 'KM'
            WHEN Kids_Revenue <= 0 AND Womens_Revenue > 0 AND Mens_Revenue > 0 THEN 'WM'
            WHEN Kids_Revenue > 0 AND Womens_Revenue > 0 AND Mens_Revenue > 0 THEN 'KWM'
            ELSE NULL 
        END AS Family_Segment,
        CASE
            WHEN Revenue_Online > 0 AND Revenue_Offline <= 0 THEN 'Online'
            WHEN Revenue_Online <= 0 AND Revenue_Offline > 0 THEN 'Offline'
            WHEN Revenue_Online > 0 AND Revenue_Offline > 0 THEN 'Omni'
            ELSE NULL 
        END AS Omni_Segment
    FROM FirstSeasonActivity
),

-- Calculate channel behavior for Current Year periods
CustomerChannelByPeriod_CY AS (
    SELECT 
        s.CUSTOMER_ID,
        -- L12M Channel Classification
        CASE 
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @CY_L12M_Start AND d.DATE_VALUE <= @Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0
            AND SUM(CASE WHEN d.DATE_VALUE >= @CY_L12M_Start AND d.DATE_VALUE <= @Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Omni'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @CY_L12M_Start AND d.DATE_VALUE <= @Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Online'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @CY_L12M_Start AND d.DATE_VALUE <= @Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Offline' 
        END AS Channel_L12M,
        -- FYTD Channel Classification
        CASE 
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @CY_FYTD_Start AND d.DATE_VALUE <= @Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0
            AND SUM(CASE WHEN d.DATE_VALUE >= @CY_FYTD_Start AND d.DATE_VALUE <= @Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Omni'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @CY_FYTD_Start AND d.DATE_VALUE <= @Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Online'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @CY_FYTD_Start AND d.DATE_VALUE <= @Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Offline' 
        END AS Channel_FYTD,
        -- STD Channel Classification
        CASE 
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @CY_STD_Start AND d.DATE_VALUE <= @Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0
            AND SUM(CASE WHEN d.DATE_VALUE >= @CY_STD_Start AND d.DATE_VALUE <= @Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Omni'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @CY_STD_Start AND d.DATE_VALUE <= @Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Online'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @CY_STD_Start AND d.DATE_VALUE <= @Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Offline' 
        END AS Channel_STD,
        -- YTD Channel Classification
        CASE 
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @CY_YTD_Start AND d.DATE_VALUE <= @Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0
            AND SUM(CASE WHEN d.DATE_VALUE >= @CY_YTD_Start AND d.DATE_VALUE <= @Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Omni'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @CY_YTD_Start AND d.DATE_VALUE <= @Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Online'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @CY_YTD_Start AND d.DATE_VALUE <= @Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Offline' 
        END AS Channel_YTD
    FROM DW.FACT.Sales s
    INNER JOIN DW.DIM.Date d ON d.DATE_KEY = s.TRANSACTION_DATE_KEY
    INNER JOIN DW.DIM.Store st ON st.STORE_ID = s.STORE_ID
    WHERE s.CUSTOMER_ID > 0 
        AND s.QUANTITY > 0 
        AND d.DATE_VALUE >= @CY_L12M_Start 
        AND d.DATE_VALUE <= @Today 
        AND s.DATA_SOURCE <> 'EXCLUDE'
    GROUP BY s.CUSTOMER_ID
),

-- Calculate channel behavior for Prior Year periods (for variance)
CustomerChannelByPeriod_PY AS (
    SELECT 
        s.CUSTOMER_ID,
        CASE 
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @PY_L12M_Start AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0
            AND SUM(CASE WHEN d.DATE_VALUE >= @PY_L12M_Start AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Omni'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @PY_L12M_Start AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Online'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @PY_L12M_Start AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Offline' 
        END AS PY_Channel_L12M,
        CASE 
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @PY_FYTD_Start AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0
            AND SUM(CASE WHEN d.DATE_VALUE >= @PY_FYTD_Start AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Omni'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @PY_FYTD_Start AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Online'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @PY_FYTD_Start AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Offline' 
        END AS PY_Channel_FYTD,
        CASE 
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @PY_STD_Start AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0
            AND SUM(CASE WHEN d.DATE_VALUE >= @PY_STD_Start AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Omni'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @PY_STD_Start AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Online'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @PY_STD_Start AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Offline' 
        END AS PY_Channel_STD,
        CASE 
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @PY_YTD_Start AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0
            AND SUM(CASE WHEN d.DATE_VALUE >= @PY_YTD_Start AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Omni'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @PY_YTD_Start AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Online'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= @PY_YTD_Start AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Offline' 
        END AS PY_Channel_YTD
    FROM DW.FACT.Sales s
    INNER JOIN DW.DIM.Date d ON d.DATE_KEY = s.TRANSACTION_DATE_KEY
    INNER JOIN DW.DIM.Store st ON st.STORE_ID = s.STORE_ID
    WHERE s.CUSTOMER_ID > 0 
        AND s.QUANTITY > 0 
        AND d.DATE_VALUE >= @PY_L12M_Start 
        AND d.DATE_VALUE <= @PY_Today 
        AND s.DATA_SOURCE <> 'EXCLUDE'
    GROUP BY s.CUSTOMER_ID
),

-- Calculate "Known Customer" channel (24-month window for each period)
CustomerChannelByPeriod_Known_CY AS (
    SELECT 
        s.CUSTOMER_ID,
        -- Known L12M uses 24M lookback (L12M + prior 12M)
        CASE 
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -24, @Today) AND d.DATE_VALUE <= @Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0
            AND SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -24, @Today) AND d.DATE_VALUE <= @Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Omni'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -24, @Today) AND d.DATE_VALUE <= @Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Online'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -24, @Today) AND d.DATE_VALUE <= @Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Offline' 
        END AS Known_Channel_L12M,
        -- Known FYTD uses FYTD + prior 12M
        CASE 
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @CY_FYTD_Start) AND d.DATE_VALUE <= @Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0
            AND SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @CY_FYTD_Start) AND d.DATE_VALUE <= @Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Omni'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @CY_FYTD_Start) AND d.DATE_VALUE <= @Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Online'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @CY_FYTD_Start) AND d.DATE_VALUE <= @Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Offline' 
        END AS Known_Channel_FYTD,
        -- Known STD uses STD + prior 12M
        CASE 
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @CY_STD_Start) AND d.DATE_VALUE <= @Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0
            AND SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @CY_STD_Start) AND d.DATE_VALUE <= @Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Omni'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @CY_STD_Start) AND d.DATE_VALUE <= @Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Online'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @CY_STD_Start) AND d.DATE_VALUE <= @Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Offline' 
        END AS Known_Channel_STD,
        -- Known YTD uses YTD + prior 12M
        CASE 
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @CY_YTD_Start) AND d.DATE_VALUE <= @Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0
            AND SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @CY_YTD_Start) AND d.DATE_VALUE <= @Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Omni'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @CY_YTD_Start) AND d.DATE_VALUE <= @Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Online'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @CY_YTD_Start) AND d.DATE_VALUE <= @Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Offline' 
        END AS Known_Channel_YTD
    FROM DW.FACT.Sales s
    INNER JOIN DW.DIM.Date d ON d.DATE_KEY = s.TRANSACTION_DATE_KEY
    INNER JOIN DW.DIM.Store st ON st.STORE_ID = s.STORE_ID
    WHERE s.CUSTOMER_ID > 0 
        AND s.QUANTITY > 0 
        AND d.DATE_VALUE >= DATEADD(MONTH, -24, @Today) 
        AND s.DATA_SOURCE <> 'EXCLUDE'
    GROUP BY s.CUSTOMER_ID
),

-- Calculate "Known Customer" channel for Prior Year (for variance calculations)
CustomerChannelByPeriod_Known_PY AS (
    SELECT 
        s.CUSTOMER_ID,
        CASE 
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -24, @PY_Today) AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0
            AND SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -24, @PY_Today) AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Omni'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -24, @PY_Today) AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Online'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -24, @PY_Today) AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Offline' 
        END AS PY_Known_Channel_L12M,
        CASE 
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @PY_FYTD_Start) AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0
            AND SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @PY_FYTD_Start) AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Omni'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @PY_FYTD_Start) AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Online'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @PY_FYTD_Start) AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Offline' 
        END AS PY_Known_Channel_FYTD,
        CASE 
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @PY_STD_Start) AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0
            AND SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @PY_STD_Start) AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Omni'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @PY_STD_Start) AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Online'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @PY_STD_Start) AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Offline' 
        END AS PY_Known_Channel_STD,
        CASE 
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @PY_YTD_Start) AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0
            AND SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @PY_YTD_Start) AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Omni'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @PY_YTD_Start) AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Online'
            WHEN SUM(CASE WHEN d.DATE_VALUE >= DATEADD(MONTH, -12, @PY_YTD_Start) AND d.DATE_VALUE <= @PY_Today AND st.STORE_ID NOT IN ('801', '802', '803') THEN s.NET_AMOUNT ELSE 0 END) > 0 
            THEN 'Offline' 
        END AS PY_Known_Channel_YTD
    FROM DW.FACT.Sales s
    INNER JOIN DW.DIM.Date d ON d.DATE_KEY = s.TRANSACTION_DATE_KEY
    INNER JOIN DW.DIM.Store st ON st.STORE_ID = s.STORE_ID
    WHERE s.CUSTOMER_ID > 0 
        AND s.QUANTITY > 0 
        AND d.DATE_VALUE >= DATEADD(MONTH, -24, @PY_Today) 
        AND d.DATE_VALUE <= @PY_Today 
        AND s.DATA_SOURCE <> 'EXCLUDE'
    GROUP BY s.CUSTOMER_ID
)

-- Insert consolidated customer KPI data
INSERT INTO DW.Customers_KPI (
    CUSTOMER_ID, 
    FIRST_PURCHASE_DATE, 
    First_Purchase_Season, 
    First_Season_Purchase_Key, 
    First_Season_Revenue,
    Family_Segment, 
    Omni_Segment, 
    Baby_Revenue, 
    Is_Valid_New_Customer,
    Channel_L12M, Channel_FYTD, Channel_STD, Channel_YTD,
    PY_Channel_L12M, PY_Channel_FYTD, PY_Channel_STD, PY_Channel_YTD,
    Known_Channel_L12M, Known_Channel_FYTD, Known_Channel_STD, Known_Channel_YTD,
    PY_Known_Channel_L12M, PY_Known_Channel_FYTD, PY_Known_Channel_STD, PY_Known_Channel_YTD,
    Last_Updated
)
SELECT 
    c.CUSTOMER_ID, 
    c.FIRST_PURCHASE_DATE, 
    cs.First_Purchase_Season, 
    cs.First_Season_Purchase_Key, 
    cs.First_Season_Revenue,
    cs.Family_Segment, 
    cs.Omni_Segment, 
    cs.Baby_Revenue,
    CASE WHEN cs.CUSTOMER_ID IS NOT NULL THEN 1 ELSE 0 END,
    ch_cy.Channel_L12M, ch_cy.Channel_FYTD, ch_cy.Channel_STD, ch_cy.Channel_YTD,
    ch_py.PY_Channel_L12M, ch_py.PY_Channel_FYTD, ch_py.PY_Channel_STD, ch_py.PY_Channel_YTD,
    ch_known_cy.Known_Channel_L12M, ch_known_cy.Known_Channel_FYTD, ch_known_cy.Known_Channel_STD, ch_known_cy.Known_Channel_YTD,
    ch_known_py.PY_Known_Channel_L12M, ch_known_py.PY_Known_Channel_FYTD, ch_known_py.PY_Known_Channel_STD, ch_known_py.PY_Known_Channel_YTD,
    GETDATE()
FROM DW.DIM.Customer c
LEFT JOIN CustomerSegments cs ON c.CUSTOMER_ID = cs.CUSTOMER_ID
LEFT JOIN CustomerChannelByPeriod_CY ch_cy ON c.CUSTOMER_ID = ch_cy.CUSTOMER_ID
LEFT JOIN CustomerChannelByPeriod_PY ch_py ON c.CUSTOMER_ID = ch_py.CUSTOMER_ID
LEFT JOIN CustomerChannelByPeriod_Known_CY ch_known_cy ON c.CUSTOMER_ID = ch_known_cy.CUSTOMER_ID
LEFT JOIN CustomerChannelByPeriod_Known_PY ch_known_py ON c.CUSTOMER_ID = ch_known_py.CUSTOMER_ID;

DECLARE @EndTime DATETIME = GETDATE();
DECLARE @Duration INT = DATEDIFF(SECOND, @StartTime, @EndTime);
DECLARE @RowCount INT = @@ROWCOUNT;

PRINT '';
PRINT '========================================';
PRINT 'Weekly KPI refresh completed!';
PRINT 'Customers processed: ' + CAST(@RowCount AS VARCHAR);
PRINT 'Duration: ' + CAST(@Duration AS VARCHAR) + ' seconds (' + CAST(@Duration/60 AS VARCHAR) + ' minutes)';
PRINT 'Completed at: ' + CONVERT(VARCHAR, @EndTime, 120);
PRINT '========================================';

-- Verification query
SELECT TOP 10 * FROM DW.Customers_KPI ORDER BY Last_Updated DESC;
GO
