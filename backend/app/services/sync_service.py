"""Sync service - orchestrates Plaid transaction syncing."""

from datetime import datetime, timezone

from app.database import Database
from app.services import plaid_service


def sync_item(db: Database, plaid_item_id: str) -> dict:
    """
    Sync transactions for a single Plaid item.

    1. Creates a sync_job record.
    2. Fetches the plaid_item from DB for access_token + cursor.
    3. Calls plaid_service.sync_transactions in a loop (paginated).
    4. Upserts added/modified transactions, deletes removed ones.
    5. Updates the cursor on the plaid_item.
    6. Marks the sync_job as completed (or failed).

    Args:
        db: Database instance.
        plaid_item_id: The internal UUID of the plaid_item row.

    Returns:
        The completed sync_job dict.
    """
    now = datetime.now(timezone.utc).isoformat()

    # Create sync job
    job = db.create_sync_job({
        "plaid_item_id": plaid_item_id,
        "status": "pending",
        "transactions_added": 0,
        "transactions_modified": 0,
        "transactions_removed": 0,
    })
    job_id = job["id"]

    try:
        # Get plaid item
        item = db.get_plaid_item_by_id(plaid_item_id)
        if item is None:
            raise ValueError(f"Plaid item {plaid_item_id} not found")

        access_token = item["access_token"]
        cursor = item.get("cursor")

        # Mark job as in_progress
        db.update_sync_job(job_id, {
            "status": "in_progress",
            "started_at": now,
        })

        total_added = 0
        total_modified = 0
        total_removed = 0

        # Paginated sync loop
        has_more = True
        while has_more:
            result = plaid_service.sync_transactions(access_token, cursor)

            # Upsert added transactions
            if result["added"]:
                rows = [
                    {**txn, "plaid_item_id": plaid_item_id}
                    for txn in result["added"]
                ]
                db.upsert_transactions(rows)
                total_added += len(result["added"])

            # Upsert modified transactions
            if result["modified"]:
                rows = [
                    {**txn, "plaid_item_id": plaid_item_id}
                    for txn in result["modified"]
                ]
                db.upsert_transactions(rows)
                total_modified += len(result["modified"])

            # Delete removed transactions
            if result["removed"]:
                db.delete_transactions_by_plaid_ids(result["removed"])
                total_removed += len(result["removed"])

            cursor = result["next_cursor"]
            has_more = result["has_more"]

        # Update cursor on plaid item
        db.update_plaid_item(plaid_item_id, {
            "cursor": cursor,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        })

        # Mark job as completed
        completed_job = db.update_sync_job(job_id, {
            "status": "completed",
            "completed_at": datetime.now(timezone.utc).isoformat(),
            "transactions_added": total_added,
            "transactions_modified": total_modified,
            "transactions_removed": total_removed,
        })

        return completed_job

    except Exception as e:
        # Mark job as failed
        db.update_sync_job(job_id, {
            "status": "failed",
            "completed_at": datetime.now(timezone.utc).isoformat(),
            "error_message": str(e),
        })
        raise


def sync_all(db: Database) -> list[dict]:
    """
    Sync all active Plaid items.

    Returns:
        List of completed sync_job dicts.
    """
    items = db.get_active_plaid_items()
    results = []
    for item in items:
        try:
            job = sync_item(db, item["id"])
            results.append(job)
        except Exception:
            # Individual item failures don't stop the rest
            pass
    return results
