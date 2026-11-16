/* =====================================================================
   PROJECT : Healthcare Claims - Data Quality & Denial Analysis
   AUTHOR  : Suharta Ahmed
   ROLE    : Portfolio project for a Data Operations Analyst position
   DATA    : Synthetic (fake) claims data, Jan - Jun 2026. No real patients.
   TOOL    : SQLite (use "DB Browser for SQLite" - free, beginner friendly)
             Works with minor changes in MySQL / PostgreSQL.

   HOW TO USE THIS FILE
   1. Create a new empty database.
   2. Run PART 0 to create the 3 tables.
   3. Import the CSV files (claims.csv, payers.csv, providers.csv):
      DB Browser:  File > Import > Table from CSV file
                   (tick "Column names in first line")
   4. Run the file part by part and read the comments.

   WHAT YOU WILL FIND OUT
   PART 1  Look at the data
   PART 2  Find data quality problems  (the core job of a Data Ops Analyst)
   PART 3  Clean the data with a VIEW
   PART 4  Answer the business questions about claim denials
   ===================================================================== */


/* =====================================================================
   PART 0 : CREATE TABLES
   ===================================================================== */

DROP TABLE IF EXISTS claims;
DROP TABLE IF EXISTS payers;
DROP TABLE IF EXISTS providers;

CREATE TABLE payers (
    payer_id    TEXT,     -- insurance company ID
    payer_name  TEXT,
    payer_type  TEXT      -- Government or Commercial
);

CREATE TABLE providers (
    provider_id      TEXT,   -- doctor ID
    provider_name    TEXT,
    specialty        TEXT,
    clinic_location  TEXT
);

CREATE TABLE claims (
    claim_id         TEXT,   -- should be unique per claim
    patient_id       TEXT,
    provider_id      TEXT,
    payer_id         TEXT,
    service_date     TEXT,   -- date the patient was treated (YYYY-MM-DD)
    submission_date  TEXT,   -- date the claim was sent to the insurer
    procedure_code   TEXT,
    diagnosis_code   TEXT,
    billed_amount    REAL,   -- what the clinic charged
    allowed_amount   REAL,   -- what the insurer agreed to pay (expected money)
    paid_amount      REAL,   -- what the insurer actually paid
    claim_status     TEXT,   -- Paid / Partially Paid / Denied / Pending
    denial_reason    TEXT,   -- only filled when the claim is denied
    payment_date     TEXT
);


/* =====================================================================
   PART 1 : LOOK AT THE DATA
   ===================================================================== */

-- 1.1 How many rows are in the claims table?
SELECT COUNT(*) AS total_rows
FROM claims;

-- 1.2 Preview the first 10 rows
SELECT *
FROM claims
LIMIT 10;

-- 1.3 What period does the data cover?
SELECT MIN(service_date) AS first_service_date,
       MAX(service_date) AS last_service_date
FROM claims;

-- 1.4 How many distinct claims, patients, doctors and insurers?
SELECT COUNT(DISTINCT claim_id)   AS unique_claims,
       COUNT(DISTINCT patient_id) AS unique_patients,
       COUNT(DISTINCT provider_id) AS unique_providers,
       COUNT(DISTINCT payer_id)   AS unique_payers
FROM claims;
-- Note: unique_claims is LOWER than total_rows. Something is wrong. Let's investigate.


/* =====================================================================
   PART 2 : DATA QUALITY CHECKS
   Rule of the job: never analyse data you have not checked first.
   NOTE: CSV imports can turn empty cells into empty text ('') instead of
   NULL, so every "missing" check below tests for BOTH.
   ===================================================================== */

-- 2.1 DUPLICATE CLAIMS: which claim_ids appear more than once?
SELECT claim_id,
       COUNT(*) AS times_seen
FROM claims
GROUP BY claim_id
HAVING COUNT(*) > 1
ORDER BY claim_id
LIMIT 10;

-- 2.1b How many extra (duplicate) rows are there in total?
SELECT COUNT(*) - COUNT(DISTINCT claim_id) AS duplicate_rows
FROM claims;

