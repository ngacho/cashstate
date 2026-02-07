"""Transactions router."""

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.database import Database
from app.dependencies import get_current_user, get_database
from app.schemas.transaction import TransactionResponse, TransactionListResponse


router = APIRouter(prefix="/transactions", tags=["Transactions"])


@router.get("", response_model=TransactionListResponse)
async def list_transactions(
    date_from: str | None = Query(None, description="Filter from date (YYYY-MM-DD)"),
    date_to: str | None = Query(None, description="Filter to date (YYYY-MM-DD)"),
    limit: int = Query(50, ge=1, le=200, description="Max results"),
    offset: int = Query(0, ge=0, description="Offset for pagination"),
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """List transactions for the current user with optional date filters."""
    transactions = db.get_user_transactions(
        user_id=user["id"],
        date_from=date_from,
        date_to=date_to,
        limit=limit,
        offset=offset,
    )
    total = db.count_user_transactions(
        user_id=user["id"],
        date_from=date_from,
        date_to=date_to,
    )

    return TransactionListResponse(
        items=[
            TransactionResponse(
                id=txn["id"],
                plaid_item_id=txn["plaid_item_id"],
                plaid_transaction_id=txn["plaid_transaction_id"],
                account_id=txn["account_id"],
                amount=txn["amount"],
                iso_currency_code=txn.get("iso_currency_code"),
                date=txn["date"],
                name=txn["name"],
                merchant_name=txn.get("merchant_name"),
                category=txn.get("category"),
                pending=txn["pending"],
                created_at=txn["created_at"],
                updated_at=txn["updated_at"],
            )
            for txn in transactions
        ],
        total=total,
        limit=limit,
        offset=offset,
        has_more=(offset + limit) < total,
    )


@router.get("/{transaction_id}", response_model=TransactionResponse)
async def get_transaction(
    transaction_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Get a single transaction by ID."""
    txn = db.get_transaction_by_id(transaction_id)
    if txn is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found",
        )

    # Verify ownership via plaid_item
    item = db.get_plaid_item_by_id(txn["plaid_item_id"])
    if item is None or item["user_id"] != user["id"]:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found",
        )

    return TransactionResponse(
        id=txn["id"],
        plaid_item_id=txn["plaid_item_id"],
        plaid_transaction_id=txn["plaid_transaction_id"],
        account_id=txn["account_id"],
        amount=txn["amount"],
        iso_currency_code=txn.get("iso_currency_code"),
        date=txn["date"],
        name=txn["name"],
        merchant_name=txn.get("merchant_name"),
        category=txn.get("category"),
        pending=txn["pending"],
        created_at=txn["created_at"],
        updated_at=txn["updated_at"],
    )
