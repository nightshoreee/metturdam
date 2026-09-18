-- =====================================================================
-- File: 03_constraints_indexes.sql
-- Purpose: Add CHECK constraints (data validity) and indexes
--          (query performance) on top of the tables created in
--          02_create_tables.sql. Run AFTER 02_create_tables.sql.
-- =====================================================================

USE mettur_dam_irrigation;

-- ------------------------- CHECK constraints --------------------------
ALTER TABLE Farmers
    ADD CONSTRAINT chk_farmer_status CHECK (status IN ('ACTIVE','INACTIVE'));

ALTER TABLE Crops
    ADD CONSTRAINT chk_crop_water_positive   CHECK (water_requirement_per_acre > 0),
    ADD CONSTRAINT chk_crop_duration_positive CHECK (crop_duration_days > 0),
    ADD CONSTRAINT chk_crop_season CHECK (season IN ('KHARIF','RABI','SUMMER','YEAR_ROUND'));

ALTER TABLE Canals
    ADD CONSTRAINT chk_canal_capacity_positive CHECK (capacity_litres_per_hour > 0),
    ADD CONSTRAINT chk_canal_status CHECK (status IN ('ACTIVE','INACTIVE','MAINTENANCE'));

ALTER TABLE Dam_Status
    ADD CONSTRAINT chk_dam_level_nonneg     CHECK (water_level >= 0),
    ADD CONSTRAINT chk_dam_available_nonneg CHECK (available_water >= 0),
    ADD CONSTRAINT chk_dam_release_nonneg   CHECK (release_rate >= 0);

ALTER TABLE Land_Parcels
    ADD CONSTRAINT chk_parcel_area_positive CHECK (area_acres > 0),
    ADD CONSTRAINT chk_parcel_status CHECK (status IN ('ACTIVE','FALLOW','INACTIVE'));

ALTER TABLE Water_Schedules
    ADD CONSTRAINT chk_schedule_time_order CHECK (end_time > start_time),
    ADD CONSTRAINT chk_schedule_requested_positive CHECK (requested_water > 0),
    ADD CONSTRAINT chk_schedule_status CHECK (status IN ('PENDING','APPROVED','REJECTED','COMPLETED','CANCELLED'));

ALTER TABLE Water_Usage
    ADD CONSTRAINT chk_usage_measured_nonneg CHECK (measured_water >= 0);

ALTER TABLE Bills
    ADD CONSTRAINT chk_bill_water_used_nonneg CHECK (water_used >= 0),
    ADD CONSTRAINT chk_bill_amount_nonneg CHECK (total_amount >= 0),
    ADD CONSTRAINT chk_bill_status CHECK (status IN ('PAID','UNPAID','OVERDUE'));

ALTER TABLE Payments
    ADD CONSTRAINT chk_payment_amount_positive CHECK (amount_paid > 0),
    ADD CONSTRAINT chk_payment_status CHECK (status IN ('SUCCESS','FAILED','PENDING'));

ALTER TABLE Complaints
    ADD CONSTRAINT chk_complaint_type CHECK (
        complaint_type IN ('WATER_NOT_RECEIVED','CANAL_BLOCKAGE','INCORRECT_BILLING','SCHEDULE_ISSUE','INSUFFICIENT_WATER','OTHER')
    ),
    ADD CONSTRAINT chk_complaint_status CHECK (status IN ('OPEN','IN_PROGRESS','RESOLVED','REJECTED'));

-- ------------------------------ Indexes --------------------------------
-- Land_Parcels: farmer_id/crop_id are the most common join & filter keys
CREATE INDEX idx_parcel_farmer ON Land_Parcels(farmer_id);
CREATE INDEX idx_parcel_crop   ON Land_Parcels(crop_id);

-- Water_Schedules: canal_id + time range is scanned on EVERY booking
-- attempt for conflict detection, so it gets a composite index; farmer
-- and parcel are indexed for "my schedules" style lookups; status is
-- indexed because dashboards filter heavily by PENDING/APPROVED/etc.
CREATE INDEX idx_schedule_canal       ON Water_Schedules(canal_id);
CREATE INDEX idx_schedule_farmer      ON Water_Schedules(farmer_id);
CREATE INDEX idx_schedule_parcel      ON Water_Schedules(parcel_id);
CREATE INDEX idx_schedule_time_range  ON Water_Schedules(canal_id, start_time, end_time);
CREATE INDEX idx_schedule_status      ON Water_Schedules(status);

-- Water_Usage: every bill/usage lookup groups by schedule_id
CREATE INDEX idx_usage_schedule ON Water_Usage(schedule_id);

-- Bills: farmer lookups, status filters (UNPAID/OVERDUE reports) and
-- due-date range queries are all common
CREATE INDEX idx_bill_farmer   ON Bills(farmer_id);
CREATE INDEX idx_bill_status   ON Bills(status);
CREATE INDEX idx_bill_due_date ON Bills(due_date);

-- Payments: lookups by bill and by farmer, plus status filtering
CREATE INDEX idx_payment_bill   ON Payments(bill_id);
CREATE INDEX idx_payment_farmer ON Payments(farmer_id);
CREATE INDEX idx_payment_status ON Payments(status);

-- Complaints: farmer's complaint history and open-complaint dashboards
CREATE INDEX idx_complaint_farmer ON Complaints(farmer_id);
CREATE INDEX idx_complaint_status ON Complaints(status);

-- Dam_Status: history is always queried ordered by recorded_at
CREATE INDEX idx_dam_recorded_at ON Dam_Status(recorded_at);
