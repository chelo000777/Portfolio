-- ============================================================================
-- 5G_USERS_DEVELOPMENT_ANALYSIS_FABIO_2406_CLEANED
-- Purpose : Segment CRM users by prepaid/postpaid status, 5G N78 terminal
--           capability, observed 5G activity, legacy 2G/3G/4G traffic, urban
--           location, and NR switch status for 5G potential-user campaigns.
-- Source  : 5G_USERS_DEVELOPMENT_ANALYSIS_FABIO_2406.sql
-- Period  : May 2026 traffic analysis, with June 2026 switch-status review.
-- Notes   : Pasted query result grids and OS export/check commands were removed
--           so this file is easier to execute as SQL. Export targets are noted
--           where the original shell commands appeared.
-- ============================================================================

-- Section Index
-- 01. CRM base validation and prepaid/postpaid split
-- 02. N78-capable terminal catalog and 5G-terminal universe
-- 03. CRM users classified by 5G-terminal ownership
-- 04. Observed 5G NR traffic, RAT = 9, traffic > 1 MB
-- 05. Legacy 2G/3G/4G traffic summary for inactive 5G users
-- 06. Active vs inactive 5G-terminal user segmentation
-- 07. NR switch on/off status summary
-- 08. Inactive 5G-terminal users enriched with main 4G site and switch status
-- 09. Postpaid urban potential-user export segment
-- 10. Prepaid urban over-15GB potential-user export segment

-- Code values
-- tipo: 0 = PREPAID, 1 = POSTPAID
-- card: 0 = SIM, 1 = USIM
-- RAT: 9 = 5G NR; 1, 2, 5, 6 = legacy / 2G-4G traffic set used here


-- A_ALL USER UNIVERSE

select count(*) from subscriber_db.x_crm_mayo_2026;


select * from subscriber_db.x_crm_mayo_2026 LIMIT 3;




DESCRIBE traffic_db.SDR_FLOW_SUBSCRIBER_1DAY_<PARTITION>;


Regarding this I require to summariza regarding the following conditions:
1. key field msisdn (unique values)
2. cast(a.batchno / 10000 as int) >= 20260501 AND cast(a.batchno / 10000 as int) <= 20260531
3.




SELECT
    concat(substr(cast(a.batchno as string), 1, 4), '-', substr(cast(a.batchno as string), 5, 2), '-', substr(cast(a.batchno as string), 7, 2)) as day,
    a.msisdn,
    a.tac,
    a.rat,
    sum(a.l4_ul_throughput + a.l4_dw_throughput) / 1024 / 1024 / 1024 as PS_Traffic_GB
FROM traffic_db.SDR_FLOW_SUBSCRIBER_1DAY_<PARTITION>;






ON cast(a.tac as string) = cast(n78.tac as string)




DROP TABLE IF EXISTS PS.tmp_ALL_USERS_UNIVERSE_TERM;
CREATE TABLE PS.tmp_ALL_USERS_UNIVERSE_TERM AS
SELECT
    concat(substr(cast(a.batchno as string), 1, 4), '-', substr(cast(a.batchno as string), 5, 2), '-', substr(cast(a.batchno as string), 7, 2)) as day,
    a.msisdn,
    a.tac,
    d.TER_BRAND_NAME,
    d.TER_MODEL_NAME,
    d.TER_MODENAME,
    d.TER_TYPE_NAME_EN,
    a.rat,
    sum(a.l4_ul_throughput + a.l4_dw_throughput) / 1024 / 1024 / 1024 as PS_Traffic_GB
FROM traffic_db.SDR_FLOW_SUBSCRIBER_1DAY_<PARTITION> a
LEFT JOIN (
    SELECT DISTINCT
        tac,
        TER_BRAND_NAME,
        TER_MODEL_NAME,
        TER_MODENAME,
        TER_TYPE_NAME_EN
    FROM network_db.dim_terminal
) d
    ON cast(a.tac as string) = cast(d.tac as string)
WHERE substr(a.IMSI, 1, 5) = '<OPERATOR_IMSI_PREFIX>'
  AND cast(a.batchno / 10000 as int) >= 20260501
  AND cast(a.batchno / 10000 as int) <= 20260531
GROUP BY
    concat(substr(cast(a.batchno as string), 1, 4), '-', substr(cast(a.batchno as string), 5, 2), '-', substr(cast(a.batchno as string), 7, 2)),
    a.msisdn,
    a.tac,
    d.TER_BRAND_NAME,
    d.TER_MODEL_NAME,
    d.TER_MODENAME,
    d.TER_TYPE_NAME_EN,
    a.rat
ORDER BY PS_Traffic_GB DESC;

-- FIXED ALL_USERS_UNIVERSE_TERM

DROP TABLE IF EXISTS PS.tmp_ALL_USERS_UNIVERSE_TERM;

CREATE TABLE PS.tmp_ALL_USERS_UNIVERSE_TERM AS
WITH traffic_base AS (
    SELECT
        CONCAT(
            SUBSTR(CAST(a.batchno AS string), 1, 4), '-',
            SUBSTR(CAST(a.batchno AS string), 5, 2), '-',
            SUBSTR(CAST(a.batchno AS string), 7, 2)
        ) AS day,
        a.msisdn,
        CAST(a.tac AS string) AS tac,
        a.rat,
        SUM(
            COALESCE(a.l4_ul_throughput, 0) +
            COALESCE(a.l4_dw_throughput, 0)
        ) / 1024 / 1024 / 1024 AS PS_Traffic_GB
    FROM traffic_db.SDR_FLOW_SUBSCRIBER_1DAY_<PARTITION> a
    WHERE SUBSTR(a.IMSI, 1, 5) = '<OPERATOR_IMSI_PREFIX>'
      AND CAST(SUBSTR(CAST(a.batchno AS string), 1, 8) AS int) BETWEEN 20260501 AND 20260531
    GROUP BY
        CONCAT(
            SUBSTR(CAST(a.batchno AS string), 1, 4), '-',
            SUBSTR(CAST(a.batchno AS string), 5, 2), '-',
            SUBSTR(CAST(a.batchno AS string), 7, 2)
        ),
        a.msisdn,
        CAST(a.tac AS string),
        a.rat
),

terminal_dim AS (
    SELECT
        CAST(tac AS string) AS tac,
        MAX(TER_BRAND_NAME) AS TER_BRAND_NAME,
        MAX(TER_MODEL_NAME) AS TER_MODEL_NAME,
        MAX(TER_MODENAME) AS TER_MODENAME,
        MAX(TER_TYPE_NAME_EN) AS TER_TYPE_NAME_EN
    FROM network_db.dim_terminal
    GROUP BY CAST(tac AS string)
)

SELECT
    t.day,
    t.msisdn,
    t.tac,
    d.TER_BRAND_NAME,
    d.TER_MODEL_NAME,
    d.TER_MODENAME,
    d.TER_TYPE_NAME_EN,
    t.rat,
    t.PS_Traffic_GB
FROM traffic_base t
LEFT JOIN terminal_dim d
    ON t.tac = d.tac;

-- rat flag

DROP TABLE IF EXISTS PS.tmp_ALL_USERS_UNIVERSE_TERM_RAT_EVALUATION;
CREATE TABLE PS.PS.tmp_ALL_USERS_UNIVERSE_TERM_RAT_EVALUATION AS
SELECT
    concat(substr(cast(a.batchno as string), 1, 4), '-', substr(cast(a.batchno as string), 5, 2), '-', substr(cast(a.batchno as string), 7, 2)) as day,
    a.msisdn,
    a.tac,
    d.TER_BRAND_NAME,
    d.TER_MODEL_NAME,
    d.TER_MODENAME,
    d.TER_TYPE_NAME_EN,
    a.rat,
    sum(a.l4_ul_throughput + a.l4_dw_throughput) / 1024 / 1024 / 1024 as PS_Traffic_GB
FROM traffic_db.SDR_FLOW_SUBSCRIBER_1DAY_<PARTITION> a
LEFT JOIN (
    SELECT DISTINCT
        tac,
        TER_BRAND_NAME,
        TER_MODEL_NAME,
        TER_MODENAME,
        TER_TYPE_NAME_EN
    FROM network_db.dim_terminal
) d
    ON cast(a.tac as string) = cast(d.tac as string)
WHERE substr(a.IMSI, 1, 5) = '<OPERATOR_IMSI_PREFIX>'
  AND cast(a.batchno / 10000 as int) >= 20260501
  AND cast(a.batchno / 10000 as int) <= 20260531
