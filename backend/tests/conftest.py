"""Pytest configuration and fixtures."""

import os
import pytest
from typing import Generator
from fastapi.testclient import TestClient
from dotenv import load_dotenv

# Load .env file
load_dotenv()

# Set test environment before importing app
os.environ["APP_ENV"] = "testing"


@pytest.fixture(scope="session")
def test_settings():
    """Test settings - requires real Supabase + Plaid credentials."""
    from app.config import Settings

    return Settings(
        supabase_url=os.getenv("SUPABASE_URL", ""),
        supabase_secret_key=os.getenv("SUPABASE_SECRET_KEY", ""),
        plaid_client_id=os.getenv("PLAID_CLIENT_ID", ""),
        plaid_secret=os.getenv("PLAID_SECRET", ""),
        plaid_env=os.getenv("PLAID_ENV", "sandbox"),
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
