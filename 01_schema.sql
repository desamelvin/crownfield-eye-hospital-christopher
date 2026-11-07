-- =====================================================================
-- 01_schema.sql  |  CPU4:103 Introduction to Database
-- Crownfield Eye Hospital ophthalmology database (fictional scenario)
-- SHARED artefact: schema and sample data made by the group (Christopher and Richard).
-- Target: MySQL 8.0.16 or newer (CHECK constraints are enforced from 8.0.16).
-- Run this file FIRST. It drops and recreates the database, so it is safe to re-run.
-- =====================================================================

DROP DATABASE IF EXISTS crownfield;
CREATE DATABASE crownfield CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE crownfield;

-- ---------------------------------------------------------------------
-- PART B: DDL (11 tables, third normal form)
-- ---------------------------------------------------------------------

CREATE TABLE specialty (
  specialty_id   INT          NOT NULL AUTO_INCREMENT,
  specialty_name VARCHAR(60)  NOT NULL,
  PRIMARY KEY (specialty_id),
  UNIQUE (specialty_name)
) ENGINE=InnoDB;

CREATE TABLE clinic (
  clinic_id   INT         NOT NULL AUTO_INCREMENT,
  clinic_name VARCHAR(80) NOT NULL,
  postcode    VARCHAR(10) NOT NULL,
  PRIMARY KEY (clinic_id),
  UNIQUE (clinic_name)
) ENGINE=InnoDB;

-- specialty_id is optional (NULL): a clinician MAY have one primary specialty.
-- The foreign key is added below with ALTER TABLE.
CREATE TABLE clinician (
  clinician_id INT         NOT NULL AUTO_INCREMENT,
  full_name    VARCHAR(80) NOT NULL,
  specialty_id INT         NULL,
  PRIMARY KEY (clinician_id)
) ENGINE=InnoDB;

CREATE TABLE patient (
  patient_id           INT         NOT NULL AUTO_INCREMENT,
  patient_ref          VARCHAR(10) NOT NULL,            -- e.g. OP001 from Appendix 1
  full_name            VARCHAR(80) NOT NULL,
  postcode             VARCHAR(10) NOT NULL,
  date_of_birth        DATE        NOT NULL,
  portal_salt          CHAR(16)    NULL,                -- filled in 04_security.sql
  portal_password_hash CHAR(64)    NULL,                -- SHA2(CONCAT(salt, password), 256)
  PRIMARY KEY (patient_id),
  UNIQUE (patient_ref),
  CONSTRAINT chk_patient_dob CHECK (date_of_birth >= '1900-01-01')
) ENGINE=InnoDB;

CREATE TABLE appointment (
  appointment_id   INT          NOT NULL AUTO_INCREMENT,
  patient_id       INT          NOT NULL,
  clinician_id     INT          NOT NULL,
  clinic_id        INT          NOT NULL,
  appointment_date DATE         NOT NULL,
  appointment_time TIME         NOT NULL DEFAULT '09:00:00',
  notes            VARCHAR(200) NULL,
  PRIMARY KEY (appointment_id),
  UNIQUE (clinician_id, appointment_date, appointment_time),   -- no double booking
  CONSTRAINT chk_appt_date CHECK (appointment_date >= '2020-01-01'),
  CONSTRAINT fk_appt_patient   FOREIGN KEY (patient_id)   REFERENCES patient (patient_id),
  CONSTRAINT fk_appt_clinician FOREIGN KEY (clinician_id) REFERENCES clinician (clinician_id),
  CONSTRAINT fk_appt_clinic    FOREIGN KEY (clinic_id)    REFERENCES clinic (clinic_id)
) ENGINE=InnoDB;

CREATE TABLE diagnosis (
  diagnosis_id   INT          NOT NULL AUTO_INCREMENT,
  diagnosis_name VARCHAR(80)  NOT NULL,
  PRIMARY KEY (diagnosis_id),
  UNIQUE (diagnosis_name)
) ENGINE=InnoDB;

