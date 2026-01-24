"""
Observability initialization module
"""
import logging

logger = logging.getLogger(__name__)


def init_observability(app, db_instance=None, log_level: str = "INFO") -> None:
    """
    Initialize all observability components
    
    Parameters:
        app: Flask application instance
        db_instance: SQLAlchemy database instance (optional)
        log_level: Logging level (default: INFO)
    """
    try:
        from .metrics import metrics_endpoint, http_requests_in_progress
        from .logging import setup_logging
        from .tracing import setup_tracing
        
        setup_logging(log_level)
        setup_tracing(app, db_instance)
        
        app.add_url_rule("/metrics", "metrics", metrics_endpoint)
        
        @app.before_request
        def before_request():
            """Track request start"""
            http_requests_in_progress.inc()
        
        @app.after_request
        def after_request(response):
            """Track request completion"""
            http_requests_in_progress.dec()
            return response
        
        logger.info("Observability initialized successfully")
    except ImportError as e:
        logger.warning(f"Observability dependencies not available: {e}. Continuing without observability.")
    except Exception as e:
        logger.error(f"Failed to initialize observability: {e}. Continuing without observability.", exc_info=True)
