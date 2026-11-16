Healthcare Claims: Data Quality & Denial Analysis

A  Data Operations portfolio project using SQL. It cleans messy healthcare billing (RCM) data, finds why insurance claims get denied, and recommends what to fix first.

Note: All data is synthetic (made up for learning). It contains no real patients. It was built to behave like real billing data, including real-world errors.

Business Problem

When a clinic treats a patient, it sends a claim (a bill) to the insurance company. The insurer can pay it, pay part of it, or deny it. A denied claim means the clinic did the work but gets no money unless staff spend time fixing and resubmitting it.

A clinic network noticed more claims coming back denied. This project answers five questions:

Can we trust the data? What errors exist before we report anything?
What is the denial rate, and how much money is at risk?
Which insurers and doctors have the highest denial rates?
What are the main denial reasons, and is the problem getting worse?
Which problems can the clinic fix itself, and what comes first?
Key Results
Metric	Result
Raw claim rows	3,045
Clean rows after data cleaning	2,954 (91 removed)
Claims decided by insurers (Pending excluded)	2,767
Denial rate	15.6%
Revenue lost to denials	$34,240
Share of lost revenue that was preventable	61.1%
Findings
1. One insurer denies far more than the others

Summit Mutual denied 28.3% of claims, about 2.6 times the rate of Federal Medicare (10.7%). The cause is in the prior-authorization check: 41.7% of Summit Mutual claims that need pre-approval (chest X-ray, therapy, ECG) were denied for a missing authorization. The other insurers with a known payer had 0%.

Denial rate by insurer (%)
Summit
Unknown
Medicaid
Northstar
Evergreen
Medicare
35
30
25
20
15
10
5
0
Denial rate (%)
2. Most lost money comes from problems the clinic can control

Timely filing, missing diagnosis codes and missing prior authorization are all process errors on the clinic's side. Together with the other preventable reasons they make up 61.1% of all revenue lost to denials.

61%
39%
Revenue lost to denials ($34,240)
Preventable (process errors) $20,907 [61.1]
Other reasons $13,333 [38.9]
Denied claims by reason
Timely filing
Missing diagnosis
Prior auth
Eligibility
Coding error
Not med. necessary
Duplicate
140
130
120
110
100
90
80
70
60
50
40
30
20
10
0
Denied claims
3. Late submission is the biggest driver

Claims sent more than 30 days after the visit were denied 72.2% of the time, compared with 10.3% for claims sent within 7 days. Insurers have filing deadlines.

Denial rate by submission speed (%)
0-7 days
8-14 days
15-30 days
Over 30 days
80
70
60
50
40
30
20
10
0
Denial rate (%)
4. The problem is getting worse

The denial rate rose from 14.4% in January to 21.6% in June. Over the same months, the share of claims submitted more than 30 days late grew from 4.4% to 10.0%. The two lines move together, which suggests late filing is a main cause. (This shows a strong link, but it does not prove cause on its own.)

Denial rate vs late submissions (%), Jan to Jun 2026
Jan
Feb
Mar
Apr
May
Jun
24
22
20
18
16
14
12
10
8
6
4
2
0
Percent

Top line: denial rate. Bottom line: claims submitted over 30 days late.

5. One doctor has a documentation problem

Dr. Evans has a 27.4% denial rate and 20.1% of claims with no diagnosis code. Every other doctor is at or below 1.6% for missing diagnosis codes. This points to a workflow or habit issue for one provider, not a system-wide fault.

Denial rate by doctor (%)
Evans
Adams
Foster
Hill
Davis
Brooks
Garcia
Chen
30
28
26
24
22
20
18
16
14
12
10
8
6
4
2
0
Denial rate (%)
Data Quality Audit

Before any analysis, every column was checked against simple business rules. Seven issues were found and handled in a SQL view, so the raw table is never edited.

Issue	Rows	How it was handled
Duplicate claim rows	45	Kept one row per claim_id
Missing payer_id	30	Kept, labeled UNKNOWN, flagged
Missing diagnosis_code	103	Kept (this is a finding: it causes denials)
Negative billed_amount	13	Excluded
Paid more than billed	27	Excluded
Submitted before service date	20	Excluded
Messy claim_status text (PAID, paid)	61	Trimmed and standardized to 4 values

Some rows have more than one issue, so the counts overlap.

Recommendations
Priority	Action	Problem it targets
1	Daily report of claims not submitted after 7 days; set a 14-day internal deadline	Late filing (largest single loss, $9,645)
2	Block submission when diagnosis_code is empty; coach Dr. Evans' team on documentation	Missing diagnosis codes ($5,519)
3	Prior-authorization checklist for X-ray, therapy and ECG claims to Summit Mutual	Missing prior authorization ($5,742)
4	Run the data quality queries automatically on every new batch of claims	Duplicates, blank payers, impossible dates
5	Weekly dashboard: denial rate, late-submission %, revenue at risk	Catching trends early

If the clinic cut preventable denials in half, it would recover about $10,454 in a 6-month period in this dataset. This is a planning estimate, not a promise, because not every denied claim can be successfully resubmitted.

Dataset
Table	Rows	What it contains
claims	3,045	One row per claim: IDs, dates, procedure and diagnosis codes, billed / allowed / paid amounts, status, denial reason
payers	5	Insurance companies: name and type (Government or Commercial)
providers	8	Doctors: name, specialty and clinic location


Author

Suharta Ahmed, Junior Data Analyst LinkedIn :https://www.linkedin.com/in/suhartaahmed/