-- Link table: appointment and diagnosis are many-to-many.
CREATE TABLE appt_diagnosis (
  appointment_id INT NOT NULL,
  diagnosis_id   INT NOT NULL,
  PRIMARY KEY (appointment_id, diagnosis_id),
  CONSTRAINT fk_ad_appt FOREIGN KEY (appointment_id) REFERENCES appointment (appointment_id) ON DELETE CASCADE,
  CONSTRAINT fk_ad_diag FOREIGN KEY (diagnosis_id)   REFERENCES diagnosis (diagnosis_id)
) ENGINE=InnoDB;

CREATE TABLE medicine (
  medicine_id   INT          NOT NULL AUTO_INCREMENT,
  medicine_name VARCHAR(80)  NOT NULL,
  PRIMARY KEY (medicine_id),
  UNIQUE (medicine_name)
) ENGINE=InnoDB;

CREATE TABLE prescription (
  prescription_id INT  NOT NULL AUTO_INCREMENT,
  appointment_id  INT  NOT NULL,
  issued_date     DATE NOT NULL,
  PRIMARY KEY (prescription_id),
  CONSTRAINT fk_rx_appt FOREIGN KEY (appointment_id) REFERENCES appointment (appointment_id)
) ENGINE=InnoDB;

-- One prescription holds one or more medicines, each with dose, route, frequency, duration.
CREATE TABLE prescription_item (
  item_id         INT         NOT NULL AUTO_INCREMENT,
  prescription_id INT         NOT NULL,
  medicine_id     INT         NOT NULL,
  dose            VARCHAR(30) NOT NULL,
  route           VARCHAR(20) NOT NULL,
  frequency       VARCHAR(30) NOT NULL,
  duration_days   SMALLINT    NOT NULL,
  PRIMARY KEY (item_id),
  UNIQUE (prescription_id, medicine_id),
  CONSTRAINT chk_item_duration CHECK (duration_days > 0),
  CONSTRAINT fk_item_rx  FOREIGN KEY (prescription_id) REFERENCES prescription (prescription_id) ON DELETE CASCADE,
  CONSTRAINT fk_item_med FOREIGN KEY (medicine_id)     REFERENCES medicine (medicine_id)
) ENGINE=InnoDB;

