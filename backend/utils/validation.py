from datetime import datetime


def require_fields(data, fields):
    """Return the list of missing/empty field names, or [] if all present."""
    missing = []
    for f in fields:
        if data.get(f) in (None, "", []):
            missing.append(f)
    return missing


def parse_datetime(value, field_name="datetime"):
    """Parse an ISO-ish datetime string; raise ValueError with a clear
    message on failure so routes can turn it into a 400 response."""
    if not value:
        raise ValueError(f"{field_name} is required.")
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            continue
    raise ValueError(f"{field_name} must be a valid date/time (got: {value}).")


def is_positive_number(value):
    try:
        return float(value) > 0
    except (TypeError, ValueError):
        return False
