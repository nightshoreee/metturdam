# Database Design

## Entities & Attributes

| Table | Key Attributes |
|---|---|
| Farmers | farmer_id (PK), name, phone (UNIQUE), village, registration_date, status |
| Crops | crop_id (PK), crop_name (UNIQUE), water_requirement_per_acre, crop_duration_days, season |
| Canals | canal_id (PK), canal_name (UNIQUE), capacity_litres_per_hour, source, destination, status |
| Dam_Status | status_id (PK), water_level, available_water, release_rate, recorded_at |
| Land_Parcels | parcel_id (PK), farmer_id (FK), crop_id (FK), area_acres, location, soil_type, status |
| Water_Schedules | schedule_id (PK), farmer_id (FK), parcel_id (FK), canal_id (FK), start_time, end_time, requested_water, approved_water, status, created_at |
| Water_Usage | usage_id (PK), schedule_id (FK), measured_water, recorded_at, meter_reading, remarks |
| Bills | bill_id (PK), farmer_id (FK), schedule_id (FK, UNIQUE), water_used, rate_per_1000_litres, total_amount, bill_date, due_date, status |
| Payments | payment_id (PK), bill_id (FK), farmer_id (FK), amount_paid, payment_date, payment_mode, status |
| Complaints | complaint_id (PK), farmer_id (FK), schedule_id (FK, nullable), complaint_type, description, status, created_at, resolved_at |

## Cardinality / Relationships
- Farmers (1) --- (N) Land_Parcels
- Crops (1) --- (N) Land_Parcels
- Farmers (1) --- (N) Water_Schedules
- Land_Parcels (1) --- (N) Water_Schedules
- Canals (1) --- (N) Water_Schedules
- Water_Schedules (1) --- (N) Water_Usage
- Water_Schedules (1) --- (1) Bills (enforced by `UNIQUE(schedule_id)` on Bills)
- Farmers (1) --- (N) Bills
- Bills (1) --- (N) Payments
- Farmers (1) --- (N) Complaints
- Water_Schedules (1) --- (N) Complaints (a schedule can attract more than one complaint; a complaint can also stand alone with `schedule_id = NULL`)

## Normalization
The schema is designed directly to Third Normal Form (3NF):

- **1NF:** every column holds a single atomic value (no repeating groups
  -- e.g. a farmer's multiple parcels are separate rows in Land_Parcels,
  not a comma-separated list in Farmers).
- **2NF:** every table has a single-column surrogate primary key
  (`..._id`), so there are no partial-key dependencies to worry about.
- **3NF:** no non-key attribute depends on another non-key attribute.
  For example, `Water_Schedules` does NOT store `farmer_name` or
  `crop_name` directly -- those are transitive dependencies reachable
  through `farmer_id` / `parcel_id -> crop_id`. Anywhere that combined,
  human-readable view is needed (e.g. "farmer name on a schedule row"),
  it is produced by a JOIN or a VIEW (see `vw_schedule_details`), not by
  duplicating data into the base table.

## Functional Dependencies (examples)
- `farmer_id -> name, phone, village, registration_date, status`
- `crop_id -> crop_name, water_requirement_per_acre, crop_duration_days, season`
- `parcel_id -> farmer_id, crop_id, area_acres, location, soil_type, status`
- `schedule_id -> farmer_id, parcel_id, canal_id, start_time, end_time, requested_water, approved_water, status`
- `bill_id -> farmer_id, schedule_id, water_used, total_amount, status`

`required_water_litres` (area_acres x water_requirement_per_acre) is a
derived value and is deliberately NOT stored as a column anywhere -- it
is computed on read (in `vw_farmer_water_requirement` and in the
`/api/parcels/<id>` route) so it can never go stale relative to its
source values.

## Constraints
- **Primary keys:** every table has a single-column surrogate PK.
- **Foreign keys:** all 11 relationships above are enforced with
  `FOREIGN KEY ... REFERENCES`, with `ON DELETE CASCADE` where a child
  row has no meaning without its parent (e.g. a parcel without a
  farmer), `ON DELETE RESTRICT` where the referenced row should not be
  removable while still in use (e.g. a crop still assigned to a
  parcel), and `ON DELETE SET NULL` for the optional
  `Complaints.schedule_id` link.
- **UNIQUE:** `Farmers.phone`, `Crops.crop_name`, `Canals.canal_name`,
  `Bills.schedule_id` (one bill per schedule).
- **CHECK:** value-range and enum-style checks (e.g. `end_time >
  start_time`, `area_acres > 0`, `status IN (...)`) -- see
  `03_constraints_indexes.sql`.
- **DEFAULT:** `status` columns default to a sensible starting value
  (e.g. `'ACTIVE'`, `'PENDING'`, `'OPEN'`), and date/time columns
  default to `CURRENT_DATE` / `CURRENT_TIMESTAMP` where appropriate.

## Indexes
See the comments in `03_constraints_indexes.sql` for the rationale
behind each index; in summary: foreign-key columns are indexed to keep
joins fast, `Water_Schedules(canal_id, start_time, end_time)` is a
composite index specifically for the conflict-detection query (run on
every booking attempt), and `status` columns used in dashboard filters
(schedules, bills, complaints) are indexed.

## Views
- `vw_farmer_water_requirement` -- Farmer + Land + Crop + Area + required water
- `vw_schedule_details` -- Farmer + Crop + Canal + timing + requested/approved water + status
- `vw_billing_report` -- Farmer + water used + rate + amount + payment status
- `vw_canal_utilization` (bonus) -- per-canal schedule count and allocated litres

## Stored Procedures
- `sp_request_water` -- validates and creates a water schedule, reserving
  dam water in the same transaction (KILLER FEATURES 1, 2, 3).
- `sp_generate_bill` -- computes/updates a bill from recorded usage
  (KILLER FEATURE 4), callable on demand in addition to the automatic
  trigger.

## Triggers
- `trg_after_usage_insert` -- AFTER INSERT ON Water_Usage; recomputes the
  total usage for the schedule and upserts the matching Bill.
- `trg_schedule_status_update` -- AFTER UPDATE ON Water_Schedules;
  finalizes a bill's due date when a schedule becomes COMPLETED.

Both triggers write to a *different* table than the one they fire on
(Water_Usage -> Bills, and Water_Schedules -> Bills), so neither can
recursively re-trigger itself.

## Transactions & ACID
`sp_request_water` wraps the schedule INSERT and the dam-water
reservation INSERT in one `START TRANSACTION ... COMMIT` block, with an
`EXIT HANDLER FOR SQLEXCEPTION` that issues `ROLLBACK`. This guarantees:
- **Atomicity:** either both writes happen, or neither does.
- **Consistency:** the dam's available water is never reduced without a
  corresponding approved schedule (and vice versa).
- **Isolation:** MySQL's default `REPEATABLE READ` isolation level
  prevents two concurrent bookings from both reading the same "available
  water" value and over-committing it.
- **Durability:** once COMMIT succeeds, the schedule and the reduced
  availability persist even after a crash.

See `08_sample_transactions.sql` for runnable demonstrations, including
one where a manual transaction is explicitly rolled back and the row
count is proven to be unchanged.
