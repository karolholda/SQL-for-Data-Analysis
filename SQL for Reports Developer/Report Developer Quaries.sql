/* =====================================================================
   1) CONTROL TOTALS PER SCENARIO
   Co to robi:
   - Sprawdza, czy w danych są scenariusze (Actual/Budget/Forecast),
     ile mają rekordów i jaka jest suma Amount w wybranym okresie.
   Po co w FP&A:
   - To jest najszybszy „sanity check” po refreshu/ETL:
     • czy dane się wczytały,
     • czy nie ma pustych/zerowych totals,
     • czy nie brakuje któregoś scenariusza.
   Jak interpretować:
   - rows_cnt = 0 lub brak scenariusza → potencjalny błąd loadu / filtrów.
   - total_amount = NULL/0 → podejrzenie błędu (albo specyficzny przypadek biznesowy).
   ===================================================================== */
SELECT
    scenario,                      -- nazwa scenariusza finansowego (np. Actual/Budget/Forecast)
    COUNT(*)        AS rows_cnt,    -- liczba wierszy (czy dane w ogóle istnieją)
    SUM(amount)     AS total_amount -- suma kwot (czy totals są sensowne)
FROM finance_fact
WHERE posting_date >= '2025-01-01'  -- zakres dat (typowo: YTD lub od początku roku)
GROUP BY scenario
ORDER BY scenario;


/* =====================================================================
   2) P&L – SUMA PO LINIACH P&L DLA JEDNEGO MIESIĄCA (ACTUAL)
   Co to robi:
   - Agreguje dane do poziomu „linii P&L” (np. Revenue/COGS/OPEX),
     przelicza znak (sign_multiplier) i zwraca kwoty dla jednego miesiąca.
   Po co w FP&A:
   - To jest baza pod raport P&L w Power BI (matrix: P&L line vs kwoty).
   Jak interpretować:
   - Wynik powinien zgadzać się z raportem finansowym/GL na poziomie P&L lines.
   - Jeśli COGS/OPEX mają „zły znak” → sprawdź sign_multiplier/mapping kont.
   ===================================================================== */
SELECT
    d.year_month,                                   -- np. '2025-12' (format zależy od dim_date)
    a.pnl_line,                                     -- linia P&L (nadrzędna kategoria raportu)
    SUM(f.amount * a.sign_multiplier) AS pnl_amount -- kwota P&L z poprawnym znakiem
FROM finance_fact f
JOIN dim_date d
     ON d.[date] = f.posting_date                   -- łączymy fakt z kalendarzem
JOIN dim_account a
     ON a.account_id = f.account_id                 -- łączymy fakt z wymiarem kont
WHERE d.year_month = '2025-12'                      -- wybór konkretnego miesiąca
  AND f.scenario = 'Actual'                         -- P&L zwykle pokazuje Actual jako bazę
GROUP BY
    d.year_month,
    a.pnl_line
ORDER BY
    a.pnl_line;


/* =====================================================================
   3) ACTUAL VS BUDGET – VARIANCE (kwotowo) PER P&L LINE (miesiąc)
   Co to robi:
   - Liczy Actual, Budget i Variance (= Actual - Budget) w jednym wyniku.
   - Używa CASE WHEN do rozdzielenia scenariuszy w agregacji.
   Po co w FP&A:
   - To jest klasyczna analiza odchyleń „wykonanie vs plan”.
   Jak interpretować:
   - variance_amt > 0 dla Revenue zwykle „dobrze”, ale dla kosztów zależy od znaku
     (dlatego ważny sign_multiplier lub ustalona konwencja znaków).
   ===================================================================== */
SELECT
    d.year_month,
    a.pnl_line,

    -- Actual: sumujemy tylko wiersze scenariusza 'Actual'
    SUM(CASE
            WHEN f.scenario = 'Actual' THEN f.amount * a.sign_multiplier
            ELSE 0
        END) AS actual_amt,

    -- Budget: sumujemy tylko wiersze scenariusza 'Budget'
    SUM(CASE
            WHEN f.scenario = 'Budget' THEN f.amount * a.sign_multiplier
            ELSE 0
        END) AS budget_amt,

    -- Variance kwotowe: Actual - Budget
    SUM(CASE
            WHEN f.scenario = 'Actual' THEN f.amount * a.sign_multiplier
            ELSE 0
        END)
  - SUM(CASE
            WHEN f.scenario = 'Budget' THEN f.amount * a.sign_multiplier
            ELSE 0
        END) AS variance_amt

