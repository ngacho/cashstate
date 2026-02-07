"""Plaid integration router."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.database import Database
from app.dependencies import get_current_user, get_database
from app.schemas.plaid import (
    LinkTokenRequest,
    LinkTokenResponse,
    ExchangeTokenRequest,
    ExchangeTokenResponse,
    PlaidItemResponse,
)
from app.services import plaid_service


router = APIRouter(prefix="/plaid", tags=["Plaid"])


@router.post("/create-link-token", response_model=LinkTokenResponse)
async def create_link_token(
    user: dict = Depends(get_current_user),
):
    """Create a Plaid Link token for initializing the Link flow."""
    result = plaid_service.create_link_token(user["id"])
    return LinkTokenResponse(
        link_token=result["link_token"],
        expiration=result["expiration"],
    )


@router.post("/exchange-token", response_model=ExchangeTokenResponse)
async def exchange_token(
    request: ExchangeTokenRequest,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """
    Exchange a Plaid public token for an access token.

    Stores the resulting Plaid item in the database.
    """
    result = plaid_service.exchange_public_token(request.public_token)

    # Store plaid item in DB
    item = db.create_plaid_item({
        "user_id": user["id"],
        "plaid_item_id": result["item_id"],
        "access_token": result["access_token"],
        "institution_id": request.institution_id,
        "institution_name": request.institution_name,
        "status": "active",
    })

    return ExchangeTokenResponse(
        item_id=item["id"],
        institution_id=request.institution_id,
        institution_name=request.institution_name,
    )


@router.get("/items", response_model=list[PlaidItemResponse])
async def list_items(
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """List all Plaid items for the current user."""
    items = db.get_user_plaid_items(user["id"])
    return [
        PlaidItemResponse(
            id=item["id"],
            plaid_item_id=item["plaid_item_id"],
            institution_id=item.get("institution_id"),
            institution_name=item.get("institution_name"),
            status=item["status"],
            created_at=item["created_at"],
            updated_at=item["updated_at"],
        )
        for item in items
    ]