GROUP BY
    concat(substr(cast(a.batchno as string), 1, 4), '-', substr(cast(a.batchno as string), 5, 2), '-', substr(cast(a.batchno as string), 7, 2)),
    a.msisdn,
    a.tac,
    d.TER_BRAND_NAME,
    d.TER_MODEL_NAME,
    d.TER_MODENAME,
    d.TER_TYPE_NAME_EN,
    a.rat
ORDER BY PS_Traffic_GB DESC;



-- v2

DROP TABLE IF EXISTS PS.tmp_ALL_USERS_UNIVERSE_TERM_RAT_EVALUATION;

CREATE TABLE PS.tmp_ALL_USERS_UNIVERSE_TERM_RAT_EVALUATION AS
WITH traffic_base AS (
    SELECT
        CONCAT(
            SUBSTR(CAST(a.batchno AS string), 1, 4), '-',
            SUBSTR(CAST(a.batchno AS string), 5, 2), '-',
            SUBSTR(CAST(a.batchno AS string), 7, 2)
        ) AS day,
        a.msisdn,
        CAST(a.tac AS string) AS tac,
        a.rat,
        SUM(
            COALESCE(a.l4_ul_throughput, 0) +
            COALESCE(a.l4_dw_throughput, 0)
        ) / 1024 / 1024 / 1024 AS PS_Traffic_GB
    FROM traffic_db.SDR_FLOW_SUBSCRIBER_1DAY_<PARTITION> a
    WHERE SUBSTR(a.IMSI, 1, 5) = '<OPERATOR_IMSI_PREFIX>'
      AND CAST(SUBSTR(CAST(a.batchno AS string), 1, 8) AS int) BETWEEN 20260501 AND 20260531
    GROUP BY
        CONCAT(
            SUBSTR(CAST(a.batchno AS string), 1, 4), '-',
            SUBSTR(CAST(a.batchno AS string), 5, 2), '-',
            SUBSTR(CAST(a.batchno AS string), 7, 2)
        ),
        a.msisdn,
        CAST(a.tac AS string),
        a.rat
),

terminal_dim AS (
    SELECT
        CAST(tac AS string) AS tac,
        MAX(TER_BRAND_NAME) AS TER_BRAND_NAME,
        MAX(TER_MODEL_NAME) AS TER_MODEL_NAME,
        MAX(TER_MODENAME) AS TER_MODENAME,
        MAX(TER_TYPE_NAME_EN) AS TER_TYPE_NAME_EN
    FROM network_db.dim_terminal
    GROUP BY CAST(tac AS string)
)

SELECT
    t.day,
    t.msisdn,
    t.tac,
    d.TER_BRAND_NAME,
    d.TER_MODEL_NAME,
    d.TER_MODENAME,
    d.TER_TYPE_NAME_EN,
    t.rat,
    t.PS_Traffic_GB
FROM traffic_base t
LEFT JOIN terminal_dim d
    ON t.tac = d.tac;


--00 I require to add a field called 5G_FLAG, it is 1 if during day row evaluation, rat =9 has SUM(a.l4_ul_throughput + a.l4_dw_throughput) / 1024 / 1024  > (1.0 / 1024) 

DROP TABLE IF EXISTS PS.tmp_ALL_USERS_UNIVERSE_TERM_RAT_EVALUATION;

CREATE TABLE PS.tmp_ALL_USERS_UNIVERSE_TERM_RAT_EVALUATION AS
WITH traffic_base AS (
    SELECT
        CONCAT(
            SUBSTR(CAST(a.batchno AS string), 1, 4), '-',
            SUBSTR(CAST(a.batchno AS string), 5, 2), '-',
            SUBSTR(CAST(a.batchno AS string), 7, 2)
        ) AS day,
        a.msisdn,
        CAST(a.tac AS string) AS tac,
        a.rat,
        SUM(
            COALESCE(a.l4_ul_throughput, 0) +
            COALESCE(a.l4_dw_throughput, 0)
        ) / 1024 / 1024 AS PS_Traffic_MB,
        SUM(
            COALESCE(a.l4_ul_throughput, 0) +
            COALESCE(a.l4_dw_throughput, 0)
        ) / 1024 / 1024 / 1024 AS PS_Traffic_GB
    FROM traffic_db.SDR_FLOW_SUBSCRIBER_1DAY_<PARTITION> a
    WHERE SUBSTR(a.IMSI, 1, 5) = '<OPERATOR_IMSI_PREFIX>'
      AND CAST(SUBSTR(CAST(a.batchno AS string), 1, 8) AS int) BETWEEN 20260501 AND 20260531
    GROUP BY
        CONCAT(
            SUBSTR(CAST(a.batchno AS string), 1, 4), '-',
            SUBSTR(CAST(a.batchno AS string), 5, 2), '-',
            SUBSTR(CAST(a.batchno AS string), 7, 2)
        ),
        a.msisdn,
        CAST(a.tac AS string),
        a.rat
),

traffic_flagged AS (
    SELECT
        day,
        msisdn,
        tac,
        rat,
        CASE
            WHEN rat = 9
             AND PS_Traffic_MB > (1.0 / 1024)
            THEN 1
            ELSE 0
        END AS `5G_FLAG`,
        PS_Traffic_GB
    FROM traffic_base
),

terminal_dim AS (
    SELECT
        CAST(tac AS string) AS tac,
        MAX(TER_BRAND_NAME) AS TER_BRAND_NAME,
        MAX(TER_MODEL_NAME) AS TER_MODEL_NAME,
        MAX(TER_MODENAME) AS TER_MODENAME,
        MAX(TER_TYPE_NAME_EN) AS TER_TYPE_NAME_EN
    FROM network_db.dim_terminal
    GROUP BY CAST(tac AS string)
)

SELECT
    t.day,
    t.msisdn,
    t.tac,
    d.TER_BRAND_NAME,
    d.TER_MODEL_NAME,
    d.TER_MODENAME,
    d.TER_TYPE_NAME_EN,
    t.rat,
    t.`5G_FLAG`,
    t.PS_Traffic_GB
FROM traffic_flagged t
LEFT JOIN terminal_dim d
    ON t.tac = d.tac;

select * from PS.tmp_ALL_USERS_UNIVERSE_TERM_RAT_EVALUATION order by 10 desc limit 100;

select * from PS.tmp_ALL_USERS_UNIVERSE_TERM_RAT_EVALUATION where 5G_FLAG =1 order by 10 desc limit 100;































-- ============================================================================
-- 01. CRM base validation and prepaid/postpaid split
-- ============================================================================
-- 0_ALL USERS 7218240
select count(*) from subscriber_db.x_crm_mayo_2026;

-- SEGMENTATION_PREPAID_POST_PAID_USERS
    -- PREPAID = 0 
    -- POSTPAID = 1

    -- USIM = 1
    -- SIM = 0
-- v1
Select DISTINCT tipo, count(*) from subscriber_db.x_crm_mayo_2026 group by tipo;
--  1_PREPAID_POSTPAID_SEGMENTATION
SELECT
    CASE
        WHEN tipo = 0 THEN 'PREPAID'
        WHEN tipo = 1 THEN 'POSTPAID'
        ELSE 'UNKNOWN'
    END AS tipo,
    COUNT(*) AS total_users,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS share_percentage
FROM subscriber_db.x_crm_mayo_2026
GROUP BY
    CASE
        WHEN tipo = 0 THEN 'PREPAID'
        WHEN tipo = 1 THEN 'POSTPAID'
        ELSE 'UNKNOWN'
    END;

-- v3_USIM_SIM
SELECT
    CASE
        WHEN tipo = 0 THEN 'PREPAID'
        WHEN tipo = 1 THEN 'POSTPAID'
        ELSE 'UNKNOWN'
    END AS tipo,

    CASE
        WHEN card = 1 THEN 'USIM'
        WHEN card = 0 THEN 'SIM'
        ELSE 'UNKNOWN'
    END AS card_type,

    COUNT(*) AS total_users,

    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS share_percentage
FROM subscriber_db.x_crm_abril_2026
GROUP BY
    CASE
        WHEN tipo = 0 THEN 'PREPAID'
        WHEN tipo = 1 THEN 'POSTPAID'
        ELSE 'UNKNOWN'
    END,
    CASE
        WHEN card = 1 THEN 'USIM'
        WHEN card = 0 THEN 'SIM'
        ELSE 'UNKNOWN'
    END
ORDER BY tipo, card_type;

--  PREPAID_POST_PAID TABLE CREATION

-- PREPAID = 0
DROP TABLE IF EXISTS subscriber_db.x_crm_PREPAID;
CREATE TABLE subscriber_db.x_crm_PREPAID AS
SELECT msisdn, tipo, card
FROM subscriber_db.x_crm_mayo_2026
WHERE tipo = 0;

