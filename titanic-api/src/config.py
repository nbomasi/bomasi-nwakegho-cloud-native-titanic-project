"""
Module containing environment configurations
"""
import os


def get_database_url():
    """
    Constructs database URL from environment variables or uses DATABASE_URL if set
    """
    database_url = os.getenv("DATABASE_URL")
    if database_url:
        import logging
        logger = logging.getLogger(__name__)
        logger.info(f"Using DATABASE_URL from environment: postgresql+psycopg2://***@***")
        return database_url

    # Fallback: construct from individual environment variables
    postgres_user = os.getenv("POSTGRES_USER", "titanic_user")
    postgres_password = os.getenv("POSTGRES_PASSWORD")
    postgres_db = os.getenv("POSTGRES_DB", "postgres")
    postgres_host = os.getenv("POSTGRES_HOST", "db")
    postgres_port = os.getenv("POSTGRES_PORT", "5432")

    if not postgres_password:
        raise RuntimeError(
            "POSTGRES_PASSWORD is required when DATABASE_URL is not set"
        )

    url = f"postgresql+psycopg2://{postgres_user}:{postgres_password}@{postgres_host}:{postgres_port}/{postgres_db}"
    import logging

    logger = logging.getLogger(__name__)
    logger.warning(
        f"DATABASE_URL not set, constructing from individual vars: postgresql+psycopg2://{postgres_user}:***@{postgres_host}:{postgres_port}/{postgres_db}"
    )
    return url


class Development:
    """
    Development environment configuration
    """
    DEBUG = True
    TESTING = False
    SQLALCHEMY_TRACK_MODIFICATIONS = False


class Production:
    """
    Production environment configuration
    """
    DEBUG = False
    TESTING = False
    SQLALCHEMY_TRACK_MODIFICATIONS = False


class Staging:
    """
    Staging environment configuration
    """
    DEBUG = False
    TESTING = False
    SQLALCHEMY_TRACK_MODIFICATIONS = False


app_config = {
    "development": Development,
    "production": Production,
    "staging": Staging,
}
