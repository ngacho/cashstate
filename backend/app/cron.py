"""Scheduled cron jobs for background tasks."""

from datetime import date, timedelta
from fastapi_utils.tasks import repeat_every
from app.database import Database, get_supabase_client
from app.services.simplefin_service import (
    fetch_accounts,
    parse_simplefin_accounts,
    parse_simplefin_transactions,
)
from app.services.snapshot_service import SnapshotService
from app.utils.encryption import decrypt_token
from app.config import get_settings


settings = get_settings()


@repeat_every(seconds=60 * 60 * 24)  # Run every 24 hours
async def sync_simplefin_transactions():
    """
    Auto-sync SimpleFin transactions for all active items.

    Runs daily to fetch new transactions from SimpleFin.
    Respects the 24-hour rate limit per item.
    """
    print("[CRON] Starting SimpleFin transaction sync...")

    try:
        # Get Supabase client with service role (admin access)
        client = get_supabase_client()
        db = Database(client)

        # Get all active SimpleFin items
        active_items = db.get_active_simplefin_items()

        if not active_items:
            print("[CRON] No active SimpleFin items to sync")
            return

        print(f"[CRON] Found {len(active_items)} active SimpleFin item(s)")

        synced_count = 0
        skipped_count = 0
        error_count = 0

        for item in active_items:
            try:
                # Check if we've synced in the last 24 hours (rate limit)
                if item.get("last_synced_at"):
                    from datetime import datetime, timezone

                    last_synced = item["last_synced_at"]
                    if isinstance(last_synced, str):
                        last_synced = datetime.fromisoformat(
                            last_synced.replace("Z", "+00:00")
                        )

                    time_since_sync = datetime.now(timezone.utc) - last_synced
                    if time_since_sync.total_seconds() < 86400:  # 24 hours
                        print(f"[CRON] Skipping item {item['id']} - synced recently")
                        skipped_count += 1
                        continue

                # Create sync job
                sync_job = db.create_simplefin_sync_job(
                    {
                        "user_id": item["user_id"],
                        "simplefin_item_id": item["id"],
                        "status": "running",
                    }
                )

                # Decrypt access URL
                access_url = decrypt_token(item["access_url"])

                # Fetch accounts and transactions
                # Get transactions from 30 days ago
                from datetime import datetime

                start_date = int((datetime.now() - timedelta(days=30)).timestamp())

                accounts_data = fetch_accounts(access_url, start_date=start_date)

                # Parse and upsert accounts
                accounts = parse_simplefin_accounts(
                    accounts_data,
                    item["id"],
                    item["user_id"],
                )

                upserted_accounts = []
                if accounts:
                    upserted_accounts = db.upsert_simplefin_accounts(accounts)

                # Build account ID map
                account_id_map = {
                    acc["simplefin_account_id"]: acc["id"] for acc in upserted_accounts
                }

                # Parse and upsert transactions
                transactions = parse_simplefin_transactions(
                    accounts_data,
                    account_id_map,
                    item["user_id"],
                )

                if transactions:
                    db.upsert_simplefin_transactions(transactions)

                # Update sync job
                db.update_simplefin_sync_job(
                    sync_job["id"],
                    {
                        "status": "completed",
                        "completed_at": "now()",
                        "accounts_synced": len(accounts),
                        "transactions_added": len(transactions),
                    },
                )

                # Update item's last_synced_at
                db.update_simplefin_item(
                    item["id"],
                    {
                        "last_synced_at": "now()",
                    },
                )

                print(
                    f"[CRON] Synced item {item['id']}: {len(accounts)} accounts, {len(transactions)} transactions"
                )
                synced_count += 1

            except Exception as e:
                print(f"[CRON] Error syncing item {item['id']}: {str(e)}")
                error_count += 1

                # Mark sync job as failed if it exists
                if "sync_job" in locals():
                    db.update_simplefin_sync_job(
                        sync_job["id"],
                        {
                            "status": "failed",
                            "completed_at": "now()",
                            "error_message": str(e),
                        },
                    )

        print(
            f"[CRON] SimpleFin sync complete: {synced_count} synced, {skipped_count} skipped, {error_count} errors"
        )

    except Exception as e:
        print(f"[CRON] Fatal error in SimpleFin sync: {str(e)}")


@repeat_every(seconds=60 * 60 * 24)  # Run every 24 hours
async def update_daily_snapshots():
    """
    Store daily account balance snapshots for all users.

    Snapshots current balances from simplefin_accounts table.
    Net worth is calculated on-the-fly when requested.
    """
    print("[CRON] Starting daily snapshots update...")

    try:
        # Get Supabase client with service role
        client = get_supabase_client()
        db = Database(client)

        # Get all users who have SimpleFin items
        result = (
            client.table("simplefin_items")
            .select("user_id")
            .eq("status", "active")
            .execute()
        )

        if not result.data:
            print("[CRON] No users with active SimpleFin items")
            return

        # Get unique user IDs
        user_ids = list(set(item["user_id"] for item in result.data))
        print(f"[CRON] Updating snapshots for {len(user_ids)} user(s)")

        success_count = 0
        error_count = 0

        for user_id in user_ids:
            try:
                snapshot_service = SnapshotService(db)

                # Store account balance snapshots for today
                await snapshot_service.store_daily_account_balances(
                    user_id=user_id, snapshot_date=date.today()
                )

                print(f"[CRON] Updated snapshots for user {user_id}")
                success_count += 1

            except Exception as e:
                print(f"[CRON] Error updating snapshots for user {user_id}: {str(e)}")
                error_count += 1

        print(
            f"[CRON] Snapshots update complete: {success_count} succeeded, {error_count} errors"
        )

    except Exception as e:
        print(f"[CRON] Fatal error in snapshots update: {str(e)}")
