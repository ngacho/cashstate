"""Transactions router - SimpleFin only."""

from fastapi import APIRouter, Depends, HTTPException, Query

from app.database import Database
from app.dependencies import get_current_user, get_database
from app.logging_config import get_logger
from app.schemas.transaction import (
    TransactionResponse,
    TransactionListResponse,
    TransactionUpdate,
    TransactionBatchUpdate,
    TransactionBatchUpdateResponse,
)


router = APIRouter(prefix="/transactions", tags=["Transactions"])
logger = get_logger("transactions")


@router.get("", response_model=TransactionListResponse)
async def list_transactions(
    date_from: str | None = Query(None, description="Start date (YYYY-MM-DD)"),
    date_to: str | None = Query(None, description="End date (YYYY-MM-DD)"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """List SimpleFin transactions with account info using joined view."""
    transactions = db.get_user_transactions_with_account_info(
        user_id=user["id"],
        date_from=date_from,
        date_to=date_to,
        limit=limit,
        offset=offset,
    )
    total = db.count_user_transactions_with_account_info(
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
    """Get a single SimpleFin transaction by ID with account info."""
    # Query from transactions_view to get joined data
    result = (
        db.client.table("transactions_view")
        .select("*")
        .eq("id", transaction_id)
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Transaction not found")

    transaction = result.data[0]

    # Verify the transaction belongs to the user (RLS should handle this, but double-check)
    if transaction["user_id"] != user["id"]:
        raise HTTPException(
            status_code=403,
            detail="Not authorized to access this transaction",
        )

    return TransactionResponse(**transaction)


@router.patch("/{transaction_id}", response_model=TransactionResponse)
async def update_transaction(
    transaction_id: str,
    update: TransactionUpdate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Update transaction categorization (category_id, subcategory_id)."""
    # Get existing transaction
    transaction = db.get_simplefin_transaction_by_id(transaction_id)

    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")

    # Verify ownership
    if transaction["user_id"] != user["id"]:
        raise HTTPException(
            status_code=403,
            detail="Not authorized to update this transaction",
        )

    # Update only the categorization fields
    update_data = {}
    if update.category_id is not None:
        update_data["category_id"] = update.category_id
    if update.subcategory_id is not None:
        update_data["subcategory_id"] = update.subcategory_id

    if not update_data:
        # No updates provided, return as-is
        return TransactionResponse(**transaction)

    # Perform update
    updated_transaction = db.update_simplefin_transaction(
        transaction_id=transaction_id,
        updates=update_data,
    )

    return TransactionResponse(**updated_transaction)


@router.patch("/batch/categorize", response_model=TransactionBatchUpdateResponse)
async def batch_update_transactions(
    batch: TransactionBatchUpdate,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Batch update transaction categorizations - TRUE batch with single SQL query."""
    logger.info(
        f"[PATCH /transactions/batch/categorize] User: {user['id']}, Updates: {len(batch.updates)}"
    )

    # Extract all transaction IDs
    transaction_ids = [item.transaction_id for item in batch.updates]

    # Batch fetch all transactions in ONE query
    transactions = db.get_simplefin_transactions_by_ids(transaction_ids)
    transaction_map = {tx["id"]: tx for tx in transactions}
    logger.debug(
        f"[PATCH /transactions/batch/categorize] Fetched {len(transactions)} transactions from DB"
    )

    # Verify ownership and build valid updates
    failed_ids = []
    valid_updates = []

    for item in batch.updates:
        transaction = transaction_map.get(item.transaction_id)

        if not transaction:
            failed_ids.append(item.transaction_id)
            continue

        if transaction["user_id"] != user["id"]:
            failed_ids.append(item.transaction_id)
            continue

        # Build update data
        update_data = {"id": item.transaction_id}
        if item.category_id is not None:
            update_data["category_id"] = item.category_id
        if item.subcategory_id is not None:
            update_data["subcategory_id"] = item.subcategory_id

        if len(update_data) > 1:  # More than just 'id'
            valid_updates.append(update_data)

    # Batch update ALL valid transactions in ONE SQL query
    updated_count = 0
    if valid_updates:
        logger.debug(
            f"[PATCH /transactions/batch/categorize] Updating {len(valid_updates)} transactions"
        )
        updated_count = db.batch_update_simplefin_transactions(valid_updates)
        logger.info(
            f"[PATCH /transactions/batch/categorize] Successfully updated {updated_count} transactions"
        )
    else:
        logger.warning(
            "[PATCH /transactions/batch/categorize] No valid updates to process"
        )

    if failed_ids:
        logger.warning(
            f"[PATCH /transactions/batch/categorize] Failed IDs: {failed_ids}"
        )

    logger.info(
        f"[PATCH /transactions/batch/categorize] Complete: {updated_count} updated, {len(failed_ids)} failed"
    )

    return TransactionBatchUpdateResponse(
        updated_count=updated_count,
        failed_count=len(failed_ids),
        failed_ids=failed_ids,
    )
