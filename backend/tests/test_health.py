"""Tests for the FastAPI health check endpoint."""

from fastapi.testclient import TestClient

from app.main import create_app


class TestHealthEndpoint:
    """Test suite for /health endpoint."""

    def setup_method(self) -> None:
        """Create a new test client for each test."""
        app = create_app()
        self.client = TestClient(app)

    def test_health_returns_ok(self) -> None:
        """Should return a successful response payload."""
        response = self.client.get("/health")
        assert response.status_code == 200
        assert response.json() == {"status": "ok"}