-- POSTPAID = 1
DROP TABLE IF EXISTS subscriber_db.x_crm_POSTPAID;
CREATE TABLE subscriber_db.x_crm_POSTPAID AS
SELECT msisdn, tipo, card
FROM subscriber_db.x_crm_mayo_2026
WHERE tipo = 1;


-- ============================================================================
-- 02. N78-capable terminal catalog and 5G-terminal universe
-- ============================================================================
-- 5G TERMINAL & N78 TABLE CREATION

DROP TABLE IF EXISTS network_db.tac_5G_terminal_n78;

CREATE TABLE network_db.tac_5G_terminal_n78
STORED BY 'org.apache.carbondata.format'
AS
SELECT DISTINCT
    cast(TAC as string) as TAC,
    TER_BRAND_NAME,
    TER_MODEL_NAME,
    TER_MODENAME,
    TER_TYPE_ID,
    TER_TYPE_NAME_EN
FROM network_db.dim_terminal
WHERE TERBAND like '%5078%';

--  ALL USERS WITH 5G_TERMINAL CREATION 
DROP TABLE IF EXISTS PS.tmp_5G_TERMINAL_USERS_UNIVERSE;
CREATE TABLE PS.tmp_5G_TERMINAL_USERS_UNIVERSE AS
SELECT
    concat(substr(cast(a.batchno as string), 1, 4), '-', substr(cast(a.batchno as string), 5, 2), '-', substr(cast(a.batchno as string), 7, 2)) as day,
    a.msisdn,
    a.tac,
    d.TER_BRAND_NAME,
    d.TER_MODEL_NAME,
    d.TER_MODENAME,
    d.TER_TYPE_NAME_EN,
    a.rat,
    sum(a.l4_ul_throughput + a.l4_dw_throughput) / 1024 / 1024 / 1024 as PS_Traffic_GB
FROM traffic_db.SDR_FLOW_SUBSCRIBER_1DAY_<PARTITION> a
INNER JOIN (
    SELECT DISTINCT tac
    FROM network_db.tac_5G_terminal_n78
) n78
    ON cast(a.tac as string) = cast(n78.tac as string)
LEFT JOIN (
    SELECT DISTINCT
        tac,
        TER_BRAND_NAME,
        TER_MODEL_NAME,
        TER_MODENAME,
        TER_TYPE_NAME_EN
    FROM network_db.dim_terminal
) d
    ON cast(a.tac as string) = cast(d.tac as string)
WHERE substr(a.IMSI, 1, 5) = '<OPERATOR_IMSI_PREFIX>'
  AND cast(a.batchno / 10000 as int) >= 20260501
  AND cast(a.batchno / 10000 as int) <= 20260531
GROUP BY
    concat(substr(cast(a.batchno as string), 1, 4), '-', substr(cast(a.batchno as string), 5, 2), '-', substr(cast(a.batchno as string), 7, 2)),
    a.msisdn,
    a.tac,
    d.TER_BRAND_NAME,
    d.TER_MODEL_NAME,
    d.TER_MODENAME,
    d.TER_TYPE_NAME_EN,
    a.rat
ORDER BY PS_Traffic_GB DESC;

SELECT COUNT(*) FROM PS.tmp_5G_TERMINAL_USERS_UNIVERSE;

SELECT COUNT(DISTINCT msisdn) FROM PS.tmp_5G_TERMINAL_USERS_UNIVERSE;

SELECT * FROM PS.tmp_5G_TERMINAL_USERS_UNIVERSE LIMIT 4;

-- POST_PAID_USERS WITH 5G_TERMINALS 

-- 0 = PREPAID
-- 1 = POSTPAID

describe PS.tmp_5G_TERMINAL_USERS_UNIVERSE;

describe subscriber_db.x_crm_mayo_2026;

-- COUNT OF PREPAID AND POSTPAID USERS WITH 5G TERMINALS
SELECT
    crm.tipo,
    CASE
        WHEN crm.tipo = '0' THEN 'PREPAID'
        WHEN crm.tipo = '1' THEN 'POSTPAID'
    END AS user_type,
    COUNT(DISTINCT crm.msisdn) AS total_msisdn
FROM subscriber_db.x_crm_mayo_2026 crm
WHERE crm.tipo IN ('0', '1')
  AND EXISTS (
      SELECT 1
      FROM PS.tmp_5G_TERMINAL_USERS_UNIVERSE u
      WHERE u.msisdn = crm.msisdn
  )
GROUP BY
    crm.tipo,
    CASE
        WHEN crm.tipo = '0' THEN 'PREPAID'
        WHEN crm.tipo = '1' THEN 'POSTPAID'
    END
ORDER BY crm.tipo;


-- ============================================================================
-- 03. CRM users classified by 5G-terminal ownership
-- ============================================================================
-- CRM USERS CLASSIFIED BY 5G TERMINAL OWNERSHIP

-- 1. PREPAID USERS WITH 5G TERMINALS
DROP TABLE IF EXISTS subscriber_db.TMP_CRM_PREPAID_5G_TERM;
CREATE TABLE subscriber_db.TMP_CRM_PREPAID_5G_TERM AS
SELECT DISTINCT
    p.msisdn
FROM subscriber_db.x_crm_PREPAID p
WHERE EXISTS (
    SELECT 1
    FROM PS.tmp_5G_TERMINAL_USERS_UNIVERSE u
    WHERE u.msisdn = p.msisdn
);

-- 2. PREPAID USERS WITHOUT 5G TERMINALS
DROP TABLE IF EXISTS subscriber_db.TMP_CRM_PREPAID_NO_5G_TERM;
CREATE TABLE subscriber_db.TMP_CRM_PREPAID_NO_5G_TERM AS
SELECT DISTINCT
    p.msisdn
FROM subscriber_db.x_crm_PREPAID p
WHERE NOT EXISTS (
    SELECT 1
    FROM PS.tmp_5G_TERMINAL_USERS_UNIVERSE u
    WHERE u.msisdn = p.msisdn
);

-- 3. POSTPAID USERS WITH 5G TERMINALS
DROP TABLE IF EXISTS subscriber_db.TMP_CRM_POSTPAID_5G_TERM;
CREATE TABLE subscriber_db.TMP_CRM_POSTPAID_5G_TERM AS
SELECT DISTINCT
    p.msisdn
FROM subscriber_db.x_crm_POSTPAID p
WHERE EXISTS (
    SELECT 1
    FROM PS.tmp_5G_TERMINAL_USERS_UNIVERSE u
    WHERE u.msisdn = p.msisdn
);

-- 4. POSTPAID USERS WITHOUT 5G TERMINALS
DROP TABLE IF EXISTS subscriber_db.TMP_CRM_POSTPAID_NO_5G_TERM;
CREATE TABLE subscriber_db.TMP_CRM_POSTPAID_NO_5G_TERM AS
SELECT DISTINCT
    p.msisdn
FROM subscriber_db.x_crm_POSTPAID p
WHERE NOT EXISTS (
    SELECT 1
    FROM PS.tmp_5G_TERMINAL_USERS_UNIVERSE u
    WHERE u.msisdn = p.msisdn
);

SELECT COUNT(*) FROM subscriber_db.TMP_CRM_PREPAID_5G_TERM;

SELECT COUNT(*) FROM subscriber_db.TMP_CRM_PREPAID_NO_5G_TERM;

SELECT COUNT(*) FROM subscriber_db.TMP_CRM_POSTPAID_5G_TERM;

SELECT COUNT(*) FROM subscriber_db.TMP_CRM_POSTPAID_NO_5G_TERM;


-- ============================================================================
-- 04. Observed 5G NR traffic, RAT = 9, traffic > 1 MB
-- ============================================================================
-- 5G USERS IN N78 BAND, ALL USERS, PREPAID & POSTPAID_TRAFFIC_OVER_1MB

DROP TABLE IF EXISTS PS.tmp_5G_TRAFFIC_PLUS_1MB;
CREATE TABLE PS.tmp_5G_TRAFFIC_PLUS_1MB AS
SELECT
    concat(substr(cast(a.batchno as string), 1, 4), '-', substr(cast(a.batchno as string), 5, 2), '-', substr(cast(a.batchno as string), 7, 2)) as day,
    a.msisdn,
    a.tac,
    d.TER_BRAND_NAME,
    d.TER_MODEL_NAME,
    d.TER_MODENAME,
    d.TER_TYPE_NAME_EN,
    a.rat,
    sum(a.l4_ul_throughput + a.l4_dw_throughput) / 1024 / 1024 / 1024 as PS_Traffic_GB
