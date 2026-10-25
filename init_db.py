#!/usr/bin/env python3
"""One-time-safe initializer for Mettur Dam's Aiven MySQL database.

Place this file at the repository root beside the `backend/` and `database/`
folders. It runs the existing project SQL files without using MySQL Workbench.
It deliberately does NOT execute 01_create_database.sql because that file drops
and recreates the database; create the database in Aiven Console instead.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

import mysql.connector

ROOT = Path(__file__).resolve().parent
SQL_DIR = ROOT / "database"
DB_NAME = os.environ.get("DB_NAME", "mettur_dam_irrigation")

EXPECTED_TABLES = {
    "Farmers", "Crops", "Canals", "Dam_Status", "Land_Parcels",
    "Water_Schedules", "Water_Usage", "Bills", "Payments", "Complaints",
}
EXPECTED_VIEWS = {
    "vw_farmer_water_requirement", "vw_schedule_details",
    "vw_billing_report", "vw_canal_utilization",
}
EXPECTED_PROCEDURES = {"sp_request_water", "sp_generate_bill"}
EXPECTED_TRIGGERS = {"trg_after_usage_insert", "trg_schedule_status_update"}
SQL_FILES = [
    "02_create_tables.sql",
    "03_constraints_indexes.sql",
    "04_seed_data.sql",
    "05_views.sql",
    "06_stored_procedures.sql",
    "07_triggers.sql",
]


def split_sql_script(source: str) -> list[str]:
    """Split a mysql-client-style script, supporting DELIMITER directives."""
    delimiter = ";"
    statements: list[str] = []
    buffer = ""

    for line in source.splitlines():
        stripped = line.strip()
        if re.match(r"^DELIMITER\s+", stripped, re.IGNORECASE):
            match = re.match(r"^DELIMITER\s+(\S+)\s*$", stripped, re.IGNORECASE)
            if not match:
                raise ValueError(f"Invalid DELIMITER directive: {line}")
            delimiter = match.group(1)
            continue
        # SQL in these project scripts uses full-line -- comments.
        if stripped.startswith("--"):
            continue

        buffer += line + "\n"
        while delimiter and delimiter in buffer:
            statement, buffer = buffer.split(delimiter, 1)
            if statement.strip():
                statements.append(statement.strip())

    if buffer.strip():
        statements.append(buffer.strip())
    return statements


def object_state(cursor) -> tuple[set[str], set[str], set[str], set[str]]:
    cursor.execute(
        "SELECT TABLE_NAME, TABLE_TYPE FROM information_schema.TABLES "
        "WHERE TABLE_SCHEMA = %s",
        (DB_NAME,),
    )
    rows = cursor.fetchall()
    tables = {name for name, kind in rows if kind.upper() == "BASE TABLE"}
    views = {name for name, kind in rows if kind.upper() == "VIEW"}

    cursor.execute(
        "SELECT ROUTINE_NAME FROM information_schema.ROUTINES "
        "WHERE ROUTINE_SCHEMA = %s AND ROUTINE_TYPE = 'PROCEDURE'",
        (DB_NAME,),
    )
    procedures = {row[0] for row in cursor.fetchall()}

    cursor.execute(
        "SELECT TRIGGER_NAME FROM information_schema.TRIGGERS "
        "WHERE TRIGGER_SCHEMA = %s",
        (DB_NAME,),
    )
    triggers = {row[0] for row in cursor.fetchall()}
    return tables, views, procedures, triggers


def main() -> int:
    required_env = ["DB_HOST", "DB_PORT", "DB_USER", "DB_PASSWORD", "DB_NAME"]
    missing = [key for key in required_env if not os.environ.get(key)]
    if missing:
        print("ERROR: Missing Render environment variables: " + ", ".join(missing))
        return 1

    for filename in SQL_FILES:
        if not (SQL_DIR / filename).is_file():
            print(f"ERROR: Expected project SQL file not found: {SQL_DIR / filename}")
            print("Ensure the Render Root Directory is blank (repository root).")
            return 1

    try:
        connection = mysql.connector.connect(
            host=os.environ["DB_HOST"],
            port=int(os.environ["DB_PORT"]),
            user=os.environ["DB_USER"],
            password=os.environ["DB_PASSWORD"],
            database=DB_NAME,
            connection_timeout=20,
        )
        cursor = connection.cursor()

        tables, views, procedures, triggers = object_state(cursor)
        complete = (
            EXPECTED_TABLES <= tables
            and EXPECTED_VIEWS <= views
            and EXPECTED_PROCEDURES <= procedures
            and EXPECTED_TRIGGERS <= triggers
        )
        if complete:
            print(f"Database `{DB_NAME}` already has all expected tables, views, procedures and triggers; skipping initialization.")
            return 0

        any_project_objects = (
            tables & EXPECTED_TABLES
            or views & EXPECTED_VIEWS
            or procedures & EXPECTED_PROCEDURES
            or triggers & EXPECTED_TRIGGERS
        )
        if any_project_objects:
            print("ERROR: A partial Mettur Dam schema already exists in this database.")
            print("Initialization stopped to avoid overwriting or duplicating data.")
            print("Use Aiven Console to create a fresh empty database named `mettur_dam_irrigation`, then set Render DB_NAME to that database.")
            return 1

        for filename in SQL_FILES:
            path = SQL_DIR / filename
            print(f"Running {filename}...")
            statements = split_sql_script(path.read_text(encoding="utf-8"))
            for statement in statements:
                cursor.execute(statement)
            connection.commit()

        tables, views, procedures, triggers = object_state(cursor)
        if not (
            EXPECTED_TABLES <= tables
            and EXPECTED_VIEWS <= views
            and EXPECTED_PROCEDURES <= procedures
            and EXPECTED_TRIGGERS <= triggers
        ):
            print("ERROR: Script execution finished but some expected database objects are missing.")
            print(f"Tables present: {sorted(tables)}")
            print(f"Views present: {sorted(views)}")
            print(f"Procedures present: {sorted(procedures)}")
            print(f"Triggers present: {sorted(triggers)}")
            return 1

        cursor.execute("SELECT COUNT(*) FROM Farmers")
        farmer_count = cursor.fetchone()[0]
        print("Database initialization completed successfully.")
        print(f"Tables: {len(EXPECTED_TABLES)}; views: {len(EXPECTED_VIEWS)}; procedures: {len(EXPECTED_PROCEDURES)}; triggers: {len(EXPECTED_TRIGGERS)}")
        print(f"Farmer sample records loaded: {farmer_count}")
        return 0
    except Exception as exc:
        print(f"DATABASE INITIALIZATION FAILED: {type(exc).__name__}: {exc}")
        return 1
    finally:
        try:
            cursor.close()
        except Exception:
            pass
        try:
            connection.close()
        except Exception:
            pass


if __name__ == "__main__":
    sys.exit(main())
