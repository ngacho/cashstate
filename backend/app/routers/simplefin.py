"""SimpleFin integration router."""

from fastapi import APIRouter, Depends, HTTPException

from app.config import get_settings
from app.database import Database
from app.dependencies import get_current_user, get_database
from app.schemas.simplefin import (
    SetupTokenRequest,
    SetupTokenResponse,
    SimplefinItemResponse,
    SimplefinAccountResponse,
    SimplefinTransactionResponse,
    SyncResponse,
    FetchAccountsResponse,
)
from app.services import simplefin_service
from app.utils.encryption import encrypt_token, decrypt_token


router = APIRouter(prefix="/simplefin", tags=["SimpleFin"])


@router.post("/setup", response_model=SetupTokenResponse)
async def exchange_setup_token(
    request: SetupTokenRequest,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """
    Exchange a SimpleFin setup token for an access URL.

    This can only be done once per setup token. The access URL is stored
    encrypted and used for all subsequent data fetches.

    If user already has a SimpleFin item, returns the existing item instead
    of trying to claim again.
    """
    # Check if user already has a SimpleFin item
    existing_items = db.get_user_simplefin_items(user["id"])
    if existing_items:
        # Return the first active item
        for item in existing_items:
            if item["status"] == "active":
                return SetupTokenResponse(
                    item_id=item["id"],
                    institution_name=item["institution_name"],
                )

    try:
        # In development mode, check if we have a pre-claimed access URL in env
        settings = get_settings()
        if settings.is_development and settings.simplefin_access_url:
            access_url = settings.simplefin_access_url
        else:
            # Claim the access URL from SimpleFin
            access_url = simplefin_service.claim_access_url(request.setup_token)

        # Validate the access URL
        if not simplefin_service.validate_access_url(access_url):
            raise HTTPException(
                status_code=400,
                detail="Invalid access URL received from SimpleFin",
            )

        # Encrypt the access URL before storing
        encrypted_url = encrypt_token(access_url)

        # Store SimpleFin item in DB
        item = db.create_simplefin_item({
            "user_id": user["id"],
            "access_url": encrypted_url,
            "institution_name": request.institution_name or "SimpleFin Bank",
            "status": "active",
        })

        return SetupTokenResponse(
            item_id=item["id"],
            institution_name=item["institution_name"],
        )

    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Failed to exchange setup token: {str(e)}",
        )


