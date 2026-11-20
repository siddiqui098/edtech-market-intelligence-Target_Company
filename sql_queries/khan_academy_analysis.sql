-- =====================================================================
-- DASHBOARD 4&5: KHAN ACADEMY PUBLIC DATA INTELLIGENCE
-- Database: edtech_market_intelligence
-- Tables: stg_khan_academy (school-year metrics),
--         stg_khan_academy_financial (Form 990 calendar-year data)
-- Khan Academy is a nonprofit and is analysed separately from the
-- commercial companies.
-- =====================================================================
 
-- =====================================================================
-- : EDUCATIONAL REACH AND ENGAGEMENT (school years)


-- Khan Academy ( a non_profitable platform) Dashboard 3 & 4

-- Question 1: How has Khan Academy's new learner acquisition changed over time?
-- Objective: Analyze annual new registered learners from SY2021–22 to SY2024–25, while preserving the qualifications attached to approximate figures.
-- Query 1 — Retrieve the relevant data
SELECT
    period,
    value AS new_registered_learners,
    unit,
    previous_period_value,
    change_pct,
    analysis_status,
    interpretation,
    source
FROM edtech_market_intelligence.stg_khan_academy
WHERE metric = 'New registered learners'
ORDER BY period;

-- Query 2 — Validate KPI calculations
SELECT
    period,
    value AS new_registered_learners,
    previous_period_value,
    change_pct AS recorded_change_pct,
    ROUND(
        (value - previous_period_value)
        / NULLIF(previous_period_value, 0) * 100,
        2
    ) AS recalculated_change_pct
FROM edtech_market_intelligence.stg_khan_academy
WHERE metric = 'New registered learners'
ORDER BY period;

-- Query 3 — Assess data reliability
SELECT
    period,
    value AS new_registered_learners,
    analysis_status,
    interpretation,
    source
FROM edtech_market_intelligence.stg_khan_academy
WHERE metric = 'New registered learners'
ORDER BY period;

-- question2: How has Khan Academy’s reported annual learning activity changed over time?

SELECT
    period,
    value AS annual_learning_minutes,
    unit,
    analysis_status,
    interpretation,
    source
FROM edtech_market_intelligence.stg_khan_academy
WHERE metric = 'Annual learning minutes'
ORDER BY period;

-- Question 2: How has Khan Academy's reported annual learning activity changed over time?
--
-- Khan Academy reported annual learning activity of approximately
-- 7.0 billion minutes in SY2021–22, 7.7 billion in SY2022–23,
-- 8.7 billion in SY2023–24, and 8.1 billion in SY2024–25.
--
-- These figures provide descriptive context for reported platform activity.
-- However, the reporting scope differs at least between SY2021–22 and
-- SY2022–23 because the earlier figure excludes Khan Academy Kids minutes.
-- Consistent coverage across all four years has not been established,
-- so the figures should not be treated as a fully comparable
-- year-over-year trend.


-- question3: What does Khan Academy’s reported cumulative learner reach show?


-- Question 3: Cumulative Learner Reach
-- Purpose: Retrieve verified observations and their qualifications.

SELECT
    period AS school_year,
    value AS stored_learner_reach,
    unit,
    analysis_status,
    interpretation,
    source
FROM edtech_market_intelligence.stg_khan_academy
WHERE metric = 'Cumulative registered users'
ORDER BY period;


/*
QUESTION 3: Cumulative Learner Reach — Analysis Conclusion

Khan Academy's reported cumulative registered-user reach
increased from 140 million in SY2021-22 to 189.6 million
in SY2024-25.

The available records also report more than 150 million
users in SY2022-23 and more than 168 million in SY2023-24.

DATA LIMITATION:
The SY2022-23 and SY2023-24 figures are lower-bound
statements, not exact counts. Therefore, the four stored
values do not support a precise growth-rate calculation.

CONCLUSION:
The reported figures provide descriptive evidence of
Khan Academy's cumulative learner reach. However, the
intermediate lower-bound values and the need to confirm
consistent reporting definitions limit precise
year-over-year growth comparisons.

ANALYSIS STATUS: Descriptive analysis completed;
precise growth calculation excluded.
*/

