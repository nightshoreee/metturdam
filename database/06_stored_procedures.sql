-- =====================================================================
-- File: 06_stored_procedures.sql
-- Purpose: sp_request_water (KILLER FEATURES 1, 2, 3 combined) and
--          sp_generate_bill (KILLER FEATURE 4). Both use explicit
--          transactions with ROLLBACK on error, per the ACID
--          requirement in the project brief. Run AFTER 05_views.sql.
-- =====================================================================

USE mettur_dam_irrigation;

DROP PROCEDURE IF EXISTS sp_request_water;
DROP PROCEDURE IF EXISTS sp_generate_bill;

DELIMITER $$

-- -----------------------------------------------------------------------
-- sp_request_water
-- Validates a water request end-to-end and, if every check passes,
-- creates the schedule AND reserves the water from the dam in a single
-- transaction. If ANY check fails, nothing is written and available
-- water is left untouched.
--
-- Checks, in order: farmer exists & active -> parcel belongs to farmer
-- & active -> canal exists & active -> valid time range -> canal slot
-- conflict (interval overlap) -> canal capacity for the duration ->
-- dam water availability.
-- -----------------------------------------------------------------------
CREATE PROCEDURE sp_request_water(
    IN  p_farmer_id        INT,
    IN  p_parcel_id        INT,
    IN  p_canal_id         INT,
    IN  p_start_time       DATETIME,
    IN  p_end_time         DATETIME,
    IN  p_requested_water  DECIMAL(12,2),
    OUT p_status           VARCHAR(20),
    OUT p_message          VARCHAR(255),
    OUT p_schedule_id      INT
)
proc_block: BEGIN
    DECLARE v_farmer_status     VARCHAR(20);
    DECLARE v_parcel_farmer     INT;
    DECLARE v_parcel_status     VARCHAR(20);
    DECLARE v_canal_status      VARCHAR(20);
    DECLARE v_canal_capacity    DECIMAL(12,2);
    DECLARE v_conflict_count    INT;
    DECLARE v_available_water   DECIMAL(14,2);
    DECLARE v_duration_hours    DECIMAL(10,2);
    DECLARE v_capacity_available DECIMAL(14,2);
    DECLARE v_latest_level      DECIMAL(6,2);
    DECLARE v_latest_release    DECIMAL(12,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status = 'ERROR';
        SET p_message = 'An unexpected database error occurred. No schedule was created.';
        SET p_schedule_id = NULL;
    END;

    SET p_schedule_id = NULL;

    -- 1. Time range
    IF p_end_time <= p_start_time THEN
        SET p_status = 'REJECTED';
        SET p_message = 'Invalid time range: end time must be after start time.';
        LEAVE proc_block;
    END IF;

    -- 2. Farmer
    SELECT status INTO v_farmer_status FROM Farmers WHERE farmer_id = p_farmer_id;
    IF v_farmer_status IS NULL THEN
        SET p_status = 'REJECTED'; SET p_message = 'Farmer does not exist.'; LEAVE proc_block;
    ELSEIF v_farmer_status <> 'ACTIVE' THEN
        SET p_status = 'REJECTED'; SET p_message = 'Farmer account is not active.'; LEAVE proc_block;
    END IF;

    -- 3. Parcel ownership
    SELECT farmer_id, status INTO v_parcel_farmer, v_parcel_status
    FROM Land_Parcels WHERE parcel_id = p_parcel_id;
    IF v_parcel_farmer IS NULL THEN
        SET p_status = 'REJECTED'; SET p_message = 'Land parcel does not exist.'; LEAVE proc_block;
    ELSEIF v_parcel_farmer <> p_farmer_id THEN
        SET p_status = 'REJECTED'; SET p_message = 'This land parcel does not belong to the specified farmer.'; LEAVE proc_block;
    ELSEIF v_parcel_status <> 'ACTIVE' THEN
        SET p_status = 'REJECTED'; SET p_message = 'Land parcel is not active.'; LEAVE proc_block;
    END IF;

    -- 4. Canal
    SELECT status, capacity_litres_per_hour INTO v_canal_status, v_canal_capacity
    FROM Canals WHERE canal_id = p_canal_id;
    IF v_canal_status IS NULL THEN
        SET p_status = 'REJECTED'; SET p_message = 'Canal does not exist.'; LEAVE proc_block;
    ELSEIF v_canal_status <> 'ACTIVE' THEN
        SET p_status = 'REJECTED'; SET p_message = 'Canal is not active (inactive or under maintenance).'; LEAVE proc_block;
    END IF;

    -- 5. KILLER FEATURE 1: canal slot conflict detection.
    -- Standard interval-overlap test: existing_start < new_end AND existing_end > new_start.
    SELECT COUNT(*) INTO v_conflict_count
    FROM Water_Schedules
    WHERE canal_id = p_canal_id
      AND status IN ('PENDING','APPROVED','COMPLETED')
      AND start_time < p_end_time
      AND end_time   > p_start_time;

    IF v_conflict_count > 0 THEN
        SET p_status = 'REJECTED';
        SET p_message = 'SLOT CONFLICT: this canal is already allocated during the requested time window.';
        LEAVE proc_block;
    END IF;

    -- 6. Canal capacity for the requested duration
    SET v_duration_hours = TIMESTAMPDIFF(MINUTE, p_start_time, p_end_time) / 60.0;
    SET v_capacity_available = v_canal_capacity * v_duration_hours;
    IF p_requested_water > v_capacity_available THEN
        SET p_status = 'REJECTED';
        SET p_message = CONCAT('CANAL CAPACITY EXCEEDED: canal can deliver at most ', v_capacity_available, ' litres in this window.');
        LEAVE proc_block;
    END IF;

    -- 7. KILLER FEATURE 3: dam water availability (latest reading)
    SELECT water_level, available_water, release_rate
      INTO v_latest_level, v_available_water, v_latest_release
    FROM Dam_Status
    ORDER BY recorded_at DESC
    LIMIT 1;

    IF v_available_water IS NULL OR p_requested_water > v_available_water THEN
        SET p_status = 'REJECTED';
        SET p_message = 'INSUFFICIENT DAM WATER: not enough water currently available at the dam.';
        LEAVE proc_block;
    END IF;

    -- All checks passed: create the schedule AND reserve the water
    -- atomically. If the second insert fails, the EXIT HANDLER rolls
    -- back the first one too, so available water is never reduced
    -- without a matching approved schedule (and vice versa).
    START TRANSACTION;

    INSERT INTO Water_Schedules
        (farmer_id, parcel_id, canal_id, start_time, end_time, requested_water, approved_water, status)
    VALUES
        (p_farmer_id, p_parcel_id, p_canal_id, p_start_time, p_end_time, p_requested_water, p_requested_water, 'APPROVED');

    SET p_schedule_id = LAST_INSERT_ID();

    INSERT INTO Dam_Status (water_level, available_water, release_rate, recorded_at)
    VALUES (v_latest_level, v_available_water - p_requested_water, v_latest_release, NOW());

    COMMIT;

    SET p_status = 'APPROVED';
    SET p_message = 'Water request approved and scheduled successfully.';
END$$


-- -----------------------------------------------------------------------
-- sp_generate_bill
-- KILLER FEATURE 4: computes water_used x rate for a schedule from its
-- recorded Water_Usage rows and creates/updates the corresponding
-- Bill. This is the same computation the trg_after_usage_insert
-- trigger performs automatically; this procedure lets it also be
-- triggered manually/on demand (e.g. re-billing after a correction).
-- -----------------------------------------------------------------------
CREATE PROCEDURE sp_generate_bill(
    IN  p_schedule_id INT,
    OUT p_bill_id     INT,
    OUT p_message     VARCHAR(255)
)
proc_block: BEGIN
    DECLARE v_farmer_id   INT;
    DECLARE v_total_used  DECIMAL(12,2);
    DECLARE v_rate        DECIMAL(8,2) DEFAULT 5.00;
    DECLARE v_amount      DECIMAL(10,2);
    DECLARE v_exists      INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_bill_id = NULL;
        SET p_message = 'An unexpected database error occurred while generating the bill.';
    END;

    SELECT farmer_id INTO v_farmer_id FROM Water_Schedules WHERE schedule_id = p_schedule_id;
    IF v_farmer_id IS NULL THEN
        SET p_bill_id = NULL;
        SET p_message = 'Schedule does not exist.';
        LEAVE proc_block;
    END IF;

    SELECT COALESCE(SUM(measured_water), 0) INTO v_total_used
    FROM Water_Usage WHERE schedule_id = p_schedule_id;

    IF v_total_used = 0 THEN
        SET p_bill_id = NULL;
        SET p_message = 'No recorded water usage for this schedule yet; nothing to bill.';
        LEAVE proc_block;
    END IF;

    SET v_amount = ROUND((v_total_used / 1000) * v_rate, 2);

    START TRANSACTION;

    SELECT bill_id INTO v_exists FROM Bills WHERE schedule_id = p_schedule_id;

    IF v_exists IS NULL THEN
        INSERT INTO Bills (farmer_id, schedule_id, water_used, rate_per_1000_litres, total_amount, bill_date, due_date, status)
        VALUES (v_farmer_id, p_schedule_id, v_total_used, v_rate, v_amount, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 15 DAY), 'UNPAID');
        SET p_bill_id = LAST_INSERT_ID();
    ELSE
        UPDATE Bills SET water_used = v_total_used, total_amount = v_amount WHERE bill_id = v_exists;
        SET p_bill_id = v_exists;
    END IF;

    COMMIT;
    SET p_message = 'Bill generated successfully.';
END$$

DELIMITER ;
