"""Pytest configuration and fixtures."""

import os
import pytest
from datetime import datetime, timedelta, timezone
from typing import Generator
from fastapi.testclient import TestClient
from dotenv import load_dotenv

# Load .env file
load_dotenv()

# Set test environment before importing app
os.environ["APP_ENV"] = "testing"


@pytest.fixture(scope="session")
def test_settings():
    """Test settings - requires real Supabase credentials."""
    from app.config import Settings

    # These should be set in the test environment
    return Settings(
        supabase_url=os.getenv("SUPABASE_URL", ""),
        supabase_secret_key=os.getenv("SUPABASE_SECRET_KEY", ""),
        app_env="testing",
        debug=True,
    )


@pytest.fixture(scope="session")
def app():
    """Create test application."""
    from app.main import app
    return app


@pytest.fixture(scope="session")
def client(app) -> Generator:
    """Create test client."""
    with TestClient(app) as c:
        yield c


@pytest.fixture
def test_user_email():
    """Generate unique test user email."""
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    return f"test_{timestamp}@example.com"


@pytest.fixture
def test_user_password():
    """Test user password."""
    return "TestPassword123!"


@pytest.fixture
def auth_headers(client, test_user_email, test_user_password):
    """Get auth headers for a test user."""
    # Try to register
    response = client.post(
        "/app/v1/auth/register",
        json={
            "email": test_user_email,
            "password": test_user_password,
            "display_name": "Test User",
        },
    )

    if response.status_code == 201:
        token = response.json()["access_token"]
    else:
        # Try to login if registration failed (user exists)
        response = client.post(
            "/app/v1/auth/login",
            json={
                "email": test_user_email,
                "password": test_user_password,
            },
        )
        token = response.json()["access_token"]

    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def sample_airport():
    """Sample airport data."""
    return {
        "code": "LAX",
        "name": "Los Angeles International Airport",
        "latitude": 33.9425,
        "longitude": -118.4081,
    }


@pytest.fixture
def sample_flight_data():
    """Sample flight creation data."""
    departure = datetime.now(timezone.utc) + timedelta(hours=24)
    arrival = departure + timedelta(hours=3)

    return {
        "flight_number": "AA123",
        "airline": "American Airlines",
        "departure_airport": "LAX",
        "arrival_airport": "JFK",
        "departure_time": departure.isoformat(),
        "arrival_time": arrival.isoformat(),
    }


@pytest.fixture
def sample_location_lax():
    """Sample location near LAX."""
    return {
        "latitude": 33.9425,
        "longitude": -118.4081,
    }
