from flask import Blueprint, request
import mysql.connector
from db.connection import get_connection
from utils.responses import success_response, error_response
from utils.validation import require_fields

parcels_bp = Blueprint("parcels", __name__)


@parcels_bp.route("", methods=["GET"])
def list_parcels():
    farmer_id = request.args.get("farmer_id")
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        base = """SELECT lp.*, f.name AS farmer_name, c.crop_name
                   FROM Land_Parcels lp
                   JOIN Farmers f ON f.farmer_id = lp.farmer_id
                   JOIN Crops c ON c.crop_id = lp.crop_id"""
        if farmer_id:
            cur.execute(base + " WHERE lp.farmer_id = %s ORDER BY lp.parcel_id", (farmer_id,))
        else:
            cur.execute(base + " ORDER BY lp.parcel_id")
        return success_response(cur.fetchall())
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to fetch parcels.", 500, e)
    finally:
        if conn:
            conn.close()


@parcels_bp.route("/<int:parcel_id>", methods=["GET"])
def get_parcel(parcel_id):
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        cur.execute(
            """SELECT lp.*, f.name AS farmer_name, c.crop_name, c.water_requirement_per_acre
               FROM Land_Parcels lp
               JOIN Farmers f ON f.farmer_id = lp.farmer_id
               JOIN Crops c ON c.crop_id = lp.crop_id
               WHERE lp.parcel_id = %s""",
            (parcel_id,),
        )
        parcel = cur.fetchone()
        if not parcel:
            return error_response("Parcel not found.", 404)
        # KILLER FEATURE 2: crop-based water requirement, computed here
        # from live database values -- never hardcoded on the frontend.
        parcel["required_water_litres"] = round(
            float(parcel["area_acres"]) * float(parcel["water_requirement_per_acre"]), 2
        )
        return success_response(parcel)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to fetch parcel.", 500, e)
    finally:
        if conn:
            conn.close()


@parcels_bp.route("", methods=["POST"])
def create_parcel():
    data = request.get_json(silent=True) or {}
    missing = require_fields(data, ["farmer_id", "crop_id", "area_acres", "location", "soil_type"])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO Land_Parcels (farmer_id, crop_id, area_acres, location, soil_type, status) VALUES (%s, %s, %s, %s, %s, %s)",
            (data["farmer_id"], data["crop_id"], data["area_acres"], data["location"], data["soil_type"], data.get("status", "ACTIVE")),
        )
        conn.commit()
        return success_response({"parcel_id": cur.lastrowid}, "Land parcel created.", 201)
    except mysql.connector.IntegrityError as e:
        return error_response("Invalid farmer_id or crop_id (foreign key violation).", 409, e)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to create parcel.", 500, e)
    finally:
        if conn:
            conn.close()


@parcels_bp.route("/<int:parcel_id>", methods=["PUT"])
def update_parcel(parcel_id):
    data = request.get_json(silent=True) or {}
    allowed = {"crop_id", "area_acres", "location", "soil_type", "status"}
    updates = {k: v for k, v in data.items() if k in allowed}
    if not updates:
        return error_response("No valid fields provided to update.", 400)

    set_clause = ", ".join(f"{k} = %s" for k in updates)
    values = list(updates.values()) + [parcel_id]

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute(f"UPDATE Land_Parcels SET {set_clause} WHERE parcel_id = %s", values)
        conn.commit()
        if cur.rowcount == 0:
            return error_response("Parcel not found.", 404)
        return success_response(None, "Parcel updated.")
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to update parcel.", 500, e)
    finally:
        if conn:
            conn.close()


@parcels_bp.route("/<int:parcel_id>", methods=["DELETE"])
def delete_parcel(parcel_id):
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("UPDATE Land_Parcels SET status = 'INACTIVE' WHERE parcel_id = %s", (parcel_id,))
        conn.commit()
        if cur.rowcount == 0:
            return error_response("Parcel not found.", 404)
        return success_response(None, "Parcel deactivated.")
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to deactivate parcel.", 500, e)
    finally:
        if conn:
            conn.close()
