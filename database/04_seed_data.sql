-- =====================================================================
-- File: 04_seed_data.sql
-- Purpose: Demo/illustrative sample data only -- fictional farmer
--          names, illustrative crop water-requirement figures, and
--          simulated dam readings. NOT official government data and
--          NOT real personal information. Run AFTER 03_constraints_indexes.sql.
-- =====================================================================

USE mettur_dam_irrigation;

-- ---------------------------------------------------------------------
-- Crops (5) -- water_requirement_per_acre is an ILLUSTRATIVE academic
-- figure in litres/acre for the whole crop cycle, not an official
-- Tamil Nadu Water Resources Department allocation.
-- ---------------------------------------------------------------------
INSERT INTO Crops (crop_name, water_requirement_per_acre, crop_duration_days, season) VALUES
('Paddy',      5000.00, 120, 'KHARIF'),
('Sugarcane',  8000.00, 300, 'YEAR_ROUND'),
('Cotton',     3000.00, 180, 'KHARIF'),
('Banana',     6000.00, 300, 'YEAR_ROUND'),
('Groundnut',  2500.00, 110, 'RABI');

-- ---------------------------------------------------------------------
-- Canals (5)
-- ---------------------------------------------------------------------
INSERT INTO Canals (canal_name, capacity_litres_per_hour, source, destination, status) VALUES
('Main Canal', 500000.00, 'Mettur Dam Reservoir', 'Distribution Hub', 'ACTIVE'),
('Canal C1',   150000.00, 'Main Canal', 'Salem Sector',    'ACTIVE'),
('Canal C2',   120000.00, 'Main Canal', 'Erode Sector',    'ACTIVE'),
('Canal C3',   100000.00, 'Main Canal', 'Namakkal Sector', 'ACTIVE'),
('Canal C4',    90000.00, 'Main Canal', 'Karur Sector',    'MAINTENANCE');

-- ---------------------------------------------------------------------
-- Dam_Status (10 historical readings -- DEMO DATA, not live telemetry)
-- ---------------------------------------------------------------------
INSERT INTO Dam_Status (water_level, available_water, release_rate, recorded_at) VALUES
(122.40, 48000000.00, 30000.00, '2026-08-01 08:00:00'),
(121.80, 47200000.00, 30500.00, '2026-08-02 08:00:00'),
(121.10, 46500000.00, 31000.00, '2026-08-03 08:00:00'),
(120.50, 45800000.00, 31200.00, '2026-08-04 08:00:00'),
(119.90, 45100000.00, 31500.00, '2026-08-05 08:00:00'),
(119.20, 44300000.00, 32000.00, '2026-08-06 08:00:00'),
(118.60, 43600000.00, 32200.00, '2026-08-07 08:00:00'),
(118.00, 42900000.00, 32500.00, '2026-08-08 08:00:00'),
(117.50, 42300000.00, 32800.00, '2026-08-09 08:00:00'),
(117.00, 41800000.00, 33000.00, '2026-08-10 08:00:00');

-- ---------------------------------------------------------------------
-- Farmers (15) -- fictional names for demonstration only
-- ---------------------------------------------------------------------
INSERT INTO Farmers (name, phone, village, registration_date, status) VALUES
('Murugan S',      '9800000001', 'Kolathur',     '2025-01-10', 'ACTIVE'),
('Lakshmi R',       '9800000002', 'Anaikarai',    '2025-01-12', 'ACTIVE'),
('Karthik V',        '9800000003', 'Bhavani',      '2025-01-15', 'ACTIVE'),
('Priya N',           '9800000004', 'Kodumudi',     '2025-01-20', 'ACTIVE'),
('Ramasamy K',         '9800000005', 'Suriyampalayam','2025-02-01','ACTIVE'),
('Selvi T',             '9800000006', 'Bhavanisagar', '2025-02-05', 'ACTIVE'),
('Dhanapal M',           '9800000007', 'Ammapettai',   '2025-02-10', 'ACTIVE'),
('Kavitha S',             '9800000008', 'Vellakoil',    '2025-02-15', 'ACTIVE'),
('Elumalai P',             '9800000009', 'Sankari',      '2025-02-18', 'ACTIVE'),
('Meena R',                 '9800000010', 'Mettur',       '2025-03-01', 'ACTIVE'),
('Rajendran C',              '9800000011', 'Omalur',       '2025-03-05', 'ACTIVE'),
('Saraswathi K',              '9800000012', 'Namakkal',     '2025-03-08', 'ACTIVE'),
('Balamurugan D',              '9800000013', 'Rasipuram',    '2025-03-12', 'ACTIVE'),
('Vasanthi J',                  '9800000014', 'Karur',        '2025-03-18', 'ACTIVE'),
('Sundaram L',                    '9800000015', 'Kulithalai',   '2025-03-22', 'INACTIVE');

