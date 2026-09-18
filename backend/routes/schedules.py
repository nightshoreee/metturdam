from flask import Blueprint, request
import mysql.connector
from db.connection import get_connection
from utils.responses import success_response, error_response
from utils.validation import require_fields, parse_datetime

schedules_bp = Blueprint("schedules", __name__)

REQUIRED_FIELDS = ["farmer_id", "parcel_id", "canal_id", "start_time", "end_time", "requested_water"]


def _evaluate_request(cur, farmer_id, parcel_id, canal_id, start_time, end_time, requested_water):
    """Read-only evaluation of a water request, mirroring every check
    sp_request_water performs. Used by /check so the UI can preview the
    result (SLOT AVAILABLE / SLOT CONFLICT / INSUFFICIENT DAM WATER /
    CANAL CAPACITY EXCEEDED) before the farmer actually submits."""

    cur.execute("SELECT status FROM Farmers WHERE farmer_id = %s", (farmer_id,))
    farmer = cur.fetchone()
    if not farmer:
        return "REJECTED", "Farmer does not exist."
    if farmer["status"] != "ACTIVE":
        return "REJECTED", "Farmer account is not active."

    cur.execute("SELECT farmer_id, status FROM Land_Parcels WHERE parcel_id = %s", (parcel_id,))
    parcel = cur.fetchone()
    if not parcel:
        return "REJECTED", "Land parcel does not exist."
    if parcel["farmer_id"] != farmer_id:
        return "REJECTED", "This land parcel does not belong to the specified farmer."
    if parcel["status"] != "ACTIVE":
        return "REJECTED", "Land parcel is not active."

    cur.execute("SELECT status, capacity_litres_per_hour FROM Canals WHERE canal_id = %s", (canal_id,))
    canal = cur.fetchone()
    if not canal:
        return "REJECTED", "Canal does not exist."
    if canal["status"] != "ACTIVE":
        return "REJECTED", "Canal is not active (inactive or under maintenance)."

    if end_time <= start_time:
        return "REJECTED", "Invalid time range: end time must be after start time."

    # KILLER FEATURE 1: canal slot conflict detection (interval overlap)
    cur.execute(
        """SELECT start_time, end_time FROM Water_Schedules
           WHERE canal_id = %s AND status IN ('PENDING','APPROVED','COMPLETED')
             AND start_time < %s AND end_time > %s
           LIMIT 1""",
        (canal_id, end_time, start_time),
    )
    conflict = cur.fetchone()
    if conflict:
        return "REJECTED", (
            f"SLOT CONFLICT: Canal is already allocated during the requested time "
            f"(existing allocation: {conflict['start_time']} - {conflict['end_time']})."
        )

    duration_hours = (end_time - start_time).total_seconds() / 3600
    capacity_available = float(canal["capacity_litres_per_hour"]) * duration_hours
    if requested_water > capacity_available:
        return "REJECTED", f"CANAL CAPACITY EXCEEDED: canal can deliver at most {capacity_available:.2f} litres in this window."

    # KILLER FEATURE 3: dam water availability
    cur.execute("SELECT available_water FROM Dam_Status ORDER BY recorded_at DESC LIMIT 1")
    dam = cur.fetchone()
    if not dam or requested_water > float(dam["available_water"]):
        return "REJECTED", "INSUFFICIENT DAM WATER: not enough water currently available at the dam."

    return "APPROVED", "SLOT AVAILABLE: this request can be approved."


@schedules_bp.route("/check", methods=["POST"])
def check_availability():
    data = request.get_json(silent=True) or {}
    missing = require_fields(data, REQUIRED_FIELDS)
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    try:
        start_time = parse_datetime(data["start_time"], "start_time")
        end_time = parse_datetime(data["end_time"], "end_time")
        requested_water = float(data["requested_water"])
    except ValueError as e:
        return error_response(str(e), 400)

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        status, message = _evaluate_request(
            cur, int(data["farmer_id"]), int(data["parcel_id"]), int(data["canal_id"]),
            start_time, end_time, requested_water,
        )
        return success_response({"status": status, "message": message}, message)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to check availability.", 500, e)
    finally:
        if conn:
            conn.close()


@schedules_bp.route("", methods=["POST"])
def create_schedule():
    data = request.get_json(silent=True) or {}
    missing = require_fields(data, REQUIRED_FIELDS)
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    try:
        start_time = parse_datetime(data["start_time"], "start_time")
        end_time = parse_datetime(data["end_time"], "end_time")
        requested_water = float(data["requested_water"])
    except ValueError as e:
        return error_response(str(e), 400)

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        # sp_request_water re-runs every validation server-side (never
        # trust the frontend) inside its own transaction, and reserves
        # the dam water atomically with the schedule insert.
        #
        # mysql-connector-python's callproc() returns the full argument
        # tuple with OUT parameters filled in at their original
        # positions, so args[6..8] below are status/message/schedule_id.
        args = (
            int(data["farmer_id"]), int(data["parcel_id"]), int(data["canal_id"]),
            start_time, end_time, requested_water,
            "", "", 0,
        )
        result_args = cur.callproc("sp_request_water", args)
        status, message, schedule_id = result_args[6], result_args[7], result_args[8]
        conn.commit()

        if status != "APPROVED":
            return error_response(message, 409, {"status": status})
        return success_response(
            {"schedule_id": schedule_id, "status": status},
            message,
            201,
        )
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to create schedule.", 500, e)
    finally:
        if conn:
            conn.close()


@schedules_bp.route("", methods=["GET"])
def list_schedules():
    farmer_id = request.args.get("farmer_id")
    status = request.args.get("status")
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        query = """SELECT vsd.* FROM vw_schedule_details vsd WHERE 1=1"""
        params = []
        if farmer_id:
            query += " AND vsd.schedule_id IN (SELECT schedule_id FROM Water_Schedules WHERE farmer_id = %s)"
            params.append(farmer_id)
        if status:
            query += " AND vsd.status = %s"
            params.append(status)
        query += " ORDER BY vsd.start_time DESC"
        cur.execute(query, params)
        return success_response(cur.fetchall())
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to fetch schedules.", 500, e)
    finally:
        if conn:
            conn.close()


@schedules_bp.route("/<int:schedule_id>", methods=["PUT"])
def update_schedule_status(schedule_id):
    data = request.get_json(silent=True) or {}
    new_status = data.get("status")
    valid = {"PENDING", "APPROVED", "REJECTED", "COMPLETED", "CANCELLED"}
    if new_status not in valid:
        return error_response(f"status must be one of {sorted(valid)}", 400)

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        # Marking a schedule COMPLETED fires trg_schedule_status_update,
        # which finalizes the due date on its bill (if one exists).
        cur.execute("UPDATE Water_Schedules SET status = %s WHERE schedule_id = %s", (new_status, schedule_id))
        conn.commit()
        if cur.rowcount == 0:
            return error_response("Schedule not found.", 404)
        return success_response(None, f"Schedule marked {new_status}.")
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to update schedule.", 500, e)
    finally:
        if conn:
            conn.close()
