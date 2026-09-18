from flask import Blueprint, request
import mysql.connector
from db.connection import get_connection
from utils.responses import success_response, error_response
from utils.validation import require_fields

dam_bp = Blueprint("dam", __name__)


@dam_bp.route("/status", methods=["GET"])
def dam_status():
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT * FROM Dam_Status ORDER BY recorded_at DESC LIMIT 1")
        latest = cur.fetchone()
        if not latest:
            return error_response("No dam status recorded yet.", 404)
        return success_response(latest)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to fetch dam status.", 500, e)
    finally:
        if conn:
            conn.close()


@dam_bp.route("/history", methods=["GET"])
def dam_history():
    limit = request.args.get("limit", 30, type=int)
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT * FROM Dam_Status ORDER BY recorded_at DESC LIMIT %s", (limit,))
        rows = cur.fetchall()
        rows.reverse()  # chronological order, ready for charting
        return success_response(rows)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to fetch dam history.", 500, e)
    finally:
        if conn:
            conn.close()


@dam_bp.route("/status", methods=["POST"])
def record_dam_status():
    """Manually log a new dam reading (separate from the automatic
    readings sp_request_water writes when it reserves water)."""
    data = request.get_json(silent=True) or {}
    missing = require_fields(data, ["water_level", "available_water", "release_rate"])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO Dam_Status (water_level, available_water, release_rate) VALUES (%s, %s, %s)",
            (data["water_level"], data["available_water"], data["release_rate"]),
        )
        conn.commit()
        return success_response({"status_id": cur.lastrowid}, "Dam status recorded.", 201)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to record dam status.", 500, e)
    finally:
        if conn:
            conn.close()