-- ---------------------------------------------------------------------
-- Land_Parcels (15, one per farmer) -- soil types and locations are
-- illustrative examples.
-- ---------------------------------------------------------------------
INSERT INTO Land_Parcels (farmer_id, crop_id, area_acres, location, soil_type, status) VALUES
(1,  1, 3.50, 'Kolathur North Block',      'Clay Loam',   'ACTIVE'),
(2,  2, 2.00, 'Anaikarai Riverside',       'Alluvial',    'ACTIVE'),
(3,  3, 4.00, 'Bhavani West Field',        'Red Soil',    'ACTIVE'),
(4,  4, 1.50, 'Kodumudi Plot 4',           'Black Soil',  'ACTIVE'),
(5,  5, 2.50, 'Suriyampalayam East',       'Sandy Loam',  'ACTIVE'),
(6,  1, 3.00, 'Bhavanisagar Block B',      'Clay Loam',   'ACTIVE'),
(7,  2, 3.00, 'Ammapettai Canal Side',     'Alluvial',    'ACTIVE'),
(8,  3, 2.00, 'Vellakoil Plot 2',          'Red Soil',    'ACTIVE'),
(9,  4, 2.70, 'Sankari South Field',       'Black Soil',  'ACTIVE'),
(10, 5, 2.00, 'Mettur Reservoir Side',     'Sandy Loam',  'ACTIVE'),
(11, 1, 2.00, 'Omalur Block C',            'Clay Loam',   'ACTIVE'),
(12, 2, 3.00, 'Namakkal North Plot',       'Alluvial',    'ACTIVE'),
(13, 3, 2.00, 'Rasipuram West Field',      'Red Soil',    'ACTIVE'),
(14, 4, 2.65, 'Karur Plot 7',              'Black Soil',  'ACTIVE'),
(15, 5, 2.00, 'Kulithalai Plot 1',         'Sandy Loam',  'FALLOW');

-- ---------------------------------------------------------------------
-- Water_Schedules (20) -- times are deliberately non-overlapping per
-- canal EXCEPT where noted; SLOT CONFLICT is demonstrated live via the
-- API/stored procedure in 08_sample_transactions.sql and the test
-- cases, not baked into this seed data.
-- ---------------------------------------------------------------------
INSERT INTO Water_Schedules (farmer_id, parcel_id, canal_id, start_time, end_time, requested_water, approved_water, status, created_at) VALUES
(1,  1,  3, '2026-08-05 06:00:00', '2026-08-05 08:00:00', 10000.00, 10000.00, 'COMPLETED', '2026-08-04 10:00:00'),
(2,  2,  3, '2026-08-05 08:00:00', '2026-08-05 10:00:00', 16000.00, 16000.00, 'COMPLETED', '2026-08-04 10:05:00'),
(3,  3,  3, '2026-08-05 10:00:00', '2026-08-05 12:00:00',  6000.00,  6000.00, 'COMPLETED', '2026-08-04 10:10:00'),
(4,  4,  4, '2026-08-05 06:00:00', '2026-08-05 09:00:00', 24000.00, 24000.00, 'COMPLETED', '2026-08-04 11:00:00'),
(5,  5,  4, '2026-08-05 09:00:00', '2026-08-05 11:00:00',  5000.00,  5000.00, 'COMPLETED', '2026-08-04 11:05:00'),
(6,  6,  2, '2026-08-06 06:00:00', '2026-08-06 08:00:00', 15000.00, 15000.00, 'COMPLETED', '2026-08-05 09:00:00'),
(7,  7,  2, '2026-08-06 08:00:00', '2026-08-06 10:00:00', 24000.00, 24000.00, 'COMPLETED', '2026-08-05 09:05:00'),
(8,  8,  3, '2026-08-06 06:00:00', '2026-08-06 08:00:00',  6000.00,  6000.00, 'COMPLETED', '2026-08-05 09:10:00'),
(9,  9,  3, '2026-08-06 08:00:00', '2026-08-06 10:00:00', 16000.00, 16000.00, 'COMPLETED', '2026-08-05 09:15:00'),
(10, 10, 4, '2026-08-06 06:00:00', '2026-08-06 08:00:00',  5000.00,  5000.00, 'COMPLETED', '2026-08-05 09:20:00'),
(11, 11, 4, '2026-08-07 06:00:00', '2026-08-07 09:00:00', 15000.00, 15000.00, 'APPROVED',  '2026-08-06 08:00:00'),
(12, 12, 2, '2026-08-07 06:00:00', '2026-08-07 08:00:00', 24000.00, 24000.00, 'APPROVED',  '2026-08-06 08:05:00'),
(13, 13, 3, '2026-08-07 06:00:00', '2026-08-07 08:00:00',  6000.00,  6000.00, 'APPROVED',  '2026-08-06 08:10:00'),
(14, 14, 3, '2026-08-07 08:00:00', '2026-08-07 10:00:00', 16000.00, 16000.00, 'APPROVED',  '2026-08-06 08:15:00'),
(11, 11, 4, '2026-08-07 09:00:00', '2026-08-07 11:00:00',  5000.00,  5000.00, 'APPROVED',  '2026-08-06 08:20:00'),
(1,  1,  2, '2026-08-10 06:00:00', '2026-08-10 08:00:00', 10000.00, NULL,     'PENDING',   '2026-08-09 07:00:00'),
(3,  3,  3, '2026-08-10 06:00:00', '2026-08-10 08:00:00',  6000.00, NULL,     'PENDING',   '2026-08-09 07:05:00'),
(5,  5,  4, '2026-08-10 06:00:00', '2026-08-10 08:00:00',  5000.00, NULL,     'PENDING',   '2026-08-09 07:10:00'),
(7,  7,  2, '2026-08-11 06:00:00', '2026-08-11 08:00:00', 50000.00, NULL,     'REJECTED',  '2026-08-10 07:00:00'),
(9,  9,  3, '2026-08-11 06:00:00', '2026-08-11 08:00:00', 16000.00, NULL,     'CANCELLED', '2026-08-10 07:05:00');

