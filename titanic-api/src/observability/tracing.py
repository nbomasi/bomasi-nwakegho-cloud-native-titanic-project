"""
OpenTelemetry tracing configuration for Titanic API
"""
import os
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor


def setup_tracing(app, db_instance=None) -> None:
    """
    Configure OpenTelemetry tracing for Flask and SQLAlchemy
    
    Parameters:
        app: Flask application instance
        db_instance: SQLAlchemy database instance (optional)
    """
    service_name = os.getenv("SERVICE_NAME", "titanic-api")
    environment = os.getenv("FLASK_ENV", "development")
    
    resource = Resource.create({
        "service.name": service_name,
        "service.environment": environment,
    })
    
    tracer_provider = TracerProvider(resource=resource)
    trace.set_tracer_provider(tracer_provider)
    
    FlaskInstrumentor().instrument_app(app)
    
    # Only instrument SQLAlchemy if db_instance is provided and we have an app context
    if db_instance:
        try:
            # Access engine within app context to avoid "No application found" error
            with app.app_context():
                SQLAlchemyInstrumentor().instrument(
                    engine=db_instance.engine,
                    enable_commenter=True,
                    commenter_options={},
                )
        except Exception as e:
            # If we can't access the engine, skip SQLAlchemy instrumentation
            # This can happen if called before app context is fully initialized
            import logging
            logging.getLogger(__name__).warning(f"Could not instrument SQLAlchemy: {e}. Continuing without SQLAlchemy tracing.")
