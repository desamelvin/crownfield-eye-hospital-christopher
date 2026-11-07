-- =====================================================================
-- 02_individual_queries.sql  |  CPU4:103  |  Student: Christopher
-- INDIVIDUAL work. Run after 01_schema.sql.
-- Queries 1 to 4 are here. Query 5 (stored procedure) and query 6 (trigger)
-- are in 03_procedure_and_trigger.sql.
-- For each query: the question, the SQL, and what the result should show.
-- =====================================================================
USE crownfield;

-- ---------------------------------------------------------------------
-- Q1  AGGREGATE with GROUP BY and HAVING
-- Question: Which clinicians have more than two appointments?
-- Expected: Dr Maya Shah (6), Dr Hannah Cole (5), Dr Leo Grant (3), Dr Tom Hughes (3).
-- Why it is correct: COUNT(*) counts appointment rows per clinician, and HAVING keeps only
-- groups with a count above 2 (WHERE cannot filter on an aggregate).
-- ---------------------------------------------------------------------
SELECT k.full_name         AS clinician,
       COUNT(*)            AS appointment_count
FROM   appointment a
JOIN   clinician  k ON k.clinician_id = a.clinician_id
GROUP  BY k.clinician_id, k.full_name
HAVING COUNT(*) > 2
ORDER  BY appointment_count DESC, clinician;

-- ---------------------------------------------------------------------
-- Q2  INNER JOIN across four related tables
-- Question: Which patient saw which clinician, at which clinic and when?
-- Expected: 29 rows, one per appointment, each with the correct names.
-- Why it is correct: the join conditions use the foreign keys, so every appointment row
-- matches exactly one patient, one clinician and one clinic.
-- ---------------------------------------------------------------------
SELECT p.patient_ref,
       p.full_name        AS patient,
       k.full_name        AS clinician,
       c.clinic_name      AS clinic,
       a.appointment_date,
       a.appointment_time
FROM   appointment a
INNER JOIN patient   p ON p.patient_id   = a.patient_id
INNER JOIN clinician k ON k.clinician_id = a.clinician_id
INNER JOIN clinic    c ON c.clinic_id    = a.clinic_id
ORDER  BY a.appointment_date, a.appointment_time;

-- ---------------------------------------------------------------------
-- Q3  LEFT JOIN that reveals missing data
-- Question: Which appointments have no prescription?
-- Expected: 11 rows, including OP003 on 2026-10-06 (the "None" row from Appendix 1).
-- Why it is correct: LEFT JOIN keeps every appointment. Where no prescription exists the
-- prescription columns are NULL, and WHERE ... IS NULL keeps only those rows.
-- ---------------------------------------------------------------------
SELECT a.appointment_id,
       p.full_name        AS patient,
       a.appointment_date,
       a.notes
FROM   appointment a
JOIN   patient p              ON p.patient_id = a.patient_id
LEFT JOIN prescription rx     ON rx.appointment_id = a.appointment_id
WHERE  rx.prescription_id IS NULL
ORDER  BY a.appointment_date;

-- ---------------------------------------------------------------------
-- Q4  COMMON TABLE EXPRESSION (CTE)
-- Question: Which patients have an open urgent follow-up, and when is it due?
-- Expected: Daniel Reed (due 2026-11-02 and 2026-11-23) and Grace Adeyemi (due 2026-11-11).
-- Why it is correct: the CTE first picks only follow-ups that are Urgent AND still Open.
-- The main query then walks follow-up -> appointment -> patient to name the people.
-- ---------------------------------------------------------------------
WITH open_urgent AS (
  SELECT appointment_id, due_date
  FROM   follow_up
  WHERE  priority = 'Urgent'
    AND  status   = 'Open'
)
SELECT p.patient_ref,
       p.full_name AS patient,
       ou.due_date
FROM   open_urgent ou
JOIN   appointment a ON a.appointment_id = ou.appointment_id
JOIN   patient     p ON p.patient_id     = a.patient_id
ORDER  BY ou.due_date;