-- ---------------------------------------------------------------------
-- Water_Usage (20) -- multiple readings for schedules 1-5 (morning +
-- evening meter reads), single readings for schedules 6-15.
-- ---------------------------------------------------------------------
INSERT INTO Water_Usage (schedule_id, measured_water, recorded_at, meter_reading, remarks) VALUES
(1,  5200.00, '2026-08-05 07:00:00', 105200.00, 'Morning reading'),
(1,  4600.00, '2026-08-05 08:00:00', 109800.00, 'Evening reading'),
(2,  8200.00, '2026-08-05 09:00:00', 118000.00, 'Morning reading'),
(2,  7900.00, '2026-08-05 10:00:00', 125900.00, 'Evening reading'),
(3,  3100.00, '2026-08-05 11:00:00', 129000.00, 'Morning reading'),
(3,  2850.00, '2026-08-05 12:00:00', 131850.00, 'Evening reading'),
(4, 12500.00, '2026-08-05 07:30:00', 144350.00, 'Morning reading'),
(4, 11800.00, '2026-08-05 09:00:00', 156150.00, 'Evening reading'),
(5,  2600.00, '2026-08-05 10:00:00', 158750.00, 'Morning reading'),
(5,  2300.00, '2026-08-05 11:00:00', 161050.00, 'Evening reading'),
(6, 14700.00, '2026-08-06 08:00:00', 175750.00, 'Meter check'),
(7, 24500.00, '2026-08-06 10:00:00', 200250.00, 'Meter check'),
(8,  5900.00, '2026-08-06 08:00:00', 206150.00, 'Meter check'),
(9, 16200.00, '2026-08-06 10:00:00', 222350.00, 'Meter check'),
(10, 4950.00, '2026-08-06 08:00:00', 227300.00, 'Meter check'),
(11,15100.00, '2026-08-07 09:00:00', 242400.00, 'Meter check'),
(12,23800.00, '2026-08-07 08:00:00', 266200.00, 'Meter check'),
(13, 6100.00, '2026-08-07 08:00:00', 272300.00, 'Meter check'),
(14,15950.00, '2026-08-07 10:00:00', 288250.00, 'Meter check'),
(15, 5050.00, '2026-08-07 11:00:00', 293300.00, 'Meter check');

-- ---------------------------------------------------------------------
-- Bills -- normally auto-created/updated by trg_after_usage_insert as
-- Water_Usage rows are inserted. They are re-inserted explicitly here
-- ONLY because bulk seed inserts above do not fire per-row session
-- context the same way a live application would; running this section
-- keeps the seed data self-consistent even if triggers are disabled.
-- The trigger still fires normally for all usage recorded via the API.
-- ---------------------------------------------------------------------
INSERT INTO Bills (farmer_id, schedule_id, water_used, rate_per_1000_litres, total_amount, bill_date, due_date, status) VALUES
(1,  1,  9800.00, 5.00,  49.00, '2026-08-05', '2026-08-20', 'PAID'),
(2,  2, 16100.00, 5.00,  80.50, '2026-08-05', '2026-08-20', 'PAID'),
(3,  3,  5950.00, 5.00,  29.75, '2026-08-05', '2026-08-20', 'UNPAID'),
(4,  4, 24300.00, 5.00, 121.50, '2026-08-05', '2026-08-20', 'PAID'),
(5,  5,  4900.00, 5.00,  24.50, '2026-08-05', '2026-08-20', 'UNPAID'),
(6,  6, 14700.00, 5.00,  73.50, '2026-08-06', '2026-08-21', 'PAID'),
(7,  7, 24500.00, 5.00, 122.50, '2026-08-06', '2026-08-21', 'UNPAID'),
(8,  8,  5900.00, 5.00,  29.50, '2026-08-06', '2026-08-21', 'PAID'),
(9,  9, 16200.00, 5.00,  81.00, '2026-08-06', '2026-08-21', 'UNPAID'),
(10, 10, 4950.00, 5.00,  24.75, '2026-08-06', '2026-08-21', 'PAID'),
(11, 11,15100.00, 5.00,  75.50, '2026-08-07', '2026-08-22', 'UNPAID'),
(12, 12,23800.00, 5.00, 119.00, '2026-08-07', '2026-07-25', 'OVERDUE'),
(13, 13, 6100.00, 5.00,  30.50, '2026-08-07', '2026-08-22', 'UNPAID'),
(14, 14,15950.00, 5.00,  79.75, '2026-08-07', '2026-08-22', 'PAID'),
(11, 15, 5050.00, 5.00,  25.25, '2026-08-07', '2026-07-25', 'OVERDUE');

