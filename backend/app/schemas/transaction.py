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
    created_at: datetime
    updated_at: datetime


class TransactionListResponse(BaseModel):
    """Paginated list of transactions."""

    items: list[TransactionResponse]
    total: int
    limit: int
    offset: int
