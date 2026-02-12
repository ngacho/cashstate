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

        if date_from:
            query = query.gte("posted_date", date_from)
        if date_to:
            query = query.lte("posted_date", date_to)
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
