-- =====================================================================
-- File: 02_create_tables.sql
-- Purpose: Create all 10 core tables with primary keys, foreign keys,
--          NOT NULL and UNIQUE constraints. CHECK constraints and
--          indexes are added separately in 03_constraints_indexes.sql.
-- Run AFTER 01_create_database.sql.
-- =====================================================================

USE mettur_dam_irrigation;

-- ---------------------------------------------------------------------
-- 1. Farmers
-- Why: every land parcel, schedule, bill, payment and complaint
-- belongs to a farmer -- the root entity of the whole system.
-- ---------------------------------------------------------------------
CREATE TABLE Farmers (
    farmer_id           INT AUTO_INCREMENT PRIMARY KEY,
    name                 VARCHAR(100) NOT NULL,
    phone                VARCHAR(15) NOT NULL UNIQUE,
    village              VARCHAR(100) NOT NULL,
    registration_date    DATE NOT NULL DEFAULT (CURRENT_DATE),
    status               VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
);

-- ---------------------------------------------------------------------
-- 2. Crops
-- Why: crop-specific water requirement drives KILLER FEATURE 2
-- (crop-based water requirement calculation).
-- ---------------------------------------------------------------------
CREATE TABLE Crops (
    crop_id                     INT AUTO_INCREMENT PRIMARY KEY,
    crop_name                   VARCHAR(50) NOT NULL UNIQUE,
    water_requirement_per_acre  DECIMAL(10,2) NOT NULL,
    crop_duration_days          INT NOT NULL,
    season                      VARCHAR(20) NOT NULL
);

-- ---------------------------------------------------------------------
-- 3. Canals
-- Why: canals are the physical resource time-shared between farmers;
-- capacity here drives conflict detection and capacity checks.
-- ---------------------------------------------------------------------
CREATE TABLE Canals (
    canal_id                    INT AUTO_INCREMENT PRIMARY KEY,
    canal_name                  VARCHAR(50) NOT NULL UNIQUE,
    capacity_litres_per_hour    DECIMAL(12,2) NOT NULL,
    source                      VARCHAR(100) NOT NULL,
    destination                 VARCHAR(100) NOT NULL,
    status                      VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
);

