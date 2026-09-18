from flask import Blueprint, request
import mysql.connector
from db.connection import get_connection
from utils.responses import success_response, error_response
from utils.validation import require_fields

payments_bp = Blueprint("payments", __name__)


@payments_bp.route("", methods=["GET"])
def list_payments():
    farmer_id = request.args.get("farmer_id")
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        if farmer_id:
            cur.execute("SELECT * FROM Payments WHERE farmer_id = %s ORDER BY payment_date DESC", (farmer_id,))
        else:
            cur.execute("SELECT * FROM Payments ORDER BY payment_date DESC")
        return success_response(cur.fetchall())
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to fetch payments.", 500, e)
    finally:
        if conn:
            conn.close()


@payments_bp.route("", methods=["POST"])
def create_payment():
    """Records a payment (no real online payment processing -- this is
    an academic project). If the bill is now fully paid, its status is
    updated to PAID."""
    data = request.get_json(silent=True) or {}
    missing = require_fields(data, ["bill_id", "farmer_id", "amount_paid"])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT * FROM Bills WHERE bill_id = %s", (data["bill_id"],))
        bill = cur.fetchone()
        if not bill:
            return error_response("Bill does not exist.", 404)

        write_cur = conn.cursor()
        write_cur.execute(
            "INSERT INTO Payments (bill_id, farmer_id, amount_paid, payment_mode, status) VALUES (%s, %s, %s, %s, %s)",
            (data["bill_id"], data["farmer_id"], data["amount_paid"], data.get("payment_mode", "CASH"), "SUCCESS"),
        )
        conn.commit()

        cur.execute(
            "SELECT COALESCE(SUM(amount_paid), 0) AS total_paid FROM Payments WHERE bill_id = %s AND status = 'SUCCESS'",
            (data["bill_id"],),
        )
        total_paid = float(cur.fetchone()["total_paid"])
        if total_paid >= float(bill["total_amount"]):
            status_cur = conn.cursor()
            status_cur.execute("UPDATE Bills SET status = 'PAID' WHERE bill_id = %s", (data["bill_id"],))
            conn.commit()

        return success_response({"payment_id": write_cur.lastrowid}, "Payment recorded.", 201)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to record payment.", 500, e)
    finally:
        if conn:
            conn.close()
