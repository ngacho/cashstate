"""Dependency injection for FastAPI routes."""

import time
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from jwt import PyJWKClient
from supabase import Client

from app.config import get_settings, Settings
from app.database import get_db, Database


security = HTTPBearer()

# Cache for JWKS client
_jwks_client: PyJWKClient | None = None
_jwks_client_timestamp: float = 0
JWKS_CACHE_TTL = 3600  # 1 hour


def get_jwks_client(settings: Settings) -> PyJWKClient:
    """Get cached JWKS client for Supabase JWT verification."""
    global _jwks_client, _jwks_client_timestamp

    current_time = time.time()

    # Refresh if cache expired or not initialized
    if _jwks_client is None or (current_time - _jwks_client_timestamp) > JWKS_CACHE_TTL:
        jwks_url = f"{settings.supabase_url}/auth/v1/.well-known/jwks.json"
        _jwks_client = PyJWKClient(jwks_url)
        _jwks_client_timestamp = current_time

    return _jwks_client


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    settings: Settings = Depends(get_settings),
    db: Client = Depends(get_db),
) -> dict:
    """
    Validate JWT token using JWKS and return current user.

    Uses Supabase's JWKS endpoint for public key verification.
    """
    token = credentials.credentials

    try:
        # Get the signing key from JWKS
        jwks_client = get_jwks_client(settings)
        signing_key = jwks_client.get_signing_key_from_jwt(token)

        # Verify and decode the JWT
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256", "ES256"],
            audience="authenticated",
            issuer=f"{settings.supabase_url}/auth/v1",
        )

        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token: missing user ID",
                headers={"WWW-Authenticate": "Bearer"},
            )

    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token verification failed: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Fetch user from database
    database = Database(db)
    user = database.get_user_by_id(user_id)

    if user is None:
        # Auto-create user record for users created directly in Supabase Auth
        email = payload.get("email")
        user_data = {
            "id": user_id,
            "email": email,
            "display_name": None,
        }
        user = database.create_user(user_data)
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create user record",
            )

    return user


async def get_optional_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(
        HTTPBearer(auto_error=False)
    ),
    settings: Settings = Depends(get_settings),
    db: Client = Depends(get_db),
) -> dict | None:
    """
    Optionally validate JWT token and return user if present.

    Returns None if no token provided, useful for endpoints that
    work for both authenticated and anonymous users.
    """
    if credentials is None:
        return None

    try:
        # Get the signing key from JWKS
        jwks_client = get_jwks_client(settings)
        signing_key = jwks_client.get_signing_key_from_jwt(credentials.credentials)

        # Verify and decode the JWT
        payload = jwt.decode(
            credentials.credentials,
            signing_key.key,
            algorithms=["RS256", "ES256"],
            audience="authenticated",
            issuer=f"{settings.supabase_url}/auth/v1",
        )

        user_id: str = payload.get("sub")
        if user_id is None:
            return None

        database = Database(db)
        return database.get_user_by_id(user_id)

    except Exception:
        return None


def get_database(db: Client = Depends(get_db)) -> Database:
    """Get Database helper instance."""
    return Database(db)
