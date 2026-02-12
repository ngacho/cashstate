"""SimpleFin-specific schemas optimized for SimpleFin's data structure."""

from datetime import datetime
from pydantic import BaseModel, Field


# ============================================================================
# Request Schemas
# ============================================================================

class SetupTokenRequest(BaseModel):
    """Request to exchange a SimpleFin setup token for an access URL."""

    setup_token: str = Field(..., description="Base64-encoded SimpleFin setup token")
    institution_name: str | None = Field(None, description="User-provided name for this connection")


# ============================================================================
# SimpleFin Item Schemas
# ============================================================================

class SimplefinItemResponse(BaseModel):
    """SimpleFin connection/item details."""

    id: str
    institution_name: str | None
    status: str
    last_synced_at: datetime | None
    created_at: datetime
    updated_at: datetime


class SetupTokenResponse(BaseModel):
    """Response after exchanging a setup token."""

    item_id: str
    institution_name: str | None


# ============================================================================
# SimpleFin Account Schemas
# ============================================================================

class SimplefinAccountResponse(BaseModel):
    """SimpleFin account with balance and institution info."""

    id: str
    simplefin_account_id: str
    name: str
    currency: str

    balance: float | None
    available_balance: float | None
    balance_date: int | None  # Unix timestamp

    organization_name: str | None
    organization_domain: str | None

    created_at: datetime
    updated_at: datetime


# ============================================================================
# SimpleFin Transaction Schemas
# ============================================================================

class SimplefinTransactionResponse(BaseModel):
    """SimpleFin transaction with all available fields."""

    id: str
    simplefin_account_id: str
    simplefin_transaction_id: str

    amount: float
    currency: str

    posted_date: int          # Unix timestamp
    transaction_date: int     # Unix timestamp

    description: str          # Raw merchant description
    payee: str | None        # Cleaned-up merchant name
    memo: str | None         # Additional notes

    pending: bool

    created_at: datetime
    updated_at: datetime


# ============================================================================
# SimpleFin Sync Schemas
# ============================================================================

class SyncResponse(BaseModel):
    """Response from a SimpleFin sync operation."""

    success: bool
    sync_job_id: str
    accounts_synced: int
    transactions_added: int
    transactions_updated: int
    errors: list[str] = []


class SimplefinSyncJobResponse(BaseModel):
    """SimpleFin sync job status."""

    id: str
    simplefin_item_id: str
    status: str
    accounts_synced: int
    transactions_added: int
    transactions_updated: int
    error_message: str | None
    created_at: datetime
    completed_at: datetime | None


# ============================================================================
# Raw SimpleFin API Response Schemas (for debugging/preview)
# ============================================================================

class SimplefinRawTransaction(BaseModel):
    """Raw transaction from SimpleFin API."""

    id: str
    posted: int
    amount: str
    description: str
    payee: str | None = None
    memo: str | None = None
    transacted_at: int


class SimplefinRawOrganization(BaseModel):
    """Organization info from SimpleFin API."""

    domain: str
    name: str
    url: str
    id: str


class SimplefinRawAccount(BaseModel):
    """Raw account from SimpleFin API."""

    id: str
    name: str
    currency: str
    balance: str
    available_balance: str = Field(alias="available-balance")
    balance_date: int = Field(alias="balance-date")
    transactions: list[SimplefinRawTransaction] = []
    org: SimplefinRawOrganization

    class Config:
        """Pydantic config to support field aliases."""

        populate_by_name = True


class FetchAccountsResponse(BaseModel):
    """Response from fetching SimpleFin accounts (raw API response)."""

    accounts: list[SimplefinRawAccount]
    errors: list[str] = []
