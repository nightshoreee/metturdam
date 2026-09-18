from flask import Flask
from flask_cors import CORS
from config import Config

from routes.farmers import farmers_bp
from routes.parcels import parcels_bp
from routes.crops import crops_bp
from routes.canals import canals_bp
from routes.dam import dam_bp
from routes.schedules import schedules_bp
from routes.usage import usage_bp
from routes.billing import billing_bp
from routes.payments import payments_bp
from routes.complaints import complaints_bp
from routes.reports import reports_bp


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    # Allow the static frontend (opened locally or served from GitHub
    # Pages) to call this API from a different origin.
    CORS(app)

    app.register_blueprint(farmers_bp,    url_prefix="/api/farmers")
    app.register_blueprint(parcels_bp,    url_prefix="/api/parcels")
    app.register_blueprint(crops_bp,      url_prefix="/api/crops")
    app.register_blueprint(canals_bp,     url_prefix="/api/canals")
    app.register_blueprint(dam_bp,        url_prefix="/api/dam")
    app.register_blueprint(schedules_bp,  url_prefix="/api/schedules")
    app.register_blueprint(usage_bp,      url_prefix="/api/usage")
    app.register_blueprint(billing_bp,    url_prefix="/api/bills")
    app.register_blueprint(payments_bp,   url_prefix="/api/payments")
    app.register_blueprint(complaints_bp, url_prefix="/api/complaints")
    app.register_blueprint(reports_bp,    url_prefix="/api/reports")

    @app.route("/api/health")
    def health():
        return {"status": "ok", "service": "Mettur Dam Irrigation API"}

    @app.errorhandler(404)
    def not_found(e):
        return {"success": False, "message": "Endpoint not found."}, 404

    @app.errorhandler(405)
    def method_not_allowed(e):
        return {"success": False, "message": "Method not allowed on this endpoint."}, 405

    @app.errorhandler(500)
    def server_error(e):
        return {"success": False, "message": "Internal server error."}, 500

    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=Config.DEBUG)
