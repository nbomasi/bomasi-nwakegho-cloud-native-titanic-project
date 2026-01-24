"""
Module containing environment configurations
"""
import os


def get_database_url():
    """
    Constructs database URL from environment variables or uses DATABASE_URL if set
    """
    database_url = os.getenv('DATABASE_URL')
    if database_url:
        return database_url
    
    postgres_user = os.getenv('POSTGRES_USER', 'titanic_user')
    postgres_password = os.getenv('POSTGRES_PASSWORD', 'titanic_password')
    postgres_db = os.getenv('POSTGRES_DB', 'postgres')
    postgres_host = os.getenv('POSTGRES_HOST', 'db')
    postgres_port = os.getenv('POSTGRES_PORT', '5432')
    
    url = f'postgresql+psycopg2://{postgres_user}:{postgres_password}@{postgres_host}:{postgres_port}/{postgres_db}'
    import logging
    logger = logging.getLogger(__name__)
    logger.info(f"Constructed DATABASE_URL: postgresql+psycopg2://{postgres_user}:***@{postgres_host}:{postgres_port}/{postgres_db}")
    return url


class Development:
    """
    Development environment configuration
    """
    DEBUG = True
    TESTING = False
    JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY')
    SQLALCHEMY_DATABASE_URI = get_database_url()
    SQLALCHEMY_TRACK_MODIFICATIONS = False


class Production:
    """
    Production environment configuration
    """
    DEBUG = False
    TESTING = False
    JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY')
    SQLALCHEMY_DATABASE_URI = get_database_url()
    SQLALCHEMY_TRACK_MODIFICATIONS = False


app_config = {
    'development': Development,
    'production': Production,
}