FROM finance_fact f
JOIN dim_date d
     ON d.[date] = f.posting_date
JOIN dim_account a
     ON a.account_id = f.account_id
WHERE d.year_month = '2025-12'
  AND f.scenario IN ('Actual','Budget')             -- ograniczamy dane do porównywanych scenariuszy
GROUP BY
    d.year_month,
    a.pnl_line
ORDER BY
    a.pnl_line;


/* =====================================================================
   4) VARIANCE % – (Actual - Budget) / Budget z ochroną na 0
   Co to robi:
   - Najpierw w CTE liczy Actual i Budget per P&L line,
     potem liczy variance_pct z CASE, aby nie dzielić przez 0.
   Po co w FP&A:
   - W % łatwiej ocenić skalę odchylenia (np. +2% vs +200%).
   Jak interpretować:
   - NULL w variance_pct oznacza, że budget = 0 (brak bazy do %).
   - Jeśli budżet ma zera, często trzeba uzgodnić z finance jak raportować % (np. BLANK).
   ===================================================================== */
WITH base AS (
    SELECT
        a.pnl_line,

        -- Suma Actual
        SUM(CASE
                WHEN f.scenario = 'Actual' THEN f.amount * a.sign_multiplier
                ELSE 0
            END) AS actual_amt,

        -- Suma Budget
        SUM(CASE
                WHEN f.scenario = 'Budget' THEN f.amount * a.sign_multiplier
                ELSE 0
            END) AS budget_amt

    FROM finance_fact f
    JOIN dim_date d
         ON d.[date] = f.posting_date
    JOIN dim_account a
         ON a.account_id = f.account_id
    WHERE d.year_month = '2025-12'
      AND f.scenario IN ('Actual','Budget')
    GROUP BY a.pnl_line
)
SELECT
    pnl_line,
    actual_amt,
    budget_amt,
    actual_amt - budget_amt AS variance_amt,

    -- Variance %: ochrona na dzielenie przez 0
    CASE
        WHEN budget_amt = 0 THEN NULL
        ELSE (actual_amt - budget_amt) / budget_amt
    END AS variance_pct
FROM base
ORDER BY pnl_line;


/* =====================================================================
   5) TOP 10 COST CENTERS – największe przekroczenie OPEX (Actual vs Budget)
   Co to robi:
   - Dla OPEX liczy actual_opex, budget_opex i variance_opex per cost center,
     a potem wybiera TOP 10 z największym variance (overspend).
   Po co w FP&A:
   - To typowa lista do rozmowy ze stakeholderami:
     „gdzie przekroczyliśmy budżet i o ile?”
   Jak interpretować:
   - W kosztach variance_opex dodatnie zwykle oznacza overspend,
     ALE zależy od konwencji znaków (tu zakładamy koszty jako dodatnie).
   ===================================================================== */
WITH opex AS (
    SELECT
        cc.cost_center_name,

        -- Actual OPEX
        SUM(CASE
                WHEN f.scenario = 'Actual' THEN f.amount
                ELSE 0
            END) AS actual_opex,

        -- Budget OPEX
        SUM(CASE
                WHEN f.scenario = 'Budget' THEN f.amount
                ELSE 0
            END) AS budget_opex

    FROM finance_fact f
    JOIN dim_date d
         ON d.[date] = f.posting_date
    JOIN dim_account a
         ON a.account_id = f.account_id
    JOIN dim_cost_center cc
         ON cc.cost_center_id = f.cost_center_id
    WHERE d.year_month = '2025-12'
      AND a.account_group = 'OPEX'                  -- ograniczamy do kosztów operacyjnych
      AND f.scenario IN ('Actual','Budget')
    GROUP BY cc.cost_center_name
)
SELECT TOP 10
    cost_center_name,
    actual_opex,
    budget_opex,
    actual_opex - budget_opex AS variance_opex      -- różnica kosztów (overspend)
FROM opex
ORDER BY variance_opex DESC;                         -- największe przekroczenia na górze


