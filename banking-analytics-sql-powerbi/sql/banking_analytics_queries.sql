-- ================================================================================
--  RETAIL BANKING ANALYTICS — SQL CASE STUDY
--  Database: PostgreSQL 16  |  Schema: clientes, productos, transacciones, carteras
--  Author: Juan Marcelo Párraga Calizaya
-- ================================================================================
--
--  CONTEXT
--  -------
--  Synthetic dataset simulating a retail bank's core tables (50 customers,
--  12 products, ~200 transactions, 50 portfolio/holding records). The goal is
--  to answer 8 progressively harder business questions using CTEs, window
--  functions, and aggregate filtering — then feed the results into a Power BI
--  dashboard (see /screenshots and the companion .pbip project).
--
--  Table and column names are kept in Spanish to match the original schema;
--  all comments and business logic below are in English.
--
--  GENERAL ASSUMPTIONS
--  --------------------
--  1) Data spans 2024-01-05 to 2025-04-24. Queries scoped to "2024" use a
--     half-open range [2024-01-01, 2025-01-01) to exclude 2025 records.
--  2) A half-open range is used instead of EXTRACT(YEAR..) to keep the filter
--     sargable (index-friendly on the `fecha` column).
--  3) "Active portfolio" = fecha_cierre IS NULL, per the case brief.
--  4) Where the brief doesn't restrict transaction status, all statuses are
--     included; where it does, the filter is applied explicitly.
-- ================================================================================


-- ════════════════════════════════════════════════════════════════════════════════
--  LEVEL 1 — BASE QUERIES
-- ════════════════════════════════════════════════════════════════════════════════

