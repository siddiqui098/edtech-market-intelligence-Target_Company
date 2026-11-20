-- DASHBOARD 2: DUOLINGO ENGAGEMENT AND MONETIZATION
-- Database: edtech_market_intelligence | Scope: FY2021-FY2025 (2026 excluded)
-- Table: duolingo_analysis_data
-- =====================================================================
 
USE edtech_market_intelligence;


-- A seperate dashboard analysis for Duilingo (2)
-- Q1. How have Duolingo's daily active users (DAU) and monthly active users (MAU) changed from FY2021 to FY2025?


USE edtech_market_intelligence;

SELECT
    company,
    period,
    period_start,
    mau_m,
    dau_m
FROM duolingo_analysis_data
WHERE company = 'Duolingo'
  AND period IN ('FY2021', 'FY2022', 'FY2023', 'FY2024', 'FY2025')
ORDER BY period_start;


SELECT
    period AS fiscal_year,
    mau_m AS mau_millions,
    dau_m AS dau_millions
FROM edtech_market_intelligence.duolingo_analysis_data
WHERE company = 'Duolingo'
  AND period IN ('FY2021', 'FY2022', 'FY2023', 'FY2024', 'FY2025')
ORDER BY period_start;

-- Q2. How has Duolingo's DAU/MAU ratio evolved from FY2021 to FY2025?


SELECT
    period AS fiscal_year,
    ROUND(dau_m / mau_m * 100, 2) AS dau_mau_ratio_pct
FROM edtech_market_intelligence.duolingo_analysis_data
WHERE company = 'Duolingo'
  AND period IN ('FY2021', 'FY2022', 'FY2023', 'FY2024', 'FY2025')
ORDER BY period_start;

-- Question 3: How have Duolingo's subscription bookings and total bookings evolved from FY2021 to FY2025?

WITH annual_bookings AS (
    SELECT
        period,
        period_start,
        subscription_bookings_usd_m,
        total_bookings_usd_m,
        LAG(subscription_bookings_usd_m) OVER (
            ORDER BY period_start
        ) AS previous_subscription_bookings,
        LAG(total_bookings_usd_m) OVER (
            ORDER BY period_start
        ) AS previous_total_bookings
    FROM edtech_market_intelligence.duolingo_analysis_data
    WHERE company = 'Duolingo'
      AND period IN ('FY2021', 'FY2022', 'FY2023', 'FY2024', 'FY2025')
)
SELECT
    period AS fiscal_year,
    subscription_bookings_usd_m,
    ROUND(
        (subscription_bookings_usd_m - previous_subscription_bookings)
        / previous_subscription_bookings * 100,
        2
    ) AS subscription_bookings_yoy_growth_pct,
    total_bookings_usd_m,
    ROUND(
        (total_bookings_usd_m - previous_total_bookings)
        / previous_total_bookings * 100,
        2
    ) AS total_bookings_yoy_growth_pct
FROM annual_bookings
ORDER BY period_start;

-- Question4.How has Duolingo's subscription bookings contribution to total bookings changed from FY2021 to FY2025?

SELECT
    period AS fiscal_year,
    subscription_bookings_usd_m,
    total_bookings_usd_m,
    ROUND(
        subscription_bookings_usd_m
        / NULLIF(total_bookings_usd_m, 0) * 100,
        2
    ) AS subscription_bookings_share_pct
FROM edtech_market_intelligence.duolingo_analysis_data
WHERE company = 'Duolingo'
  AND period IN ('FY2021', 'FY2022', 'FY2023', 'FY2024', 'FY2025')
ORDER BY period_start;


