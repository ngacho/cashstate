"""Transaction schemas - SimpleFin only."""

from datetime import datetime
from pydantic import BaseModel


class TransactionResponse(BaseModel):
    """Single SimpleFin transaction."""

    id: str
    simplefin_item_id: str
    simplefin_transaction_id: str
    account_id: str
    account_name: str | None
    amount: float
    currency: str | None
    date: str
    posted: datetime | None
    description: str
    payee: str | None
    pending: bool
    category_id: str | None = None
    subcategory_id: str | None = None
    created_at: datetime
    updated_at: datetime


class TransactionListResponse(BaseModel):
    """Paginated list of transactions."""

    items: list[TransactionResponse]
    total: int
    limit: int
    offset: int


class TransactionUpdate(BaseModel):
    """Update transaction categorization."""

    category_id: str | None = None
    subcategory_id: str | None = None


class TransactionBatchUpdateItem(BaseModel):
    """Single transaction update in a batch."""

    transaction_id: str
    category_id: str | None = None
    subcategory_id: str | None = None


class TransactionBatchUpdate(BaseModel):
    """Batch update multiple transactions."""

    updates: list[TransactionBatchUpdateItem]


class TransactionBatchUpdateResponse(BaseModel):
    """Response from batch update."""

    updated_count: int
    failed_count: int
    failed_ids: list[str] = []
