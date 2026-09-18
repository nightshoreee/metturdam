# Mettur Dam Smart Water & Irrigation Management System

A DBMS mini-project simulating irrigation water distribution from
Mettur Dam to farmers through canals -- with a MySQL database (tables,
constraints, indexes, views, stored procedures, triggers,
transactions), a Flask REST API, and a Bootstrap/Chart.js dashboard.

> **Demo data disclaimer:** all farmer names, dam readings, and crop
> water-requirement figures are fictional/illustrative. This is an
> academic simulation, not affiliated with the Tamil Nadu Water
> Resources Department or the real Mettur Dam.

## 1. Project Title
Mettur Dam Smart Water & Irrigation Management System

## 2. Problem Statement
Without a system to track canal bookings, dam water availability, and
per-farmer usage, two farmers can be scheduled onto the same canal at
the same time, water can be over-committed relative to what the dam
actually has, and billing can be inconsistent. This project builds a
full-stack simulation of a system that prevents that, backed by a
properly normalized relational database. See `docs/project-overview.md`
for more detail.

## 3. Objectives
- Normalized relational schema (10 core tables) with PK/FK/CHECK/UNIQUE
  constraints enforced at the database level.
- Canal slot conflict detection via interval-overlap logic.
- Crop-based water requirement calculated dynamically from live data.
- Dam-availability-aware approval logic.
- Automatic billing driven by a database trigger.
- Real transactions with COMMIT/ROLLBACK.
- A working REST API and dashboard UI with zero business logic
  hardcoded on the frontend.

## 4. Features
- Farmers, Land Parcels, Crops, Canals, Dam Status, Water Scheduling,
  Water Usage, Billing, Payments, Complaints, Reports -- full CRUD /
  workflow pages for each.
- **Killer Feature 1 -- Canal Slot Conflict Detection:** rejects any
  booking that overlaps an existing PENDING/APPROVED/COMPLETED booking
  on the same canal.
- **Killer Feature 2 -- Crop-Based Water Requirement:** `area_acres x
  water_requirement_per_acre`, computed server-side, never hardcoded on
  the frontend.
- **Killer Feature 3 -- Dam Water Availability:** a request is only
  approved if the dam's latest recorded `available_water` covers it.
- **Killer Feature 4 -- Automatic Billing:** recording usage
  automatically creates/updates the matching bill via a trigger.
- **Killer Feature 5 -- Water Usage Monitoring:** scheduled vs actual
  water, with SAVED/OVERUSE classification.
- **Killer Feature 6 -- Complaint Management:** farmers can raise and
  track complaints through to resolution.

## 5. Technology Stack
| Layer | Technology |
|---|---|
| Database | MySQL 8+ (tested against MariaDB 10.x during development) |
| Backend | Python 3, Flask, mysql-connector-python |
| Frontend | HTML5, CSS3, vanilla JavaScript, Bootstrap 5, Chart.js |

## 6. System Architecture
```
Browser (frontend/) --fetch()--> Flask REST API (backend/) --SQL--> MySQL (database/)
```
See `docs/project-overview.md` for the full diagram and data flow.

## 7. Database Schema
10 core tables: Farmers, Land_Parcels, Crops, Canals, Dam_Status,
Water_Schedules, Water_Usage, Bills, Payments, Complaints. Full column
lists, constraints, and index rationale are in `docs/database-design.md`.

## 8. ER Relationship Explanation
All relationships are 1-to-many: Farmers->Land_Parcels,
Crops->Land_Parcels, Farmers->Water_Schedules,
Land_Parcels->Water_Schedules, Canals->Water_Schedules,
Water_Schedules->Water_Usage, Water_Schedules->Bills (1:1 via a UNIQUE
constraint), Farmers->Bills, Bills->Payments, Farmers->Complaints,
Water_Schedules->Complaints. Details in `docs/database-design.md`.

## 9. Installation / 10. MySQL Setup / 11. Flask Setup / 12. Frontend
Setup / 13. How to Run
**See `docs/setup-guide.md` for the full step-by-step guide.** Quick
version:
```bash
# 1) Database
cd database
mysql -u root -p < 01_create_database.sql
mysql -u root -p < 02_create_tables.sql
mysql -u root -p < 03_constraints_indexes.sql
mysql -u root -p < 04_seed_data.sql
mysql -u root -p < 05_views.sql
mysql -u root -p < 06_stored_procedures.sql
mysql -u root -p < 07_triggers.sql

# 2) Backend
cd ../backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # then edit .env with your real DB password
python3 app.py

# 3) Frontend
cd ../frontend
python3 -m http.server 8000
# visit http://localhost:8000
```

## 14. GitHub Deployment Explanation
GitHub Pages can only host the **static frontend** -- it cannot run
Flask or MySQL. So:
- `frontend/` -> deploy to GitHub Pages (or any static host). Update
  `API_BASE` in `frontend/js/api.js` to point at your deployed backend.
- `backend/` -> deploy to a Python-capable host (Render, Railway,
  PythonAnywhere, a VPS...).
- `database/` -> run on any MySQL-compatible database host.

The `database/*.sql` files ARE committed to this repository (per the
project brief) -- only the real `.env` file with live credentials is
excluded via `.gitignore`.

## 15. Limitations
- No authentication/authorization layer (out of scope for this DBMS
  project -- anyone with the API URL can call any endpoint).
- No real payment gateway integration (by design -- academic project).
- Dam readings are manually logged demo data, not live telemetry.
- Billing rate is a flat `rate_per_1000_litres` rather than a tiered or
  crop-specific rate structure.

## 16. Future Enhancements
- Role-based login (farmer vs. operator/admin views).
- SMS/email notifications on approval, rejection, or bill due dates.
- CSV export and date-range filtering on reports.
- Replace manual dam-reading entry with a telemetry/IoT integration.
- Tiered billing rates by crop or usage volume.

## Project Structure
```
mettur-dam-project/
├── frontend/     # Static HTML/CSS/JS -- deploy to GitHub Pages
├── backend/      # Flask REST API -- deploy to a Python host
├── database/     # MySQL schema, seed data, views, procedures, triggers
├── docs/         # Full documentation (see below)
└── README.md     # This file
```

## Documentation Index
- `docs/project-overview.md` -- problem statement, objectives, architecture
- `docs/database-design.md` -- schema, normalization, FDs, constraints, indexes
- `docs/api-documentation.md` -- every REST endpoint
- `docs/setup-guide.md` -- full installation & deployment guide
- `docs/dbms-concepts.md` -- viva-ready DBMS concept explanations
- `docs/test-cases.md` -- 22 test cases covering every killer feature
- `docs/viva-questions.md` -- anticipated viva Q&A