-- 2.2 MISSING PAYER: claims with no insurance company
SELECT COUNT(*) AS claims_missing_payer
FROM claims
WHERE payer_id IS NULL OR TRIM(payer_id) = '';

-- 2.3 MISSING DIAGNOSIS CODE: a claim cannot be paid without one
SELECT COUNT(*) AS claims_missing_diagnosis
FROM claims
WHERE diagnosis_code IS NULL OR TRIM(diagnosis_code) = '';

-- 2.3b Which doctors have the most missing diagnosis codes?
SELECT provider_id,
       COUNT(*) AS total_claims,
       SUM(CASE WHEN diagnosis_code IS NULL OR TRIM(diagnosis_code) = '' THEN 1 ELSE 0 END) AS missing_diagnosis,
       ROUND(100.0 * SUM(CASE WHEN diagnosis_code IS NULL OR TRIM(diagnosis_code) = '' THEN 1 ELSE 0 END) / COUNT(*), 1) AS missing_pct
FROM claims
GROUP BY provider_id
ORDER BY missing_pct DESC;

-- 2.4 NEGATIVE AMOUNTS: a charge can never be below zero
SELECT COUNT(*) AS negative_billed_rows
FROM claims
WHERE billed_amount < 0;

-- 2.5 OVERPAYMENT: the insurer paid MORE than the clinic billed
SELECT COUNT(*) AS paid_more_than_billed
FROM claims
WHERE paid_amount > billed_amount;

-- 2.6 IMPOSSIBLE DATES: claim sent BEFORE the patient was treated
SELECT COUNT(*) AS submitted_before_service
FROM claims
WHERE submission_date < service_date;

-- 2.7 INCONSISTENT TEXT: the same status written in different ways
SELECT claim_status,
       COUNT(*) AS rows_count
FROM claims
GROUP BY claim_status
ORDER BY rows_count DESC;
-- 'Paid', 'PAID', 'paid', ' Paid' are all the same thing but SQL sees them as different.

-- 2.8 DATA QUALITY SCORECARD (all issues in one table)
SELECT 'Duplicate rows' AS issue,
       COUNT(*) - COUNT(DISTINCT claim_id) AS rows_affected
FROM claims
UNION ALL
SELECT 'Missing payer_id', COUNT(*)
FROM claims
WHERE payer_id IS NULL OR TRIM(payer_id) = ''
UNION ALL
SELECT 'Missing diagnosis_code', COUNT(*)
FROM claims
WHERE diagnosis_code IS NULL OR TRIM(diagnosis_code) = ''
UNION ALL
SELECT 'Negative billed_amount', COUNT(*)
FROM claims
WHERE billed_amount < 0
UNION ALL
SELECT 'Paid more than billed', COUNT(*)
FROM claims
WHERE paid_amount > billed_amount
UNION ALL
SELECT 'Submitted before service date', COUNT(*)
FROM claims
WHERE submission_date < service_date
UNION ALL
SELECT 'Messy claim_status text', COUNT(*)
FROM claims
WHERE claim_status NOT IN ('Paid', 'Denied', 'Pending', 'Partially Paid');


/* =====================================================================
   PART 3 : CLEAN THE DATA (using a VIEW)
   A view is a saved query. The raw table stays untouched and we analyse
   the clean version. This is good practice: never edit raw data.

   Cleaning rules used:
   - Keep only ONE row per claim_id (remove duplicates)
   - Standardise claim_status text (trim spaces + fix capital letters)
   - Treat blank payer as 'UNKNOWN' (keep the claim, but flag it)
   - Remove rows with impossible values (negative billed, overpaid,
     submitted before service date)
   - Add a helper column: days_to_submit
   ===================================================================== */

DROP VIEW IF EXISTS claims_clean;

