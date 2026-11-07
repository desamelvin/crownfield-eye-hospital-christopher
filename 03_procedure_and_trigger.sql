-- =====================================================================
-- 03_procedure_and_trigger.sql  |  CPU4:103  |  Student: Christopher
-- INDIVIDUAL work. Run after 01_schema.sql (and 02 if you like).
-- Q5: stored procedure with an input parameter
-- Q6: trigger that enforces a business rule
-- =====================================================================
USE crownfield;

DROP PROCEDURE IF EXISTS sp_patient_appts;
DROP TRIGGER   IF EXISTS trg_followup_due_check;

DELIMITER $$

-- ---------------------------------------------------------------------
-- Q5  STORED PROCEDURE with an INPUT parameter
-- Question: What are one patient's appointments (date, time, clinic, clinician)?
-- Input: p_id = the patient's ID.
-- Why it is safe: p_id is a typed parameter used as a value, never joined into SQL text,
-- so it cannot change the query (this also helps against SQL injection).
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_patient_appts (IN p_id INT)
BEGIN
  SELECT a.appointment_date,
         a.appointment_time,
         k.clinic_name,
         c.full_name AS clinician
  FROM   appointment a
  JOIN   clinic     k ON k.clinic_id    = a.clinic_id
  JOIN   clinician  c ON c.clinician_id = a.clinician_id
  WHERE  a.patient_id = p_id
  ORDER  BY a.appointment_date, a.appointment_time;
END$$

-- ---------------------------------------------------------------------
-- Q6  TRIGGER that enforces a business rule
-- Rule: a follow-up can never be due BEFORE the appointment it belongs to.
-- A CHECK constraint cannot read another table, so a BEFORE INSERT trigger does it.
-- SQLSTATE '45000' is the standard "user-defined error" and stops the INSERT.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_followup_due_check
BEFORE INSERT ON follow_up
FOR EACH ROW
BEGIN
  IF NEW.due_date < (SELECT appointment_date
                     FROM   appointment
                     WHERE  appointment_id = NEW.appointment_id) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Due before appointment';
  END IF;
END$$

DELIMITER ;

-- =====================================================================
-- DEMONSTRATION (run these live in the recording)
-- =====================================================================

-- Q5 demo: patient 1 (Amina Yusuf) has 3 appointments, shown in date order.
CALL sp_patient_appts(1);
-- Expected: 2026-10-05 City Road, 2026-11-16 Bedford, 2026-12-14 Bedford.
-- Change the number to see another patient, for example CALL sp_patient_appts(4);

-- Q6 demo, part 1: a VALID insert (due date after the appointment date) works.
-- Appointment 9 (2026-10-09) has no follow-up yet.
INSERT INTO follow_up (appointment_id, due_date, priority)
VALUES (9, '2026-11-09', 'Routine');
SELECT follow_up_id, appointment_id, due_date, priority, status
FROM   follow_up WHERE appointment_id = 9;

-- Q6 demo, part 2: an INVALID insert is rejected. Appointment 11 is on 2026-10-13.
-- Expected: ERROR 1644 (45000): Due before appointment
-- (Take your screenshot of this error. In the mysql command-line client the script stops
--  here, which is fine because this is the last statement.)
INSERT INTO follow_up (appointment_id, due_date, priority)
VALUES (11, '2026-10-01', 'High');