-- --------------------------------------------------------------------------------
-- QUERY 1 — Total transacted amount by month in 2024, split by transaction type.
-- Assumption: includes all statuses (the brief doesn't restrict to 'Completed').
-- Transaction count is added for context — an amount without volume is hard
-- to read on its own.
-- --------------------------------------------------------------------------------
SELECT
    DATE_TRUNC('month', t.fecha)::DATE AS mes,
    t.tipo,
    COUNT(*)                           AS cantidad_transacciones,
    SUM(t.monto)                       AS monto_total
FROM transacciones t
WHERE t.fecha >= DATE '2024-01-01'
  AND t.fecha <  DATE '2025-01-01'
GROUP BY DATE_TRUNC('month', t.fecha), t.tipo
ORDER BY mes ASC, t.tipo;


-- --------------------------------------------------------------------------------
-- QUERY 2 — Top 10 customers by total balance across active portfolios.
-- Using an inner JOIN (not LEFT JOIN) correctly excludes customers with no
-- active portfolio — they shouldn't compete for a "top balance" ranking.
-- --------------------------------------------------------------------------------
SELECT
    c.cliente_id,
    c.nombre,
    c.segmento,
    c.ciudad,
    SUM(ca.saldo_actual)  AS saldo_total,
    COUNT(*)              AS carteras_activas
FROM clientes c
JOIN carteras ca
      ON ca.cliente_id = c.cliente_id
     AND ca.fecha_cierre IS NULL          -- filter inside the JOIN: active only
GROUP BY c.cliente_id, c.nombre, c.segmento, c.ciudad
ORDER BY saldo_total DESC
LIMIT 10;


-- --------------------------------------------------------------------------------
-- QUERY 3 — Customers holding 2 or more distinct products.
-- Counted over `carteras` (product holdings), not `transacciones`.
-- COUNT(DISTINCT) guards against the same product being counted twice.
-- --------------------------------------------------------------------------------
SELECT
    c.cliente_id,
    c.nombre,
    c.segmento,
    COUNT(DISTINCT ca.producto_id) AS productos_distintos
FROM clientes c
JOIN carteras ca ON ca.cliente_id = c.cliente_id
GROUP BY c.cliente_id, c.nombre, c.segmento
HAVING COUNT(DISTINCT ca.producto_id) >= 2     -- HAVING: filter on the aggregate
ORDER BY productos_distintos DESC, c.nombre;


-- ════════════════════════════════════════════════════════════════════════════════
--  LEVEL 2 — INTERMEDIATE ANALYSIS
-- ════════════════════════════════════════════════════════════════════════════════

-- --------------------------------------------------------------------------------
-- QUERY 4 — Top 3 customers per segment by completed deposits in 2024.
-- RANK() (not ROW_NUMBER) is used deliberately: on a tie, RANK returns both
-- customers, which is the fairer behavior for a business ranking. Filtering
-- "RANK <= 3" requires a subquery because window functions can't be used
-- directly in a WHERE clause (they're evaluated after it).
-- --------------------------------------------------------------------------------
WITH depositos_cliente AS (
    SELECT
        c.cliente_id,
        c.nombre,
        c.segmento,
        SUM(t.monto) AS total_depositos
    FROM transacciones t
    JOIN clientes c ON c.cliente_id = t.cliente_id
    WHERE t.tipo   = 'Depósito'
      AND t.estado = 'Completada'                -- brief explicitly requires completed
      AND t.fecha >= DATE '2024-01-01'
      AND t.fecha <  DATE '2025-01-01'
    GROUP BY c.cliente_id, c.nombre, c.segmento
),
ranking AS (
    SELECT
        d.*,
        RANK() OVER (PARTITION BY d.segmento ORDER BY d.total_depositos DESC) AS rk
    FROM depositos_cliente d
)
SELECT segmento, rk AS ranking, nombre, total_depositos
FROM ranking
WHERE rk <= 3
ORDER BY segmento, rk;


-- --------------------------------------------------------------------------------
-- QUERY 5 — "At-risk" customers.
-- Definition: has ≥1 active credit product AND withdrawals in the last 6
-- months exceed 50% of their total active-portfolio balance.
--
-- KEY ASSUMPTION: "last 6 months of available data" is anchored to MAX(fecha)
-- in the table (2025-04-24), NOT to CURRENT_DATE — so the query stays valid
-- if the dataset is reloaded later with different real-world dates.
--
-- ASSUMPTION: compared against total balance across all active portfolios
-- (all categories), as the brief states, not only the credit balance.
--
-- Aggregations are computed in separate CTEs BEFORE joining: joining
-- `carteras` and `transacciones` directly would fan-out (row multiplication)
-- and inflate both sums.
-- --------------------------------------------------------------------------------
WITH ventana AS (
    -- Rolling anchor: last 6 months relative to the latest available date
    SELECT (MAX(fecha) - INTERVAL '6 months')::DATE AS desde,
            MAX(fecha)                              AS hasta
    FROM transacciones
),
saldo_activo AS (
    -- Total balance per customer across active portfolios
    SELECT cliente_id, SUM(saldo_actual) AS saldo_total
    FROM carteras
    WHERE fecha_cierre IS NULL
    GROUP BY cliente_id
),
credito_activo AS (
    -- Customers holding at least one active 'Crédito' (credit) product
    SELECT DISTINCT ca.cliente_id
    FROM carteras ca
    JOIN productos p ON p.producto_id = ca.producto_id
    WHERE ca.fecha_cierre IS NULL
      AND p.categoria = 'Crédito'
),
retiros_6m AS (
    -- Completed withdrawals within the rolling window
    SELECT t.cliente_id, SUM(t.monto) AS total_retiros
    FROM transacciones t
    CROSS JOIN ventana v
    WHERE t.tipo   = 'Retiro'
      AND t.estado = 'Completada'      -- a rejected withdrawal doesn't drain the balance
      AND t.fecha >= v.desde
      AND t.fecha <= v.hasta
    GROUP BY t.cliente_id
)
SELECT
    c.cliente_id,
    c.nombre,
    c.segmento,
    s.saldo_total,
    r.total_retiros,
    ROUND(100.0 * r.total_retiros / NULLIF(s.saldo_total, 0), 2) AS pct_retiros_sobre_saldo
FROM clientes c
JOIN credito_activo cr ON cr.cliente_id = c.cliente_id
JOIN saldo_activo   s  ON s.cliente_id  = c.cliente_id
JOIN retiros_6m     r  ON r.cliente_id  = c.cliente_id
WHERE r.total_retiros > 0.50 * s.saldo_total     -- NULLIF above avoids a division by zero
ORDER BY pct_retiros_sobre_saldo DESC;


-- --------------------------------------------------------------------------------
-- QUERY 6 — Rejection rate by transaction type.
-- FILTER is the ANSI SQL syntax and reads more cleanly than SUM(CASE WHEN..).
-- The 100.0 literal forces decimal arithmetic — with plain integers, the
-- division would truncate to 0.
-- No year filter: the brief doesn't restrict this to a specific year.
-- --------------------------------------------------------------------------------
SELECT
    t.tipo,
    COUNT(*)                                          AS total_transacciones,
    COUNT(*) FILTER (WHERE t.estado = 'Rechazada')    AS rechazadas,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE t.estado = 'Rechazada') / COUNT(*)
    , 2)                                              AS tasa_rechazo_pct
FROM transacciones t
GROUP BY t.tipo
HAVING COUNT(*) > 5                                   -- only types with >5 transactions
ORDER BY tasa_rechazo_pct DESC;

