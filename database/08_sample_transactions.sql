-- =====================================================================
-- File: 08_sample_transactions.sql
-- Purpose: Demonstrates real transactions (COMMIT / ROLLBACK) as
--          required by the project brief: the system must never
--          reduce available dam water if schedule creation fails.
--          Run AFTER 07_triggers.sql. Safe to run multiple times.
-- =====================================================================

USE mettur_dam_irrigation;

-- =====================================================================
-- Demonstration 1: a successful water request via sp_request_water.
-- The procedure wraps the schedule insert and the dam-water reservation
-- in ONE transaction (see 06_stored_procedures.sql) -- both succeed
-- together or neither is written.
-- =====================================================================
CALL sp_request_water(2, 2, 4, '2026-08-20 06:00:00', '2026-08-20 08:00:00', 8000, @status1, @message1, @schedule1);
SELECT @status1 AS status, @message1 AS message, @schedule1 AS schedule_id;

-- =====================================================================
-- Demonstration 2: a conflicting request on the same canal/time is
-- rejected and NOTHING is written -- prove it with a row-count check.
-- =====================================================================
SELECT COUNT(*) AS schedules_before FROM Water_Schedules;

CALL sp_request_water(4, 4, 4, '2026-08-20 07:00:00', '2026-08-20 09:00:00', 5000, @status2, @message2, @schedule2);
SELECT @status2 AS status, @message2 AS message;

SELECT COUNT(*) AS schedules_after FROM Water_Schedules;
-- schedules_before should equal schedules_after: the conflicting request was rejected.

-- =====================================================================
-- Demonstration 3: an explicit manual transaction with ROLLBACK.
-- This is why the reservation step above lives inside a transaction:
-- if the dam-status insert were to fail partway through, the schedule
-- insert must not be left behind on its own (that would silently
-- commit a schedule for water that was never actually reserved).
-- =====================================================================
START TRANSACTION;

INSERT INTO Water_Schedules (farmer_id, parcel_id, canal_id, start_time, end_time, requested_water, approved_water, status)
VALUES (6, 6, 3, '2026-08-21 06:00:00', '2026-08-21 07:00:00', 4000, 4000, 'APPROVED');

-- Simulate a failure discovered after the insert (e.g. a downstream
-- validation step determined the reservation must not proceed).
ROLLBACK;

-- Confirm the row was never persisted:
SELECT COUNT(*) AS should_be_zero
FROM Water_Schedules
WHERE canal_id = 3 AND start_time = '2026-08-21 06:00:00';

-- =====================================================================
-- Demonstration 4: sp_generate_bill on a schedule with recorded usage.
-- =====================================================================
CALL sp_generate_bill(6, @bill_id4, @message4);
SELECT @bill_id4 AS bill_id, @message4 AS message;
