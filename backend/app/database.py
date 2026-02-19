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
    return create_client(settings.supabase_url, settings.supabase_secret_key)


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
        result = (
            self.client.table("simplefin_items").select("*").eq("id", item_id).execute()
        )
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
        result = (
            self.client.table("simplefin_items")
            .update(data)
            .eq("id", item_id)
            .execute()
        )
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
            .upsert(
                accounts, on_conflict="user_id,simplefin_item_id,simplefin_account_id"
            )
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

    def get_simplefin_transactions_by_ids(
        self, transaction_ids: list[str]
    ) -> list[dict]:
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
            updates: List of dicts with 'id' and fields to update

        Returns:
            Number of transactions updated
        """
        import logging

        logger = logging.getLogger("cashstate.database")

        if not updates:
            logger.warning(
                "[DB] batch_update_simplefin_transactions: No updates provided"
            )
            return 0

        logger.info(f"[DB] Batch updating {len(updates)} transactions")

        transaction_ids = [u["id"] for u in updates]
        category_ids = [u.get("category_id") for u in updates]
        subcategory_ids = [u.get("subcategory_id") for u in updates]
        categorization_sources = [u.get("categorization_source", "ai") for u in updates]

        result = self.client.rpc(
            "batch_update_transaction_categories",
            {
                "transaction_ids": transaction_ids,
                "category_ids": category_ids,
                "subcategory_ids": subcategory_ids,
                "categorization_sources": categorization_sources,
            },
        ).execute()

        updated_count = result.data if isinstance(result.data, int) else len(updates)
        logger.info(
            f"[DB] ✓ Batch update complete: {updated_count} transactions updated"
        )

        return updated_count

    def get_user_simplefin_transactions(
        self,
        user_id: str,
        date_from: int | None = None,
        date_to: int | None = None,
        limit: int = 50,
        offset: int = 0,
    ) -> list[dict]:
        """Get user's SimpleFin transactions."""
        query = self.client.table("simplefin_transactions").select("*")
        query = query.eq("user_id", user_id)

        if date_from is not None:
            query = query.gte("posted_date", date_from)
        if date_to is not None:
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
        """Get user's transactions with joined account information from transactions_view."""
        query = self.client.table("transactions_view").select("*")
        query = query.eq("user_id", user_id)

        if date_from:
            query = query.gte("date", date_from)
        if date_to:
            query = query.lte("date", date_to)

        result = (
            query.order("posted", desc=True).range(offset, offset + limit - 1).execute()
        )
        return result.data

    def count_user_transactions_with_account_info(
        self,
        user_id: str,
        date_from: str | None = None,
        date_to: str | None = None,
    ) -> int:
        """Count user's transactions from the transactions_view."""
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
        result = (
            self.client.table("simplefin_sync_jobs")
            .select("*")
            .eq("id", job_id)
            .execute()
        )
        return result.data[0] if result.data else None

    def get_simplefin_sync_jobs_for_user(
        self, user_id: str, limit: int = 20
    ) -> list[dict]:
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
        result = (
            self.client.table("simplefin_sync_jobs")
            .update(data)
            .eq("id", job_id)
            .execute()
        )
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
            self.client.table("categories").select("*").eq("id", category_id).execute()
        )
        return result.data[0] if result.data else None

    def get_user_category_by_name(self, user_id: str, name: str) -> dict | None:
        """Get a user's category by name."""
        result = (
            self.client.table("categories")
            .select("*")
            .eq("user_id", user_id)
            .eq("name", name)
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
            self.client.table("categories").update(data).eq("id", category_id).execute()
        )
        return result.data[0] if result.data else None

    def delete_category(self, category_id: str) -> None:
        """Delete a category."""
        self.client.table("categories").delete().eq("id", category_id).execute()

    def reassign_transactions_category(
        self, user_id: str, from_category_id: str, to_category_id: str
    ) -> None:
        """Reassign all transactions from one category to another."""
        self.client.table("simplefin_transactions").update(
            {
                "category_id": to_category_id,
                "subcategory_id": None,
            }
        ).eq("user_id", user_id).eq("category_id", from_category_id).execute()

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

    def clear_transaction_subcategory(self, user_id: str, subcategory_id: str) -> None:
        """Null out subcategory_id on all transactions with the given subcategory."""
        self.client.table("simplefin_transactions").update(
            {
                "subcategory_id": None,
            }
        ).eq("user_id", user_id).eq("subcategory_id", subcategory_id).execute()

    # ========================================================================
    # Categorization Rules
    # ========================================================================

    def get_categorization_rules(self, user_id: str) -> list[dict]:
        """Get all categorization rules for a user."""
        result = (
            self.client.table("categorization_rules")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .execute()
        )
        return result.data

    def get_categorization_rule_by_id(self, rule_id: str) -> dict | None:
        """Get a single categorization rule by ID."""
        result = (
            self.client.table("categorization_rules")
            .select("*")
            .eq("id", rule_id)
            .execute()
        )
        return result.data[0] if result.data else None

    def create_categorization_rule(self, rule_data: dict) -> dict:
        """Create a new categorization rule."""
        result = self.client.table("categorization_rules").insert(rule_data).execute()
        return result.data[0]

    def delete_categorization_rule(self, rule_id: str) -> None:
        """Delete a categorization rule."""
        self.client.table("categorization_rules").delete().eq("id", rule_id).execute()

    # ========================================================================
    # Budgets
    # ========================================================================

    def create_budget(self, budget_data: dict) -> dict:
        """Create a new budget."""
        # If setting as default, unset other defaults first
        if budget_data.get("is_default"):
            self.client.table("budgets").update({"is_default": False}).eq(
                "user_id", budget_data["user_id"]
            ).execute()

        result = self.client.table("budgets").insert(budget_data).execute()
        return result.data[0]

    def get_budgets(self, user_id: str) -> list[dict]:
        """Get all budgets for a user."""
        result = (
            self.client.table("budgets")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .execute()
        )
        return result.data

    def get_budget(self, budget_id: str) -> dict | None:
        """Get a single budget by ID."""
        result = self.client.table("budgets").select("*").eq("id", budget_id).execute()
        return result.data[0] if result.data else None

    def get_default_budget(self, user_id: str) -> dict | None:
        """Get the default budget for a user."""
        result = (
            self.client.table("budgets")
            .select("*")
            .eq("user_id", user_id)
            .eq("is_default", True)
            .execute()
        )
        return result.data[0] if result.data else None

    def update_budget(self, budget_id: str, update_data: dict) -> dict | None:
        """Update a budget."""
        # If setting as default, unset other defaults first
        if update_data.get("is_default"):
            budget = self.get_budget(budget_id)
            if budget:
                self.client.table("budgets").update({"is_default": False}).eq(
                    "user_id", budget["user_id"]
                ).execute()

        result = (
            self.client.table("budgets")
            .update(update_data)
            .eq("id", budget_id)
            .execute()
        )
        return result.data[0] if result.data else None

    def delete_budget(self, budget_id: str) -> None:
        """Delete a budget (cascades to line_items, accounts, months)."""
        self.client.table("budgets").delete().eq("id", budget_id).execute()

    # ========================================================================
    # Budget Accounts
    # ========================================================================

    def get_budget_accounts(self, budget_id: str) -> list[dict]:
        """Get all accounts linked to a budget."""
        result = (
            self.client.table("budget_accounts")
            .select("*, simplefin_accounts(id, name, balance, currency)")
            .eq("budget_id", budget_id)
            .execute()
        )
        rows = []
        for row in result.data:
            account = row.pop("simplefin_accounts", {}) or {}
            row["account_name"] = account.get("name", "")
            row["balance"] = float(account.get("balance") or 0.0)
            rows.append(row)
        return rows

    def get_account_budget(self, account_id: str) -> dict | None:
        """Find which budget an account belongs to (if any)."""
        result = (
            self.client.table("budget_accounts")
            .select("*, budgets(id, name, user_id)")
            .eq("account_id", account_id)
            .execute()
        )
        return result.data[0] if result.data else None

    def add_budget_account(self, budget_id: str, account_id: str) -> dict:
        """Add an account to a budget. Raises error if account already linked."""
        result = (
            self.client.table("budget_accounts")
            .insert(
                {
                    "budget_id": budget_id,
                    "account_id": account_id,
                }
            )
            .execute()
        )
        return result.data[0]

    def remove_budget_account(self, budget_id: str, account_id: str) -> None:
        """Remove an account from a budget."""
        self.client.table("budget_accounts").delete().eq("budget_id", budget_id).eq(
            "account_id", account_id
        ).execute()

    def get_budget_account_ids(self, budget_id: str) -> list[str]:
        """Get just the account IDs for a budget."""
        result = (
            self.client.table("budget_accounts")
            .select("account_id")
            .eq("budget_id", budget_id)
            .execute()
        )
        return [row["account_id"] for row in result.data]

    # ========================================================================
    # Budget Line Items
    # ========================================================================

    def get_budget_line_items(self, budget_id: str) -> list[dict]:
        """Get all line items for a budget."""
        result = (
            self.client.table("budget_line_items")
            .select("*")
            .eq("budget_id", budget_id)
            .execute()
        )
        return result.data

    def get_budget_line_item(self, item_id: str) -> dict | None:
        """Get a single line item by ID."""
        result = (
            self.client.table("budget_line_items")
            .select("*")
            .eq("id", item_id)
            .execute()
        )
        return result.data[0] if result.data else None

    def create_budget_line_item(self, item_data: dict) -> dict:
        """Create a new line item in a budget."""
        result = self.client.table("budget_line_items").insert(item_data).execute()
        return result.data[0]

    def update_budget_line_item(self, item_id: str, update_data: dict) -> dict | None:
        """Update a budget line item."""
        result = (
            self.client.table("budget_line_items")
            .update(update_data)
            .eq("id", item_id)
            .execute()
        )
        return result.data[0] if result.data else None

    def delete_budget_line_item(self, item_id: str) -> None:
        """Delete a budget line item."""
        self.client.table("budget_line_items").delete().eq("id", item_id).execute()

    # ========================================================================
    # Budget Months
    # ========================================================================

    def get_budget_months(self, user_id: str) -> list[dict]:
        """Get all budget month overrides for a user."""
        result = (
            self.client.table("budget_months")
            .select("*")
            .eq("user_id", user_id)
            .order("month", desc=True)
            .execute()
        )
        return result.data

    def get_budget_month(self, user_id: str, month: str) -> dict | None:
        """Get budget month override for a specific month (YYYY-MM-01 format)."""
        result = (
            self.client.table("budget_months")
            .select("*")
            .eq("user_id", user_id)
            .eq("month", month)
            .execute()
        )
        return result.data[0] if result.data else None

    def get_budget_month_by_id(self, month_id: str) -> dict | None:
        """Get budget month by ID."""
        result = (
            self.client.table("budget_months").select("*").eq("id", month_id).execute()
        )
        return result.data[0] if result.data else None

    def create_budget_month(self, month_data: dict) -> dict:
        """Assign a budget to a specific month."""
        result = self.client.table("budget_months").insert(month_data).execute()
        return result.data[0]

    def delete_budget_month(self, month_id: str) -> None:
        """Delete a budget month override."""
        self.client.table("budget_months").delete().eq("id", month_id).execute()

    # ========================================================================
    # Budget Summary
    # ========================================================================

    def get_spending_by_category(
        self, user_id: str, start_date, end_date, account_ids: list[str] = None
    ) -> dict:
        """Calculate spending by category and subcategory for a date range.

        Only counts negative amounts (expenses), not income.
        Filters by account_ids if provided (empty = all accounts).

        Returns:
            {
                "total": float,
                "categories": {category_id: amount},
                "subcategories": {subcategory_id: amount}
            }
        """
        from datetime import datetime, date

        # Convert date to datetime if needed
        if isinstance(start_date, date) and not isinstance(start_date, datetime):
            start_dt = datetime.combine(start_date, datetime.min.time())
        else:
            start_dt = start_date

        if isinstance(end_date, date) and not isinstance(end_date, datetime):
            end_dt = datetime.combine(end_date, datetime.min.time())
        else:
            end_dt = end_date

        # Build query
        query = (
            self.client.table("simplefin_transactions")
            .select("amount, category_id, subcategory_id, simplefin_account_id")
            .eq("user_id", user_id)
            .lt("amount", 0)  # Only expenses (negative amounts)
            .gte("transaction_date", int(start_dt.timestamp()))
            .lt("transaction_date", int(end_dt.timestamp()))
        )

        # Filter by accounts if specified
        if account_ids:
            query = query.in_("simplefin_account_id", account_ids)

        result = query.execute()
        transactions = result.data

        # Aggregate spending
        total = 0
        categories = {}
        subcategories = {}

        for txn in transactions:
            amount = abs(txn["amount"])  # Convert to positive for spending
            total += amount

            if txn.get("category_id"):
                cat_id = txn["category_id"]
                categories[cat_id] = categories.get(cat_id, 0) + amount

            if txn.get("subcategory_id"):
                sub_id = txn["subcategory_id"]
                subcategories[sub_id] = subcategories.get(sub_id, 0) + amount

        return {
            "total": total,
            "categories": categories,
            "subcategories": subcategories,
        }

    # ========================================================================
    # Goals
    # ========================================================================

    def create_goal(self, data: dict) -> dict:
        """Create a new goal."""
        result = self.client.table("goals").insert(data).execute()
        return result.data[0]

    def get_user_goals(self, user_id: str) -> list[dict]:
        """Get all goals for a user."""
        result = (
            self.client.table("goals")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .execute()
        )
        return result.data

    def get_goal(self, goal_id: str) -> dict | None:
        """Get a goal by ID."""
        result = self.client.table("goals").select("*").eq("id", goal_id).execute()
        return result.data[0] if result.data else None

    def update_goal(self, goal_id: str, data: dict) -> dict | None:
        """Update a goal."""
        result = self.client.table("goals").update(data).eq("id", goal_id).execute()
        return result.data[0] if result.data else None

    def delete_goal(self, goal_id: str) -> None:
        """Delete a goal (cascades to goal_accounts)."""
        self.client.table("goals").delete().eq("id", goal_id).execute()

    # ========================================================================
    # Goal Accounts
    # ========================================================================

    def get_goal_accounts(self, goal_id: str) -> list[dict]:
        """Get all account associations for a goal, joined with account details."""
        result = (
            self.client.table("goal_accounts")
            .select("*, simplefin_accounts(id, name, balance, currency)")
            .eq("goal_id", goal_id)
            .execute()
        )
        rows = []
        for row in result.data:
            account = row.pop("simplefin_accounts", {}) or {}
            row["account_name"] = account.get("name", "")
            row["current_balance"] = float(account.get("balance") or 0.0)
            if row.get("starting_balance") is not None:
                row["starting_balance"] = float(row["starting_balance"])
            rows.append(row)
        return rows

    def get_account_total_allocation(
        self, account_id: str, exclude_goal_id: str | None = None
    ) -> float:
        """Get sum of allocation_percentage for an account across all goals."""
        query = (
            self.client.table("goal_accounts")
            .select("allocation_percentage")
            .eq("simplefin_account_id", account_id)
        )
        if exclude_goal_id:
            query = query.neq("goal_id", exclude_goal_id)
        result = query.execute()
        return sum(row["allocation_percentage"] for row in result.data)

    def create_goal_account(self, data: dict) -> dict:
        """Create a goal-account association."""
        result = self.client.table("goal_accounts").insert(data).execute()
        return result.data[0]

    def delete_goal_account(self, goal_account_id: str) -> None:
        """Delete a goal-account association."""
        self.client.table("goal_accounts").delete().eq("id", goal_account_id).execute()

    def delete_goal_accounts_for_goal(self, goal_id: str) -> None:
        """Delete all account associations for a goal."""
        self.client.table("goal_accounts").delete().eq("goal_id", goal_id).execute()

    def get_goal_snapshots(
        self,
        goal_id: str,
        start_date: str,
        end_date: str,
        granularity: str = "day",
        goal_type: str = "savings",
    ) -> list[dict]:
        """Compute progress over time for a goal."""
        from collections import defaultdict

        goal_accounts = self.get_goal_accounts(goal_id)
        if not goal_accounts:
            return []

        account_ids = [ga["simplefin_account_id"] for ga in goal_accounts]
        allocation_map = {
            ga["simplefin_account_id"]: ga["allocation_percentage"] / 100.0
            for ga in goal_accounts
        }

        result = (
            self.client.table("account_balance_history")
            .select("simplefin_account_id, snapshot_date, balance")
            .in_("simplefin_account_id", account_ids)
            .gte("snapshot_date", start_date)
            .lte("snapshot_date", end_date)
            .order("snapshot_date")
            .execute()
        )

        daily_totals: dict[str, float] = defaultdict(float)
        for row in result.data:
            d = row["snapshot_date"]
            balance = float(row["balance"] or 0)
            account_id = row["simplefin_account_id"]

            if goal_type == "debt_payment":
                daily_totals[d] += balance
            else:
                alloc = allocation_map.get(account_id, 0)
                daily_totals[d] += balance * alloc

        if granularity == "day":
            snapshots = [
                {"date": d, "balance": round(b, 2)}
                for d, b in sorted(daily_totals.items())
            ]
        else:
            from datetime import date as date_type

            def period_key(date_str: str) -> str:
                d = date_type.fromisoformat(date_str)
                if granularity == "week":
                    return f"{d.isocalendar()[0]}-W{d.isocalendar()[1]:02d}"
                elif granularity == "month":
                    return f"{d.year}-{d.month:02d}"
                elif granularity == "year":
                    return str(d.year)
                return date_str

            period_last: dict[str, tuple[str, float]] = {}
            for date_str, balance in sorted(daily_totals.items()):
                key = period_key(date_str)
                period_last[key] = (date_str, balance)

            snapshots = [
                {"date": v[0], "balance": round(v[1], 2)}
                for v in sorted(period_last.values(), key=lambda x: x[0])
            ]

        return snapshots

    # ========================================================================
    # Transaction Categorization
    # ========================================================================

    def update_transaction_category(
        self,
        transaction_id: str,
        category_id: str | None,
        subcategory_id: str | None,
        categorization_source: str = "manual",
    ) -> dict | None:
        """Update transaction categorization."""
        import logging

        logger = logging.getLogger("cashstate.database")

        logger.debug(
            f"[DB] Updating transaction {transaction_id}: "
            f"category_id={category_id}, subcategory_id={subcategory_id}, "
            f"source={categorization_source}"
        )

        result = (
            self.client.table("simplefin_transactions")
            .update(
                {
                    "category_id": category_id,
                    "subcategory_id": subcategory_id,
                    "categorization_source": categorization_source,
                }
            )
            .eq("id", transaction_id)
            .execute()
        )

        if result.data:
            logger.debug(f"[DB] ✓ Successfully updated transaction {transaction_id}")
            return result.data[0]
        else:
            logger.error(f"[DB] ✗ Failed to update transaction {transaction_id}")
            return None