FROM traffic_db.SDR_FLOW_SUBSCRIBER_1DAY_<PARTITION> a
INNER JOIN (
    SELECT DISTINCT tac
    FROM network_db.tac_5G_terminal_n78
) n78
    ON cast(a.tac as string) = cast(n78.tac as string)
LEFT JOIN (
    SELECT DISTINCT
        tac,
        TER_BRAND_NAME,
        TER_MODEL_NAME,
        TER_MODENAME,
        TER_TYPE_NAME_EN
    FROM network_db.dim_terminal
) d
    ON cast(a.tac as string) = cast(d.tac as string)
WHERE substr(a.IMSI, 1, 5) = '<OPERATOR_IMSI_PREFIX>'
  AND cast(a.batchno / 10000 as int) >= 20260501
  AND cast(a.batchno / 10000 as int) <= 20260531
  AND a.rat = 9
GROUP BY
    concat(substr(cast(a.batchno as string), 1, 4), '-', substr(cast(a.batchno as string), 5, 2), '-', substr(cast(a.batchno as string), 7, 2)),
    a.msisdn,
    a.tac,
    d.TER_BRAND_NAME,
    d.TER_MODEL_NAME,
    d.TER_MODENAME,
    d.TER_TYPE_NAME_EN,
    a.rat
HAVING
    SUM(a.l4_ul_throughput + a.l4_dw_throughput) / 1024 / 1024  > (1.0 / 1024) 
ORDER BY PS_Traffic_GB DESC;


-- Export command removed from executable SQL. See original file for shell command details.

-- 2_2_PREPAID_5G_TERMINAL_EVALUATION

SELECT COUNT(*) FROM PS.tmp_5G_TRAFFIC_PLUS_1MB;
SELECT COUNT( DISTINCT msisdn) FROM PS.tmp_5G_TRAFFIC_PLUS_1MB;
SELECT * FROM PS.tmp_5G_TRAFFIC_PLUS_1MB LIMIT 3;

DESCRIBE PS.tmp_5G_TRAFFIC_PLUS_1MB;

 DESCRIBE PS.tmp_5G_TRAFFIC_PLUS_1MB;


-- ============================================================================
-- 05. Legacy 2G/3G/4G traffic summary for inactive 5G users
-- ============================================================================
-- TRAFFIC AND DETAIL CALCULATION FOR NO_5G_USERS
-- TABLE CREATION FOR NOT 5G USERS

        -- traffic_db.SDR_FLOW_SUBSCRIBER_1DAY_<PARTITION>
        -- rat in (1,2,5,6)

DROP TABLE IF EXISTS PS.tmp_2G3G4G_TRAFFIC_PLUS_1MB;
CREATE TABLE PS.tmp_2G3G4G_TRAFFIC_PLUS_1MB AS
SELECT
    concat(substr(cast(a.batchno as string), 1, 4), '-', substr(cast(a.batchno as string), 5, 2), '-', substr(cast(a.batchno as string), 7, 2)) AS day,
    a.msisdn,
    a.tac,
    d.TER_BRAND_NAME,
    d.TER_MODEL_NAME,
    d.TER_MODENAME,
    d.TER_TYPE_NAME_EN,
    a.rat,
    SUM(a.l4_ul_throughput + a.l4_dw_throughput) / 1024 / 1024 / 1024 AS PS_Traffic_GB
FROM traffic_db.SDR_FLOW_SUBSCRIBER_1DAY_<PARTITION> a
INNER JOIN (
    SELECT DISTINCT tac
    FROM network_db.dim_terminal
) terminals
    ON CAST(a.tac AS string) = CAST(terminals.tac AS string)
LEFT JOIN (
    SELECT DISTINCT
        tac,
        TER_BRAND_NAME,
        TER_MODEL_NAME,
        TER_MODENAME,
        TER_TYPE_NAME_EN
    FROM network_db.dim_terminal
) d
    ON CAST(a.tac AS string) = CAST(d.tac AS string)
WHERE substr(a.IMSI, 1, 5) = '<OPERATOR_IMSI_PREFIX>'
  AND CAST(a.batchno / 10000 AS int) >= 20260501
  AND CAST(a.batchno / 10000 AS int) <= 20260531
  AND a.rat IN (1, 2, 5, 6)
GROUP BY
    concat(substr(cast(a.batchno as string), 1, 4), '-', substr(cast(a.batchno as string), 5, 2), '-', substr(cast(a.batchno as string), 7, 2)),
    a.msisdn,
    a.tac,
    d.TER_BRAND_NAME,
    d.TER_MODEL_NAME,
    d.TER_MODENAME,
    d.TER_TYPE_NAME_EN,
    a.rat
HAVING
    SUM(a.l4_ul_throughput + a.l4_dw_throughput) / 1024 / 1024 / 1024 > (1.0 / 1024)
ORDER BY PS_Traffic_GB DESC;

SELECT * FROM PS.tmp_2G3G4G_TRAFFIC_PLUS_1MB LIMIT 3;

SELECT COUNT(*) FROM PS.tmp_2G3G4G_TRAFFIC_PLUS_1MB;

SELECT COUNT(DISTINCT msisdn) FROM PS.tmp_2G3G4G_TRAFFIC_PLUS_1MB;

-- ONE ROW PER MSISDN: LATEST TERMINAL + MONTHLY 2G/3G/4G TRAFFIC SUMMARY
DROP TABLE IF EXISTS PS.tmp_2G3G4G_TRAFFIC_PLUS_1MB_SUMMARIZED;

CREATE TABLE PS.tmp_2G3G4G_TRAFFIC_PLUS_1MB_SUMMARIZED AS
WITH latest_terminal AS (
    SELECT
        msisdn,
        tac,
        TER_BRAND_NAME,
        TER_MODEL_NAME,
        TER_MODENAME,
        TER_TYPE_NAME_EN,
        ROW_NUMBER() OVER (
            PARTITION BY msisdn
            ORDER BY day DESC, PS_Traffic_GB DESC, tac DESC
        ) AS rn
    FROM PS.tmp_2G3G4G_TRAFFIC_PLUS_1MB
),
traffic_summary AS (
    SELECT
        msisdn,
        COUNT(DISTINCT tac) AS diff_tac_count,
        SUM(PS_Traffic_GB) AS total_PS_Traffic_GB,
        COUNT(DISTINCT day) AS days_w_traff_over_1MB
    FROM PS.tmp_2G3G4G_TRAFFIC_PLUS_1MB
    GROUP BY msisdn
)
SELECT
    s.msisdn,
    l.tac AS last_tac,
    l.TER_BRAND_NAME,
    l.TER_MODEL_NAME,
    l.TER_MODENAME,
    l.TER_TYPE_NAME_EN,
    s.diff_tac_count,
    s.total_PS_Traffic_GB,
    s.days_w_traff_over_1MB
FROM traffic_summary s
INNER JOIN latest_terminal l
    ON s.msisdn = l.msisdn
   AND l.rn = 1;

SELECT COUNT(DISTINCT msisdn) from PS.tmp_2G3G4G_TRAFFIC_PLUS_1MB_SUMMARIZED;
SELECT COUNT(*) from PS.tmp_2G3G4G_TRAFFIC_PLUS_1MB_SUMMARIZED;

-- THE TWO COUNTS MUST MATCH: THE SUMMARY HAS ONE ROW PER UNIQUE MSISDN.
SELECT
    COUNT(*) AS summarized_rows,
    COUNT(DISTINCT msisdn) AS unique_msisdn
FROM PS.tmp_2G3G4G_TRAFFIC_PLUS_1MB_SUMMARIZED;

select * from PS.tmp_2G3G4G_TRAFFIC_PLUS_1MB_SUMMARIZED limit 3 order by total_PS_Traffic_GB desc ;


-- ============================================================================
-- 06. Active vs inactive 5G-terminal user segmentation
-- ============================================================================
-- CRM 5G-TERMINAL USERS CLASSIFIED BY ACTIVE 5G TRAFFIC

-- 1. ACTIVE PREPAID USERS WITH 5G TERMINALS
DROP TABLE IF EXISTS subscriber_db.TMP_CRM_PREPAID_5G_TERM_ACTIVE_USER;

CREATE TABLE subscriber_db.TMP_CRM_PREPAID_5G_TERM_ACTIVE_USER AS
WITH traffic_ranked AS (
    SELECT
        t.*,
        ROW_NUMBER() OVER (
            PARTITION BY t.msisdn
            ORDER BY t.day DESC, t.PS_Traffic_GB DESC
        ) AS rn
    FROM PS.tmp_5G_TRAFFIC_PLUS_1MB t
)
SELECT
    p.msisdn,
    t.day,
    t.tac,
    t.TER_BRAND_NAME,
    t.TER_MODEL_NAME,
    t.TER_MODENAME,
    t.TER_TYPE_NAME_EN,
    t.rat,
    t.PS_Traffic_GB
