-- =====================================================================
-- File: 05_views.sql
-- Purpose: Reusable SQL views used by both the reports and the Flask
--          API layer. Run AFTER 04_seed_data.sql.
-- =====================================================================

USE mettur_dam_irrigation;

-- View 1: vw_farmer_water_requirement
-- Farmer + land + crop + area + calculated required water (KILLER
-- FEATURE 2), computed dynamically from Land_Parcels x Crops.
CREATE OR REPLACE VIEW vw_farmer_water_requirement AS
SELECT
    f.farmer_id,
    f.name AS farmer_name,
    lp.parcel_id,
    lp.location,
    c.crop_name,
    lp.area_acres,
    c.water_requirement_per_acre,
    ROUND(lp.area_acres * c.water_requirement_per_acre, 2) AS required_water_litres
FROM Land_Parcels lp
JOIN Farmers f ON f.farmer_id = lp.farmer_id
JOIN Crops   c ON c.crop_id   = lp.crop_id;

-- View 2: vw_schedule_details
-- Farmer + crop + canal + timing + requested/approved water + status
-- for every water schedule, joined across 4 tables.
CREATE OR REPLACE VIEW vw_schedule_details AS
SELECT
    ws.schedule_id,
    f.name AS farmer_name,
    c.crop_name,
    cn.canal_name,
    ws.start_time,
    ws.end_time,
    ws.requested_water,
    ws.approved_water,
    ws.status
FROM Water_Schedules ws
JOIN Farmers      f  ON f.farmer_id   = ws.farmer_id
JOIN Land_Parcels lp ON lp.parcel_id  = ws.parcel_id
JOIN Crops        c  ON c.crop_id     = lp.crop_id
JOIN Canals       cn ON cn.canal_id   = ws.canal_id;

-- View 3: vw_billing_report
-- Farmer + water used + rate + amount + payment status, with total
-- successfully paid amount aggregated from Payments.
CREATE OR REPLACE VIEW vw_billing_report AS
SELECT
    b.bill_id,
    b.farmer_id,
    f.name AS farmer_name,
    b.schedule_id,
    b.water_used,
    b.rate_per_1000_litres,
    b.total_amount,
    b.bill_date,
    b.due_date,
    b.status AS bill_status,
    COALESCE(SUM(p.amount_paid), 0) AS amount_paid
FROM Bills b
JOIN Farmers f ON f.farmer_id = b.farmer_id
LEFT JOIN Payments p ON p.bill_id = b.bill_id AND p.status = 'SUCCESS'
GROUP BY b.bill_id, b.farmer_id, f.name, b.schedule_id, b.water_used,
         b.rate_per_1000_litres, b.total_amount, b.bill_date, b.due_date, b.status;

-- View 4 (bonus): vw_canal_utilization
-- Total schedules and total allocated litres per canal, used by the
-- Canal page's utilization indicator and the canal-utilization report.
CREATE OR REPLACE VIEW vw_canal_utilization AS
SELECT
    cn.canal_id,
    cn.canal_name,
    cn.capacity_litres_per_hour,
    cn.status,
    COUNT(ws.schedule_id) AS total_schedules,
    COALESCE(SUM(CASE WHEN ws.status IN ('APPROVED','COMPLETED') THEN ws.approved_water ELSE 0 END), 0) AS total_allocated_litres
FROM Canals cn
LEFT JOIN Water_Schedules ws ON ws.canal_id = cn.canal_id
GROUP BY cn.canal_id, cn.canal_name, cn.capacity_litres_per_hour, cn.status;
