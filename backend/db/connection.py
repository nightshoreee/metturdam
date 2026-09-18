import mysql.connector
from mysql.connector import Error
from config import Config


def get_connection():
    """Return a new MySQL connection. The caller is responsible for
    closing it (routes do this in a `finally` block)."""
    try:
        conn = mysql.connector.connect(
            host=Config.DB_HOST,
            port=Config.DB_PORT,
            user=Config.DB_USER,
            password=Config.DB_PASSWORD,
            database=Config.DB_NAME,
        )
        return conn
    except Error as e:
        # Re-raised as a plain ConnectionError so route handlers can
        # catch one exception type for both "can't connect" and
        # "query failed" without importing mysql.connector everywhere.
        raise ConnectionError(f"Could not connect to MySQL database: {e}")
