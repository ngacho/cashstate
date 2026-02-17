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
    # Budget Templates
    # ========================================================================

    def create_budget_template(self, template_data: dict) -> dict:
        """Create a new budget template with optional account associations."""
        # Extract account_ids before inserting
        account_ids = template_data.pop("account_ids", [])

        # If setting as default, unset other defaults first
        if template_data.get("is_default"):
            self.client.table("budget_templates").update({"is_default": False}).eq(
                "user_id", template_data["user_id"]
            ).execute()

        # Create template
        result = self.client.table("budget_templates").insert(template_data).execute()
        template = result.data[0]

        # Create account associations
        if account_ids:
            self._create_template_accounts(template["id"], account_ids)

        template["account_ids"] = account_ids
        return template

    def get_budget_templates(self, user_id: str) -> list[dict]:
        """Get all budget templates for a user."""
        result = self.client.table("budget_templates").select("*").eq("user_id", user_id).execute()
        templates = result.data

        # Fetch account associations
        for template in templates:
            template["account_ids"] = self._get_template_account_ids(template["id"])

        return templates

    def get_budget_template(self, template_id: str) -> dict | None:
        """Get a single budget template by ID."""
        result = self.client.table("budget_templates").select("*").eq("id", template_id).execute()
        if not result.data:
            return None

        template = result.data[0]
        template["account_ids"] = self._get_template_account_ids(template_id)
        return template

    def get_default_budget_template(self, user_id: str) -> dict | None:
        """Get the default budget template for a user."""
        result = (
            self.client.table("budget_templates")
            .select("*")
            .eq("user_id", user_id)
            .eq("is_default", True)
            .execute()
        )
        if not result.data:
            return None

        template = result.data[0]
        template["account_ids"] = self._get_template_account_ids(template["id"])
        return template

    def update_budget_template(self, template_id: str, update_data: dict) -> dict | None:
        """Update a budget template."""
        # Extract account_ids for separate handling
        account_ids = update_data.pop("account_ids", None)

        # If setting as default, unset other defaults first
        if update_data.get("is_default"):
            # Get user_id of this template
            template = self.get_budget_template(template_id)
            if template:
                self.client.table("budget_templates").update({"is_default": False}).eq(
                    "user_id", template["user_id"]
                ).execute()

        # Update template fields
        if update_data:
            result = self.client.table("budget_templates").update(update_data).eq("id", template_id).execute()
            if not result.data:
                return None
            template = result.data[0]
        else:
            template = self.get_budget_template(template_id)

        # Update account associations
        if account_ids is not None:
            self._delete_template_accounts(template_id)
            if account_ids:
                self._create_template_accounts(template_id, account_ids)

        template["account_ids"] = self._get_template_account_ids(template_id)
        return template

    def delete_budget_template(self, template_id: str) -> None:
        """Delete a budget template (cascades to categories, subcategories, accounts, periods)."""
        self.client.table("budget_templates").delete().eq("id", template_id).execute()

    def _create_template_accounts(self, template_id: str, account_ids: list[str]) -> None:
        """Create template-account associations."""
        if not account_ids:
            return

        associations = [
            {"template_id": template_id, "account_id": account_id}
            for account_id in account_ids
        ]
        self.client.table("budget_template_accounts").insert(associations).execute()

    def _get_template_account_ids(self, template_id: str) -> list[str]:
        """Get account IDs associated with a template."""
        result = (
            self.client.table("budget_template_accounts")
            .select("account_id")
            .eq("template_id", template_id)
            .execute()
        )
        return [row["account_id"] for row in result.data]

    def _delete_template_accounts(self, template_id: str) -> None:
        """Delete all account associations for a template."""
        self.client.table("budget_template_accounts").delete().eq("template_id", template_id).execute()

    # ========================================================================
    # Budget Categories
    # ========================================================================

    def create_budget_category(self, category_data: dict) -> dict:
        """Create a category budget within a template."""
        result = self.client.table("budget_categories").insert(category_data).execute()
        return result.data[0]

    def get_budget_categories(self, template_id: str) -> list[dict]:
        """Get all category budgets for a template."""
        result = self.client.table("budget_categories").select("*").eq("template_id", template_id).execute()
        return result.data

    def update_budget_category(self, category_budget_id: str, update_data: dict) -> dict | None:
        """Update a category budget."""
        result = self.client.table("budget_categories").update(update_data).eq("id", category_budget_id).execute()
        return result.data[0] if result.data else None

    def delete_budget_category(self, category_budget_id: str) -> None:
        """Delete a category budget."""
        self.client.table("budget_categories").delete().eq("id", category_budget_id).execute()

    # ========================================================================
    # Budget Subcategories
    # ========================================================================

    def create_budget_subcategory(self, subcategory_data: dict) -> dict:
        """Create a subcategory budget within a template."""
        result = self.client.table("budget_subcategories").insert(subcategory_data).execute()
        return result.data[0]

    def get_budget_subcategories(self, template_id: str) -> list[dict]:
        """Get all subcategory budgets for a template."""
        result = self.client.table("budget_subcategories").select("*").eq("template_id", template_id).execute()
        return result.data

    def update_budget_subcategory(self, subcategory_budget_id: str, update_data: dict) -> dict | None:
        """Update a subcategory budget."""
        result = self.client.table("budget_subcategories").update(update_data).eq("id", subcategory_budget_id).execute()
        return result.data[0] if result.data else None

    def delete_budget_subcategory(self, subcategory_budget_id: str) -> None:
        """Delete a subcategory budget."""
        self.client.table("budget_subcategories").delete().eq("id", subcategory_budget_id).execute()

    # ========================================================================
    # Budget Periods
    # ========================================================================

    def create_budget_period(self, period_data: dict) -> dict:
        """Apply a template to a specific month."""
        result = self.client.table("budget_periods").insert(period_data).execute()
        return result.data[0]

    def get_budget_period(self, user_id: str, period_month: str) -> dict | None:
        """Get budget period for a specific month (YYYY-MM-DD format)."""
        result = (
            self.client.table("budget_periods")
            .select("*")
            .eq("user_id", user_id)
            .eq("period_month", period_month)
            .execute()
        )
        return result.data[0] if result.data else None

    def get_budget_periods(self, user_id: str) -> list[dict]:
        """Get all budget periods for a user."""
        result = self.client.table("budget_periods").select("*").eq("user_id", user_id).order("period_month", desc=True).execute()
        return result.data

    def delete_budget_period(self, period_id: str) -> None:
        """Delete a budget period (reverts to default template)."""
        self.client.table("budget_periods").delete().eq("id", period_id).execute()

    def get_budget_for_month(self, user_id: str, year: int, month: int) -> dict | None:
        """Get budget for a specific month with inheritance logic and spending.

        Returns template + categories + subcategories + spending data.
        Implements inheritance: checks for period override, falls back to default.
        """
        from datetime import date

        # Format period_month as YYYY-MM-01
        period_month = date(year, month, 1)

        # Check if user has override for this month
        period = self.get_budget_period(user_id, period_month.isoformat())

        if period:
            # User selected specific template for this month
            template_id = period["template_id"]
        else:
            # Use default template
            template = self.get_default_budget_template(user_id)
            if not template:
                return None
            template_id = template["id"]

        # Load template details
        template = self.get_budget_template(template_id)
        if not template:
            return None

        # Get categories and subcategories
        categories = self.get_budget_categories(template_id)
        subcategories = self.get_budget_subcategories(template_id)

        # Calculate spending for this month
        start_date = period_month
        if month == 12:
            end_date = date(year + 1, 1, 1)
        else:
            end_date = date(year, month + 1, 1)

        spending = self.get_spending_by_category(
            user_id=user_id,
            start_date=start_date,
            end_date=end_date,
            account_ids=template.get("account_ids", [])
        )

        # Attach spending to categories
        for cat in categories:
            cat["spent"] = spending["categories"].get(cat["category_id"], 0)

        # Attach spending to subcategories
        for subcat in subcategories:
            subcat["spent"] = spending["subcategories"].get(subcat["subcategory_id"], 0)

        return {
            "template": template,
            "categories": categories,
            "subcategories": subcategories,
            "subcategory_spending": spending["subcategories"],
            "period_month": period_month.isoformat(),
            "total_spent": spending["total"],
            "has_override": period is not None,
        }

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

            # Aggregate by category
            if txn.get("category_id"):
                cat_id = txn["category_id"]
                categories[cat_id] = categories.get(cat_id, 0) + amount

            # Aggregate by subcategory
            if txn.get("subcategory_id"):
                sub_id = txn["subcategory_id"]
                subcategories[sub_id] = subcategories.get(sub_id, 0) + amount

        return {
            "total": total,
            "categories": categories,
            "subcategories": subcategories,
        }

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
