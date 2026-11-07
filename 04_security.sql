-- =====================================================================
-- 04_security.sql  |  CPU4:103  |  Student: Christopher
-- INDIVIDUAL work. Run after 01_schema.sql and 03_procedure_and_trigger.sql.
-- Part D: roles and privileges, hashing, transactions, secure coding.
-- Run as a MySQL admin (for example root). Needs MySQL 8.0 for roles.
-- Passwords below are DEMO values for the fictional system only. Never reuse them.
-- =====================================================================
USE crownfield;

-- =====================================================================
-- D1  ROLES AND PRIVILEGES  (principle of least privilege)
-- Access matrix:
--   Role           Patients    Appointments   Diagnoses, Rx   Follow-ups
--   Administrator  Full        Full           Full            Full
--   Doctor         Read        Read, update   Read, write     Read, write
--   Receptionist   Read, write Read, write    None            Read
--   Patient        Own record  Own record     Own record      Own record  (through views)
--   Read = SELECT | Write = INSERT, UPDATE | Full = SELECT, INSERT, UPDATE, DELETE
-- =====================================================================
DROP ROLE IF EXISTS 'admin_role', 'doctor_role', 'reception_role', 'patient_role';
CREATE ROLE 'admin_role', 'doctor_role', 'reception_role', 'patient_role';

-- Administrator: full access to every table.
GRANT SELECT, INSERT, UPDATE, DELETE ON crownfield.* TO 'admin_role';

-- Doctor
GRANT SELECT ON crownfield.patient   TO 'doctor_role';
GRANT SELECT ON crownfield.clinician TO 'doctor_role';
GRANT SELECT ON crownfield.clinic    TO 'doctor_role';
GRANT SELECT ON crownfield.specialty TO 'doctor_role';
GRANT SELECT, UPDATE         ON crownfield.appointment        TO 'doctor_role';
GRANT SELECT, INSERT, UPDATE ON crownfield.diagnosis          TO 'doctor_role';
GRANT SELECT, INSERT, UPDATE ON crownfield.appt_diagnosis     TO 'doctor_role';
GRANT SELECT, INSERT, UPDATE ON crownfield.medicine           TO 'doctor_role';
GRANT SELECT, INSERT, UPDATE ON crownfield.prescription       TO 'doctor_role';
GRANT SELECT, INSERT, UPDATE ON crownfield.prescription_item  TO 'doctor_role';
GRANT SELECT, INSERT, UPDATE ON crownfield.follow_up          TO 'doctor_role';

-- Receptionist: no clinical data (no diagnosis or prescription tables).
-- The receptionist sees patient columns but NOT the password hash (column-level grant).
GRANT SELECT (patient_id, patient_ref, full_name, postcode, date_of_birth) ON crownfield.patient TO 'reception_role';
GRANT INSERT (patient_ref, full_name, postcode, date_of_birth)             ON crownfield.patient TO 'reception_role';
GRANT UPDATE (full_name, postcode)                                          ON crownfield.patient TO 'reception_role';
GRANT SELECT, INSERT, UPDATE ON crownfield.appointment TO 'reception_role';
GRANT SELECT ON crownfield.follow_up TO 'reception_role';
GRANT SELECT ON crownfield.clinician TO 'reception_role';
GRANT SELECT ON crownfield.clinic    TO 'reception_role';
GRANT SELECT ON crownfield.specialty TO 'reception_role';

-- Patient: only their own rows, through filtered views.
-- USER() is the account the client connected as (for example 'pt_op001@localhost').
-- The part after "pt_" is turned into a patient reference (OP001) and used as the filter.
CREATE OR REPLACE VIEW v_my_record AS
  SELECT patient_ref, full_name, postcode, date_of_birth
  FROM   patient
  WHERE  patient_ref = UPPER(SUBSTRING_INDEX(SUBSTRING_INDEX(USER(), '@', 1), '_', -1));

CREATE OR REPLACE VIEW v_my_appointments AS
  SELECT a.appointment_date, a.appointment_time, c.clinic_name, k.full_name AS clinician
  FROM   appointment a
  JOIN   patient   p ON p.patient_id   = a.patient_id
  JOIN   clinic    c ON c.clinic_id    = a.clinic_id
  JOIN   clinician k ON k.clinician_id = a.clinician_id
  WHERE  p.patient_ref = UPPER(SUBSTRING_INDEX(SUBSTRING_INDEX(USER(), '@', 1), '_', -1));

CREATE OR REPLACE VIEW v_my_follow_ups AS
  SELECT f.due_date, f.priority, f.status
  FROM   follow_up f
  JOIN   appointment a ON a.appointment_id = f.appointment_id
  JOIN   patient     p ON p.patient_id     = a.patient_id
  WHERE  p.patient_ref = UPPER(SUBSTRING_INDEX(SUBSTRING_INDEX(USER(), '@', 1), '_', -1));

