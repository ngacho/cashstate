"""Plaid-related schemas."""

from datetime import datetime
from pydantic import BaseModel


class LinkTokenRequest(BaseModel):
    """Request to create a Plaid Link token."""
    pass


class LinkTokenResponse(BaseModel):
    """Response containing a Plaid Link token."""

    link_token: str
    expiration: str


class ExchangeTokenRequest(BaseModel):
    """Request to exchange a Plaid public token."""

    public_token: str
    institution_id: str | None = None
    institution_name: str | None = None


class ExchangeTokenResponse(BaseModel):
    """Response after exchanging a public token."""

    item_id: str
    institution_id: str | None
    institution_name: str | None


class PlaidItemResponse(BaseModel):
    """Plaid item details."""

    id: str
    plaid_item_id: str
    institution_id: str | None
    institution_name: str | None
    status: str
    created_at: datetime
    updated_at: datetime
