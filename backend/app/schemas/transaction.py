"""Transaction schemas."""

from datetime import datetime
from typing import Any
from pydantic import BaseModel


class TransactionResponse(BaseModel):
    """Single transaction."""

    id: str
    plaid_item_id: str
    plaid_transaction_id: str
    account_id: str
    amount: float
    iso_currency_code: str | None
    date: str
    name: str
    merchant_name: str | None
    category: list[str] | None
    pending: bool
    created_at: datetime
    updated_at: datetime


class TransactionListResponse(BaseModel):
    """Paginated list of transactions."""

    items: list[TransactionResponse]
    total: int
    limit: int
    offset: int
    has_more: bool
