"""Pydantic schemas for request/response validation."""

from app.schemas.common import (
    SuccessResponse,
    ErrorResponse,
    PaginatedResponse,
)
from app.schemas.auth import (
    RegisterRequest,
    LoginRequest,
    TokenResponse,
    RefreshRequest,
)
from app.schemas.plaid import (
    LinkTokenRequest,
    LinkTokenResponse,
    ExchangeTokenRequest,
    ExchangeTokenResponse,
    PlaidItemResponse,
)
from app.schemas.transaction import (
    TransactionResponse,
    TransactionListResponse,
)
from app.schemas.sync import (
    SyncTriggerResponse,
    SyncJobResponse,
    SyncStatusResponse,
)

__all__ = [
    # Common
    "SuccessResponse",
    "ErrorResponse",
    "PaginatedResponse",
    # Auth
    "RegisterRequest",
    "LoginRequest",
    "TokenResponse",
    "RefreshRequest",
    # Plaid
    "LinkTokenRequest",
    "LinkTokenResponse",
    "ExchangeTokenRequest",
    "ExchangeTokenResponse",
    "PlaidItemResponse",
    # Transactions
    "TransactionResponse",
    "TransactionListResponse",
    # Sync
    "SyncTriggerResponse",
    "SyncJobResponse",
    "SyncStatusResponse",
]
