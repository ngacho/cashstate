"""Authentication router."""

from fastapi import APIRouter, Depends, HTTPException, status
from supabase import Client
from gotrue.errors import AuthApiError

from app.database import get_db
from app.schemas.auth import (
    RegisterRequest,
    LoginRequest,
    TokenResponse,
    RefreshRequest,
)
from app.services.auth_service import AuthService


router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(
    request: RegisterRequest,
    db: Client = Depends(get_db),
):
    """
    Register a new user.

    Creates a new user account with the provided email and password.
    Returns access and refresh tokens on successful registration.
    """
    auth_service = AuthService(db)

    try:
        result = auth_service.register(
            email=request.email,
            password=request.password,
            display_name=request.display_name,
        )

        if not result.get("access_token"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Registration successful but email confirmation may be required",
            )

        return TokenResponse(
            access_token=result["access_token"],
            refresh_token=result["refresh_token"],
            expires_in=result["expires_in"],
            user_id=result["user_id"],
        )

    except AuthApiError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.post("/login", response_model=TokenResponse)
async def login(
    request: LoginRequest,
    db: Client = Depends(get_db),
):
    """
    Log in a user.

    Authenticates with email and password.
    Returns access and refresh tokens on success.
    """
    auth_service = AuthService(db)

    try:
        result = auth_service.login(
            email=request.email,
            password=request.password,
        )

        return TokenResponse(
            access_token=result["access_token"],
            refresh_token=result["refresh_token"],
            expires_in=result["expires_in"],
            user_id=result["user_id"],
        )

    except AuthApiError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(
    request: RefreshRequest,
    db: Client = Depends(get_db),
):
    """
    Refresh an access token.

    Exchange a refresh token for a new access token.
    """
    auth_service = AuthService(db)

    try:
        result = auth_service.refresh_token(request.refresh_token)

        return TokenResponse(
            access_token=result["access_token"],
            refresh_token=result["refresh_token"],
            expires_in=result["expires_in"],
            user_id=result["user_id"],
        )

    except AuthApiError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )
