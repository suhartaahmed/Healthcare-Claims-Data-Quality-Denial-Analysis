# Healthcare Claims: Data Quality & Denial Analysis

A  **Data Operations** portfolio project using SQL. It cleans messy healthcare billing (RCM) data, finds why insurance claims get denied, and recommends what to fix first.

> **Note:** All data is **synthetic** (made up for learning). It contains no real patients. It was built to behave like real billing data, including real-world errors.

---

## Business Problem

When a clinic treats a patient, it sends a **claim** (a bill) to the insurance company. The insurer can pay it, pay part of it, or **deny** it. A denied claim means the clinic did the work but gets no money unless staff spend time fixing and resubmitting it.

A clinic network noticed more claims coming back denied. This project answers five questions:

1. Can we trust the data? What errors exist before we report anything?
2. What is the denial rate, and how much money is at risk?
3. Which insurers and doctors have the highest denial rates?
4. What are the main denial reasons, and is the problem getting worse?
5. Which problems can the clinic fix itself, and what comes first?

## Key Results

| Metric | Result |
|---|---|
| Raw claim rows | 3,045 |
| Clean rows after data cleaning | 2,954 (91 removed) |
| Claims decided by insurers (Pending excluded) | 2,767 |
| **Denial rate** | **15.6%** |
| **Revenue lost to denials** | **$34,240** |
| Share of lost revenue that was **preventable** | **61.1%** |

## Findings

### 1. One insurer denies far more than the others

Summit Mutual denied **28.3%** of claims, about 2.6 times the rate of Federal Medicare (10.7%). The cause is in the prior-authorization check: **41.7%** of Summit Mutual claims that need pre-approval (chest X-ray, therapy, ECG) were denied for a missing authorization. The other insurers with a known payer had 0%.

```
Summit Mutual    | ████████████████████████████ 28.3%
Unknown payer    | ██████████████████ 18.5%
State Medicaid   | ████████████████ 16.4%
Northstar Health | ██████████████ 14.0%
Evergreen Health | ████████████ 12.1%
Federal Medicare | ███████████ 10.7%
```

### 2. Most lost money comes from problems the clinic can control

Timely filing, missing diagnosis codes and missing prior authorization are all process errors on the clinic's side. Together with the other preventable reasons they make up **61.1%** of all revenue lost to denials.

```
Preventable (process errors) | ████████████████████████████ 61.1%
Other reasons                | ██████████████████ 38.9%
```

Preventable = $20,907 of the $34,240 lost. Other reasons = $13,333.

```
Timely filing      | ████████████████████████████ 120
Missing diagnosis  | ██████████████████ 76
Prior auth missing | ███████████████ 65
Eligibility issue  | █████████████ 56
Coding error       | ███████████ 49
Not med. necessary | ████████ 33
Duplicate claim    | ███████ 32
```

### 3. Late submission is the biggest driver

Claims sent more than 30 days after the visit were denied **72.2%** of the time, compared with **10.3%** for claims sent within 7 days. Insurers have filing deadlines.

```
0-7 days     | ████ 10.3%
8-14 days    | █████ 12.6%
15-30 days   | █████ 13.9%
Over 30 days | ████████████████████████████ 72.2%
```

### 4. The problem is getting worse

The denial rate rose from **14.4%** in January to **21.6%** in June. Over the same months, the share of claims submitted more than 30 days late grew from **4.4%** to **10.0%**. The two lines move together, which suggests late filing is a main cause. (This shows a strong link, but it does not prove cause on its own.)

```
Month | Denial rate                    | Late (>30 days) submissions
Jan   | ███████████████████          14.4% | ██████          4.4%
Feb   | ███████████████████          14.4% | ███████         5.1%
Mar   | ████████████████             12.2% | ██████          4.7%
Apr   | █████████████████            13.0% | █████████       7.2%
May   | ████████████████████████     18.6% | ███████████     8.2%
Jun   | ████████████████████████████ 21.6% | █████████████  10.0%
```

### 5. One doctor has a documentation problem

