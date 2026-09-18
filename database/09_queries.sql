-- =====================================================================
-- File: 09_queries.sql
-- Purpose: Query demonstration file for the DBMS viva -- basic,
--          intermediate and advanced SQL, plus the 10 report queries
--          also exposed via /api/reports/* in the Flask backend.
-- Run AFTER 08_sample_transactions.sql (or any time after seed data).
-- =====================================================================

USE mettur_dam_irrigation;

-- =====================================================================
-- SECTION A: BASIC QUERIES (SELECT / INSERT / UPDATE / DELETE)
-- =====================================================================

-- A1. SELECT: all active farmers
SELECT farmer_id, name, phone, village FROM Farmers WHERE status = 'ACTIVE';

-- A2. INSERT: register a new farmer
INSERT INTO Farmers (name, phone, village, status) VALUES ('Demo Farmer', '9800000099', 'Demo Village', 'ACTIVE');

-- A3. UPDATE: correct a farmer's village
UPDATE Farmers SET village = 'Updated Village' WHERE phone = '9800000099';

-- A4. DELETE: remove the demo farmer created above
DELETE FROM Farmers WHERE phone = '9800000099';

-- =====================================================================
-- SECTION B: INTERMEDIATE QUERIES (JOINs, GROUP BY, HAVING, aggregates)
-- =====================================================================

-- B1. INNER JOIN: every parcel with its farmer and crop
SELECT lp.parcel_id, f.name AS farmer, c.crop_name, lp.area_acres
FROM Land_Parcels lp
INNER JOIN Farmers f ON f.farmer_id = lp.farmer_id
INNER JOIN Crops c ON c.crop_id = lp.crop_id;

-- B2. LEFT JOIN: every canal with its schedules, including canals with none
SELECT cn.canal_name, ws.schedule_id, ws.status
FROM Canals cn
LEFT JOIN Water_Schedules ws ON ws.canal_id = cn.canal_id
ORDER BY cn.canal_name;

-- B3. GROUP BY + aggregate: total water requested per farmer
SELECT farmer_id, SUM(requested_water) AS total_requested
FROM Water_Schedules
GROUP BY farmer_id
ORDER BY total_requested DESC;

-- B4. HAVING: farmers who have requested more than 20,000 litres in total
SELECT farmer_id, SUM(requested_water) AS total_requested
FROM Water_Schedules
GROUP BY farmer_id
HAVING SUM(requested_water) > 20000
ORDER BY total_requested DESC;

-- B5. ORDER BY + aggregate: canals ranked by number of completed schedules
SELECT cn.canal_name, COUNT(*) AS completed_count
FROM Water_Schedules ws
JOIN Canals cn ON cn.canal_id = ws.canal_id
WHERE ws.status = 'COMPLETED'
GROUP BY cn.canal_name
ORDER BY completed_count DESC;

-- =====================================================================
-- SECTION C: ADVANCED QUERIES (subqueries, CASE, date filtering, multi-join)
-- =====================================================================

-- C1. Subquery: farmers who have never submitted a complaint
SELECT name, phone FROM Farmers
WHERE farmer_id NOT IN (SELECT DISTINCT farmer_id FROM Complaints);

-- C2. Correlated subquery: each farmer's most recent schedule start time
SELECT f.name,
       (SELECT MAX(ws.start_time) FROM Water_Schedules ws WHERE ws.farmer_id = f.farmer_id) AS latest_schedule
FROM Farmers f;

-- C3. CASE: classify bills by how overdue they are
SELECT bill_id, farmer_id, due_date, status,
       CASE
           WHEN status = 'PAID' THEN 'Settled'
           WHEN due_date < CURDATE() THEN 'Overdue'
           ELSE 'Within Due Date'
       END AS payment_health
FROM Bills;

-- C4. Date/time filtering: schedules starting in the next 7 days
SELECT schedule_id, farmer_id, canal_id, start_time, end_time
FROM Water_Schedules
WHERE start_time BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL 7 DAY);

-- C5. Multi-table JOIN: full picture of a bill (farmer, schedule, canal, crop)
SELECT b.bill_id, f.name AS farmer, cn.canal_name, c.crop_name, b.water_used, b.total_amount, b.status
FROM Bills b
JOIN Farmers f       ON f.farmer_id  = b.farmer_id
JOIN Water_Schedules ws ON ws.schedule_id = b.schedule_id
JOIN Canals cn        ON cn.canal_id  = ws.canal_id
JOIN Land_Parcels lp  ON lp.parcel_id = ws.parcel_id
JOIN Crops c          ON c.crop_id    = lp.crop_id;

-- =====================================================================
-- SECTION D: THE 10 REPORT QUERIES (also exposed as /api/reports/*)
-- =====================================================================

-- D1. Total water used by each farmer
SELECT f.farmer_id, f.name, COALESCE(SUM(wu.measured_water), 0) AS total_water_used
FROM Farmers f
LEFT JOIN Water_Schedules ws ON ws.farmer_id = f.farmer_id
LEFT JOIN Water_Usage wu ON wu.schedule_id = ws.schedule_id
GROUP BY f.farmer_id, f.name
ORDER BY total_water_used DESC;

-- D2. Total water used by each canal
SELECT cn.canal_id, cn.canal_name, COALESCE(SUM(wu.measured_water), 0) AS total_water_used
FROM Canals cn
LEFT JOIN Water_Schedules ws ON ws.canal_id = cn.canal_id
LEFT JOIN Water_Usage wu ON wu.schedule_id = ws.schedule_id
GROUP BY cn.canal_id, cn.canal_name
ORDER BY total_water_used DESC;

-- D3. Highest water-consuming crops
SELECT c.crop_id, c.crop_name, COALESCE(SUM(wu.measured_water), 0) AS total_water_used
FROM Crops c
JOIN Land_Parcels lp ON lp.crop_id = c.crop_id
JOIN Water_Schedules ws ON ws.parcel_id = lp.parcel_id
JOIN Water_Usage wu ON wu.schedule_id = ws.schedule_id
GROUP BY c.crop_id, c.crop_name
ORDER BY total_water_used DESC;

-- D4. Farmers with unpaid bills
SELECT f.farmer_id, f.name, f.phone, COUNT(b.bill_id) AS unpaid_bills, SUM(b.total_amount) AS total_due
FROM Farmers f
JOIN Bills b ON b.farmer_id = f.farmer_id
WHERE b.status IN ('UNPAID', 'OVERDUE')
GROUP BY f.farmer_id, f.name, f.phone
HAVING total_due > 0
ORDER BY total_due DESC;

-- D5. Daily water allocation
SELECT DATE(start_time) AS allocation_date, COUNT(*) AS schedule_count, SUM(approved_water) AS total_allocated
FROM Water_Schedules
WHERE status IN ('APPROVED', 'COMPLETED')
GROUP BY DATE(start_time)
ORDER BY allocation_date DESC;

-- D6. Canal utilization
SELECT * FROM vw_canal_utilization ORDER BY total_allocated_litres DESC;

-- D7. Water usage vs scheduled allocation
SELECT ws.schedule_id, f.name AS farmer_name, ws.approved_water AS scheduled_water,
       COALESCE(SUM(wu.measured_water), 0) AS actual_water,
       (ws.approved_water - COALESCE(SUM(wu.measured_water), 0)) AS difference
FROM Water_Schedules ws
JOIN Farmers f ON f.farmer_id = ws.farmer_id
LEFT JOIN Water_Usage wu ON wu.schedule_id = ws.schedule_id
WHERE ws.approved_water IS NOT NULL
GROUP BY ws.schedule_id, f.name, ws.approved_water
ORDER BY ws.schedule_id;

-- D8. Current dam water availability
SELECT * FROM Dam_Status ORDER BY recorded_at DESC LIMIT 1;

-- D9. Number of complaints by type
SELECT complaint_type, COUNT(*) AS total FROM Complaints GROUP BY complaint_type ORDER BY total DESC;

-- D10. Number of completed irrigation schedules
SELECT COUNT(*) AS completed_count FROM Water_Schedules WHERE status = 'COMPLETED';