CREATE OR REPLACE VIEW v_my_prescriptions AS
  SELECT rx.issued_date, m.medicine_name, i.dose, i.route, i.frequency, i.duration_days
  FROM   prescription rx
  JOIN   appointment a        ON a.appointment_id  = rx.appointment_id
  JOIN   patient     p        ON p.patient_id      = a.patient_id
  JOIN   prescription_item i  ON i.prescription_id = rx.prescription_id
  JOIN   medicine    m        ON m.medicine_id     = i.medicine_id
  WHERE  p.patient_ref = UPPER(SUBSTRING_INDEX(SUBSTRING_INDEX(USER(), '@', 1), '_', -1));

GRANT SELECT ON crownfield.v_my_record        TO 'patient_role';
GRANT SELECT ON crownfield.v_my_appointments  TO 'patient_role';
GRANT SELECT ON crownfield.v_my_follow_ups    TO 'patient_role';
GRANT SELECT ON crownfield.v_my_prescriptions TO 'patient_role';

-- Users (one per role) and role assignment
DROP USER IF EXISTS 'admin_chris'@'localhost', 'dr_shah'@'localhost', 'rec_jones'@'localhost', 'pt_op001'@'localhost';
CREATE USER 'admin_chris'@'localhost' IDENTIFIED BY 'Admin#Demo1';
CREATE USER 'dr_shah'@'localhost'     IDENTIFIED BY 'Doctor#Demo1';
CREATE USER 'rec_jones'@'localhost'   IDENTIFIED BY 'Reception#Demo1';
CREATE USER 'pt_op001'@'localhost'    IDENTIFIED BY 'Patient#Demo1';

GRANT 'admin_role'     TO 'admin_chris'@'localhost';
GRANT 'doctor_role'    TO 'dr_shah'@'localhost';
GRANT 'reception_role' TO 'rec_jones'@'localhost';
GRANT 'patient_role'   TO 'pt_op001'@'localhost';
SET DEFAULT ROLE ALL TO 'admin_chris'@'localhost', 'dr_shah'@'localhost', 'rec_jones'@'localhost', 'pt_op001'@'localhost';

-- Prove it: SHOW GRANTS (take a screenshot of these)
SHOW GRANTS FOR 'dr_shah'@'localhost' USING 'doctor_role';
SHOW GRANTS FOR 'rec_jones'@'localhost' USING 'reception_role';
SHOW GRANTS FOR 'pt_op001'@'localhost' USING 'patient_role';

-- REVOKE takes a privilege away again. Example: doctors may no longer update appointments.
REVOKE UPDATE ON crownfield.appointment FROM 'doctor_role';
SHOW GRANTS FOR 'doctor_role';
-- Put it back (the access matrix says doctors can update appointments):
GRANT UPDATE ON crownfield.appointment TO 'doctor_role';

-- To test as a user, open a NEW connection, for example in the command line:
--   mysql -u dr_shah -p crownfield     (then try:  SELECT * FROM patient;  DELETE FROM patient;)
--   mysql -u pt_op001 -p crownfield    (then try:  SELECT * FROM v_my_record;  SELECT * FROM patient;)
-- Expected: the doctor can read patients but DELETE fails with error 1142 (command denied).
--           the patient sees only OP001 in the views and gets error 1142 on the patient table.

-- =====================================================================
-- D2  DATA PROTECTION: salted SHA-256 hashing of portal passwords
-- Method: stored value = SHA2(CONCAT(salt, password), 256).
-- A random salt per patient means two patients with the same password get different hashes.
-- MD5 is not used because the lecture says it is compromised.
-- Demo passwords follow the pattern Pass#<patient_ref> and exist only for this test.
-- =====================================================================
SET SQL_SAFE_UPDATES = 0;      -- MySQL Workbench blocks UPDATE without a key in WHERE; these updates cover every row on purpose
UPDATE patient
SET    portal_salt          = HEX(RANDOM_BYTES(8)),               -- 16 hex characters
       portal_password_hash = NULL;
UPDATE patient
SET    portal_password_hash = SHA2(CONCAT(portal_salt, CONCAT('Pass#', patient_ref)), 256);

-- Proof 1: the table holds hashes, not passwords.
SELECT patient_ref, portal_salt, portal_password_hash FROM patient LIMIT 4;