FROM subscriber_db.TMP_CRM_PREPAID_5G_TERM p
INNER JOIN traffic_ranked t
    ON t.msisdn = p.msisdn
   AND t.rn = 1
WHERE p.msisdn IS NOT NULL;

select * from subscriber_db.TMP_CRM_PREPAID_5G_TERM_ACTIVE_USER limit 10;
select count(*) from subscriber_db.TMP_CRM_PREPAID_5G_TERM_ACTIVE_USER;

-- 2. **INACTIVE PREPAID USERS WITH 5G TERMINALS
DROP TABLE IF EXISTS subscriber_db.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER;
CREATE TABLE subscriber_db.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER AS
SELECT DISTINCT
    p.msisdn,
    s.last_tac,
    s.TER_BRAND_NAME,
    s.TER_MODEL_NAME,
    s.TER_MODENAME,
    s.TER_TYPE_NAME_EN,
    s.diff_tac_count,
    s.total_PS_Traffic_GB,
    s.days_w_traff_over_1MB
FROM subscriber_db.TMP_CRM_PREPAID_5G_TERM p
LEFT JOIN PS.tmp_2G3G4G_TRAFFIC_PLUS_1MB_SUMMARIZED s
    ON p.msisdn = s.msisdn
WHERE p.msisdn IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM PS.tmp_5G_TRAFFIC_PLUS_1MB t
      WHERE t.msisdn = p.msisdn
  );

SELECT * FROM subscriber_db.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER LIMIT 3;

SELECT COUNT(*) FROM subscriber_db.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER;

-- 3. ACTIVE POSTPAID USERS WITH 5G TERMINALS
DROP TABLE IF EXISTS subscriber_db.TMP_CRM_POSTPAID_5G_TERM_ACTIVE_USER;

CREATE TABLE subscriber_db.TMP_CRM_POSTPAID_5G_TERM_ACTIVE_USER AS
WITH traffic_ranked AS (
    SELECT
        t.*,
        ROW_NUMBER() OVER (
            PARTITION BY t.msisdn
            ORDER BY t.day DESC, t.PS_Traffic_GB DESC
        ) AS rn
    FROM PS.tmp_5G_TRAFFIC_PLUS_1MB t
)
SELECT
    p.msisdn,
    t.day,
    t.tac,
    t.TER_BRAND_NAME,
    t.TER_MODEL_NAME,
    t.TER_MODENAME,
    t.TER_TYPE_NAME_EN,
    t.rat,
    t.PS_Traffic_GB
FROM subscriber_db.TMP_CRM_POSTPAID_5G_TERM p
INNER JOIN traffic_ranked t
    ON t.msisdn = p.msisdn
   AND t.rn = 1
WHERE p.msisdn IS NOT NULL;

select * from subscriber_db.TMP_CRM_POSTPAID_5G_TERM_ACTIVE_USER limit 10;
select count(*) from subscriber_db.TMP_CRM_POSTPAID_5G_TERM_ACTIVE_USER;

-- 4. INACTIVE POSTPAID USERS WITH 5G TERMINALS
DROP TABLE IF EXISTS subscriber_db.TMP_CRM_POSTPAID_5G_TERM_INACTIVE_USER;
CREATE TABLE subscriber_db.TMP_CRM_POSTPAID_5G_TERM_INACTIVE_USER AS
SELECT DISTINCT
    p.msisdn,
    s.last_tac,
    s.TER_BRAND_NAME,
    s.TER_MODEL_NAME,
    s.TER_MODENAME,
    s.TER_TYPE_NAME_EN,
    s.diff_tac_count,
    s.total_PS_Traffic_GB,
    s.days_w_traff_over_1MB
FROM subscriber_db.TMP_CRM_POSTPAID_5G_TERM p
LEFT JOIN PS.tmp_2G3G4G_TRAFFIC_PLUS_1MB_SUMMARIZED s
    ON p.msisdn = s.msisdn
WHERE p.msisdn IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM PS.tmp_5G_TRAFFIC_PLUS_1MB t
      WHERE t.msisdn = p.msisdn
  );

SELECT * FROM subscriber_db.TMP_CRM_POSTPAID_5G_TERM_INACTIVE_USER ORDER BY 8 DESC LIMIT 3;

SELECT COUNT(*) FROM subscriber_db.TMP_CRM_POSTPAID_5G_TERM_INACTIVE_USER;

-- COVERAGE_RETRIEVING FOR POTENTIAL USERS UNACTIVE 5G TERMINAL POST AND PREPAID

-- PREPAID USERS

-- | No. | Database   | Table                             | Purpose                       |
-- | --: | ---------- | --------------------------------- | ----------------------------- |
-- |   1 | `ps`       | `detail_ufdr_streaming_20493`     | Streaming traffic records     |
-- |   2 | `ps`       | `detail_ufdr_voip_20493`          | VoIP traffic records          |
-- |   3 | `ps`       | `detail_ufdr_ftp_20493`           | FTP traffic records           |
-- |   4 | `ps`       | `detail_ufdr_other_20493`         | Other application traffic     |
-- |   5 | `ps`       | `detail_ufdr_fileaccess_20493`    | File-access traffic records   |
-- |   6 | `ps`       | `detail_ufdr_im_20493`            | Instant-messaging traffic     |
-- |   7 | `ps`       | `detail_ufdr_http_browsing_20493` | HTTP browsing traffic         |
-- |   8 | `ps`       | `detail_ufdr_email_20493`         | Email traffic records         |
-- |   9 | `nethouse` | `tmp_borrar_high_pot_users`       | Filter list of selected IMSIs |

-- LEFT JOIN (
--     SELECT DISTINCT
--         a.NE_NAME,
--         a.RAN_NE_ID,
--         a.NE_IP,
--         b.BSCRNC_NAME,
--         b.XPOS,
--         b.YPOS,
--         b.LAYER2NAME,
--         b.LAYER3NAME
--     FROM (
--         SELECT
--             NE_NAME,
--             RAN_NE_ID,
--             NE_IP
--         FROM network_db.cfg_enodeb_ip
--         WHERE NE_IP_TYPE IN (1)
--     ) a
--     LEFT JOIN (
--         SELECT
--             BSCRNC_NAME,
--             XPOS,
--             YPOS,
--             LAYER2NAME,
--             LAYER3NAME
--         FROM NETHOUSE.DIM_LOC_CGISAI
--         WHERE access_type = '4G'
--     ) b
--         ON a.NE_NAME = b.BSCRNC_NAME
-- ) y


-- ============================================================================
-- 07. NR switch on/off status summary
-- ============================================================================
-- switch_on_switch_off_analysis

