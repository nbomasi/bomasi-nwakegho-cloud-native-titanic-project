import logging
import os
import time

from flask import Flask, request
from sqlalchemy import text

from .config import app_config
from .models import db
from .views.people import people_api as people

logger = logging.getLogger(__name__)

AUTH_AVAILABLE = False
auth = None

try:
    from .views.auth import auth_api as auth
    AUTH_AVAILABLE = True
except ImportError as e:
    logger.warning(f"Auth module not available: {e}. Running without authentication.")
except Exception as e:
    logger.warning(f"Auth module failed to load: {e}. Running without authentication.")

OBSERVABILITY_AVAILABLE = False
http_requests_total = None
http_request_duration_seconds = None

try:
    from .observability import init_observability
    from .observability.metrics import (
        http_requests_total as _http_requests_total,
        http_request_duration_seconds as _http_request_duration_seconds,
    )
    http_requests_total = _http_requests_total
    http_request_duration_seconds = _http_request_duration_seconds
    OBSERVABILITY_AVAILABLE = True
    logger.info("Observability modules loaded successfully")
except ImportError as e:
    logger.warning(f"Observability modules not available: {e}. Running without metrics and tracing.")
except Exception as e:
    logger.warning(f"Failed to load observability modules: {e}. Running without metrics and tracing.")


def create_app(env_name: str) -> Flask:
    """
    Initializes the application registers

    Parameters:
        env_name: the name of the environment to initialize the app with

    Returns:
        The initialized app instance
    """
    app = Flask(__name__)
    app.config.from_object(app_config[env_name])

    database_url = os.getenv("DATABASE_URL")
    logger.info(f"DATABASE_URL: {database_url}")
    db_uri_key = "SQLALCHEMY_DATABASE_URI"
    logger.info(f"SQLALCHEMY_DATABASE_URI: {app.config.get(db_uri_key)}")

    db.init_app(app)

    if OBSERVABILITY_AVAILABLE:
        init_observability(app, db_instance=db, log_level=os.getenv("LOG_LEVEL", "INFO"))

    @app.before_request
    def before_request():
        """Track request metrics"""
        request.start_time = time.time()

    @app.after_request
    def after_request(response):
        """Track request completion metrics"""
        if OBSERVABILITY_AVAILABLE and hasattr(request, "start_time") and http_requests_total and http_request_duration_seconds:
            try:
                duration = time.time() - request.start_time
                endpoint = request.endpoint or "unknown"
                method = request.method
                status_code = response.status_code

                http_request_duration_seconds.labels(
                    method=method, endpoint=endpoint
                ).observe(duration)

                http_requests_total.labels(
                    method=method, endpoint=endpoint, status=str(status_code)
                ).inc()

                logger.info(
                    f"Request completed: {method} {request.path} - {status_code}",
                    extra={
                        "path": request.path,
                        "method": method,
                        "status_code": status_code,
                        "duration_ms": round(duration * 1000, 2),
                    },
                )
            except Exception as e:
                logger.warning(f"Failed to record metrics: {e}")

        return response

    # Create tables if they don't exist
    with app.app_context():
        try:
            db.create_all()
            logger.info("Database tables created/verified")
        except Exception as e:
            logger.warning(f"Could not create tables: {str(e)}")

    app.register_blueprint(people, url_prefix="/")
    if AUTH_AVAILABLE:
        app.register_blueprint(auth, url_prefix="/")

    @app.route("/", methods=["GET"])
    def index():
        """
        Root endpoint for populating root route

        Returns:
            Greeting message
        """
        return """
        Welcome to the Titanic API
        """

    @app.route("/health", methods=["GET"])
    def health():
        """
        Health check endpoint for container orchestration

        Returns:
            Health status
        """
        try:
            with app.app_context():
                db.session.execute(text("SELECT 1"))
                db.session.commit()
            return {"status": "healthy", "database": "connected"}, 200
        except Exception as e:
            logger.error(f"Health check failed: {str(e)}")
            return {
                "status": "unhealthy",
                "database": "disconnected",
                "error": str(e),
            }, 503

    return app
