import os
from dotenv import load_dotenv

# Load variables from a local .env file (if present) into the environment.
load_dotenv()


class Config:
    """Central place for all configuration. Values come from environment
    variables so that no credentials are ever hardcoded in source code."""

    DB_HOST = os.environ.get("DB_HOST", "localhost")
    DB_PORT = int(os.environ.get("DB_PORT", 3306))
    DB_USER = os.environ.get("DB_USER", "root")
    DB_PASSWORD = os.environ.get("DB_PASSWORD", "")
    DB_NAME = os.environ.get("DB_NAME", "mettur_dam_irrigation")

    SECRET_KEY = os.environ.get("FLASK_SECRET_KEY", "dev-secret-key-change-me")
    DEBUG = os.environ.get("FLASK_DEBUG", "True").lower() == "true"