drop table network_db.temp_review5g_ter_switch_on_off;
create table network_db.temp_review5g_ter_switch_on_off as 
select msisdn, imsi , from_unixtime(PROC_STARTTIME, 'yyyy-MM-dd') as myday, substr(imei,1,8) as tac,sv,
sum(case when (proc_type in (100,103) and dcnr=1) or proc_type in (126) then 1 else 0 end)as sum_on, 
sum(case when (proc_type in (100,103) and (dcnr=0 or dcnr is null)) then 1 else 0 end )as sum_off,
count(*) as num 
from subscriber_db.DETAIL_CDR_S1MME_<NODE_1>
where PROC_SUCCED_FLAG = 0  and substr(imei,1,8) in (select tac  from network_db.dim_terminal WHERE TERBAND like '%5078%' and TER_TYPE_ID in (0,3,5) group by tac)
group by 1,2,3,4,5
union ALL
select msisdn, imsi , from_unixtime(PROC_STARTTIME, 'yyyy-MM-dd') as myday, substr(imei,1,8) as tac,sv,
sum(case when (proc_type in (100,103) and dcnr=1) or proc_type in (126) then 1 else 0 end)as sum_on, 
sum(case when (proc_type in (100,103) and (dcnr=0 or dcnr is null)) then 1 else 0 end )as sum_off,
count(*) as num 
from subscriber_db.DETAIL_CDR_S1MME_<NODE_2>
where PROC_SUCCED_FLAG = 0  and substr(imei,1,8) in (select tac  from network_db.dim_terminal WHERE TERBAND like '%5078%' and TER_TYPE_ID in (0,3,5) group by tac)
group by 1,2,3,4,5
union all
select msisdn, imsi , from_unixtime(PROC_STARTTIME, 'yyyy-MM-dd') as myday, substr(imei,1,8) as tac,sv,
sum(case when (proc_type in (100,103) and dcnr=1) or proc_type in (126) then 1 else 0 end)as sum_on, 
sum(case when (proc_type in (100,103) and (dcnr=0 or dcnr is null)) then 1 else 0 end )as sum_off,
count(*) as num 
from subscriber_db.DETAIL_CDR_S1MME_<NODE_3>
where PROC_SUCCED_FLAG = 0  and substr(imei,1,8) in (select tac  from network_db.dim_terminal WHERE TERBAND like '%5078%' and TER_TYPE_ID in (0,3,5) group by tac)
group by 1,2,3,4,5
union ALL
select msisdn, imsi , from_unixtime(PROC_STARTTIME, 'yyyy-MM-dd') as myday, substr(imei,1,8) as tac,sv,
sum(case when (proc_type in (100,103) and dcnr=1) or proc_type in (126) then 1 else 0 end)as sum_on, 
sum(case when (proc_type in (100,103) and (dcnr=0 or dcnr is null)) then 1 else 0 end )as sum_off,
count(*) as num 
from subscriber_db.DETAIL_CDR_S1MME_<NODE_4>
where PROC_SUCCED_FLAG = 0  and substr(imei,1,8) in (select tac  from network_db.dim_terminal WHERE TERBAND like '%5078%' and TER_TYPE_ID in (0,3,5) group by tac)
group by 1,2,3,4,5
union ALL
select msisdn, imsi , from_unixtime(PROC_STARTTIME, 'yyyy-MM-dd') as myday, substr(imei,1,8) as tac,sv,
sum(case when (proc_type in (100,103) and dcnr=1) or proc_type in (126) then 1 else 0 end)as sum_on, 
sum(case when (proc_type in (100,103) and (dcnr=0 or dcnr is null)) then 1 else 0 end )as sum_off,
count(*) as num 
from subscriber_db.DETAIL_CDR_S1MME_<NODE_5>
where PROC_SUCCED_FLAG = 0  and substr(imei,1,8) in (select tac  from network_db.dim_terminal WHERE TERBAND like '%5078%' and TER_TYPE_ID in (0,3,5) group by tac)
group by 1,2,3,4,5
union ALL
select msisdn, imsi , from_unixtime(PROC_STARTTIME, 'yyyy-MM-dd') as myday, substr(imei,1,8) as tac,sv,
sum(case when (proc_type in (100,103) and dcnr=1) or proc_type in (126) then 1 else 0 end)as sum_on, 
sum(case when (proc_type in (100,103) and (dcnr=0 or dcnr is null)) then 1 else 0 end )as sum_off,
count(*) as num 
from subscriber_db.DETAIL_CDR_S1MME_<NODE_6>
where PROC_SUCCED_FLAG = 0  and substr(imei,1,8) in (select tac  from network_db.dim_terminal WHERE TERBAND like '%5078%' and TER_TYPE_ID in (0,3,5) group by tac)
group by 1,2,3,4,5
union ALL
select msisdn, imsi , from_unixtime(PROC_STARTTIME, 'yyyy-MM-dd') as myday, substr(imei,1,8) as tac,sv,
sum(case when (proc_type in (100,103) and dcnr=1) or proc_type in (126) then 1 else 0 end)as sum_on, 
sum(case when (proc_type in (100,103) and (dcnr=0 or dcnr is null)) then 1 else 0 end )as sum_off,
count(*) as num 
from subscriber_db.DETAIL_CDR_S1MME_<NODE_7>
where PROC_SUCCED_FLAG = 0  and substr(imei,1,8) in (select tac  from network_db.dim_terminal WHERE TERBAND like '%5078%' and TER_TYPE_ID in (6,0,4,11,5) group by tac)
group by 1,2,3,4,5;

select * from network_db.temp_review5g_ter_switch_on_off where msisdn IN (<SAMPLE_MSISDN_1>, <SAMPLE_MSISDN_2>);

-- summarization switch status

drop table if exists network_db.temp_review5g_ter_switch_on_off_summary;

create table network_db.temp_review5g_ter_switch_on_off_summary as
select 
    msisdn,
    tac,
    sum(case when sum_on > 0 and num > 0 then 1 else 0 end) as switch_on,
    sum(case when sum_on = 0 and sum_off > 0 and num > 0 then 1 else 0 end) as switch_off,
    sum(case when sum_on = 0 and sum_off = 0 and num > 0 then 1 else 0 end) as indefinido
from network_db.temp_review5g_ter_switch_on_off
where char_length(msisdn) = 8
group by 1,2
order by 1,2;

select * from network_db.temp_review5g_ter_switch_on_off_summary limit 10;

select * from network_db.temp_review5g_ter_switch_on_off_summary where msisdn = <SAMPLE_MSISDN_1>;

-- Q_total summarization
DROP TABLE IF EXISTS network_db.temp_review5g_ter_switch_on_off_summary_2;
CREATE TABLE  network_db.temp_review5g_ter_switch_on_off_summary_2 as
select
    msisdn,
    tac,
    case
        when switch_on > 0 then 1
        else 0
    end as switch_on,
    case
        when switch_on = 0 and switch_off > 0 then 1
        else 0
    end as switch_off,
    case
        when switch_on = 0 and switch_off = 0 and indefinido > 0 then 1
        else 0
    end as indefinido
from network_db.temp_review5g_ter_switch_on_off_summary;

-- TWO-GROUP SUMMARY:
-- 1) SWITCH_ON
-- 2) SWITCH_OFF, INCLUDING THE PREVIOUS SWITCH_OFF AND INDEFINIDO GROUPS
DROP TABLE IF EXISTS network_db.temp_review5g_ter_switch_on_off_summary_3;
CREATE TABLE network_db.temp_review5g_ter_switch_on_off_summary_3 AS
SELECT
    msisdn,
    tac,
    CASE
        WHEN switch_on > 0 THEN 1
        ELSE 0
    END AS switch_on,
    CASE
        WHEN switch_on = 0
         AND (switch_off > 0 OR indefinido > 0) THEN 1
        ELSE 0
    END AS switch_off
FROM network_db.temp_review5g_ter_switch_on_off_summary;

SELECT *
FROM network_db.temp_review5g_ter_switch_on_off_summary_3
LIMIT 10;

describe network_db.temp_review5g_ter_switch_on_off_summary_3;


-- Export command removed from executable SQL. See original file for shell command details.


-- ============================================================================
-- 08. Inactive 5G-terminal users enriched with main 4G site and switch status
-- ============================================================================
-- *5G_PREPAID NO ACTIVE USERS WITH LOCATION

