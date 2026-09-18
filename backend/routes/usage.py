from flask import Blueprint, request
import mysql.connector
from db.connection import get_connection
from utils.responses import success_response, error_response
from utils.validation import require_fields

usage_bp = Blueprint("usage", __name__)


@usage_bp.route("", methods=["GET"])
def list_usage():
    schedule_id = request.args.get("schedule_id")
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        if schedule_id:
            cur.execute("SELECT * FROM Water_Usage WHERE schedule_id = %s ORDER BY recorded_at", (schedule_id,))
        else:
            cur.execute(
                """SELECT wu.*, ws.farmer_id, f.name AS farmer_name FROM Water_Usage wu
                   JOIN Water_Schedules ws ON ws.schedule_id = wu.schedule_id
                   JOIN Farmers f ON f.farmer_id = ws.farmer_id
                   ORDER BY wu.recorded_at DESC"""
            )
        return success_response(cur.fetchall())
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to fetch usage records.", 500, e)
    finally:
        if conn:
            conn.close()


@usage_bp.route("/compare/<int:schedule_id>", methods=["GET"])
def compare_usage(schedule_id):
    """KILLER FEATURE 5: scheduled vs actual water, with SAVED/OVERUSE
    classification."""
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT approved_water FROM Water_Schedules WHERE schedule_id = %s", (schedule_id,))
        sched = cur.fetchone()
        if not sched:
            return error_response("Schedule not found.", 404)

        cur.execute(
            "SELECT COALESCE(SUM(measured_water), 0) AS total_used FROM Water_Usage WHERE schedule_id = %s",
            (schedule_id,),
        )
        used = cur.fetchone()["total_used"]

        scheduled = float(sched["approved_water"] or 0)
        actual = float(used)
        status = "SAVED" if actual < scheduled else ("OVERUSE" if actual > scheduled else "EXACT")

        return success_response({
            "scheduled_water": scheduled,
            "actual_water": actual,
            "difference": round(scheduled - actual, 2),
            "status": status,
        })
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to compare usage.", 500, e)
    finally:
        if conn:
            conn.close()


@usage_bp.route("", methods=["POST"])
def record_usage():
    data = request.get_json(silent=True) or {}
    missing = require_fields(data, ["schedule_id", "measured_water"])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("SELECT schedule_id FROM Water_Schedules WHERE schedule_id = %s", (data["schedule_id"],))
        if not cur.fetchone():
            return error_response("Schedule does not exist.", 404)

        # trg_after_usage_insert (see 07_triggers.sql) automatically
        # creates/updates the bill for this schedule -- no billing
        # logic needed here in the backend.
        cur.execute(
            "INSERT INTO Water_Usage (schedule_id, measured_water, meter_reading, remarks) VALUES (%s, %s, %s, %s)",
            (data["schedule_id"], data["measured_water"], data.get("meter_reading"), data.get("remarks")),
        )
        conn.commit()
        return success_response({"usage_id": cur.lastrowid}, "Water usage recorded; bill updated automatically.", 201)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to record usage.", 500, e)
    finally:
        if conn:
            conn.close()
