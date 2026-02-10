"""Encryption utilities for sensitive data."""

from cryptography.fernet import Fernet
from app.config import get_settings


def get_cipher() -> Fernet:
    """Get Fernet cipher instance using the encryption key from settings."""
    settings = get_settings()
    return Fernet(settings.encryption_key.encode())


def encrypt_token(token: str) -> str:
    """Encrypt a token (e.g., Plaid access token).

    Args:
        token: Plain text token to encrypt

    Returns:
        Encrypted token as a string
    """
    cipher = get_cipher()
    encrypted = cipher.encrypt(token.encode())
    return encrypted.decode()


def decrypt_token(encrypted_token: str) -> str:
    """Decrypt an encrypted token.

    Args:
        encrypted_token: Encrypted token string

    Returns:
        Decrypted plain text token
    """
    cipher = get_cipher()
    decrypted = cipher.decrypt(encrypted_token.encode())
    return decrypted.decode()