DROP TABLE IF EXISTS PS.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER_LOCATION;
CREATE TABLE PS.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER_LOCATION AS
WITH ufdr_union AS
(
    SELECT
        msisdn,
        RAN_NE_ID,
        SUM(Total_MB_tmp) AS Total_MB_tmp
    FROM
    (
        SELECT
            msisdn,
            RAN_NE_ID,
            SUM(
                COALESCE(L4_UL_THROUGHPUT, 0)
                + COALESCE(L4_DW_THROUGHPUT, 0)
            ) / 1024 / 1024 AS Total_MB_tmp
        FROM subscriber_db.detail_ufdr_streaming_<PARTITION>
        WHERE rat = 6
        GROUP BY msisdn, RAN_NE_ID

        UNION ALL

        SELECT
            msisdn,
            RAN_NE_ID,
            SUM(
                COALESCE(L4_UL_THROUGHPUT, 0)
                + COALESCE(L4_DW_THROUGHPUT, 0)
            ) / 1024 / 1024 AS Total_MB_tmp
        FROM subscriber_db.detail_ufdr_voip_<PARTITION>
        WHERE rat = 6
        GROUP BY msisdn, RAN_NE_ID

        UNION ALL

        SELECT
            msisdn,
            RAN_NE_ID,
            SUM(
                COALESCE(L4_UL_THROUGHPUT, 0)
                + COALESCE(L4_DW_THROUGHPUT, 0)
            ) / 1024 / 1024 AS Total_MB_tmp
        FROM subscriber_db.detail_ufdr_ftp_<PARTITION>
        WHERE rat = 6
        GROUP BY msisdn, RAN_NE_ID

        UNION ALL

        SELECT
            msisdn,
            RAN_NE_ID,
            SUM(
                COALESCE(L4_UL_THROUGHPUT, 0)
                + COALESCE(L4_DW_THROUGHPUT, 0)
            ) / 1024 / 1024 AS Total_MB_tmp
        FROM subscriber_db.detail_ufdr_other_<PARTITION>
        WHERE rat = 6
        GROUP BY msisdn, RAN_NE_ID

        UNION ALL

        SELECT
            msisdn,
            RAN_NE_ID,
            SUM(
                COALESCE(L4_UL_THROUGHPUT, 0)
                + COALESCE(L4_DW_THROUGHPUT, 0)
            ) / 1024 / 1024 AS Total_MB_tmp
        FROM subscriber_db.detail_ufdr_fileaccess_<PARTITION>
        WHERE rat = 6
        GROUP BY msisdn, RAN_NE_ID

        UNION ALL

        SELECT
            msisdn,
            RAN_NE_ID,
            SUM(
                COALESCE(L4_UL_THROUGHPUT, 0)
                + COALESCE(L4_DW_THROUGHPUT, 0)
            ) / 1024 / 1024 AS Total_MB_tmp
        FROM subscriber_db.detail_ufdr_im_<PARTITION>
        WHERE rat = 6
        GROUP BY msisdn, RAN_NE_ID

        UNION ALL

        SELECT
            msisdn,
            RAN_NE_ID,
            SUM(
                COALESCE(L4_UL_THROUGHPUT, 0)
                + COALESCE(L4_DW_THROUGHPUT, 0)
            ) / 1024 / 1024 AS Total_MB_tmp
        FROM subscriber_db.detail_ufdr_http_browsing_<PARTITION>
        WHERE rat = 6
        GROUP BY msisdn, RAN_NE_ID

        UNION ALL

        SELECT
            msisdn,
            RAN_NE_ID,
            SUM(
                COALESCE(L4_UL_THROUGHPUT, 0)
                + COALESCE(L4_DW_THROUGHPUT, 0)
            ) / 1024 / 1024 AS Total_MB_tmp
        FROM subscriber_db.detail_ufdr_email_<PARTITION>
        WHERE rat = 6
        GROUP BY msisdn, RAN_NE_ID
    ) x
    WHERE msisdn IS NOT NULL
      AND RAN_NE_ID IS NOT NULL
    GROUP BY
        msisdn,
        RAN_NE_ID
),

ran_location AS
(
    SELECT DISTINCT
        a.RAN_NE_ID,
        a.NE_NAME,
        a.NE_IP,
        b.BSCRNC_NAME,
        b.XPOS,
        b.YPOS,
        b.LAYER2NAME,
        b.LAYER3NAME
    FROM
    (
        SELECT DISTINCT
            RAN_NE_ID,
            NE_NAME,
            NE_IP
        FROM network_db.cfg_enodeb_ip
        WHERE NE_IP_TYPE = 1
    ) a
    LEFT JOIN
    (
        SELECT DISTINCT
            BSCRNC_NAME,
            XPOS,
            YPOS,
            LAYER2NAME,
            LAYER3NAME
        FROM network_db.dim_loc_cgisai
        WHERE access_type = '4G'
    ) b
        ON a.NE_NAME = b.BSCRNC_NAME
),

ranked_ran AS
(
    SELECT
        u.msisdn,
        u.RAN_NE_ID,
        u.Total_MB_tmp,
        y.NE_NAME,
        y.NE_IP,
        y.BSCRNC_NAME,
        y.XPOS,
        y.YPOS,
        y.LAYER2NAME,
        y.LAYER3NAME,
        ROW_NUMBER() OVER
        (
            PARTITION BY u.msisdn
            ORDER BY
                u.Total_MB_tmp DESC,
                u.RAN_NE_ID
        ) AS rn
    FROM ufdr_union u
    LEFT JOIN ran_location y
        ON u.RAN_NE_ID = y.RAN_NE_ID
),

switch_summary AS
(
    SELECT
        msisdn,
        MAX(switch_on) AS switch_on
    FROM network_db.temp_review5g_ter_switch_on_off_summary_3
    GROUP BY msisdn
)

SELECT
    p.msisdn,
    p.last_tac,
    p.TER_BRAND_NAME,
    p.TER_MODEL_NAME,
    p.TER_MODENAME,
    p.TER_TYPE_NAME_EN,
    p.diff_tac_count,
    p.total_PS_Traffic_GB,
    p.days_w_traff_over_1MB,
    r.RAN_NE_ID,
    r.NE_NAME,
    r.NE_IP,
    r.BSCRNC_NAME,
    r.XPOS,
    r.YPOS,
    r.LAYER2NAME,
    r.LAYER3NAME,
    r.Total_MB_tmp AS max_RAN_Total_MB,
    s.switch_on

FROM subscriber_db.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER p

LEFT JOIN ranked_ran r
    ON p.msisdn = r.msisdn
   AND r.rn = 1

LEFT JOIN switch_summary s
    ON p.msisdn = s.msisdn;

SELECT * FROM PS.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER_LOCATION LIMIT 3;

-- *5G_POSTPAID NO ACTIVE USERS WITH LOCATION

DROP TABLE IF EXISTS PS.TMP_CRM_POSTPAID_5G_TERM_INACTIVE_USER_LOCATION;
CREATE TABLE PS.TMP_CRM_POSTPAID_5G_TERM_INACTIVE_USER_LOCATION AS
WITH ufdr_union AS
(
    SELECT
        msisdn,
        RAN_NE_ID,
        SUM(Total_MB_tmp) AS Total_MB_tmp
    FROM
    (
        SELECT
            msisdn,
            RAN_NE_ID,
            SUM(
                COALESCE(L4_UL_THROUGHPUT, 0)
                + COALESCE(L4_DW_THROUGHPUT, 0)
            ) / 1024 / 1024 AS Total_MB_tmp
        FROM subscriber_db.detail_ufdr_streaming_<PARTITION>
        WHERE rat = 6
        GROUP BY msisdn, RAN_NE_ID

        UNION ALL

        SELECT
            msisdn,
            RAN_NE_ID,
            SUM(
                COALESCE(L4_UL_THROUGHPUT, 0)
                + COALESCE(L4_DW_THROUGHPUT, 0)
            ) / 1024 / 1024 AS Total_MB_tmp
        FROM subscriber_db.detail_ufdr_voip_<PARTITION>
        WHERE rat = 6
        GROUP BY msisdn, RAN_NE_ID

        UNION ALL

        SELECT
            msisdn,
            RAN_NE_ID,
            SUM(
                COALESCE(L4_UL_THROUGHPUT, 0)
                + COALESCE(L4_DW_THROUGHPUT, 0)
            ) / 1024 / 1024 AS Total_MB_tmp
        FROM subscriber_db.detail_ufdr_ftp_<PARTITION>
        WHERE rat = 6
        GROUP BY msisdn, RAN_NE_ID

        UNION ALL

        SELECT
            msisdn,
            RAN_NE_ID,
            SUM(
                COALESCE(L4_UL_THROUGHPUT, 0)
                + COALESCE(L4_DW_THROUGHPUT, 0)
            ) / 1024 / 1024 AS Total_MB_tmp
        FROM subscriber_db.detail_ufdr_other_<PARTITION>
        WHERE rat = 6
        GROUP BY msisdn, RAN_NE_ID

        UNION ALL

        SELECT
            msisdn,
            RAN_NE_ID,
            SUM(
                COALESCE(L4_UL_THROUGHPUT, 0)
                + COALESCE(L4_DW_THROUGHPUT, 0)
            ) / 1024 / 1024 AS Total_MB_tmp
        FROM subscriber_db.detail_ufdr_fileaccess_<PARTITION>
        WHERE rat = 6
        GROUP BY msisdn, RAN_NE_ID

        UNION ALL

        SELECT
            msisdn,
            RAN_NE_ID,
            SUM(
                COALESCE(L4_UL_THROUGHPUT, 0)
                + COALESCE(L4_DW_THROUGHPUT, 0)
            ) / 1024 / 1024 AS Total_MB_tmp
        FROM subscriber_db.detail_ufdr_im_<PARTITION>
        WHERE rat = 6
        GROUP BY msisdn, RAN_NE_ID

        UNION ALL

        SELECT
            msisdn,
            RAN_NE_ID,
            SUM(
                COALESCE(L4_UL_THROUGHPUT, 0)
                + COALESCE(L4_DW_THROUGHPUT, 0)
            ) / 1024 / 1024 AS Total_MB_tmp
        FROM subscriber_db.detail_ufdr_http_browsing_<PARTITION>
        WHERE rat = 6
        GROUP BY msisdn, RAN_NE_ID

        UNION ALL

        SELECT
            msisdn,
            RAN_NE_ID,
            SUM(
                COALESCE(L4_UL_THROUGHPUT, 0)
                + COALESCE(L4_DW_THROUGHPUT, 0)
            ) / 1024 / 1024 AS Total_MB_tmp
        FROM subscriber_db.detail_ufdr_email_<PARTITION>
        WHERE rat = 6
        GROUP BY msisdn, RAN_NE_ID
    ) x
    WHERE msisdn IS NOT NULL
      AND RAN_NE_ID IS NOT NULL
    GROUP BY
        msisdn,
        RAN_NE_ID
),

