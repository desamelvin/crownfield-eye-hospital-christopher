# Crownfield Eye Hospital ophthalmology database

CPU4:103 Introduction to Database. Fictional teaching scenario (not a real hospital system).
**Student:** Christopher (group partner: Richard). Module leader: Puna-Rimam Maiyaki.

## What is in this repository

| File | Purpose |
|---|---|
| `01_schema.sql` | Shared (group). Creates the database, 11 tables, constraints and sample data, plus Part B tests. |
| `02_individual_queries.sql` | Individual. Q1 GROUP BY + HAVING, Q2 INNER JOIN (4 tables), Q3 LEFT JOIN, Q4 CTE. |
| `03_procedure_and_trigger.sql` | Individual. Q5 stored procedure sp_patient_appts, Q6 trigger trg_followup_due_check. |
| `04_security.sql` | Individual. Roles and privileges, access matrix, SHA-256 hashing, transactions, SQL injection examples. |
| `05_ERD/erd.png`, `05_ERD/erd.mmd` | ER diagram in Crow's Foot notation (image and Mermaid source). Shared artefact. |
| `TEST_LOG.md` | Short test log (Part B evidence): what to run and what should happen. |

## Setup (about 5 minutes)

1. Install **MySQL Server 8.0.16 or newer** and **MySQL Workbench** (CHECK constraints and roles need 8.0).
2. Connect as `root` (or any admin account) in Workbench or with `mysql -u root -p`.
3. Run the files **in this order**. Each file starts with `USE crownfield;` except `01`, which creates the database.
   1. `01_schema.sql`
   2. `02_individual_queries.sql`
   3. `03_procedure_and_trigger.sql`
   4. `04_security.sql`
4. Command line example: `mysql -u root -p < 01_schema.sql`, then the same for 02, 03 and 04.
   Files 03 and 04 use `DELIMITER`, which the `mysql` client and Workbench both support.
5. `01_schema.sql` drops and recreates the `crownfield` database, so you can re-run the whole sequence at any time.

## Notes on running

- The last statement of `03` (and one example in `01`) is meant to **fail** to show a rule working
  (error 1644 or 1451). In the command-line client an error stops the script, so those are last or commented out.
  In Workbench, run the failing statement alone and take your screenshot.
- Run `04_security.sql` as an admin. To test a role, open a new connection as that user (users and demo passwords are in the file).
- All passwords in the files are demo values for a fictional system.

## Assumptions

1. Each clinician has at most one primary specialty (`specialty_id` can be NULL).
2. "None" under Medicines in Appendix 1 means there is **no prescription row**, not a medicine called None.
3. Follow-up durations in weeks are counted from the appointment date. "6 weeks | High" became `due_date` and `priority`.
4. An appointment has at most one follow-up plan (UNIQUE on `follow_up.appointment_id`).
5. A clinician cannot be double-booked at the same date and time (UNIQUE on clinician, date, time).
6. Appendix 1 rows are kept as appointments 1 to 5. Other rows are synthetic (made up).

## My individual contribution (Christopher)

> TODO (write this in your own words before submitting; the marking rubric looks for it):
> list exactly which files and queries you wrote yourself, and which parts were shared with Richard
> (the schema, sample data and ER diagram).

## References

Add your Harvard-style references here (for example the MySQL 8.0 Reference Manual, OWASP, the module lectures).
