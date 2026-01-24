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
    
    if db_instance:
        SQLAlchemyInstrumentor().instrument(
            engine=db_instance.engine,
            enable_commenter=True,
            commenter_options={},
        )
