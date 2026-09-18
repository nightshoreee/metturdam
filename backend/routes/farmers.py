from flask import Blueprint, request
import mysql.connector
from db.connection import get_connection
from utils.responses import success_response, error_response
from utils.validation import require_fields

farmers_bp = Blueprint("farmers", __name__)


@farmers_bp.route("", methods=["GET"])
def list_farmers():
    search = request.args.get("search", "").strip()
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        if search:
            like = f"%{search}%"
            cur.execute(
                "SELECT * FROM Farmers WHERE name LIKE %s OR village LIKE %s OR phone LIKE %s ORDER BY farmer_id",
                (like, like, like),
            )
        else:
            cur.execute("SELECT * FROM Farmers ORDER BY farmer_id")
        return success_response(cur.fetchall())
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to fetch farmers.", 500, e)
    finally:
        if conn:
            conn.close()


@farmers_bp.route("/<int:farmer_id>", methods=["GET"])
def get_farmer(farmer_id):
    """Farmer details plus their parcels, schedules, bills and
    complaints in one response -- demonstrates the relational data
    behind a single farmer."""
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT * FROM Farmers WHERE farmer_id = %s", (farmer_id,))
        farmer = cur.fetchone()
        if not farmer:
            return error_response("Farmer not found.", 404)

        cur.execute(
            """SELECT lp.*, c.crop_name FROM Land_Parcels lp
               JOIN Crops c ON c.crop_id = lp.crop_id
               WHERE lp.farmer_id = %s ORDER BY lp.parcel_id""",
            (farmer_id,),
        )
        farmer["parcels"] = cur.fetchall()

        cur.execute(
            """SELECT ws.*, cn.canal_name FROM Water_Schedules ws
               JOIN Canals cn ON cn.canal_id = ws.canal_id
               WHERE ws.farmer_id = %s ORDER BY ws.start_time DESC""",
            (farmer_id,),
        )
        farmer["schedules"] = cur.fetchall()

        cur.execute("SELECT * FROM Bills WHERE farmer_id = %s ORDER BY bill_date DESC", (farmer_id,))
        farmer["bills"] = cur.fetchall()

        cur.execute("SELECT * FROM Complaints WHERE farmer_id = %s ORDER BY created_at DESC", (farmer_id,))
        farmer["complaints"] = cur.fetchall()

        return success_response(farmer)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to fetch farmer.", 500, e)
    finally:
        if conn:
            conn.close()


@farmers_bp.route("", methods=["POST"])
def create_farmer():
    data = request.get_json(silent=True) or {}
    missing = require_fields(data, ["name", "phone", "village"])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO Farmers (name, phone, village, status) VALUES (%s, %s, %s, %s)",
            (data["name"], data["phone"], data["village"], data.get("status", "ACTIVE")),
        )
        conn.commit()
        return success_response({"farmer_id": cur.lastrowid}, "Farmer created.", 201)
    except mysql.connector.IntegrityError as e:
        return error_response("A farmer with this phone number already exists.", 409, e)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to create farmer.", 500, e)
    finally:
        if conn:
            conn.close()


@farmers_bp.route("/<int:farmer_id>", methods=["PUT"])
def update_farmer(farmer_id):
    data = request.get_json(silent=True) or {}
    allowed = {"name", "phone", "village", "status"}
    updates = {k: v for k, v in data.items() if k in allowed}
    if not updates:
        return error_response("No valid fields provided to update.", 400)

    set_clause = ", ".join(f"{k} = %s" for k in updates)
    values = list(updates.values()) + [farmer_id]

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute(f"UPDATE Farmers SET {set_clause} WHERE farmer_id = %s", values)
        conn.commit()
        if cur.rowcount == 0:
            return error_response("Farmer not found.", 404)
        return success_response(None, "Farmer updated.")
    except mysql.connector.IntegrityError as e:
        return error_response("Update violates a uniqueness constraint (duplicate phone).", 409, e)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to update farmer.", 500, e)
    finally:
        if conn:
            conn.close()


@farmers_bp.route("/<int:farmer_id>", methods=["DELETE"])
def delete_farmer(farmer_id):
    """Soft delete: farmers are deactivated, not removed, so historical
    schedules/bills/complaints stay intact for reporting."""
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("UPDATE Farmers SET status = 'INACTIVE' WHERE farmer_id = %s", (farmer_id,))
        conn.commit()
        if cur.rowcount == 0:
            return error_response("Farmer not found.", 404)
        return success_response(None, "Farmer deactivated.")
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to deactivate farmer.", 500, e)
    finally:
        if conn:
            conn.close()
