-- =====================================================================
-- File: 07_triggers.sql
-- Purpose: Two triggers.
--   1. trg_after_usage_insert -- automatic billing when usage is
--      recorded (fires on Water_Usage, writes to Bills: no recursion).
--   2. trg_schedule_status_update -- when a schedule becomes COMPLETED,
--      finalize the due date on its bill if one already exists (fires
--      on Water_Schedules, writes to Bills: no recursion back onto
--      Water_Schedules, so it cannot re-trigger itself).
-- Run AFTER 06_stored_procedures.sql.
-- =====================================================================

USE mettur_dam_irrigation;

DROP TRIGGER IF EXISTS trg_after_usage_insert;
DROP TRIGGER IF EXISTS trg_schedule_status_update;

DELIMITER $$

-- -----------------------------------------------------------------------
-- Trigger 1: automatic billing.
-- Every time a Water_Usage row is inserted, recompute the TOTAL
-- measured water for that schedule (a schedule can have several usage
-- readings) and create or update the matching bill. Uses
-- INSERT ... ON DUPLICATE KEY UPDATE against the UNIQUE(schedule_id)
-- constraint on Bills, so it is safe to call repeatedly.
-- -----------------------------------------------------------------------
CREATE TRIGGER trg_after_usage_insert
AFTER INSERT ON Water_Usage
FOR EACH ROW
BEGIN
    DECLARE v_farmer_id   INT;
    DECLARE v_total_used  DECIMAL(12,2);
    DECLARE v_rate        DECIMAL(8,2) DEFAULT 5.00;
    DECLARE v_amount      DECIMAL(10,2);

    SELECT farmer_id INTO v_farmer_id
    FROM Water_Schedules
    WHERE schedule_id = NEW.schedule_id;

    SELECT COALESCE(SUM(measured_water), 0) INTO v_total_used
    FROM Water_Usage
    WHERE schedule_id = NEW.schedule_id;

    SET v_amount = ROUND((v_total_used / 1000) * v_rate, 2);

    INSERT INTO Bills (farmer_id, schedule_id, water_used, rate_per_1000_litres, total_amount, bill_date, due_date, status)
    VALUES (v_farmer_id, NEW.schedule_id, v_total_used, v_rate, v_amount, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 15 DAY), 'UNPAID')
    ON DUPLICATE KEY UPDATE
        water_used    = v_total_used,
        total_amount  = v_amount;
END$$

-- -----------------------------------------------------------------------
-- Trigger 2: schedule-completion workflow.
-- When a schedule's status changes TO 'COMPLETED', finalize the due
-- date on its bill (if a bill already exists) to 15 days from today,
-- so the payment clock only truly starts once irrigation is confirmed
-- complete. This UPDATEs Bills, never Water_Schedules, so it cannot
-- recursively re-fire itself.
-- -----------------------------------------------------------------------
CREATE TRIGGER trg_schedule_status_update
AFTER UPDATE ON Water_Schedules
FOR EACH ROW
BEGIN
    IF NEW.status = 'COMPLETED' AND OLD.status <> 'COMPLETED' THEN
        UPDATE Bills
           SET due_date = DATE_ADD(CURDATE(), INTERVAL 15 DAY)
         WHERE schedule_id = NEW.schedule_id
           AND status = 'UNPAID';
    END IF;
END$$

DELIMITER ;
