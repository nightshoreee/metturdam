from flask import Blueprint, request
import mysql.connector
from db.connection import get_connection
from utils.responses import success_response, error_response
from utils.validation import require_fields

complaints_bp = Blueprint("complaints", __name__)

VALID_TYPES = {
    "WATER_NOT_RECEIVED", "CANAL_BLOCKAGE", "INCORRECT_BILLING",
    "SCHEDULE_ISSUE", "INSUFFICIENT_WATER", "OTHER",
}
VALID_STATUSES = {"OPEN", "IN_PROGRESS", "RESOLVED", "REJECTED"}


@complaints_bp.route("", methods=["GET"])
def list_complaints():
    farmer_id = request.args.get("farmer_id")
    status = request.args.get("status")
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        query = """SELECT co.*, f.name AS farmer_name FROM Complaints co
                    JOIN Farmers f ON f.farmer_id = co.farmer_id WHERE 1=1"""
        params = []
        if farmer_id:
            query += " AND co.farmer_id = %s"
            params.append(farmer_id)
        if status:
            query += " AND co.status = %s"
            params.append(status)
        query += " ORDER BY co.created_at DESC"
        cur.execute(query, params)
        return success_response(cur.fetchall())
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to fetch complaints.", 500, e)
    finally:
        if conn:
            conn.close()


@complaints_bp.route("", methods=["POST"])
def create_complaint():
    data = request.get_json(silent=True) or {}
    missing = require_fields(data, ["farmer_id", "complaint_type", "description"])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)
    if data["complaint_type"] not in VALID_TYPES:
        return error_response(f"complaint_type must be one of {sorted(VALID_TYPES)}", 400)

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO Complaints (farmer_id, schedule_id, complaint_type, description, status) VALUES (%s, %s, %s, %s, 'OPEN')",
            (data["farmer_id"], data.get("schedule_id"), data["complaint_type"], data["description"]),
        )
        conn.commit()
        return success_response({"complaint_id": cur.lastrowid}, "Complaint submitted.", 201)
    except mysql.connector.IntegrityError as e:
        return error_response("Invalid farmer_id or schedule_id.", 409, e)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to submit complaint.", 500, e)
    finally:
        if conn:
            conn.close()


@complaints_bp.route("/<int:complaint_id>", methods=["PUT"])
def update_complaint(complaint_id):
    data = request.get_json(silent=True) or {}
    new_status = data.get("status")
    if new_status not in VALID_STATUSES:
        return error_response(f"status must be one of {sorted(VALID_STATUSES)}", 400)

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        if new_status in ("RESOLVED", "REJECTED"):
            cur.execute(
                "UPDATE Complaints SET status = %s, resolved_at = NOW() WHERE complaint_id = %s",
                (new_status, complaint_id),
            )
        else:
            cur.execute("UPDATE Complaints SET status = %s WHERE complaint_id = %s", (new_status, complaint_id))
        conn.commit()
        if cur.rowcount == 0:
            return error_response("Complaint not found.", 404)
        return success_response(None, f"Complaint marked {new_status}.")
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to update complaint.", 500, e)
    finally:
        if conn:
            conn.close()