@router.get("/items", response_model=list[SimplefinItemResponse])
async def list_items(
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """List all SimpleFin items for the current user."""
    items = db.get_user_simplefin_items(user["id"])
    return [
        SimplefinItemResponse(
            id=item["id"],
            institution_name=item.get("institution_name"),
            status=item["status"],
            last_synced_at=item.get("last_synced_at"),
            created_at=item["created_at"],
            updated_at=item["updated_at"],
        )
        for item in items
    ]


@router.delete("/items/{item_id}")
async def delete_item(
    item_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """Delete a SimpleFin item and all associated transactions."""
    # Verify the item belongs to the user
    item = db.get_simplefin_item_by_id(item_id)
    if not item:
        raise HTTPException(status_code=404, detail="SimpleFin item not found")

    if item["user_id"] != user["id"]:
        raise HTTPException(
            status_code=403,
            detail="Not authorized to delete this item",
        )

    # Delete the item (cascades to transactions due to FK constraint)
    db.delete_simplefin_item(item_id)

    return {"success": True, "message": "SimpleFin item deleted"}


@router.get("/accounts/{item_id}", response_model=list[SimplefinAccountResponse])
async def list_accounts(
    item_id: str,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """List all accounts for a SimpleFin item."""
    # Verify the item belongs to the user
    item = db.get_simplefin_item_by_id(item_id)
    if not item:
        raise HTTPException(status_code=404, detail="SimpleFin item not found")

    if item["user_id"] != user["id"]:
        raise HTTPException(
            status_code=403,
            detail="Not authorized to access this item",
        )

    accounts = db.get_simplefin_accounts_by_item(item_id)
    return accounts


@router.get("/transactions", response_model=list[SimplefinTransactionResponse])
async def list_transactions(
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
    date_from: int | None = None,
    date_to: int | None = None,
    limit: int = 50,
    offset: int = 0,
):
    """List all SimpleFin transactions for the current user."""
    transactions = db.get_user_simplefin_transactions(
        user_id=user["id"],
        date_from=date_from,
        date_to=date_to,
        limit=limit,
        offset=offset,
    )
    return transactions


@router.post("/sync/{item_id}", response_model=SyncResponse)
async def sync_item(
    item_id: str,
    start_date: int | None = None,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """
    Fetch latest accounts and transactions from SimpleFin for a specific item.

    SimpleFin has no cursor-based sync - this fetches all available data.
    Rate limited to 24 requests per day by SimpleFin.

    Args:
        item_id: SimpleFin item ID.
        start_date: Optional start date (Unix timestamp in seconds since epoch).
                   Example: 1704067200 for 2024-01-01.
                   If not provided, SimpleFin returns recent transactions only.
        user: Current authenticated user (injected).
        db: Database instance (injected).
    """
    # Verify the item belongs to the user
    item = db.get_simplefin_item_by_id(item_id)
    if not item:
        raise HTTPException(status_code=404, detail="SimpleFin item not found")

    if item["user_id"] != user["id"]:
        raise HTTPException(
            status_code=403,
            detail="Not authorized to sync this item",
        )

    # Rate limiting: Check last sync time (24 hour cooldown)
    if item.get("last_synced_at"):
        from datetime import datetime, timezone, timedelta

        last_synced = item["last_synced_at"]
        # Handle both string and datetime objects
        if isinstance(last_synced, str):
            last_synced = datetime.fromisoformat(last_synced.replace('Z', '+00:00'))

        now = datetime.now(timezone.utc)
        time_since_last_sync = now - last_synced

        if time_since_last_sync < timedelta(hours=24):
            hours_remaining = 24 - (time_since_last_sync.total_seconds() / 3600)
            raise HTTPException(
                status_code=429,
                detail=f"Rate limited. You can sync again in {hours_remaining:.1f} hours. "
                       f"SimpleFin allows 24 syncs per day to prevent excessive API usage.",
            )

    try:
        # Create SimpleFin sync job
        sync_job = db.create_simplefin_sync_job({
            "simplefin_item_id": item_id,
            "status": "running",
        })

        # Decrypt the access URL
        access_url = decrypt_token(item["access_url"])

        # Fetch accounts and transactions from SimpleFin
        accounts_data = simplefin_service.fetch_accounts(
            access_url,
            start_date=start_date,
        )

        # Parse and upsert accounts (with balance info)
        accounts = simplefin_service.parse_simplefin_accounts(
            accounts_data,
            item_id,
            user["id"],
        )
        upserted_accounts = []
        if accounts:
            upserted_accounts = db.upsert_simplefin_accounts(accounts)

        # Build mapping of SimpleFin account IDs to our UUIDs
        account_id_map = {
            acc["simplefin_account_id"]: acc["id"]
            for acc in upserted_accounts
        }

        # Parse and upsert transactions using the account ID map
        transactions = simplefin_service.parse_simplefin_transactions(
            accounts_data,
            account_id_map,
        )
        if transactions:
            db.upsert_simplefin_transactions(transactions)

        # Update sync job
        db.update_simplefin_sync_job(sync_job["id"], {
            "status": "completed",
            "completed_at": "now()",
            "accounts_synced": len(accounts),
            "transactions_added": len(transactions),
            "transactions_updated": 0,
        })

        # Update item's last_synced_at
        db.update_simplefin_item(item_id, {
            "last_synced_at": "now()",
        })

        return {
            "success": True,
            "sync_job_id": sync_job["id"],
            "accounts_synced": len(accounts),
            "transactions_added": len(transactions),
            "transactions_updated": 0,
            "errors": accounts_data.get("errors", []),
        }

    except Exception as e:
        # Mark sync job as failed
        if 'sync_job' in locals():
            db.update_simplefin_sync_job(sync_job["id"], {
                "status": "failed",
                "completed_at": "now()",
                "error_message": str(e),
            })
        raise HTTPException(
            status_code=500,
            detail=f"Failed to sync SimpleFin data: {str(e)}",
        )


@router.get("/raw-accounts/{item_id}", response_model=FetchAccountsResponse)
async def fetch_raw_accounts(
    item_id: str,
    start_date: int | None = None,
    user: dict = Depends(get_current_user),
    db: Database = Depends(get_database),
):
    """
    Fetch raw account data from SimpleFin API (for debugging/preview).

    This returns the raw SimpleFin API response and does NOT store anything.
    Use POST /sync/{item_id} to actually sync and store data.

    Args:
        item_id: SimpleFin item ID.
        start_date: Optional start date (Unix timestamp in seconds since epoch).
        user: Current authenticated user (injected).
        db: Database instance (injected).
    """
    # Verify the item belongs to the user
    item = db.get_simplefin_item_by_id(item_id)
    if not item:
        raise HTTPException(status_code=404, detail="SimpleFin item not found")

    if item["user_id"] != user["id"]:
        raise HTTPException(
            status_code=403,
            detail="Not authorized to access this item",
        )

    try:
        # Decrypt the access URL
        access_url = decrypt_token(item["access_url"])

        # Fetch accounts from SimpleFin
        data = simplefin_service.fetch_accounts(
            access_url,
            start_date=start_date,
        )

        return FetchAccountsResponse(
            accounts=data.get("accounts", []),
            errors=data.get("errors", []),
        )

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch accounts: {str(e)}",
        )
