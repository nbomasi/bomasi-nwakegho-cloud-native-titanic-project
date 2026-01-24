from flask import Flask
from sqlalchemy import text
from .config import app_config
from .models import db
from .views.people import people_api as people
import os
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


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

    # Create tables if they don't exist
    with app.app_context():
        try:
            db.create_all()
            logger.info("Database tables created/verified")
        except Exception as e:
            logger.warning(f"Could not create tables: {str(e)}")

    app.register_blueprint(people, url_prefix="/")

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
