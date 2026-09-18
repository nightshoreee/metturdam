from flask import Blueprint, request
import mysql.connector
from db.connection import get_connection
from utils.responses import success_response, error_response
from utils.validation import require_fields

crops_bp = Blueprint("crops", __name__)


@crops_bp.route("", methods=["GET"])
def list_crops():
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT * FROM Crops ORDER BY crop_id")
        return success_response(cur.fetchall())
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to fetch crops.", 500, e)
    finally:
        if conn:
            conn.close()


@crops_bp.route("/<int:crop_id>", methods=["GET"])
def get_crop(crop_id):
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT * FROM Crops WHERE crop_id = %s", (crop_id,))
        crop = cur.fetchone()
        if not crop:
            return error_response("Crop not found.", 404)
        return success_response(crop)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to fetch crop.", 500, e)
    finally:
        if conn:
            conn.close()


@crops_bp.route("", methods=["POST"])
def create_crop():
    data = request.get_json(silent=True) or {}
    missing = require_fields(data, ["crop_name", "water_requirement_per_acre", "crop_duration_days", "season"])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO Crops (crop_name, water_requirement_per_acre, crop_duration_days, season) VALUES (%s, %s, %s, %s)",
            (data["crop_name"], data["water_requirement_per_acre"], data["crop_duration_days"], data["season"]),
        )
        conn.commit()
        return success_response({"crop_id": cur.lastrowid}, "Crop created.", 201)
    except mysql.connector.IntegrityError as e:
        return error_response("A crop with this name already exists.", 409, e)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to create crop.", 500, e)
    finally:
        if conn:
            conn.close()


@crops_bp.route("/<int:crop_id>", methods=["PUT"])
def update_crop(crop_id):
    data = request.get_json(silent=True) or {}
    allowed = {"crop_name", "water_requirement_per_acre", "crop_duration_days", "season"}
    updates = {k: v for k, v in data.items() if k in allowed}
    if not updates:
        return error_response("No valid fields provided to update.", 400)

    set_clause = ", ".join(f"{k} = %s" for k in updates)
    values = list(updates.values()) + [crop_id]

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute(f"UPDATE Crops SET {set_clause} WHERE crop_id = %s", values)
        conn.commit()
        if cur.rowcount == 0:
            return error_response("Crop not found.", 404)
        return success_response(None, "Crop updated.")
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to update crop.", 500, e)
    finally:
        if conn:
            conn.close()


@crops_bp.route("/<int:crop_id>", methods=["DELETE"])
def delete_crop(crop_id):
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("DELETE FROM Crops WHERE crop_id = %s", (crop_id,))
        conn.commit()
        if cur.rowcount == 0:
            return error_response("Crop not found.", 404)
        return success_response(None, "Crop deleted.")
    except mysql.connector.IntegrityError as e:
        return error_response("Cannot delete crop: it is still referenced by land parcels.", 409, e)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to delete crop.", 500, e)
    finally:
        if conn:
            conn.close()