-- An appointment has at most one follow-up plan (UNIQUE on appointment_id).
CREATE TABLE follow_up (
  follow_up_id   INT         NOT NULL AUTO_INCREMENT,
  appointment_id INT         NOT NULL UNIQUE,
  due_date       DATE        NOT NULL,
  priority       VARCHAR(10) NOT NULL,
  status         VARCHAR(10) NOT NULL DEFAULT 'Open',
  PRIMARY KEY (follow_up_id),
  CHECK (priority IN ('Routine','High','Urgent')),
  CHECK (status   IN ('Open','Done','Cancelled')),
  FOREIGN KEY (appointment_id) REFERENCES appointment (appointment_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- ALTER TABLE examples
-- ---------------------------------------------------------------------
ALTER TABLE clinician
  ADD CONSTRAINT fk_clinician_specialty FOREIGN KEY (specialty_id) REFERENCES specialty (specialty_id);
ALTER TABLE patient
  ADD CONSTRAINT chk_patient_postcode CHECK (CHAR_LENGTH(postcode) BETWEEN 5 AND 8);
ALTER TABLE appointment ADD INDEX idx_appt_date (appointment_date);
ALTER TABLE follow_up   ADD INDEX idx_followup_due (due_date);

-- ---------------------------------------------------------------------
-- SAMPLE DATA
-- The first rows of each table come from Appendix 1 (patients OP001-OP004,
-- Drs Shah, Grant and Nair, the City Road, Bedford and Croydon clinics, and the five
-- appointments). All other rows are synthetic (made up) and extend the data so every
-- main table has 10 or more extra records.
-- Appendix 1 handling: "None" under Medicines means NO prescription row (assumption).
-- Follow-up "6 weeks | High" is split into due_date (appointment date + 6 weeks) and priority.
-- ---------------------------------------------------------------------

INSERT INTO specialty (specialty_name) VALUES
  ('Glaucoma'),
  ('Retina'),
  ('Cornea'),
  ('Cataract'),
  ('Oculoplastics'),
  ('Paediatric Ophthalmology'),
  ('Neuro-ophthalmology'),
  ('Uveitis'),
  ('Medical Retina'),
  ('Refractive Surgery');

INSERT INTO clinic (clinic_name, postcode) VALUES
  ('City Road', 'EC1V 2PD'),
  ('Bedford', 'MK40 1AA'),
  ('Croydon', 'CR0 1PB'),
  ('Newcastle Eye Centre', 'NE1 4LP'),
  ('Hackney', 'E8 1HQ'),
  ('Lewisham', 'SE13 6LH'),
  ('Camden', 'NW1 8DP'),
  ('Stratford', 'E15 1AZ'),
  ('Richmond', 'TW9 1TW'),
  ('Islington', 'N1 9AB'),
  ('Brixton', 'SW2 1AA');

INSERT INTO clinician (full_name, specialty_id) VALUES
  ('Dr Maya Shah', 1),
  ('Dr Leo Grant', 2),
  ('Dr Priya Nair', 3),
  ('Dr Hannah Cole', 4),
  ('Dr Omar Farouk', 5),
  ('Dr Elena Rossi', 6),
  ('Dr Ben Walker', 7),
  ('Dr Aisha Khan', 8),
  ('Dr Tom Hughes', 9),
  ('Dr Grace Lee', 10),
  ('Dr Samuel Price', NULL),
  ('Dr Nina Patel', 4);

INSERT INTO patient (patient_ref, full_name, postcode, date_of_birth) VALUES
  ('OP001', 'Amina Yusuf', 'NE1 4AB', '1968-03-14'),
  ('OP002', 'Daniel Reed', 'N16 7QP', '1957-11-02'),
  ('OP003', 'Sofia Bennett', 'E8 2LD', '1975-06-21'),
  ('OP004', 'Michael Okoro', 'SE6 3RT', '1999-01-30'),
  ('OP005', 'Priya Menon', 'CR0 2AA', '1962-09-09'),
  ('OP006', 'Jack Turner', 'SW2 4RT', '1950-04-18'),
  ('OP007', 'Laura Chen', 'NW1 6XE', '1984-12-05'),
  ('OP008', 'Ibrahim Hassan', 'E15 3QR', '1971-07-27'),
  ('OP009', 'Emma Collins', 'TW9 2AB', '1990-02-11'),
  ('OP010', 'Noah Bailey', 'N1 7GU', '2012-08-23'),
  ('OP011', 'Grace Adeyemi', 'SE13 5JN', '1966-05-16'),
  ('OP012', 'Oliver Grant', 'MK40 2BQ', '1979-10-03'),
  ('OP013', 'Hannah Wright', 'NE2 1AB', '1955-01-25'),
  ('OP014', 'Samuel Osei', 'E8 4DL', '1988-09-14'),
  ('OP015', 'Chloe Martin', 'N16 0AA', '1994-03-08'),
  ('OP016', 'Victor Ramos', 'EC1V 9HX', '1947-12-19');

INSERT INTO appointment (patient_id, clinician_id, clinic_id, appointment_date, appointment_time, notes) VALUES
  (1, 1, 1, '2026-10-05', '09:00', 'Review IOP'),
  (2, 2, 1, '2026-10-05', '09:30', 'OCT before review'),
  (1, 1, 2, '2026-11-16', '10:15', 'Visual field test'),
  (3, 1, 1, '2026-10-06', '11:00', 'Monitor'),
  (4, 3, 3, '2026-10-07', '14:00', 'Corneal topography'),
  (5, 4, 3, '2026-10-08', '09:00', 'Cataract assessment'),
  (6, 4, 3, '2026-10-08', '09:45', 'Pre-op check'),
  (7, 4, 1, '2026-10-12', '10:00', 'Cataract review'),
  (8, 5, 4, '2026-10-09', '13:30', 'Eyelid assessment'),
  (9, 6, 5, '2026-10-09', '15:00', 'Squint review'),
  (10, 6, 5, '2026-10-13', '15:30', 'Vision screening'),
  (11, 7, 7, '2026-10-14', '11:15', 'Visual field loss'),
  (12, 8, 6, '2026-10-15', '09:15', 'Uveitis flare'),
  (13, 9, 8, '2026-10-15', '10:30', 'Macular scan'),
  (14, 9, 8, '2026-10-20', '10:30', 'OCT follow-up'),
  (2, 2, 1, '2026-10-26', '09:30', 'Injection visit'),
  (2, 2, 1, '2026-11-23', '09:30', 'Injection visit'),
  (3, 1, 1, '2026-11-02', '11:00', 'Pressure check'),
  (1, 1, 2, '2026-12-14', '10:15', 'Field test results'),
  (9, 3, 3, '2026-10-21', '14:30', 'Corneal scar review'),
  (10, 10, 9, '2026-10-22', '16:00', 'Laser consultation'),
  (5, 4, 3, '2026-11-05', '09:00', 'Post-op review'),
  (6, 4, 3, '2026-11-05', '09:45', 'Post-op review'),
  (7, 1, 1, '2026-10-27', '13:00', 'Glaucoma screening'),
  (8, 7, 7, '2026-10-28', '11:15', 'Neuro review'),
  (11, 8, 6, '2026-11-10', '09:15', 'Uveitis review'),
  (12, 9, 8, '2026-11-12', '10:30', 'Macular review'),
  (13, 5, 4, '2026-11-18', '13:30', 'Eyelid surgery review'),
  (14, 10, 9, '2026-11-19', '16:00', 'Refraction check');

INSERT INTO diagnosis (diagnosis_name) VALUES
  ('Ocular hypertension'),
  ('Diabetic macular oedema'),
  ('Glaucoma suspect'),
  ('Keratoconus'),
  ('Cataract'),
  ('Ptosis'),
  ('Strabismus'),
  ('Optic neuritis'),
  ('Anterior uveitis'),
  ('Age-related macular degeneration'),
  ('Myopia'),
  ('Corneal scar');

INSERT INTO appt_diagnosis (appointment_id, diagnosis_id) VALUES
  (1, 1),
  (2, 2),
  (3, 1),
  (4, 3),
  (5, 4),
  (6, 5),
  (7, 5),
  (8, 5),
  (9, 6),
  (10, 7),
  (11, 7),
  (12, 8),
  (13, 9),
  (14, 10),
  (15, 10),
  (16, 2),
  (17, 2),
  (18, 3),
  (19, 1),
  (20, 12),
  (21, 11),
  (22, 5),
  (23, 5),
  (24, 3),
  (25, 8),
  (26, 9),
  (27, 10),
  (28, 6),
  (29, 11);

INSERT INTO medicine (medicine_name) VALUES
  ('Latanoprost'),
  ('Timolol'),
  ('Aflibercept'),
  ('Sodium chloride drops'),
  ('Dorzolamide'),
  ('Prednisolone drops'),
  ('Atropine drops'),
  ('Chloramphenicol ointment'),
  ('Carbomer gel'),
  ('Ranibizumab'),
  ('Brimonidine'),
  ('Cyclopentolate');

INSERT INTO prescription (appointment_id, issued_date) VALUES
  (1, '2026-10-05'),
  (2, '2026-10-05'),
  (3, '2026-11-16'),
  (5, '2026-10-07'),
  (7, '2026-10-08'),
  (8, '2026-10-12'),
  (10, '2026-10-09'),
  (13, '2026-10-15'),
  (14, '2026-10-15'),
  (16, '2026-10-26'),
  (17, '2026-11-23'),
  (18, '2026-11-02'),
  (19, '2026-12-14'),
  (22, '2026-11-05'),
  (24, '2026-10-27'),
  (27, '2026-11-12'),
  (20, '2026-10-21'),
  (28, '2026-11-18');

INSERT INTO prescription_item (prescription_id, medicine_id, dose, route, frequency, duration_days) VALUES
  (1, 1, '1 drop', 'Eye', 'Once nightly', 42),
  (1, 2, '1 drop', 'Eye', 'Twice daily', 42),
  (2, 3, '2 mg', 'Intravitreal', 'Every 4 weeks', 28),
  (3, 1, '1 drop', 'Eye', 'Once nightly', 84),
  (4, 4, '1 drop', 'Eye', 'Four times daily', 56),
  (5, 8, '1 cm ribbon', 'Eye', 'Three times daily', 7),
  (6, 6, '1 drop', 'Eye', 'Four times daily', 28),
  (7, 7, '1 drop', 'Eye', 'Once daily', 90),
  (8, 6, '1 drop', 'Eye', 'Hourly', 14),
  (8, 12, '1 drop', 'Eye', 'Twice daily', 14),
  (9, 10, '0.5 mg', 'Intravitreal', 'Every 4 weeks', 28),
  (10, 3, '2 mg', 'Intravitreal', 'Every 4 weeks', 28),
  (11, 3, '2 mg', 'Intravitreal', 'Every 4 weeks', 28),
  (12, 5, '1 drop', 'Eye', 'Three times daily', 60),
  (13, 1, '1 drop', 'Eye', 'Once nightly', 56),
  (14, 6, '1 drop', 'Eye', 'Four times daily', 28),
  (15, 11, '1 drop', 'Eye', 'Twice daily', 60),
  (16, 10, '0.5 mg', 'Intravitreal', 'Every 4 weeks', 28),
  (17, 9, '1 drop', 'Eye', 'Four times daily', 30),
  (18, 9, '1 drop', 'Eye', 'Four times daily', 30);

INSERT INTO follow_up (appointment_id, due_date, priority, status) VALUES
  (1, '2026-11-16', 'High', 'Open'),
  (2, '2026-11-02', 'Urgent', 'Open'),
  (3, '2027-02-08', 'Routine', 'Open'),
  (4, '2027-04-06', 'Routine', 'Open'),
  (5, '2026-12-02', 'Routine', 'Open'),
  (6, '2026-11-05', 'Routine', 'Done'),
  (7, '2026-10-22', 'High', 'Done'),
  (8, '2026-11-23', 'Routine', 'Open'),
  (10, '2026-12-04', 'Routine', 'Open'),
  (12, '2026-11-11', 'Urgent', 'Open'),
  (13, '2026-10-29', 'Urgent', 'Done'),
  (14, '2026-11-26', 'High', 'Open'),
  (16, '2026-11-23', 'Urgent', 'Open'),
  (18, '2026-12-28', 'Routine', 'Open'),
  (20, '2027-01-13', 'Routine', 'Cancelled'),
  (22, '2026-11-19', 'High', 'Open'),
  (24, '2027-01-19', 'Routine', 'Open');

-- ---------------------------------------------------------------------
-- TESTS (Part B): controlled UPDATE and DELETE, and an integrity check
-- ---------------------------------------------------------------------
SELECT 'specialty' AS tbl, COUNT(*) AS row_count FROM specialty UNION ALL
SELECT 'clinic', COUNT(*) FROM clinic UNION ALL
SELECT 'clinician', COUNT(*) FROM clinician UNION ALL
SELECT 'patient', COUNT(*) FROM patient UNION ALL
SELECT 'appointment', COUNT(*) FROM appointment UNION ALL
SELECT 'diagnosis', COUNT(*) FROM diagnosis UNION ALL
SELECT 'appt_diagnosis', COUNT(*) FROM appt_diagnosis UNION ALL
SELECT 'medicine', COUNT(*) FROM medicine UNION ALL
SELECT 'prescription', COUNT(*) FROM prescription UNION ALL
SELECT 'prescription_item', COUNT(*) FROM prescription_item UNION ALL
SELECT 'follow_up', COUNT(*) FROM follow_up;

-- Controlled UPDATE (allowed)
UPDATE follow_up SET status = 'Done' WHERE follow_up_id = 17;
SELECT follow_up_id, status FROM follow_up WHERE follow_up_id = 17;          -- Done
-- Put it back so every student starts the later files with the same data
UPDATE follow_up SET status = 'Open' WHERE follow_up_id = 17;

-- Controlled DELETE on a leaf row (allowed: nothing points at a follow-up)
DELETE FROM follow_up WHERE follow_up_id = 9;
SELECT COUNT(*) AS follow_up_9_left FROM follow_up WHERE follow_up_id = 9;   -- 0

-- Re-create the follow-up we just removed so later files see the same data
INSERT INTO follow_up (follow_up_id, appointment_id, due_date, priority, status)
VALUES (9, 10, '2026-12-04', 'Routine', 'Open');

-- Referential integrity test (BLOCKED on purpose).
-- Uncomment the next line to see MySQL error 1451 (patient 1 still has appointments).
-- If you run this file with the mysql client, an error stops the script, so it stays commented.
-- DELETE FROM patient WHERE patient_id = 1;
