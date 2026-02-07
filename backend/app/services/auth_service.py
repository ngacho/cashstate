"""Authentication service using Supabase Auth."""

from supabase import Client
from gotrue.errors import AuthApiError

from app.database import Database


class AuthService:
    """Service for authentication operations."""

    def __init__(self, client: Client):
        self.client = client
        self.db = Database(client)

    def register(self, email: str, password: str, display_name: str | None = None) -> dict:
        """
        Register a new user.

        Args:
            email: User's email
            password: User's password
            display_name: Optional display name

        Returns:
            Dict with user info and tokens

        Raises:
            AuthApiError: If registration fails
        """
        # Create user in Supabase Auth
        auth_response = self.client.auth.sign_up({
            "email": email,
            "password": password,
        })

        if auth_response.user is None:
            raise AuthApiError("Registration failed", 400)

        user_id = auth_response.user.id

        # Create user profile in our users table
        user_data = {
            "id": user_id,
            "email": email,
            "display_name": display_name,
        }

        self.db.create_user(user_data)

        return {
            "user_id": user_id,
            "email": email,
            "access_token": auth_response.session.access_token if auth_response.session else None,
            "refresh_token": auth_response.session.refresh_token if auth_response.session else None,
            "expires_in": auth_response.session.expires_in if auth_response.session else None,
        }

    def login(self, email: str, password: str) -> dict:
        """
        Log in a user.

        Args:
            email: User's email
            password: User's password

        Returns:
            Dict with tokens and user info

        Raises:
            AuthApiError: If login fails
        """
        auth_response = self.client.auth.sign_in_with_password({
            "email": email,
            "password": password,
        })

        if auth_response.user is None or auth_response.session is None:
            raise AuthApiError("Login failed", 401)

        return {
            "user_id": auth_response.user.id,
            "email": auth_response.user.email,
            "access_token": auth_response.session.access_token,
            "refresh_token": auth_response.session.refresh_token,
            "expires_in": auth_response.session.expires_in,
        }

    def refresh_token(self, refresh_token: str) -> dict:
        """
        Refresh an access token.

        Args:
            refresh_token: The refresh token

        Returns:
            Dict with new tokens

        Raises:
            AuthApiError: If refresh fails
        """
        auth_response = self.client.auth.refresh_session(refresh_token)

        if auth_response.session is None:
            raise AuthApiError("Token refresh failed", 401)

        return {
            "access_token": auth_response.session.access_token,
            "refresh_token": auth_response.session.refresh_token,
            "expires_in": auth_response.session.expires_in,
            "user_id": auth_response.user.id if auth_response.user else None,
        }

    def logout(self) -> None:
        """Log out the current user."""
        self.client.auth.sign_out()

    def get_user_by_token(self, token: str) -> dict | None:
        """
        Get user info from an access token.

        Args:
            token: Access token

        Returns:
            User dict or None
        """
        try:
            user_response = self.client.auth.get_user(token)
            if user_response.user:
                return self.db.get_user_by_id(user_response.user.id)
            return None
        except AuthApiError:
            return None
