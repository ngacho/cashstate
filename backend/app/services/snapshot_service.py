"""Service for managing daily financial snapshots.

Handles two types of snapshots:
1. User-level snapshots (net_snapshots) - Overall net worth across all accounts
2. Account-level snapshots (transaction_snapshots) - Per-account balance history
"""
from datetime import date, datetime, timedelta
from typing import List, Optional
from decimal import Decimal
from app.database import Database


class SnapshotService:
    """Service for calculating and retrieving financial snapshots."""

    def __init__(self, db: Database):
        self.db = db

    async def calculate_snapshots(self, user_id: str, start_date: Optional[date] = None, end_date: Optional[date] = None) -> None:
        """
        Calculate daily snapshots for a date range.
        Called after transaction sync to update affected dates.
        """
        if not end_date:
            end_date = date.today()
        if not start_date:
            # Get earliest transaction date for this user
            result = self.db.client.table("simplefin_transactions") \
                .select("posted_date") \
                .eq("user_id", user_id) \
                .order("posted_date", desc=False) \
                .limit(1) \
                .execute()

            if result.data:
                first_txn_timestamp = result.data[0]["posted_date"]
                start_date = datetime.fromtimestamp(first_txn_timestamp).date()
            else:
                start_date = end_date  # No transactions, just do today

        # Iterate through each day in the range
        current_date = start_date
        while current_date <= end_date:
            await self._calculate_snapshot_for_date(user_id, current_date)
            current_date += timedelta(days=1)

    async def _calculate_snapshot_for_date(self, user_id: str, snapshot_date: date) -> None:
        """Calculate snapshot for a specific date - just the total balance."""
        # Get end of day timestamp
        end_timestamp = int(datetime.combine(snapshot_date, datetime.max.time()).timestamp())

        # Get all transactions up to end of this date
        all_txns = self.db.client.table("simplefin_transactions") \
            .select("amount") \
            .eq("user_id", user_id) \
            .lte("posted_date", end_timestamp) \
            .execute()

        # Sum up all transaction amounts to get total balance
        total_balance = sum(Decimal(str(t["amount"])) for t in all_txns.data)

        # Upsert snapshot
        snapshot_data = {
            "user_id": user_id,
            "snapshot_date": snapshot_date.isoformat(),
            "total_balance": float(total_balance),
            "updated_at": datetime.utcnow().isoformat(),
        }

        self.db.client.table("net_snapshots") \
            .upsert(snapshot_data, on_conflict="user_id,snapshot_date") \
            .execute()

    async def get_snapshots(
        self,
        user_id: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        granularity: str = "day"
    ) -> List[dict]:
        """
        Get net worth snapshots for date range with optional aggregation.

        Args:
            granularity: 'day', 'week', 'month', or 'year'

        Returns:
            List of {date, balance} dicts
        """
        if not end_date:
            end_date = date.today()

        if not start_date:
            # Default based on granularity
            if granularity == "day":
                start_date = end_date - timedelta(days=30)
            elif granularity == "week":
                start_date = end_date - timedelta(days=90)
            elif granularity == "month":
                start_date = end_date - timedelta(days=365)
            else:  # year
                # Get first snapshot date
                result = self.db.client.table("net_snapshots") \
                    .select("snapshot_date") \
                    .eq("user_id", user_id) \
                    .order("snapshot_date", desc=False) \
                    .limit(1) \
                    .execute()
                if result.data:
                    start_date = datetime.fromisoformat(result.data[0]["snapshot_date"]).date()
                else:
                    start_date = end_date

        # Fetch all daily snapshots
        result = self.db.client.table("net_snapshots") \
            .select("snapshot_date, total_balance") \
            .eq("user_id", user_id) \
            .gte("snapshot_date", start_date.isoformat()) \
            .lte("snapshot_date", end_date.isoformat()) \
            .order("snapshot_date", desc=False) \
            .execute()

        if granularity == "day":
            # Return daily snapshots as-is
            return [
                {
                    "date": row["snapshot_date"],
                    "balance": float(row["total_balance"])
                }
                for row in result.data
            ]

        # Aggregate by granularity (take last balance in each period)
        aggregated = {}
        for row in result.data:
            snapshot_dt = datetime.fromisoformat(row["snapshot_date"])

            # Determine the grouping key
            if granularity == "week":
                # ISO week (Monday as first day)
                key = snapshot_dt.isocalendar()[:2]  # (year, week)
                key_date = datetime.strptime(f"{key[0]}-W{key[1]:02d}-1", "%G-W%V-%u").date()
            elif granularity == "month":
                key = (snapshot_dt.year, snapshot_dt.month)
                key_date = date(key[0], key[1], 1)
            else:  # year
                key = snapshot_dt.year
                key_date = date(key, 1, 1)

            # Use last balance in the period
            aggregated[key] = {
                "date": key_date.isoformat(),
                "balance": float(row["total_balance"])
            }

        return sorted(aggregated.values(), key=lambda x: x["date"])

    async def calculate_transaction_snapshots(
        self,
        user_id: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None
    ) -> None:
        """
        Calculate per-account snapshots for a date range.

        Creates balance history for each individual account.
        Called after transaction sync to update affected dates.
        """
        if not end_date:
            end_date = date.today()

        # Get user's accounts
        accounts = self.db.client.table("simplefin_accounts") \
            .select("id, balance") \
            .eq("user_id", user_id) \
            .execute()

        if not accounts.data:
            return

        # If no start date, get earliest transaction date
        if not start_date:
            result = self.db.client.table("simplefin_transactions") \
                .select("posted_date") \
                .eq("user_id", user_id) \
                .order("posted_date", desc=False) \
                .limit(1) \
                .execute()

            if result.data:
                first_txn_timestamp = result.data[0]["posted_date"]
                start_date = datetime.fromtimestamp(first_txn_timestamp).date()
            else:
                start_date = end_date

        # Calculate snapshots for each account
        for account in accounts.data:
            account_id = account["id"]
            current_balance = account.get("balance") or 0

            # Iterate through each day
            current_date = start_date
            while current_date <= end_date:
                await self._calculate_account_snapshot_for_date(
                    user_id,
                    account_id,
                    current_date,
                    current_balance
                )
                current_date += timedelta(days=1)

    async def _calculate_account_snapshot_for_date(
        self,
        user_id: str,
        account_id: str,
        snapshot_date: date,
        current_balance: float
    ) -> None:
        """Calculate snapshot for a specific account on a specific date - just the balance."""
        # Get end of day timestamp
        end_timestamp = int(datetime.combine(snapshot_date, datetime.max.time()).timestamp())

        # Get all transactions for this account up to end of this date
        all_txns = self.db.client.table("simplefin_transactions") \
            .select("amount") \
            .eq("user_id", user_id) \
            .eq("simplefin_account_id", account_id) \
            .lte("posted_date", end_timestamp) \
            .execute()

        # Sum all transaction amounts to get balance
        running_balance = sum(Decimal(str(t["amount"])) for t in all_txns.data)

        # Upsert snapshot
        snapshot_data = {
            "user_id": user_id,
            "simplefin_account_id": account_id,
            "snapshot_date": snapshot_date.isoformat(),
            "balance": float(running_balance),
            "updated_at": datetime.utcnow().isoformat(),
        }

        self.db.client.table("transaction_snapshots") \
            .upsert(snapshot_data, on_conflict="user_id,simplefin_account_id,snapshot_date") \
            .execute()

    async def get_transaction_snapshots(
        self,
        user_id: str,
        account_id: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        granularity: str = "day"
    ) -> List[dict]:
        """
        Get balance snapshots for a specific account with optional aggregation.

        Args:
            granularity: 'day', 'week', 'month', or 'year'

        Returns:
            List of {date, balance} dicts
        """
        if not end_date:
            end_date = date.today()

        if not start_date:
            # Default based on granularity
            if granularity == "day":
                start_date = end_date - timedelta(days=30)
            elif granularity == "week":
                start_date = end_date - timedelta(days=90)
            elif granularity == "month":
                start_date = end_date - timedelta(days=365)
            else:  # year
                # Get first snapshot date for this account
                result = self.db.client.table("transaction_snapshots") \
                    .select("snapshot_date") \
                    .eq("user_id", user_id) \
                    .eq("simplefin_account_id", account_id) \
                    .order("snapshot_date", desc=False) \
                    .limit(1) \
                    .execute()
                if result.data:
                    start_date = datetime.fromisoformat(result.data[0]["snapshot_date"]).date()
                else:
                    start_date = end_date

        # Fetch all daily snapshots
        result = self.db.client.table("transaction_snapshots") \
            .select("snapshot_date, balance") \
            .eq("user_id", user_id) \
            .eq("simplefin_account_id", account_id) \
            .gte("snapshot_date", start_date.isoformat()) \
            .lte("snapshot_date", end_date.isoformat()) \
            .order("snapshot_date", desc=False) \
            .execute()

        if granularity == "day":
            # Return daily snapshots as-is
            return [
                {
                    "date": row["snapshot_date"],
                    "balance": float(row["balance"])
                }
                for row in result.data
            ]

        # Aggregate by granularity (take last balance in each period)
        aggregated = {}
        for row in result.data:
            snapshot_dt = datetime.fromisoformat(row["snapshot_date"])

            # Determine the grouping key
            if granularity == "week":
                key = snapshot_dt.isocalendar()[:2]
                key_date = datetime.strptime(f"{key[0]}-W{key[1]:02d}-1", "%G-W%V-%u").date()
            elif granularity == "month":
                key = (snapshot_dt.year, snapshot_dt.month)
                key_date = date(key[0], key[1], 1)
            else:  # year
                key = snapshot_dt.year
                key_date = date(key, 1, 1)

            # Use last balance in the period
            aggregated[key] = {
                "date": key_date.isoformat(),
                "balance": float(row["balance"])
            }

        return sorted(aggregated.values(), key=lambda x: x["date"])