CREATE VIEW claims_clean AS
WITH numbered AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY claim_id ORDER BY claim_id) AS row_num
    FROM claims
)
SELECT
    claim_id,
    patient_id,
    provider_id,
    COALESCE(NULLIF(TRIM(payer_id), ''), 'UNKNOWN') AS payer_id,
    service_date,
    submission_date,
    procedure_code,
    NULLIF(TRIM(diagnosis_code), '') AS diagnosis_code,
    billed_amount,
    allowed_amount,
    paid_amount,
    CASE UPPER(TRIM(claim_status))
        WHEN 'PAID'           THEN 'Paid'
        WHEN 'DENIED'         THEN 'Denied'
        WHEN 'PENDING'        THEN 'Pending'
        WHEN 'PARTIALLY PAID' THEN 'Partially Paid'
    END AS claim_status,
    NULLIF(TRIM(denial_reason), '') AS denial_reason,
    NULLIF(TRIM(payment_date), '')  AS payment_date,
    CAST(julianday(submission_date) - julianday(service_date) AS INTEGER) AS days_to_submit
FROM numbered
WHERE row_num = 1                              -- remove duplicates
  AND billed_amount > 0                        -- remove negative charges
  AND paid_amount <= billed_amount             -- remove overpayments
  AND submission_date >= service_date;         -- remove impossible dates

-- A second view that keeps only claims the insurer has already decided on.
-- 'Pending' claims have no result yet, so they would distort the denial rate.
DROP VIEW IF EXISTS claims_final;

CREATE VIEW claims_final AS
SELECT *
FROM claims_clean
WHERE claim_status <> 'Pending';

-- 3.1 Check: how many rows did cleaning remove?
SELECT (SELECT COUNT(*) FROM claims)       AS raw_rows,
       (SELECT COUNT(*) FROM claims_clean) AS clean_rows,
       (SELECT COUNT(*) FROM claims) - (SELECT COUNT(*) FROM claims_clean) AS rows_removed,
       (SELECT COUNT(*) FROM claims_final) AS decided_claims;

-- 3.2 Check: status values are now consistent
SELECT claim_status, COUNT(*) AS claims
FROM claims_clean
GROUP BY claim_status;


/* =====================================================================
   PART 4 : BUSINESS ANALYSIS
   Business question: "Why are we losing money to denied claims,
   and what can we fix first?"
   Denial rate = denied claims / decided claims (Pending excluded)
   ===================================================================== */

-- 4.1 HEADLINE NUMBERS
SELECT COUNT(*)                                              AS decided_claims,
       SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
       ROUND(100.0 * SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) / COUNT(*), 1) AS denial_rate_pct,
       ROUND(SUM(billed_amount), 0)                          AS total_billed,
       ROUND(SUM(paid_amount), 0)                            AS total_paid,
       ROUND(SUM(CASE WHEN claim_status = 'Denied' THEN allowed_amount ELSE 0 END), 0) AS revenue_lost_to_denials
FROM claims_final;
-- revenue_lost_to_denials = money the insurer WOULD have paid if the claim had not been denied.

-- 4.2 DENIAL RATE BY INSURANCE COMPANY (JOIN with payers table)
SELECT COALESCE(p.payer_name, 'Unknown payer') AS payer,
       COUNT(*) AS decided_claims,
       SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
       ROUND(100.0 * SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) / COUNT(*), 1) AS denial_rate_pct,
       ROUND(SUM(CASE WHEN c.claim_status = 'Denied' THEN c.allowed_amount ELSE 0 END), 0) AS revenue_lost
FROM claims_final c
LEFT JOIN payers p ON c.payer_id = p.payer_id
GROUP BY payer
ORDER BY denial_rate_pct DESC;

-- 4.3 WHY ARE CLAIMS DENIED? (count, money and share of all denials)
SELECT denial_reason,
       COUNT(*) AS denied_claims,
       ROUND(SUM(allowed_amount), 0) AS revenue_lost,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_of_denials_pct
FROM claims_final
WHERE claim_status = 'Denied'
GROUP BY denial_reason
ORDER BY denied_claims DESC;

