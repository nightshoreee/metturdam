from flask import Blueprint, request
import mysql.connector
from db.connection import get_connection
from utils.responses import success_response, error_response
from utils.validation import require_fields

canals_bp = Blueprint("canals", __name__)


@canals_bp.route("", methods=["GET"])
def list_canals():
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT * FROM Canals ORDER BY canal_id")
        return success_response(cur.fetchall())
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to fetch canals.", 500, e)
    finally:
        if conn:
            conn.close()


@canals_bp.route("/utilization", methods=["GET"])
def canal_utilization():
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT * FROM vw_canal_utilization ORDER BY canal_id")
        return success_response(cur.fetchall())
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to fetch canal utilization.", 500, e)
    finally:
        if conn:
            conn.close()


@canals_bp.route("/<int:canal_id>", methods=["GET"])
def get_canal(canal_id):
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT * FROM Canals WHERE canal_id = %s", (canal_id,))
        canal = cur.fetchone()
        if not canal:
            return error_response("Canal not found.", 404)
        cur.execute(
            """SELECT ws.*, f.name AS farmer_name FROM Water_Schedules ws
               JOIN Farmers f ON f.farmer_id = ws.farmer_id
               WHERE ws.canal_id = %s AND DATE(ws.start_time) = CURDATE()
               ORDER BY ws.start_time""",
            (canal_id,),
        )
        canal["todays_allocations"] = cur.fetchall()
        return success_response(canal)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to fetch canal.", 500, e)
    finally:
        if conn:
            conn.close()


@canals_bp.route("", methods=["POST"])
def create_canal():
    data = request.get_json(silent=True) or {}
    missing = require_fields(data, ["canal_name", "capacity_litres_per_hour", "source", "destination"])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO Canals (canal_name, capacity_litres_per_hour, source, destination, status) VALUES (%s, %s, %s, %s, %s)",
            (data["canal_name"], data["capacity_litres_per_hour"], data["source"], data["destination"], data.get("status", "ACTIVE")),
        )
        conn.commit()
        return success_response({"canal_id": cur.lastrowid}, "Canal created.", 201)
    except mysql.connector.IntegrityError as e:
        return error_response("A canal with this name already exists.", 409, e)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to create canal.", 500, e)
    finally:
        if conn:
            conn.close()


@canals_bp.route("/<int:canal_id>", methods=["PUT"])
def update_canal(canal_id):
    data = request.get_json(silent=True) or {}
    allowed = {"canal_name", "capacity_litres_per_hour", "source", "destination", "status"}
    updates = {k: v for k, v in data.items() if k in allowed}
    if not updates:
        return error_response("No valid fields provided to update.", 400)

    set_clause = ", ".join(f"{k} = %s" for k in updates)
    values = list(updates.values()) + [canal_id]

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute(f"UPDATE Canals SET {set_clause} WHERE canal_id = %s", values)
        conn.commit()
        if cur.rowcount == 0:
            return error_response("Canal not found.", 404)
        return success_response(None, "Canal updated.")
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to update canal.", 500, e)
    finally:
        if conn:
            conn.close()