/* =====================================================================
   6) MONTH-OVER-MONTH CHANGE – Revenue (LAG)
   Co to robi:
   - Liczy miesięczną sumę Revenue (Actual),
     następnie porównuje do poprzedniego miesiąca (LAG),
     wylicza procentową zmianę MoM.
   Po co w FP&A:
   - Wykrywanie anomalii i trendów: „czy revenue nagle nie spadło/wzrosło?”
   Jak interpretować:
   - Jeśli mom_change_pct ma bardzo wysoką wartość → sprawdź:
     • brak danych w poprzednim miesiącu,
     • jednorazowe księgowanie,
     • przesunięcie revenue recognition.
   ===================================================================== */
WITH rev AS (
    SELECT
        d.year_month,
        SUM(f.amount * a.sign_multiplier) AS revenue_amt
    FROM finance_fact f
    JOIN dim_date d
         ON d.[date] = f.posting_date
    JOIN dim_account a
         ON a.account_id = f.account_id
    WHERE f.scenario = 'Actual'
      AND a.account_group = 'Revenue'               -- tylko przychody
    GROUP BY d.year_month
),
rev2 AS (
    SELECT
        year_month,
        revenue_amt,
        LAG(revenue_amt) OVER (ORDER BY year_month) AS prev_revenue -- poprzedni miesiąc
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


/* =====================================================================
   7) DQ CHECK – brakujące scenariusze w danym miesiącu (ERROR)
   Co to robi:
   - Sprawdza, czy w danym miesiącu istnieją wiersze dla każdego scenariusza:
     Actual, Budget, Forecast.
   Po co w FP&A:
   - Jeśli brakuje Budget/Forecast, raport variances będzie błędny albo pusty.
   Jak interpretować:
   - Wynik zwraca listę brakujących scenariuszy.
   ===================================================================== */
SELECT s.scenario
FROM (VALUES ('Actual'), ('Budget'), ('Forecast')) AS s(scenario) -- lista „wymaganych” scenariuszy
WHERE NOT EXISTS (
    SELECT 1
    FROM finance_fact f
    JOIN dim_date d
         ON d.[date] = f.posting_date
    WHERE d.year_month = '2025-12'
      AND f.scenario = s.scenario
);


/* =====================================================================
   8) DQ CHECK – duplikaty po kluczu biznesowym (ERROR)
   Co to robi:
   - Wykrywa sytuację, gdy ten sam klucz biznesowy występuje więcej niż raz.
   Klucz biznesowy (przykład):
   - posting_date + account_id + cost_center_id + entity_id + scenario
   Po co w FP&A:
   - Duplikaty zawyżają totals i powodują „liczby się nie zgadzają”.
   Jak interpretować:
   - Wynik pokazuje klucz i liczbę duplikatów (cnt).
   ===================================================================== */
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
HAVING COUNT(*) > 1                               -- tylko przypadki problematyczne
ORDER BY cnt DESC;


/* =====================================================================
   9) DQ CHECK – niewymapowane konta (brak w dim_account)
   Co to robi:
   - Szuka account_id w faktach, które nie istnieją w dim_account.
   Po co w FP&A:
   - Brak mapowania = brak P&L line / account group → błędna prezentacja i totals.
   Jak interpretować:
   - Lista account_id do uzupełnienia w dim_account (mapping table).
   ===================================================================== */
SELECT DISTINCT
    f.account_id
FROM finance_fact f
LEFT JOIN dim_account a
       ON a.account_id = f.account_id
WHERE a.account_id IS NULL                        -- konto nie znalezione w dimce
ORDER BY f.account_id;


/* =====================================================================
   10) VIEW POD POWER BI – gotowy fakt finansowy
   Co to robi:
   - Buduje jeden widok, z którego Power BI może pobierać dane.
   - Łączy fakt z wymiarami (date/account/cost center/entity).
   - Dodaje amount_pnl = amount * sign_multiplier (ułatwia P&L).
   Po co w FP&A / BI:
   - Stabilne, jedno źródło dla raportów (mniej logiki po stronie Power BI).
   Jak interpretować:
   - Widok powinien być „clean” i spójny (kolumny, typy, relacje).
   ===================================================================== */
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

    (f.amount * a.sign_multiplier) AS amount_pnl   -- kwota z poprawnym znakiem do P&L

FROM finance_fact f
JOIN dim_date d
     ON d.[date] = f.posting_date
JOIN dim_account a
     ON a.account_id = f.account_id
JOIN dim_cost_center cc
     ON cc.cost_center_id = f.cost_center_id
JOIN dim_entity e
     ON e.entity_id = f.entity_id;
