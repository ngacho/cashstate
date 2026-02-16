"""Supabase client setup and database utilities."""

from functools import lru_cache
from supabase import create_client, Client
from postgrest import SyncPostgrestClient

from app.config import get_settings


@lru_cache
def get_supabase_client() -> Client:
    """Get cached Supabase client instance using secret key.

    Used for GoTrue auth operations (sign_up, sign_in, refresh).
    NOT suitable for RLS-protected table operations - use get_authenticated_postgrest_client() instead.
    """
    settings = get_settings()
    return create_client(
        settings.supabase_url,
        settings.supabase_secret_key
    )


def get_authenticated_postgrest_client(access_token: str) -> SyncPostgrestClient:
    """Create a PostgREST client authenticated with the user's JWT.

    Bypasses the Supabase Client (whose auth listener overwrites the
    Authorization header) and talks to PostgREST directly with the
    anon key as apikey and the user's JWT as Authorization.
    """
    settings = get_settings()
    return SyncPostgrestClient(
        base_url=f"{settings.supabase_url}/rest/v1",
        headers={
            "apikey": settings.supabase_publishable_key,
            "Authorization": f"Bearer {access_token}",
        },
    )


def get_db() -> Client:
    """Dependency for getting Supabase client for auth operations."""
    return get_supabase_client()