-- ---------------------------------------------------------------------
-- 4. Dam_Status
-- Why: stores HISTORICAL dam readings (not a single row) so the
-- dashboard can chart trends and approvals always check the latest
-- available water.
-- ---------------------------------------------------------------------
CREATE TABLE Dam_Status (
    status_id        INT AUTO_INCREMENT PRIMARY KEY,
    water_level       DECIMAL(6,2) NOT NULL,
    available_water   DECIMAL(14,2) NOT NULL,
    release_rate      DECIMAL(12,2) NOT NULL,
    recorded_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- 5. Land_Parcels
-- Why: links a farmer to the land they farm and the crop grown there;
-- this is what water requirement is calculated from.
-- Relationship: Farmers 1--N Land_Parcels, Crops 1--N Land_Parcels.
-- ---------------------------------------------------------------------
CREATE TABLE Land_Parcels (
    parcel_id    INT AUTO_INCREMENT PRIMARY KEY,
    farmer_id    INT NOT NULL,
    crop_id      INT NOT NULL,
    area_acres   DECIMAL(8,2) NOT NULL,
    location     VARCHAR(150) NOT NULL,
    soil_type    VARCHAR(50) NOT NULL,
    status       VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT fk_parcel_farmer FOREIGN KEY (farmer_id) REFERENCES Farmers(farmer_id) ON DELETE CASCADE,
    CONSTRAINT fk_parcel_crop   FOREIGN KEY (crop_id)   REFERENCES Crops(crop_id)     ON DELETE RESTRICT
);

-- ---------------------------------------------------------------------
-- 6. Water_Schedules
-- Why: the central booking table -- every water request/allocation on
-- a canal, for a farmer's parcel, is one row here. Conflict detection
-- and approval logic apply here.
-- ---------------------------------------------------------------------
CREATE TABLE Water_Schedules (
    schedule_id       INT AUTO_INCREMENT PRIMARY KEY,
    farmer_id         INT NOT NULL,
    parcel_id         INT NOT NULL,
    canal_id          INT NOT NULL,
    start_time        DATETIME NOT NULL,
    end_time          DATETIME NOT NULL,
    requested_water   DECIMAL(12,2) NOT NULL,
    approved_water    DECIMAL(12,2) NULL,
    status            VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_schedule_farmer FOREIGN KEY (farmer_id) REFERENCES Farmers(farmer_id)         ON DELETE CASCADE,
    CONSTRAINT fk_schedule_parcel FOREIGN KEY (parcel_id) REFERENCES Land_Parcels(parcel_id)     ON DELETE CASCADE,
    CONSTRAINT fk_schedule_canal  FOREIGN KEY (canal_id)  REFERENCES Canals(canal_id)            ON DELETE RESTRICT
);

-- ---------------------------------------------------------------------
-- 7. Water_Usage
-- Why: records what was actually measured/delivered against a
-- schedule, separate from what was requested/approved, so the system
-- can compare "scheduled vs actual" and drive automatic billing.
-- ---------------------------------------------------------------------
CREATE TABLE Water_Usage (
    usage_id         INT AUTO_INCREMENT PRIMARY KEY,
    schedule_id      INT NOT NULL,
    measured_water   DECIMAL(12,2) NOT NULL,
    recorded_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    meter_reading    DECIMAL(14,2) NULL,
    remarks          VARCHAR(255) NULL,
    CONSTRAINT fk_usage_schedule FOREIGN KEY (schedule_id) REFERENCES Water_Schedules(schedule_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- 8. Bills
-- Why: one bill per schedule, generated automatically from recorded
-- usage (see trigger and sp_generate_bill). uq_bill_schedule enforces
-- "one bill per schedule" and lets the trigger use
-- INSERT ... ON DUPLICATE KEY UPDATE safely.
-- ---------------------------------------------------------------------
CREATE TABLE Bills (
    bill_id                INT AUTO_INCREMENT PRIMARY KEY,
    farmer_id              INT NOT NULL,
    schedule_id            INT NOT NULL,
    water_used             DECIMAL(12,2) NOT NULL,
    rate_per_1000_litres   DECIMAL(8,2) NOT NULL DEFAULT 5.00,
    total_amount           DECIMAL(10,2) NOT NULL,
    bill_date              DATE NOT NULL DEFAULT (CURRENT_DATE),
    due_date               DATE NOT NULL,
    status                 VARCHAR(20) NOT NULL DEFAULT 'UNPAID',
    CONSTRAINT fk_bill_farmer   FOREIGN KEY (farmer_id)   REFERENCES Farmers(farmer_id)         ON DELETE CASCADE,
    CONSTRAINT fk_bill_schedule FOREIGN KEY (schedule_id) REFERENCES Water_Schedules(schedule_id) ON DELETE CASCADE,
    CONSTRAINT uq_bill_schedule UNIQUE (schedule_id)
);

-- ---------------------------------------------------------------------
-- 9. Payments
-- Why: a bill can be paid in more than one installment, so payments
-- are a separate 1--N table against Bills rather than one field.
-- ---------------------------------------------------------------------
CREATE TABLE Payments (
    payment_id     INT AUTO_INCREMENT PRIMARY KEY,
    bill_id        INT NOT NULL,
    farmer_id      INT NOT NULL,
    amount_paid    DECIMAL(10,2) NOT NULL,
    payment_date   DATE NOT NULL DEFAULT (CURRENT_DATE),
    payment_mode   VARCHAR(30) NOT NULL DEFAULT 'CASH',
    status         VARCHAR(20) NOT NULL DEFAULT 'SUCCESS',
    CONSTRAINT fk_payment_bill   FOREIGN KEY (bill_id)   REFERENCES Bills(bill_id)     ON DELETE CASCADE,
    CONSTRAINT fk_payment_farmer FOREIGN KEY (farmer_id) REFERENCES Farmers(farmer_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- 10. Complaints
-- Why: farmer-raised issues (water not received, canal blockage,
-- billing errors, etc.) tracked to resolution; optionally linked to
-- the schedule the complaint is about.
-- ---------------------------------------------------------------------
CREATE TABLE Complaints (
    complaint_id     INT AUTO_INCREMENT PRIMARY KEY,
    farmer_id        INT NOT NULL,
    schedule_id      INT NULL,
    complaint_type   VARCHAR(50) NOT NULL,
    description      VARCHAR(500) NOT NULL,
    status           VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at      DATETIME NULL,
    CONSTRAINT fk_complaint_farmer   FOREIGN KEY (farmer_id)   REFERENCES Farmers(farmer_id)          ON DELETE CASCADE,
    CONSTRAINT fk_complaint_schedule FOREIGN KEY (schedule_id) REFERENCES Water_Schedules(schedule_id) ON DELETE SET NULL
);