ran_location AS
(
    SELECT DISTINCT
        a.RAN_NE_ID,
        a.NE_NAME,
        a.NE_IP,
        b.BSCRNC_NAME,
        b.XPOS,
        b.YPOS,
        b.LAYER2NAME,
        b.LAYER3NAME
    FROM
    (
        SELECT DISTINCT
            RAN_NE_ID,
            NE_NAME,
            NE_IP
        FROM network_db.cfg_enodeb_ip
        WHERE NE_IP_TYPE = 1
    ) a
    LEFT JOIN
    (
        SELECT DISTINCT
            BSCRNC_NAME,
            XPOS,
            YPOS,
            LAYER2NAME,
            LAYER3NAME
        FROM network_db.dim_loc_cgisai
        WHERE access_type = '4G'
    ) b
        ON a.NE_NAME = b.BSCRNC_NAME
),

ranked_ran AS
(
    SELECT
        u.msisdn,
        u.RAN_NE_ID,
        u.Total_MB_tmp,
        y.NE_NAME,
        y.NE_IP,
        y.BSCRNC_NAME,
        y.XPOS,
        y.YPOS,
        y.LAYER2NAME,
        y.LAYER3NAME,
        ROW_NUMBER() OVER
        (
            PARTITION BY u.msisdn
            ORDER BY
                u.Total_MB_tmp DESC,
                u.RAN_NE_ID
        ) AS rn
    FROM ufdr_union u
    LEFT JOIN ran_location y
        ON u.RAN_NE_ID = y.RAN_NE_ID
),

switch_summary AS
(
    SELECT
        msisdn,
        MAX(switch_on) AS switch_on
    FROM network_db.temp_review5g_ter_switch_on_off_summary_3
    GROUP BY msisdn
)

SELECT
    p.msisdn,
    p.last_tac,
    p.TER_BRAND_NAME,
    p.TER_MODEL_NAME,
    p.TER_MODENAME,
    p.TER_TYPE_NAME_EN,
    p.diff_tac_count,
    p.total_PS_Traffic_GB,
    p.days_w_traff_over_1MB,
    r.RAN_NE_ID,
    r.NE_NAME,
    r.NE_IP,
    r.BSCRNC_NAME,
    r.XPOS,
    r.YPOS,
    r.LAYER2NAME,
    r.LAYER3NAME,
    r.Total_MB_tmp AS max_RAN_Total_MB,
    s.switch_on

FROM subscriber_db.TMP_CRM_POSTPAID_5G_TERM_INACTIVE_USER p

LEFT JOIN ranked_ran r
    ON p.msisdn = r.msisdn
   AND r.rn = 1

LEFT JOIN switch_summary s
    ON p.msisdn = s.msisdn;

SELECT * FROM PS.TMP_CRM_POSTPAID_5G_TERM_INACTIVE_USER_LOCATION LIMIT 3;


-- ============================================================================
-- 09. Postpaid urban potential-user export segment
-- ============================================================================
-- *Post_paid_urban users

SELECT
    CASE
        WHEN LAYER3NAME LIKE '%URBAN%' THEN 'URBAN'
        ELSE 'NON_URBAN'
    END AS LAYER3NAME_URBAN_FLAG,
    COUNT(*) AS ROW_COUNT
FROM PS.TMP_CRM_POSTPAID_5G_TERM_INACTIVE_USER_LOCATION
GROUP BY
    CASE
        WHEN LAYER3NAME LIKE '%URBAN%' THEN 'URBAN'
        ELSE 'NON_URBAN'
    END;

DROP TABLE IF EXISTS PS.TMP_CRM_POSTPAID_5G_TERM_INACTIVE_USER_LOCATION_URBAN;
CREATE TABLE PS.TMP_CRM_POSTPAID_5G_TERM_INACTIVE_USER_LOCATION_URBAN AS
SELECT
 msisdn,                 
 last_tac,          
 TER_BRAND_NAME,                  
 TER_MODENAME,           
 TER_TYPE_NAME_EN,       
 diff_tac_count,         
 total_PS_Traffic_GB AS TOTAL_TRAFFIC_GB,    
 days_w_traff_over_1MB,                
 NE_NAME AS SITE_NAME,                                                 
 LAYER2NAME AS DEPARTAMENTO,                         
 max_RAN_Total_MB AS TRAFFIC_MAIN_SITE_MB,       
 switch_on AS SWITCH_STATUS,
 TER_MODEL_NAME   
FROM
PS.TMP_CRM_POSTPAID_5G_TERM_INACTIVE_USER_LOCATION
WHERE
LAYER3NAME LIKE '%URBAN%';

SELECT * FROM PS.TMP_CRM_POSTPAID_5G_TERM_INACTIVE_USER_LOCATION_URBAN LIMIT 10;

SELECT COUNT(DISTINCT MSISDN) FROM PS.TMP_CRM_POSTPAID_5G_TERM_INACTIVE_USER_LOCATION_URBAN;

SELECT SWITCH_STATUS, COUNT(*) AS USER_COUNT
FROM PS.TMP_CRM_POSTPAID_5G_TERM_INACTIVE_USER_LOCATION_URBAN
GROUP BY SWITCH_STATUS
ORDER BY SWITCH_STATUS;


-- Export command removed from executable SQL. See original file for shell command details.


-- ============================================================================
-- 10. Prepaid urban over-15GB potential-user export segment
-- ============================================================================
-- *Prepaid_5G_OVER_15GB

DROP TABLE IF EXISTS PS.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER_LOCATION_OVER_15GB;

CREATE TABLE PS.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER_LOCATION_OVER_15GB AS
SELECT
    msisdn,
    last_tac,
    TER_BRAND_NAME,
    TER_MODENAME,
    TER_TYPE_NAME_EN,
    diff_tac_count,
    total_PS_Traffic_GB,
    days_w_traff_over_1MB,
    NE_NAME,
    LAYER2NAME,
    LAYER3NAME,
    max_RAN_Total_MB,
    switch_on,
    TER_MODEL_NAME
FROM PS.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER_LOCATION
WHERE total_PS_Traffic_GB >= 15;

SELECT * FROM PS.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER_LOCATION_OVER_15GB LIMIT 10;

SELECT COUNT(*) FROM PS.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER_LOCATION_OVER_15GB;

-- -- *Prepaid_5G_OVER_15GB_URBAN

SELECT
    CASE
        WHEN LAYER3NAME LIKE '%URBAN%' THEN 'URBAN'
        ELSE 'NON_URBAN'
    END AS LAYER3NAME_URBAN_FLAG,
    COUNT(*) AS ROW_COUNT
FROM PS.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER_LOCATION_OVER_15GB
GROUP BY
    CASE
        WHEN LAYER3NAME LIKE '%URBAN%' THEN 'URBAN'
        ELSE 'NON_URBAN'
    END;

DROP TABLE IF EXISTS PS.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER_LOCATION_OVER_15GB_URBAN;
CREATE TABLE PS.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER_LOCATION_OVER_15GB_URBAN AS
SELECT
 msisdn,                 
 last_tac,          
 TER_BRAND_NAME,                  
 TER_MODENAME,           
 TER_TYPE_NAME_EN,       
 diff_tac_count,         
 total_PS_Traffic_GB AS TOTAL_TRAFFIC_GB,    
 days_w_traff_over_1MB,                
 NE_NAME AS SITE_NAME,                                                 
 LAYER2NAME AS DEPARTAMENTO,                         
 max_RAN_Total_MB AS TRAFFIC_MAIN_SITE_MB,       
 switch_on AS SWITCH_STATUS,
 TER_MODEL_NAME   
FROM
PS.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER_LOCATION_OVER_15GB
WHERE
LAYER3NAME LIKE '%URBAN%';

SELECT COUNT(*) FROM PS.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER_LOCATION_OVER_15GB_URBAN;

SELECT SWITCH_STATUS, COUNT(*) AS USER_COUNT
FROM PS.TMP_CRM_PREPAID_5G_TERM_INACTIVE_USER_LOCATION_OVER_15GB_URBAN
GROUP BY SWITCH_STATUS
ORDER BY SWITCH_STATUS;


-- Export command removed from executable SQL. See original file for shell command details.

