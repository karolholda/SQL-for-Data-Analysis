/* =========================================================
   1) CONTROL TOTALS PER SCENARIO
   Cel: sanity check Actual / Budget / Forecast
   ========================================================= */
SELECT
    scenario,
    COUNT(*)        AS rows_cnt,
    SUM(amount)     AS total_amount
FROM finance_fact
WHERE posting_date >= '2025-01-01'
GROUP BY scenario
ORDER BY scenario;


/* =========================================================
   2) P&L – SUMA PO LINIACH P&L (JEDEN MIESIĄC)
   ========================================================= */
SELECT
    d.year_month,
    a.pnl_line,
    SUM(f.amount * a.sign_multiplier) AS pnl_amount
FROM finance_fact f
JOIN dim_date d      ON d.[date] = f.posting_date
JOIN dim_account a   ON a.account_id = f.account_id
WHERE d.year_month = '2025-12'
  AND f.scenario = 'Actual'
GROUP BY d.year_month, a.pnl_line
ORDER BY a.pnl_line;


/* =========================================================
   3) ACTUAL VS BUDGET – VARIANCE (MIESIĄC)
   ========================================================= */
SELECT
    d.year_month,
    a.pnl_line,

    SUM(CASE WHEN f.scenario = 'Actual'
             THEN f.amount * a.sign_multiplier ELSE 0 END) AS actual_amt,

    SUM(CASE WHEN f.scenario = 'Budget'
             THEN f.amount * a.sign_multiplier ELSE 0 END) AS budget_amt,

    SUM(CASE WHEN f.scenario = 'Actual'
             THEN f.amount * a.sign_multiplier ELSE 0 END)
  - SUM(CASE WHEN f.scenario = 'Budget'
             THEN f.amount * a.sign_multiplier ELSE 0 END) AS variance_amt

FROM finance_fact f
JOIN dim_date d    ON d.[date] = f.posting_date
JOIN dim_account a ON a.account_id = f.account_id
WHERE d.year_month = '2025-12'
  AND f.scenario IN ('Actual','Budget')
GROUP BY d.year_month, a.pnl_line
ORDER BY a.pnl_line;


/* =========================================================
   4) VARIANCE % (Z OCHRONĄ NA ZERO)
   ========================================================= */
WITH base AS (
    SELECT
        a.pnl_line,

        SUM(CASE WHEN f.scenario = 'Actual'
                 THEN f.amount * a.sign_multiplier ELSE 0 END) AS actual_amt,

        SUM(CASE WHEN f.scenario = 'Budget'
                 THEN f.amount * a.sign_multiplier ELSE 0 END) AS budget_amt

    FROM finance_fact f
    JOIN dim_date d    ON d.[date] = f.posting_date
    JOIN dim_account a ON a.account_id = f.account_id
    WHERE d.year_month = '2025-12'
      AND f.scenario IN ('Actual','Budget')
    GROUP BY a.pnl_line
)
SELECT
    pnl_line,
    actual_amt,
    budget_amt,
    actual_amt - budget_amt AS variance_amt,
    CASE
        WHEN budget_amt = 0 THEN NULL
        ELSE (actual_amt - budget_amt) / budget_amt
    END AS variance_pct
FROM base
ORDER BY pnl_line;


/* =========================================================
   5) TOP 10 COST CENTERS – NAJWIĘKSZE PRZEKROCZENIE OPEX
   ========================================================= */
WITH opex AS (
    SELECT
        cc.cost_center_name,

        SUM(CASE WHEN f.scenario = 'Actual'
                 THEN f.amount ELSE 0 END) AS actual_opex,

        SUM(CASE WHEN f.scenario = 'Budget'
                 THEN f.amount ELSE 0 END) AS budget_opex

    FROM finance_fact f
    JOIN dim_date d         ON d.[date] = f.posting_date
    JOIN dim_account a      ON a.account_id = f.account_id
    JOIN dim_cost_center cc ON cc.cost_center_id = f.cost_center_id
    WHERE d.year_month = '2025-12'
      AND a.account_group = 'OPEX'
      AND f.scenario IN ('Actual','Budget')
    GROUP BY cc.cost_center_name
)
SELECT TOP 10
    cost_center_name,
    actual_opex,
    budget_opex,
    actual_opex - budget_opex AS variance_opex
FROM opex
ORDER BY variance_opex DESC;


/* =========================================================
   6) MONTH-OVER-MONTH CHANGE – REVENUE (LAG)
   ========================================================= */
WITH rev AS (
    SELECT
        d.year_month,
        SUM(f.amount * a.sign_multiplier) AS revenue_amt
    FROM finance_fact f
    JOIN dim_date d    ON d.[date] = f.posting_date
    JOIN dim_account a ON a.account_id = f.account_id
    WHERE f.scenario = 'Actual'
      AND a.account_group = 'Revenue'
    GROUP BY d.year_month
),
rev2 AS (
    SELECT
        year_month,
        revenue_amt,
        LAG(revenue_amt) OVER (ORDER BY year_month) AS prev_revenue
    FROM rev
)
SELECT
    year_month,
    revenue_amt,
    prev_revenue,
    CASE
        WHEN prev_revenue IS NULL OR prev_revenue = 0 THEN NULL
        ELSE (revenue_amt - prev_revenue) / ABS(prev_revenue)
    END AS mom_change_pct
FROM rev2
ORDER BY year_month;


/* =========================================================
   7) DQ CHECK – BRAKUJĄCE SCENARIUSZE (ERROR)
   ========================================================= */
SELECT s.scenario
FROM (VALUES ('Actual'), ('Budget'), ('Forecast')) AS s(scenario)
WHERE NOT EXISTS (
    SELECT 1
    FROM finance_fact f
    JOIN dim_date d ON d.[date] = f.posting_date
    WHERE d.year_month = '2025-12'
      AND f.scenario = s.scenario
);


/* =========================================================
   8) DQ CHECK – DUPLIKATY PO KLUCZU BIZNESOWYM (ERROR)
   ========================================================= */
SELECT
    posting_date,
    account_id,
    cost_center_id,
    entity_id,
    scenario,
    COUNT(*) AS cnt
FROM finance_fact
GROUP BY
    posting_date,
    account_id,
    cost_center_id,
    entity_id,
    scenario
HAVING COUNT(*) > 1
ORDER BY cnt DESC;


/* =========================================================
   9) DQ CHECK – NIEWYMAPOWANE KONTA (BRAK W DIM_ACCOUNT)
   ========================================================= */
SELECT DISTINCT
    f.account_id
FROM finance_fact f
LEFT JOIN dim_account a
       ON a.account_id = f.account_id
WHERE a.account_id IS NULL
ORDER BY f.account_id;


/* =========================================================
   10) VIEW POD POWER BI – GOTOWY FACT FINANSOWY
   ========================================================= */
CREATE OR ALTER VIEW dbo.vw_finance_fact_pbi AS
SELECT
    f.posting_date,
    d.year,
    d.month,
    d.year_month,

    e.entity_name,
    cc.cost_center_name,

    a.account_name,
    a.account_group,
    a.pnl_line,
    a.sign_multiplier,

    f.scenario,
    f.amount,
    (f.amount * a.sign_multiplier) AS amount_pnl

FROM finance_fact f
JOIN dim_date d         ON d.[date] = f.posting_date
JOIN dim_account a      ON a.account_id = f.account_id
JOIN dim_cost_center cc ON cc.cost_center_id = f.cost_center_id
JOIN dim_entity e       ON e.entity_id = f.entity_id;