-- question4: What does the latest active-learner data reveal about Khan Academy's learner engagement?


-- QUESTION 4: Latest Active-Learner Data
-- Purpose: Retrieve available engagement observations
-- for the latest reported school year.

SELECT
    metric,
    period,
    value,
    unit,
    analysis_status,
    interpretation,
    source
FROM edtech_market_intelligence.stg_khan_academy
WHERE metric IN (
    'Yearly active learners (YAL)',
    'Yearly very active learners (YVAL)'
)
ORDER BY metric;

/*
QUESTION 4: Latest Active-Learner Data

BUSINESS QUESTION:
What does the latest active-learner data reveal about
Khan Academy's learner engagement?

FINDINGS:
For SY2024-25, Khan Academy reported:
- Yearly Active Learners (YAL): 104.9 million.
- Yearly Very Active Learners (YVAL): 1.6 million.

METRIC DEFINITIONS:
- YAL: People who used Khan Academy for any amount
  of time during SY2024-25.
- YVAL: People who used Khan Academy for at least
  18 hours during SY2024-25.

DATA LIMITATIONS:
- Both metrics cover only SY2024-25 in the available
  dataset; historical trends cannot be established.
- The metrics represent different levels of platform
  usage and should not be treated as interchangeable.
- No engagement rate has been calculated because this
  analysis is limited to the reported descriptive metrics.

CONCLUSION:
The figures describe Khan Academy's reported active
learner reach during SY2024-25, including the number
of learners who reached the 18-hour usage threshold.
They do not establish historical engagement growth
or explain the reasons behind learner activity.

ANALYSIS STATUS:
Descriptive analysis completed.
Historical trend excluded due to insufficient
time-series data.
No derived engagement rate calculated.
*/

-- question5: How did Khan Academy’s total revenue and total expenses change from CY2021 through CY2023?

USE edtech_market_intelligence;

WITH annual_financials AS (
    SELECT
        reporting_period,
        YEAR(period_start) AS report_year,
        total_revenue_usd,
        total_expenses_usd
    FROM stg_khan_academy_financial
    WHERE reporting_period IN ('CY2021', 'CY2022', 'CY2023')
),
year_comparison AS (
    SELECT
        report_year,
        total_revenue_usd,
        total_expenses_usd,
        LAG(total_revenue_usd) OVER (
            ORDER BY report_year
        ) AS previous_revenue,
        LAG(total_expenses_usd) OVER (
            ORDER BY report_year
        ) AS previous_expenses
    FROM annual_financials
)
SELECT
    report_year,
    total_revenue_usd,
    total_expenses_usd,
    total_revenue_usd - previous_revenue AS revenue_change_usd,
    ROUND(
        100.0 * (total_revenue_usd - previous_revenue)
        / NULLIF(previous_revenue, 0), 2
    ) AS revenue_change_pct,
    total_expenses_usd - previous_expenses AS expenses_change_usd,
    ROUND(
        100.0 * (total_expenses_usd - previous_expenses)
        / NULLIF(previous_expenses, 0), 2
    ) AS expenses_change_pct
FROM year_comparison
ORDER BY report_year;

-- question6: How did Khan Academy’s reported surplus or deficit evolve from CY2021 through CY2023, and which years recorded a deficit?

USE edtech_market_intelligence;

SELECT
    YEAR(period_start) AS report_year,
    total_revenue_usd,
    total_expenses_usd,
    surplus_deficit_usd,
    CASE
        WHEN surplus_deficit_usd > 0 THEN 'Surplus'
        WHEN surplus_deficit_usd < 0 THEN 'Deficit'
        ELSE 'Break-even'
    END AS financial_status
FROM stg_khan_academy_financial
WHERE reporting_period IN ('CY2021', 'CY2022', 'CY2023')
ORDER BY period_start;






  
