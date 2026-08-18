import os

os.environ.setdefault(
    "DATABASE_URL",
    "postgresql+psycopg2://titanic_user:test_password@localhost:5432/titanic_db",
)

from src.app import create_app


def test_health_endpoint():
    app = create_app("production")
    client = app.test_client()

    response = client.get("/health")

    assert response.status_code == 200
    assert response.get_json() == {
        "service": "titanic-api",
        "status": "healthy",
    }
