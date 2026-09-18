from flask import jsonify


def success_response(data=None, message="OK", status_code=200):
    payload = {"success": True, "message": message}
    if data is not None:
        payload["data"] = data
    return jsonify(payload), status_code


def error_response(message="An error occurred", status_code=400, details=None):
    payload = {"success": False, "message": message}
    if details is not None:
        payload["details"] = str(details)
    return jsonify(payload), status_code