Dr. Evans has a **27.4%** denial rate and **20.1%** of claims with no diagnosis code. Every other doctor is at or below 1.6% for missing diagnosis codes. This points to a workflow or habit issue for one provider, not a system-wide fault.

```
Dr. Evans  | ████████████████████████████ 27.4%
Dr. Adams  | ████████████████ 16.1%
Dr. Foster | ███████████████ 15.1%
Dr. Hill   | ███████████████ 14.3%
Dr. Davis  | ███████████████ 14.2%
Dr. Brooks | ██████████████ 14.1%
Dr. Garcia | ████████████ 11.6%
Dr. Chen   | ███████████ 10.8%
```

## Data Quality Audit

Before any analysis, every column was checked against simple business rules. Seven issues were found and handled in a SQL **view**, so the raw table is never edited.

| Issue | Rows | How it was handled |
|---|---:|---|
| Duplicate claim rows | 45 | Kept one row per `claim_id` |
| Missing `payer_id` | 30 | Kept, labeled `UNKNOWN`, flagged |
| Missing `diagnosis_code` | 103 | Kept (this is a finding: it causes denials) |
| Negative `billed_amount` | 13 | Excluded |
| Paid more than billed | 27 | Excluded |
| Submitted before service date | 20 | Excluded |
| Messy `claim_status` text (`PAID`, ` paid `) | 61 | Trimmed and standardized to 4 values |

Some rows have more than one issue, so the counts overlap.

## Recommendations

| Priority | Action | Problem it targets |
|:-:|---|---|
| 1 | Daily report of claims not submitted after 7 days; set a 14-day internal deadline | Late filing (largest single loss, $9,645) |
| 2 | Block submission when `diagnosis_code` is empty; coach Dr. Evans' team on documentation | Missing diagnosis codes ($5,519) |
| 3 | Prior-authorization checklist for X-ray, therapy and ECG claims to Summit Mutual | Missing prior authorization ($5,742) |
| 4 | Run the data quality queries automatically on every new batch of claims | Duplicates, blank payers, impossible dates |
| 5 | Weekly dashboard: denial rate, late-submission %, revenue at risk | Catching trends early |

If the clinic cut preventable denials in half, it would recover about **$10,454** in a 6-month period in this dataset. This is a planning estimate, not a promise, because not every denied claim can be successfully resubmitted.


### Dataset

| Table | Rows | What it contains |
|---|---:|---|
| `claims` | 3,045 | One row per claim: IDs, dates, procedure and diagnosis codes, billed / allowed / paid amounts, status, denial reason |
| `payers` | 5 | Insurance companies: name and type (Government or Commercial) |
| `providers` | 8 | Doctors: name, specialty and clinic location |

Key columns in `claims`:

| Column | Meaning |
|---|---|
| `billed_amount` | What the clinic charged |
| `allowed_amount` | What the insurer agreed to pay (used as the expected money) |
| `paid_amount` | What the insurer actually paid (0 when denied) |
| `claim_status` | Paid, Partially Paid, Denied or Pending |
| `denial_reason` | Why a claim was denied (only filled for denied claims) |
| `service_date` / `submission_date` | Date of the visit / date the claim was sent |


## Skills Demonstrated

- **SQL:** `SELECT`, `WHERE`, `GROUP BY`, `HAVING`, `JOIN`, `CASE WHEN`, CTEs, window functions (`ROW_NUMBER`, `SUM() OVER`), views, date functions
- **Data quality:** duplicate detection, null handling, range and logic checks, standardizing text, documenting cleaning rules
- **Business analysis:** defining KPIs (denial rate, revenue at risk), segmenting results, finding root causes
- **Communication:** turning query results into plain-English findings and prioritized recommendations for a non-technical manager

## Limitations

- The data is synthetic. Real claims data is larger, messier and needs strict privacy controls (for example HIPAA).
- Only 6 months of data are used, so seasonal patterns cannot be seen.
- Revenue lost uses the allowed amount and assumes denied claims could have been paid. In reality only some can be appealed successfully.
- 187 Pending claims were excluded from denial rates and may still be denied later.


## Author

**Suharta Ahmed**, Junior Data Analyst
[LinkedIn]:https://www.linkedin.com/in/suhartaahmed/
