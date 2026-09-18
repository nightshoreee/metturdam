from flask import Blueprint
import mysql.connector
from db.connection import get_connection
from utils.responses import success_response, error_response

reports_bp = Blueprint("reports", __name__)


def _run(query, params=None):
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(dictionary=True)
        cur.execute(query, params or ())
        return success_response(cur.fetchall())
    except (mysql.connector.Error, ConnectionError) as e:
        return error_response("Report query failed.", 500, e)
    finally:
        if conn:
            conn.close()


# Report 1: total water used by each farmer
@reports_bp.route("/water-by-farmer", methods=["GET"])
def water_by_farmer():
    return _run("""
        SELECT f.farmer_id, f.name, COALESCE(SUM(wu.measured_water),0) AS total_water_used
        FROM Farmers f
        LEFT JOIN Water_Schedules ws ON ws.farmer_id = f.farmer_id
        LEFT JOIN Water_Usage wu ON wu.schedule_id = ws.schedule_id
        GROUP BY f.farmer_id, f.name
        ORDER BY total_water_used DESC
    """)


# Report 2: total water used by each canal
@reports_bp.route("/water-by-canal", methods=["GET"])
def water_by_canal():
    return _run("""
        SELECT cn.canal_id, cn.canal_name, COALESCE(SUM(wu.measured_water),0) AS total_water_used
        FROM Canals cn
        LEFT JOIN Water_Schedules ws ON ws.canal_id = cn.canal_id
        LEFT JOIN Water_Usage wu ON wu.schedule_id = ws.schedule_id
        GROUP BY cn.canal_id, cn.canal_name
        ORDER BY total_water_used DESC
    """)


# Report 3: highest water-consuming crops
@reports_bp.route("/top-crops", methods=["GET"])
def top_crops():
    return _run("""
        SELECT c.crop_id, c.crop_name, COALESCE(SUM(wu.measured_water),0) AS total_water_used
        FROM Crops c
        JOIN Land_Parcels lp ON lp.crop_id = c.crop_id
        JOIN Water_Schedules ws ON ws.parcel_id = lp.parcel_id
        JOIN Water_Usage wu ON wu.schedule_id = ws.schedule_id
        GROUP BY c.crop_id, c.crop_name
        ORDER BY total_water_used DESC
    """)


# Report 4: farmers with unpaid bills
@reports_bp.route("/unpaid-farmers", methods=["GET"])
def unpaid_farmers():
    return _run("""
        SELECT f.farmer_id, f.name, f.phone, COUNT(b.bill_id) AS unpaid_bills, SUM(b.total_amount) AS total_due
        FROM Farmers f
        JOIN Bills b ON b.farmer_id = f.farmer_id
        WHERE b.status IN ('UNPAID', 'OVERDUE')
        GROUP BY f.farmer_id, f.name, f.phone
        HAVING total_due > 0
        ORDER BY total_due DESC
    """)


# Report 5: daily water allocation
@reports_bp.route("/daily-allocation", methods=["GET"])
def daily_allocation():
    return _run("""
        SELECT DATE(start_time) AS allocation_date, COUNT(*) AS schedule_count, SUM(approved_water) AS total_allocated
        FROM Water_Schedules
        WHERE status IN ('APPROVED','COMPLETED')
        GROUP BY DATE(start_time)
        ORDER BY allocation_date DESC
    """)


# Report 6: canal utilization
@reports_bp.route("/canal-utilization", methods=["GET"])
def canal_utilization_report():
    return _run("SELECT * FROM vw_canal_utilization ORDER BY total_allocated_litres DESC")


# Report 7: water usage vs scheduled allocation
@reports_bp.route("/usage-vs-scheduled", methods=["GET"])
def usage_vs_scheduled():
    return _run("""
        SELECT ws.schedule_id, f.name AS farmer_name, ws.approved_water AS scheduled_water,
               COALESCE(SUM(wu.measured_water),0) AS actual_water,
               (ws.approved_water - COALESCE(SUM(wu.measured_water),0)) AS difference
        FROM Water_Schedules ws
        JOIN Farmers f ON f.farmer_id = ws.farmer_id
        LEFT JOIN Water_Usage wu ON wu.schedule_id = ws.schedule_id
        WHERE ws.approved_water IS NOT NULL
        GROUP BY ws.schedule_id, f.name, ws.approved_water
        ORDER BY ws.schedule_id
    """)


# Report 8: current dam water availability
@reports_bp.route("/dam-availability", methods=["GET"])
def dam_availability():
    return _run("SELECT * FROM Dam_Status ORDER BY recorded_at DESC LIMIT 1")


# Report 9: number of complaints by type
@reports_bp.route("/complaints-by-type", methods=["GET"])
def complaints_by_type():
    return _run("SELECT complaint_type, COUNT(*) AS total FROM Complaints GROUP BY complaint_type ORDER BY total DESC")


# Report 10: number of completed irrigation schedules
@reports_bp.route("/completed-schedules", methods=["GET"])
def completed_schedules():
    return _run("SELECT COUNT(*) AS completed_count FROM Water_Schedules WHERE status = 'COMPLETED'")