-- SQL Server-portable equivalent (FILTER doesn't exist there):
--   SUM(CASE WHEN t.estado = 'Rechazada' THEN 1 ELSE 0 END)


-- ════════════════════════════════════════════════════════════════════════════════
--  LEVEL 3 — BUSINESS METRICS
-- ════════════════════════════════════════════════════════════════════════════════

-- --------------------------------------------------------------------------------
-- QUERY 7 — Profitability by product.
--
-- CALCULATION ASSUMPTIONS (the brief doesn't define exact formulas):
--   commission_income     = active_total_balance × (commission_rate / 100)
--   estimated_yield        = active_total_balance × (annual_rate / 100)
-- Both are annualized proxies over the current balance. This is an
-- approximation: no accrual date or historical average balance is available.
--
-- BUSINESS NOTE: for the 'Crédito' category, the balance represents customer
-- debt (an asset for the bank), while for 'Ahorro' (savings) it represents a
-- liability. The query sums them into one column because the brief asks for
-- it that way, but the numbers must be read by category, not blended.
--
-- LEFT JOIN preserves catalog products with no active holdings — a product
-- that isn't selling is itself a finding, not a row to discard.
-- --------------------------------------------------------------------------------
SELECT
    p.producto_id,
    p.nombre,
    p.categoria,
    p.tasa_anual,
    p.comision,
    COALESCE(SUM(ca.saldo_actual), 0)                AS saldo_total_activo,
    COUNT(DISTINCT ca.cliente_id)                    AS numero_clientes,
    ROUND(COALESCE(SUM(ca.saldo_actual), 0) * p.comision   / 100.0, 2) AS ingresos_comision_est,
    ROUND(COALESCE(SUM(ca.saldo_actual), 0) * p.tasa_anual / 100.0, 2) AS rendimiento_estimado
FROM productos p
LEFT JOIN carteras ca
       ON ca.producto_id = p.producto_id
      AND ca.fecha_cierre IS NULL     -- lives in the ON clause, not WHERE:
                                      -- putting it in WHERE would cancel the LEFT JOIN
GROUP BY p.producto_id, p.nombre, p.categoria, p.tasa_anual, p.comision
ORDER BY ingresos_comision_est DESC;


-- --------------------------------------------------------------------------------
-- QUERY 8 — Month-over-month growth of deposited amounts in 2024.
-- Formula: ((current_month - previous_month) / previous_month) × 100
--
-- LAG() over the pre-aggregated monthly CTE. The first month (January)
-- returns NULL for the growth rate — that's correct: there's no prior month,
-- and NULL ≠ 0% (0% would mean "no growth", which is a different claim).
-- NULLIF guards against a previous month with a 0 amount (division by zero).
-- --------------------------------------------------------------------------------
WITH depositos_mensuales AS (
    SELECT
        DATE_TRUNC('month', fecha)::DATE AS mes,
        SUM(monto)                       AS monto_depositado
    FROM transacciones
    WHERE tipo = 'Depósito'
      AND fecha >= DATE '2024-01-01'
      AND fecha <  DATE '2025-01-01'
    GROUP BY DATE_TRUNC('month', fecha)
),
con_mes_anterior AS (
    SELECT
        mes,
        monto_depositado,
        LAG(monto_depositado) OVER (ORDER BY mes) AS monto_mes_anterior
    FROM depositos_mensuales
)
SELECT
    mes,
    monto_depositado,
    monto_mes_anterior,
    ROUND(
        100.0 * (monto_depositado - monto_mes_anterior)
              / NULLIF(monto_mes_anterior, 0)
    , 2) AS crecimiento_pct
FROM con_mes_anterior
ORDER BY mes;


-- ================================================================================
--  APPENDIX — QUERY 5: SENSITIVITY ANALYSIS ON THE ZERO-ROW RESULT
-- ================================================================================
--  Query 5 returns 0 rows. This was verified to be a correct result, not a
--  bug in the query:
--
--  DIAGNOSIS:
--    · Only 7 customers hold an active credit product.
--    · Of those 7, only 2 have any withdrawal at all in the full history:
--         - Customer A: 1 withdrawal, ~3.7% of their active balance
--         - Customer B: 1 withdrawal, ~0.7% of their active balance
--    · Both withdrawals occurred BEFORE the 6-month rolling window.
--    · Even ignoring the time window entirely, both ratios sit far below
--      the 50% threshold.
--
--  CONCLUSION: the empty result is the correct answer. With this dataset, no
--  customer qualifies as "at risk" under any reasonable time window — the
--  rule is correct, the data simply contains no positive cases. Below is the
--  backing query used to reach this diagnosis (lifetime ratio, no window):
-- --------------------------------------------------------------------------------
WITH saldo_activo AS (
    SELECT cliente_id, SUM(saldo_actual) AS saldo_total
    FROM carteras WHERE fecha_cierre IS NULL GROUP BY cliente_id
),
credito_activo AS (
    SELECT DISTINCT ca.cliente_id
    FROM carteras ca JOIN productos p ON p.producto_id = ca.producto_id
    WHERE ca.fecha_cierre IS NULL AND p.categoria = 'Crédito'
),
retiros_historicos AS (
    SELECT cliente_id, SUM(monto) AS total_retiros
    FROM transacciones WHERE tipo = 'Retiro' AND estado = 'Completada'
    GROUP BY cliente_id
)
SELECT
    c.cliente_id, c.nombre, c.segmento,
    s.saldo_total,
    COALESCE(r.total_retiros, 0) AS retiros_historicos,
    ROUND(100.0 * COALESCE(r.total_retiros,0) / NULLIF(s.saldo_total,0), 2) AS pct_sobre_saldo,
    CASE WHEN COALESCE(r.total_retiros,0) > 0.5 * s.saldo_total
         THEN 'AT RISK' ELSE 'Normal' END AS clasificacion
FROM clientes c
JOIN credito_activo cr ON cr.cliente_id = c.cliente_id
JOIN saldo_activo   s  ON s.cliente_id  = c.cliente_id
LEFT JOIN retiros_historicos r ON r.cliente_id = c.cliente_id
ORDER BY pct_sobre_saldo DESC;
