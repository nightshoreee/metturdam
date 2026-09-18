from flask import Blueprint, request
import mysql.connector
from db.connection import get_connection
from utils.responses import success_response, error_response

billing_bp = Blueprint("billing", __name__)


@billing_bp.route("", methods=["GET"])
def list_bills():
    farmer_id = request.args.get("farmer_id")
    status = request.args.get("status")
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        query = "SELECT * FROM vw_billing_report WHERE 1=1"
        params = []
        if farmer_id:
            query += " AND farmer_id = %s"
            params.append(farmer_id)
        if status:
            query += " AND bill_status = %s"
            params.append(status)
        query += " ORDER BY bill_date DESC"
        cur.execute(query, params)
        return success_response(cur.fetchall())
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to fetch bills.", 500, e)
    finally:
        if conn:
            conn.close()


@billing_bp.route("/<int:bill_id>", methods=["GET"])
def get_bill(bill_id):
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT * FROM vw_billing_report WHERE bill_id = %s", (bill_id,))
        bill = cur.fetchone()
        if not bill:
            return error_response("Bill not found.", 404)
        return success_response(bill)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to fetch bill.", 500, e)
    finally:
        if conn:
            conn.close()


@billing_bp.route("/generate/<int:schedule_id>", methods=["POST"])
def generate_bill(schedule_id):
    """KILLER FEATURE 4 (manual trigger): calls sp_generate_bill to
    (re)compute a schedule's bill from its recorded usage on demand."""
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        result_args = cur.callproc("sp_generate_bill", (schedule_id, 0, ""))
        conn.commit()
        bill_id, message = result_args[1], result_args[2]
        if not bill_id:
            return error_response(message, 400)
        return success_response({"bill_id": bill_id}, message)
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Failed to generate bill.", 500, e)
    finally:
        if conn:
            conn.close()
