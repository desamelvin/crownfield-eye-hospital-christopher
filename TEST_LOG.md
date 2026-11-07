# Test log: Christopher

Run date: ____  MySQL version: ____ (`SELECT VERSION();`)

Fill the last two columns as you run each test and keep a screenshot for each row you show in the report.
Expected results were worked out from the sample data in `01_schema.sql`.

| # | Test | What to run | Expected result | Actual | Pass? |
|---|---|---|---|---|---|
| 1 | 01_schema.sql | Run the file. Last result sets show row counts per table, the UPDATE result (Done) and the DELETE result (0). | Row counts: specialty 10, clinic 11, clinician 12, patient 16, appointment 29, diagnosis 12, appt_diagnosis 29, medicine 12, prescription 18, prescription_item 20, follow_up 17. No errors. | | |
| 2 | 02 Q1 GROUP BY + HAVING | Run Q1. | 4 rows: Dr Maya Shah 6, Dr Hannah Cole 5, Dr Leo Grant 3, Dr Tom Hughes 3. | | |
| 3 | 02 Q2 INNER JOIN | Run Q2. | 29 rows, one per appointment, names match. | | |
| 4 | 02 Q3 LEFT JOIN | Run Q3. | 11 rows of appointments with no prescription, including OP003 on 2026-10-06. | | |
| 5 | 02 Q4 CTE | Run Q4. | 3 rows: Daniel Reed 2026-11-02, Grace Adeyemi 2026-11-11, Daniel Reed 2026-11-23. | | |
| 6 | 03 Q5 procedure | CALL sp_patient_appts(1); | 3 rows: 2026-10-05 City Road, 2026-11-16 Bedford, 2026-12-14 Bedford. | | |
| 7 | 03 Q6 trigger (valid) | Insert follow-up for appointment 9 due 2026-11-09. | 1 row inserted, status Open. | | |
| 8 | 03 Q6 trigger (invalid) | Insert follow-up for appointment 11 due 2026-10-01. | ERROR 1644 (45000): Due before appointment. No row inserted. | | |
| 9 | Integrity: delete a patient with appointments | DELETE FROM patient WHERE patient_id = 1; | ERROR 1451: cannot delete or update a parent row (foreign key fails). | | |
| 10 | 04 Roles and SHOW GRANTS | Run the roles section. | SHOW GRANTS lists only the privileges in the access matrix for each user. | | |
| 11 | 04 Role test as dr_shah | Connect as dr_shah and run DELETE FROM patient; | ERROR 1142: DELETE command denied. | | |
| 12 | 04 Role test as pt_op001 | Connect as pt_op001, run SELECT * FROM v_my_record; then SELECT * FROM patient; | First: 1 row (OP001). Second: ERROR 1142 denied. | | |
| 13 | 04 Hashing | Run the hashing section. | 64-character hashes. Right password returns 1 row, wrong password returns 0 rows. | | |
| 14 | 04 Transactions T1/T2 | Run T1 then T2. | T1: 1 booking saved. T2: appointment count before = after. | | |
| 15 | 04 Transactions T3 | Run the two CALLs of sp_book_with_followup. | First succeeds. Second: ERROR 1644 and no appointment on 2026-12-02 (check query returns 0). | | |
| 16 | 04 SQL injection | Run the unsafe and safe examples. | Unsafe returns all 16 patients. Safe returns 0 rows for the attack text and 1 row for Amina Yusuf. | | |