-- 4.4 DENIAL RATE BY DOCTOR
SELECT pr.provider_name,
       pr.specialty,
       COUNT(*) AS decided_claims,
       ROUND(100.0 * SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) / COUNT(*), 1) AS denial_rate_pct,
       ROUND(100.0 * SUM(CASE WHEN c.diagnosis_code IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS missing_diagnosis_pct
FROM claims_final c
JOIN providers pr ON c.provider_id = pr.provider_id
GROUP BY pr.provider_name, pr.specialty
ORDER BY denial_rate_pct DESC;

-- 4.5 MONTHLY TREND: is the problem getting worse?
SELECT strftime('%Y-%m', service_date) AS month,
       COUNT(*) AS decided_claims,
       SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
       ROUND(100.0 * SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) / COUNT(*), 1) AS denial_rate_pct,
       ROUND(100.0 * SUM(CASE WHEN days_to_submit > 30 THEN 1 ELSE 0 END) / COUNT(*), 1) AS late_submission_pct
FROM claims_final
GROUP BY month
ORDER BY month;
-- late_submission_pct = share of claims sent more than 30 days after the visit.
-- Compare this column with denial_rate_pct. Do they move together?

-- 4.6 DOES SUBMITTING LATE CAUSE DENIALS?
SELECT CASE
           WHEN days_to_submit <= 7  THEN '1) 0-7 days'
           WHEN days_to_submit <= 14 THEN '2) 8-14 days'
           WHEN days_to_submit <= 30 THEN '3) 15-30 days'
           ELSE                           '4) Over 30 days'
       END AS submission_speed,
       COUNT(*) AS decided_claims,
       ROUND(100.0 * SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) / COUNT(*), 1) AS denial_rate_pct
FROM claims_final
GROUP BY submission_speed
ORDER BY submission_speed;

-- 4.7 PRIOR AUTHORIZATION CHECK
-- Procedures 71046 (chest X-ray), 97110 (therapy) and 93000 (ECG) need
-- pre-approval. Do some insurers deny these much more often?
SELECT COALESCE(p.payer_name, 'Unknown payer') AS payer,
       COUNT(*) AS claims_needing_approval,
       ROUND(100.0 * SUM(CASE WHEN c.denial_reason = 'Prior Authorization Missing' THEN 1 ELSE 0 END) / COUNT(*), 1) AS prior_auth_denial_pct
FROM claims_final c
LEFT JOIN payers p ON c.payer_id = p.payer_id
WHERE c.procedure_code IN ('71046', '97110', '93000')
GROUP BY payer
ORDER BY prior_auth_denial_pct DESC;

-- 4.8 WHICH PROCEDURES LOSE THE MOST MONEY?
SELECT procedure_code,
       COUNT(*) AS denied_claims,
       ROUND(SUM(allowed_amount), 0) AS revenue_lost
FROM claims_final
WHERE claim_status = 'Denied'
GROUP BY procedure_code
ORDER BY revenue_lost DESC
LIMIT 5;

-- 4.9 HOW FAST DO INSURERS PAY? (average days from submission to payment)
SELECT COALESCE(p.payer_name, 'Unknown payer') AS payer,
       ROUND(AVG(julianday(c.payment_date) - julianday(c.submission_date)), 1) AS avg_days_to_pay
FROM claims_final c
LEFT JOIN payers p ON c.payer_id = p.payer_id
WHERE c.claim_status IN ('Paid', 'Partially Paid')
  AND c.payment_date IS NOT NULL
GROUP BY payer
ORDER BY avg_days_to_pay DESC;

-- 4.10 THE BIG PICTURE: how much of the lost money was PREVENTABLE?
-- These three reasons are caused by the clinic's own process, not by the insurer.
SELECT CASE
           WHEN denial_reason IN ('Timely Filing Exceeded',
                                  'Prior Authorization Missing',
                                  'Missing Diagnosis Code') THEN 'Preventable (process errors)'
           ELSE 'Other reasons'
       END AS denial_type,
       COUNT(*) AS denied_claims,
       ROUND(SUM(allowed_amount), 0) AS revenue_lost,
       ROUND(100.0 * SUM(allowed_amount) / SUM(SUM(allowed_amount)) OVER (), 1) AS share_of_lost_revenue_pct
FROM claims_final
WHERE claim_status = 'Denied'
GROUP BY denial_type;

/* ============================== END OF FILE ============================== */
