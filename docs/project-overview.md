# Project Overview

## Title
Mettur Dam Smart Water & Irrigation Management System

## Problem Statement
Irrigation water released from Mettur Dam is distributed to farmers through
a network of canals on a shared schedule. Without a system to track canal
bookings, dam availability, and per-farmer usage, it is easy for two
farmers to be allocated the same canal at the same time, for water to be
over-committed relative to what the dam actually has available, and for
billing to be calculated inconsistently. This project builds an academic
simulation of a system that manages that allocation end-to-end, backed by
a properly normalized relational database.

## Objectives
- Model the real-world entities involved in dam-to-farmer irrigation
  (farmers, land, crops, canals, dam readings, schedules, usage, billing,
  payments, complaints) as a normalized relational schema.
- Enforce data integrity with primary keys, foreign keys, and CHECK
  constraints rather than relying on application code alone.
- Demonstrate canal slot conflict detection using interval-overlap logic.
- Demonstrate crop-based water requirement calculation from live data.
- Demonstrate dam-availability-aware approval logic.
- Demonstrate automatic billing driven by a trigger.
- Demonstrate real transactions with COMMIT/ROLLBACK.
- Provide a working REST API and a usable dashboard UI on top of the
  database, without hardcoding any business logic on the frontend.

## Features
See the root `README.md` for the full feature list and the "killer
features" (conflict detection, crop-based water requirement, dam
availability checks, automatic billing, usage monitoring, complaint
management).

## Technology Stack
- **Database:** MySQL 8+ (tables, constraints, indexes, views, stored
  procedures, triggers, transactions)
- **Backend:** Python 3, Flask, mysql-connector-python, REST API
- **Frontend:** HTML5, CSS3, vanilla JavaScript, Bootstrap 5, Chart.js

## System Architecture
```
Browser (frontend/*.html + js/*.js)
        |  fetch() over HTTP (JSON)
        v
Flask REST API (backend/app.py + routes/*.py)
        |  mysql-connector-python
        v
MySQL Database (database/*.sql)
```

The frontend is fully static and can be hosted on GitHub Pages. The Flask
backend must run on a separate Python-capable host (GitHub Pages cannot
execute Python or MySQL). The database runs on any MySQL-compatible
server the backend can reach. See `setup-guide.md` for deployment notes.

## Data Flow
```
Mettur Dam -> Canals -> Water Scheduling -> Farmers -> Land Parcels
    -> Crops -> Water Usage -> Billing -> Payments
                       (Complaints attach to Farmers / Schedules)
```

## Demo Data Disclaimer
All farmer names, dam readings, and crop water-requirement figures in
this project are fictional/illustrative, generated for demonstration
purposes. This system is an academic simulation and is not affiliated
with, and does not use real data from, the Tamil Nadu Water Resources
Department or the actual Mettur Dam control systems.
