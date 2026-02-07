"""Supabase client setup and database utilities."""

from functools import lru_cache
from supabase import create_client, Client

from app.config import get_settings


@lru_cache
def get_supabase_client() -> Client:
    """Get cached Supabase client instance using secret key."""
    settings = get_settings()
    return create_client(
        settings.supabase_url,
        settings.supabase_secret_key
    )


def get_db() -> Client:
    """Dependency for getting Supabase client in routes."""
    return get_supabase_client()


class Database:
    """Database helper class for CashState operations."""

    def __init__(self, client: Client):
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

    # --- Plaid Items ---

    def create_plaid_item(self, item_data: dict) -> dict:
        result = self.client.table("plaid_items").insert(item_data).execute()
        return result.data[0]

    def get_plaid_item_by_id(self, item_id: str) -> dict | None:
        result = self.client.table("plaid_items").select("*").eq("id", item_id).execute()
        return result.data[0] if result.data else None

    def get_plaid_item_by_plaid_id(self, plaid_item_id: str) -> dict | None:
        result = (
            self.client.table("plaid_items")
            .select("*")
            .eq("plaid_item_id", plaid_item_id)
            .execute()
        )
        return result.data[0] if result.data else None

    def get_user_plaid_items(self, user_id: str) -> list[dict]:
        result = (
            self.client.table("plaid_items")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .execute()
        )
        return result.data

    def get_active_plaid_items(self) -> list[dict]:
        result = (
            self.client.table("plaid_items")
            .select("*")
            .eq("status", "active")
            .execute()
        )
        return result.data

    def get_user_active_plaid_items(self, user_id: str) -> list[dict]:
        result = (
            self.client.table("plaid_items")
            .select("*")
            .eq("user_id", user_id)
            .eq("status", "active")
            .execute()
        )
        return result.data

    def update_plaid_item(self, item_id: str, data: dict) -> dict:
        result = self.client.table("plaid_items").update(data).eq("id", item_id).execute()
        return result.data[0] if result.data else None

    # --- Transactions ---

    def upsert_transactions(self, transactions: list[dict]) -> list[dict]:
        if not transactions:
            return []
        result = (
            self.client.table("transactions")
            .upsert(transactions, on_conflict="plaid_transaction_id")
            .execute()
        )
        return result.data

    def delete_transactions_by_plaid_ids(self, plaid_transaction_ids: list[str]) -> None:
        if not plaid_transaction_ids:
            return
        self.client.table("transactions").delete().in_(
            "plaid_transaction_id", plaid_transaction_ids
        ).execute()

    def get_transaction_by_id(self, transaction_id: str) -> dict | None:
        result = (
            self.client.table("transactions")
            .select("*")
            .eq("id", transaction_id)
            .execute()
        )
        return result.data[0] if result.data else None

    def get_user_transactions(
        self,
        user_id: str,
        date_from: str | None = None,
        date_to: str | None = None,
        limit: int = 50,
        offset: int = 0,
    ) -> list[dict]:
        query = (
            self.client.table("transactions")
            .select("*, plaid_items!inner(user_id)")
            .eq("plaid_items.user_id", user_id)
        )
        if date_from:
            query = query.gte("date", date_from)
        if date_to:
            query = query.lte("date", date_to)
        result = (
            query.order("date", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        return result.data

    def count_user_transactions(
        self,
        user_id: str,
        date_from: str | None = None,
        date_to: str | None = None,
    ) -> int:
        query = (
            self.client.table("transactions")
            .select("id", count="exact")
            .eq("plaid_items.user_id", user_id)
        )
        if date_from:
            query = query.gte("date", date_from)
        if date_to:
            query = query.lte("date", date_to)
        result = query.execute()
        return result.count if result.count is not None else 0

    # --- Sync Jobs ---

    def create_sync_job(self, job_data: dict) -> dict:
        result = self.client.table("sync_jobs").insert(job_data).execute()
        return result.data[0]

    def get_sync_job_by_id(self, job_id: str) -> dict | None:
        result = self.client.table("sync_jobs").select("*").eq("id", job_id).execute()
        return result.data[0] if result.data else None

    def get_sync_jobs_for_user(self, user_id: str, limit: int = 20) -> list[dict]:
        result = (
            self.client.table("sync_jobs")
            .select("*, plaid_items!inner(user_id)")
            .eq("plaid_items.user_id", user_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return result.data

    def update_sync_job(self, job_id: str, data: dict) -> dict:
        result = self.client.table("sync_jobs").update(data).eq("id", job_id).execute()
        return result.data[0] if result.data else None