class Database:
    """Database helper class for CashState operations."""

    def __init__(self, client: Client | SyncPostgrestClient):
        self.client = client

    # --- Users ---

    def get_user_by_id(self, user_id: str) -> dict | None:
        result = self.client.table("users").select("*").eq("id", user_id).execute()
        return result.data[0] if result.data else None

    def get_user_by_email(self, email: str) -> dict | None:
        result = self.client.table("users").select("*").eq("email", email).execute()
        return result.data[0] if result.data else None

    def create_user(self, user_data: dict) -> dict:
        result = self.client.table("users").insert(user_data).execute()
        return result.data[0]

    def update_user(self, user_id: str, data: dict) -> dict:
        result = self.client.table("users").update(data).eq("id", user_id).execute()
        return result.data[0] if result.data else None

    # --- SimpleFin Items ---

    def create_simplefin_item(self, item_data: dict) -> dict:
        result = self.client.table("simplefin_items").insert(item_data).execute()
        return result.data[0]

    def get_simplefin_item_by_id(self, item_id: str) -> dict | None:
        result = self.client.table("simplefin_items").select("*").eq("id", item_id).execute()
        return result.data[0] if result.data else None

    def get_user_simplefin_items(self, user_id: str) -> list[dict]:
        result = (
            self.client.table("simplefin_items")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .execute()
        )
        return result.data

    def get_active_simplefin_items(self) -> list[dict]:
        result = (
            self.client.table("simplefin_items")
            .select("*")
            .eq("status", "active")
            .execute()
        )
        return result.data

    def get_user_active_simplefin_items(self, user_id: str) -> list[dict]:
        result = (
            self.client.table("simplefin_items")
            .select("*")
            .eq("user_id", user_id)
            .eq("status", "active")
            .execute()
        )
        return result.data

    def update_simplefin_item(self, item_id: str, data: dict) -> dict:
        result = self.client.table("simplefin_items").update(data).eq("id", item_id).execute()
        return result.data[0] if result.data else None

    def delete_simplefin_item(self, item_id: str) -> None:
        self.client.table("simplefin_items").delete().eq("id", item_id).execute()

    # --- SimpleFin Accounts ---

    def upsert_simplefin_accounts(self, accounts: list[dict]) -> list[dict]:
        """Upsert SimpleFin accounts (updates balance and org info on each sync)."""
        if not accounts:
            return []
        result = (
            self.client.table("simplefin_accounts")
            .upsert(accounts, on_conflict="user_id,simplefin_item_id,simplefin_account_id")
            .execute()
        )
        return result.data

    def get_simplefin_accounts_by_item(self, item_id: str) -> list[dict]:
        """Get all accounts for a SimpleFin item."""
        result = (
            self.client.table("simplefin_accounts")
            .select("*")
            .eq("simplefin_item_id", item_id)
            .execute()
        )
        return result.data

    def get_simplefin_account_by_simplefin_id(
        self, item_id: str, simplefin_account_id: str
    ) -> dict | None:
        """Get account by SimpleFin's account ID."""
        result = (
            self.client.table("simplefin_accounts")
            .select("*")
            .eq("simplefin_item_id", item_id)
            .eq("simplefin_account_id", simplefin_account_id)
            .execute()
        )
        return result.data[0] if result.data else None

    # --- SimpleFin Transactions ---

    def upsert_simplefin_transactions(self, transactions: list[dict]) -> list[dict]:
        """Upsert SimpleFin transactions."""
        if not transactions:
            return []
        result = (
            self.client.table("simplefin_transactions")
            .upsert(transactions, on_conflict="simplefin_transaction_id")
            .execute()
        )
        return result.data

    def get_simplefin_transaction_by_id(self, transaction_id: str) -> dict | None:
        result = (
            self.client.table("simplefin_transactions")
            .select("*")
            .eq("id", transaction_id)
            .execute()
        )
        return result.data[0] if result.data else None

    def update_simplefin_transaction(
        self, transaction_id: str, updates: dict
    ) -> dict | None:
        """Update a SimpleFin transaction (e.g., categorization)."""
        result = (
            self.client.table("simplefin_transactions")
            .update(updates)
            .eq("id", transaction_id)
            .execute()
        )
        return result.data[0] if result.data else None

    def get_simplefin_transactions_by_ids(self, transaction_ids: list[str]) -> list[dict]:
        """Batch fetch SimpleFin transactions by IDs in ONE query."""
        result = (
            self.client.table("simplefin_transactions")
            .select("*")
            .in_("id", transaction_ids)
            .execute()
        )
        return result.data

    def batch_update_simplefin_transactions(self, updates: list[dict]) -> int:
        """Batch update multiple SimpleFin transactions in ONE SQL query using RPC.

        Args:
            updates: List of dicts with 'id' and fields to update (category_id, subcategory_id)

        Returns:
            Number of transactions updated
        """
        import logging
        logger = logging.getLogger("cashstate.database")

        if not updates:
            logger.warning("[DB] batch_update_simplefin_transactions: No updates provided")
            return 0

        logger.info(f"[DB] Batch updating {len(updates)} transactions")
        logger.debug(f"[DB] Sample update: {updates[0] if updates else 'None'}")

        # Build arrays for batch RPC call
        transaction_ids = [u["id"] for u in updates]
        category_ids = [u.get("category_id") for u in updates]
        subcategory_ids = [u.get("subcategory_id") for u in updates]

        # Call stored procedure that does batch update in single SQL
        result = self.client.rpc(
            "batch_update_transaction_categories",
            {
                "transaction_ids": transaction_ids,
                "category_ids": category_ids,
                "subcategory_ids": subcategory_ids,
            },
        ).execute()

        # RPC returns number of updated rows
        updated_count = result.data if isinstance(result.data, int) else len(updates)
        logger.info(f"[DB] ✓ Batch update complete: {updated_count} transactions updated")

        return updated_count

    def get_user_simplefin_transactions(
        self,
        user_id: str,
        date_from: int | None = None,
        date_to: int | None = None,
        limit: int = 50,
        offset: int = 0,
    ) -> list[dict]:
        """Get user's SimpleFin transactions.

        Args:
            user_id: User UUID
            date_from: Unix timestamp (seconds since epoch)
            date_to: Unix timestamp (seconds since epoch)
            limit: Max number of results
            offset: Offset for pagination
        """
        query = self.client.table("simplefin_transactions").select("*")
        query = query.eq("user_id", user_id)

        # Note: Use 'is not None' to handle edge case where date_from could be 0 (Unix epoch)
        if date_from is not None:
            query = query.gte("posted_date", date_from)
        if date_to is not None:
            # Use lt (less than) not lte to exclude transactions at exactly the end timestamp
            # This ensures when querying for a month, we don't include the first moment of next month
            query = query.lt("posted_date", date_to)
        result = (
            query.order("posted_date", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        return result.data

    def count_user_simplefin_transactions(
        self,
        user_id: str,
        date_from: int | None = None,
        date_to: int | None = None,
    ) -> int:
        """Count user's SimpleFin transactions."""
        query = self.client.table("simplefin_transactions").select("id", count="exact")
        query = query.eq("user_id", user_id)

        if date_from:
            query = query.gte("posted_date", date_from)
        if date_to:
            query = query.lte("posted_date", date_to)
        result = query.execute()
        return result.count if result.count is not None else 0

    def get_user_transactions_with_account_info(
        self,
        user_id: str,
        date_from: str | None = None,
        date_to: str | None = None,
        limit: int = 50,
        offset: int = 0,
    ) -> list[dict]:
        """Get user's transactions with joined account information from transactions_view.

        This method queries the transactions_view which joins transactions with accounts
        to provide all fields needed for the TransactionResponse schema.

        Args:
            user_id: User UUID
            date_from: Start date in YYYY-MM-DD format
            date_to: End date in YYYY-MM-DD format
            limit: Max number of results
            offset: Offset for pagination

        Returns:
            List of transaction dicts with account info (simplefin_item_id, account_name, etc.)
        """
        query = self.client.table("transactions_view").select("*")
        query = query.eq("user_id", user_id)

        if date_from:
            query = query.gte("date", date_from)
        if date_to:
            query = query.lte("date", date_to)

        result = (
            query.order("posted", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        return result.data

    def count_user_transactions_with_account_info(
        self,
        user_id: str,
        date_from: str | None = None,
        date_to: str | None = None,
    ) -> int:
        """Count user's transactions from the transactions_view.

        Args:
            user_id: User UUID
            date_from: Start date in YYYY-MM-DD format
            date_to: End date in YYYY-MM-DD format

        Returns:
            Total count of matching transactions
        """
        query = self.client.table("transactions_view").select("id", count="exact")
        query = query.eq("user_id", user_id)

        if date_from:
            query = query.gte("date", date_from)
        if date_to:
            query = query.lte("date", date_to)

        result = query.execute()
        return result.count if result.count is not None else 0

    # --- SimpleFin Sync Jobs ---

    def create_simplefin_sync_job(self, job_data: dict) -> dict:
        """Create SimpleFin sync job."""
        result = self.client.table("simplefin_sync_jobs").insert(job_data).execute()
        return result.data[0]

    def get_simplefin_sync_job_by_id(self, job_id: str) -> dict | None:
        result = self.client.table("simplefin_sync_jobs").select("*").eq("id", job_id).execute()
        return result.data[0] if result.data else None

    def get_simplefin_sync_jobs_for_user(self, user_id: str, limit: int = 20) -> list[dict]:
        """Get user's SimpleFin sync jobs."""
        result = (
            self.client.table("simplefin_sync_jobs")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return result.data

    def update_simplefin_sync_job(self, job_id: str, data: dict) -> dict:
        result = self.client.table("simplefin_sync_jobs").update(data).eq("id", job_id).execute()
        return result.data[0] if result.data else None

    # --- Categories ---

    def get_categories(self, user_id: str) -> list[dict]:
        """Get all categories visible to user (system + user's own)."""
        result = (
            self.client.table("categories")
            .select("*")
            .order("display_order")
            .order("name")
            .execute()
        )
        return result.data

    def get_category_by_id(self, category_id: str) -> dict | None:
        """Get category by ID."""
        result = (
            self.client.table("categories")
            .select("*")
            .eq("id", category_id)
            .execute()
        )
        return result.data[0] if result.data else None

    def create_category(self, category_data: dict) -> dict:
        """Create a new user category."""
        result = self.client.table("categories").insert(category_data).execute()
        return result.data[0]

    def update_category(self, category_id: str, data: dict) -> dict | None:
        """Update a category."""
        result = (
            self.client.table("categories")
            .update(data)
            .eq("id", category_id)
            .execute()
        )
        return result.data[0] if result.data else None

    def delete_category(self, category_id: str) -> None:
        """Delete a category."""
        self.client.table("categories").delete().eq("id", category_id).execute()

    # --- Subcategories ---

    def get_subcategories(self, category_id: str | None = None) -> list[dict]:
        """Get subcategories, optionally filtered by category."""
        query = self.client.table("subcategories").select("*")
        if category_id:
            query = query.eq("category_id", category_id)
        result = query.order("display_order").order("name").execute()
        return result.data

    def get_subcategory_by_id(self, subcategory_id: str) -> dict | None:
        """Get subcategory by ID."""
        result = (
            self.client.table("subcategories")
            .select("*")
            .eq("id", subcategory_id)
            .execute()
        )
        return result.data[0] if result.data else None

    def create_subcategory(self, subcategory_data: dict) -> dict:
        """Create a new user subcategory."""
        result = self.client.table("subcategories").insert(subcategory_data).execute()
        return result.data[0]

    def update_subcategory(self, subcategory_id: str, data: dict) -> dict | None:
        """Update a subcategory."""
        result = (
            self.client.table("subcategories")
            .update(data)
            .eq("id", subcategory_id)
            .execute()
        )
        return result.data[0] if result.data else None

    def delete_subcategory(self, subcategory_id: str) -> None:
        """Delete a subcategory."""
        self.client.table("subcategories").delete().eq("id", subcategory_id).execute()

    # ========================================================================
    # Budgets
    # ========================================================================

    def create_budget(self, budget_data: dict) -> dict:
        """Create a new budget entry."""
        result = self.client.table("budgets").insert(budget_data).execute()
        return result.data[0]

    def get_budgets(self, user_id: str, category_id: str = None) -> list[dict]:
        """Get budgets for a user, optionally filtered by category."""
        query = self.client.table("budgets").select("*").eq("user_id", user_id)
        if category_id:
            query = query.eq("category_id", category_id)
        result = query.execute()
        return result.data

    # ========================================================================
    # Transaction Categorization
    # ========================================================================

    def update_transaction_category(
        self, transaction_id: str, category_id: str | None, subcategory_id: str | None
    ) -> dict | None:
        """Update transaction categorization."""
        import logging
        logger = logging.getLogger("cashstate.database")

        logger.debug(f"[DB] Updating transaction {transaction_id}: category_id={category_id}, subcategory_id={subcategory_id}")

        result = (
            self.client.table("simplefin_transactions")
            .update({"category_id": category_id, "subcategory_id": subcategory_id})
            .eq("id", transaction_id)
            .execute()
        )

        if result.data:
            logger.debug(f"[DB] ✓ Successfully updated transaction {transaction_id}")
            return result.data[0]
        else:
            logger.error(f"[DB] ✗ Failed to update transaction {transaction_id} - no data returned")
            return None
