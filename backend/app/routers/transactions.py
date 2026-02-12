"""Transactions router - SimpleFin only."""

from fastapi import APIRouter, Depends, HTTPException, Query

from app.database import Database
from app.dependencies import get_current_user, get_database
from app.schemas.transaction import (
    TransactionResponse,
    TransactionListResponse,
)


router = APIRouter(prefix="/transactions", tags=["Transactions"])


@router.get("", response_model=TransactionListResponse)
async def list_transactions(
    date_from: str | None = Query(None, description="Start date (YYYY-MM-DD)"),
    date_to: str | None = Query(None, description="End date (YYYY-MM-DD)"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """List SimpleFin transactions with optional date filters and pagination."""
    transactions = db.get_user_simplefin_transactions(
        user_id=user["id"],
        date_from=date_from,
        date_to=date_to,
        limit=limit,
        offset=offset,
    )
    total = db.count_user_simplefin_transactions(
        user_id=user["id"],
        date_from=date_from,
        date_to=date_to,
    )

    return TransactionListResponse(
        items=[TransactionResponse(**txn) for txn in transactions],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get("/{transaction_id}", response_model=TransactionResponse)
async def get_transaction(
    transaction_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Get a single SimpleFin transaction by ID."""
    transaction = db.get_simplefin_transaction_by_id(transaction_id)

    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")

    # Verify the transaction belongs to the user
    item = db.get_simplefin_item_by_id(transaction["simplefin_item_id"])
    if not item or item["user_id"] != user["id"]:
        raise HTTPException(
            status_code=403,
            detail="Not authorized to access this transaction",
        )

    return TransactionResponse(**transaction)
