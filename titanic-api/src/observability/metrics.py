"""
Prometheus metrics configuration for Titanic API
"""
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from flask import Response


http_requests_total = Counter(
    "titanic_api_http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"]
)

http_request_duration_seconds = Histogram(
    "titanic_api_http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "endpoint"],
    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
)

http_requests_in_progress = Gauge(
    "titanic_api_http_requests_in_progress",
    "Current HTTP requests in progress"
)

database_connections_active = Gauge(
    "titanic_api_database_connections_active",
    "Active database connections"
)

database_query_duration_seconds = Histogram(
    "titanic_api_database_query_duration_seconds",
    "Database query duration in seconds",
    ["query_type"],
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
)


def metrics_endpoint():
    """
    Prometheus metrics endpoint
    
    Returns:
        Response with Prometheus metrics in text format
    """
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)