-- ---------------------------------------------------------------------
-- Payments (15)
-- ---------------------------------------------------------------------
INSERT INTO Payments (bill_id, farmer_id, amount_paid, payment_date, payment_mode, status) VALUES
(1,  1,  49.00, '2026-08-06', 'CASH',   'SUCCESS'),
(2,  2,  80.50, '2026-08-06', 'UPI',    'SUCCESS'),
(4,  4, 121.50, '2026-08-06', 'UPI',    'SUCCESS'),
(6,  6,  73.50, '2026-08-07', 'CASH',   'SUCCESS'),
(8,  8,  29.50, '2026-08-07', 'CASH',   'SUCCESS'),
(10, 10, 24.75, '2026-08-07', 'UPI',    'SUCCESS'),
(14, 14, 79.75, '2026-08-08', 'CASH',   'SUCCESS'),
(3,  3,  15.00, '2026-08-08', 'CASH',   'SUCCESS'),
(5,  5,  10.00, '2026-08-08', 'CASH',   'SUCCESS'),
(7,  7,  50.00, '2026-08-09', 'UPI',    'SUCCESS'),
(9,  9,  30.00, '2026-08-09', 'CASH',   'SUCCESS'),
(11, 11, 40.00, '2026-08-09', 'CASH',   'SUCCESS'),
(12, 12,119.00, '2026-08-10', 'CASH',   'FAILED'),
(13, 13, 10.00, '2026-08-10', 'CASH',   'SUCCESS'),
(15, 11,  5.00, '2026-08-10', 'CASH',   'SUCCESS');

-- ---------------------------------------------------------------------
-- Complaints (10)
-- ---------------------------------------------------------------------
INSERT INTO Complaints (farmer_id, schedule_id, complaint_type, description, status, created_at, resolved_at) VALUES
(3,  3,  'INSUFFICIENT_WATER',  'Water flow was lower than the approved amount on Canal C2.', 'RESOLVED',    '2026-08-05 13:00:00', '2026-08-06 10:00:00'),
(7,  7,  'CANAL_BLOCKAGE',      'Debris blocking Canal C1 near the Ammapettai junction.',      'IN_PROGRESS', '2026-08-06 11:00:00', NULL),
(9,  9,  'INCORRECT_BILLING',   'Bill amount does not match the measured usage.',               'OPEN',        '2026-08-07 09:00:00', NULL),
(12, 12, 'SCHEDULE_ISSUE',      'Requested slot was approved but never opened on time.',        'OPEN',        '2026-08-07 15:00:00', NULL),
(1,  NULL,'WATER_NOT_RECEIVED', 'No water received at parcel despite an approved schedule.',    'RESOLVED',    '2026-08-08 08:00:00', '2026-08-09 12:00:00'),
(5,  5,  'INSUFFICIENT_WATER',  'Actual water delivered was noticeably less than requested.',   'REJECTED',    '2026-08-08 10:00:00', '2026-08-09 09:00:00'),
(14, 14, 'OTHER',               'Request to shift future slots to early morning.',              'OPEN',        '2026-08-09 07:00:00', NULL),
(6,  6,  'INCORRECT_BILLING',   'Rate applied seems higher than the standard rate.',            'IN_PROGRESS', '2026-08-09 14:00:00', NULL),
(11, 11, 'SCHEDULE_ISSUE',      'Overlapping request was rejected but reason was unclear.',     'RESOLVED',    '2026-08-10 08:00:00', '2026-08-10 17:00:00'),
(2,  2,  'CANAL_BLOCKAGE',      'Minor silt buildup observed near Canal C1 outlet.',            'OPEN',        '2026-08-10 16:00:00', NULL);
