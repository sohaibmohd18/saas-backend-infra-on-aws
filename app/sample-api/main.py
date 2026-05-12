import json
import logging
import os
import time

import psycopg2
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse

# ---------------------------------------------------------------------------
# Structured JSON logging (CloudWatch Logs Insights compatible)
# ---------------------------------------------------------------------------

class JSONFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        log_record = {
            "timestamp": self.formatTime(record, self.datefmt),
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
        }
        if record.exc_info:
            log_record["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_record)


handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logging.basicConfig(level=logging.INFO, handlers=[handler])
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------

app = FastAPI(title="SaaS Backend Sample API", version="1.0.0")

APP_ENV = os.environ.get("APP_ENV", "unknown")
START_TIME = time.time()


def _get_db_credentials() -> dict:
    """Parse DB credentials from the DB_SECRET environment variable.

    ECS injects the Secrets Manager JSON as a plain string into DB_SECRET.
    DB_HOST is injected separately as a plain env var (avoids writing the
    password back into Secrets Manager on every Terraform apply).
    Falls back gracefully so /health still works even without DB config.
    """
    raw = os.environ.get("DB_SECRET", "{}")
    try:
        creds = json.loads(raw)
    except json.JSONDecodeError:
        creds = {}
    # DB_HOST env var takes precedence over the (possibly empty) host in the secret
    host_override = os.environ.get("DB_HOST", "").strip()
    if host_override:
        creds["host"] = host_override
    return creds


def _check_db_connection() -> dict:
    """Attempt a connection to RDS and return status info.

    Returns only a boolean connected status — never raw exception messages,
    which can expose hostnames, ports, or credential hints to callers.
    """
    creds = _get_db_credentials()
    host = creds.get("host", "")
    if not host:
        return {"connected": False, "error": "db host not configured"}

    try:
        conn = psycopg2.connect(
            host=host,
            port=int(creds.get("port", 5432)),
            dbname=creds.get("dbname", "appdb"),
            user=creds.get("username", ""),
            password=creds.get("password", ""),
            connect_timeout=3,
        )
        conn.close()
        return {"connected": True}
    except psycopg2.OperationalError:
        # Log the full error internally but never surface it to the caller
        logger.exception("DB connection check failed")
        return {"connected": False, "error": "connection failed"}


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@app.get("/health")
def health():
    """ALB health check endpoint — must return HTTP 200."""
    return {"status": "healthy"}


@app.get("/")
def root():
    return {
        "status": "ok",
        "service": "saas-backend-sample-api",
        "version": "1.0.0",
    }


@app.get("/info")
def info():
    """Diagnostic endpoint — shows environment and DB connectivity."""
    uptime_seconds = round(time.time() - START_TIME, 1)
    db_status = _check_db_connection()

    logger.info("info endpoint called", extra={"env": APP_ENV, "db_connected": db_status["connected"]})

    return {
        "environment": APP_ENV,
        "uptime_seconds": uptime_seconds,
        "database": db_status,
    }