-- Proof 2: login check. Correct password gives 1 row, wrong password gives 0 rows.
SET @entered = 'Pass#OP001';
SELECT patient_ref, full_name AS login_ok
FROM   patient
WHERE  patient_ref = 'OP001'
  AND  portal_password_hash = SHA2(CONCAT(portal_salt, @entered), 256);
SET @entered = 'wrong-password';
SELECT patient_ref, full_name AS login_ok
FROM   patient
WHERE  patient_ref = 'OP001'
  AND  portal_password_hash = SHA2(CONCAT(portal_salt, @entered), 256);

-- =====================================================================
-- TRANSACTIONS (atomicity): a booking = appointment + follow-up, all or nothing
-- =====================================================================

-- T1: COMMIT. Both inserts succeed together.
START TRANSACTION;
INSERT INTO appointment (patient_id, clinician_id, clinic_id, appointment_date)
VALUES (1, 2, 1, '2026-11-20');                       -- time defaults to 09:00
INSERT INTO follow_up (appointment_id, due_date, priority)
VALUES (LAST_INSERT_ID(), '2027-01-01', 'High');
COMMIT;
SELECT a.appointment_id, a.appointment_date, f.due_date, f.priority
FROM   appointment a JOIN follow_up f ON f.appointment_id = a.appointment_id
WHERE  a.appointment_date = '2026-11-20';             -- 1 row

-- T2: ROLLBACK. We change our mind, so BOTH inserts are undone.
SELECT COUNT(*) AS appointments_before FROM appointment;
START TRANSACTION;
INSERT INTO appointment (patient_id, clinician_id, clinic_id, appointment_date)
VALUES (2, 1, 1, '2026-11-21');
INSERT INTO follow_up (appointment_id, due_date, priority)
VALUES (LAST_INSERT_ID(), '2027-01-15', 'Routine');
ROLLBACK;
SELECT COUNT(*) AS appointments_after FROM appointment;   -- same number as before

-- T3: automatic ROLLBACK on error, inside a stored procedure.
-- If any step fails (for example the trigger rejects a due date before the appointment),
-- the handler rolls back everything and re-raises the error.
DROP PROCEDURE IF EXISTS sp_book_with_followup;
DELIMITER $$
CREATE PROCEDURE sp_book_with_followup (
  IN p_patient  INT, IN p_clinician INT, IN p_clinic INT,
  IN p_date     DATE, IN p_time TIME,
  IN p_due      DATE, IN p_priority VARCHAR(10))
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;
  START TRANSACTION;
  INSERT INTO appointment (patient_id, clinician_id, clinic_id, appointment_date, appointment_time)
  VALUES (p_patient, p_clinician, p_clinic, p_date, p_time);
  INSERT INTO follow_up (appointment_id, due_date, priority)
  VALUES (LAST_INSERT_ID(), p_due, p_priority);
  COMMIT;
END$$
DELIMITER ;

-- Good booking: both rows are saved.
CALL sp_book_with_followup(3, 1, 1, '2026-12-01', '10:00', '2027-01-12', 'Routine');
-- Bad booking: the due date is before the appointment, so the trigger raises an error and
-- the handler rolls back. Afterwards NO appointment on 2026-12-02 exists (the next SELECT).
-- Expected: ERROR 1644 (45000): Due before appointment
CALL sp_book_with_followup(3, 1, 1, '2026-12-02', '10:00', '2026-11-30', 'High');
-- Run this by hand after the bad call (the command-line client stops at the error above):
SELECT COUNT(*) AS rolled_back_check FROM appointment WHERE appointment_date = '2026-12-02';   -- 0

-- =====================================================================
-- SECURE CODING: SQL injection (extra credit)
-- =====================================================================
-- UNSAFE: user input is joined into the SQL text.
SET @input = "x' OR '1'='1";
SET @unsafe_sql = CONCAT("SELECT patient_ref, full_name FROM patient WHERE full_name = '", @input, "'");
SELECT @unsafe_sql AS the_query_mysql_receives;
PREPARE unsafe_stmt FROM @unsafe_sql;
EXECUTE unsafe_stmt;                      -- returns EVERY patient: the attack worked
DEALLOCATE PREPARE unsafe_stmt;

-- SAFE: a prepared statement with a ? placeholder. The value is bound as DATA only.
PREPARE safe_stmt FROM 'SELECT patient_ref, full_name FROM patient WHERE full_name = ?';
EXECUTE safe_stmt USING @input;           -- returns 0 rows: the attack text is just a name nobody has
SET @real_name = 'Amina Yusuf';
EXECUTE safe_stmt USING @real_name;       -- returns 1 row
DEALLOCATE PREPARE safe_stmt;

-- Stored procedures with typed parameters give the same protection:
CALL sp_patient_appts(1);                 -- from 03_procedure_and_trigger.sql
