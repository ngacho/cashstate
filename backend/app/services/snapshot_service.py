"""Service for managing daily account balance snapshots.

Handles account balance history and calculates net worth on-the-fly:
- Stores daily balance for each account in account_balance_history
- Calculates net worth by summing all account balances per date
"""
from datetime import date, datetime, timedelta, timezone
from typing import List, Optional, Dict
from decimal import Decimal
from app.database import Database


class InsufficientDataError(Exception):
    """Raised when insufficient data is available for the requested date range."""

    def __init__(self, message: str, coverage_pct: float, min_date: Optional[date], max_date: Optional[date]):
        self.message = message
        self.coverage_pct = coverage_pct
        self.min_date = min_date
        self.max_date = max_date
        super().__init__(message)


class SnapshotService:
    """Service for calculating and retrieving account balance snapshots."""

    def __init__(self, db: Database):
        self.db = db

    async def store_daily_account_balances(
        self,
        user_id: str,
        snapshot_date: Optional[date] = None
    ) -> None:
        """
        Store current account balances as daily snapshots.

        Called by cron job to snapshot each account's balance from simplefin_accounts table.
        This runs daily to ensure continuous data for charting.

        Args:
            user_id: User ID to snapshot accounts for
            snapshot_date: Date to snapshot (defaults to today)
        """
        if not snapshot_date:
            snapshot_date = date.today()

        # Get all user's accounts with current balances
        accounts = self.db.client.table("simplefin_accounts") \
            .select("id, balance") \
            .eq("user_id", user_id) \
            .execute()

        if not accounts.data:
            return

        # Store snapshot for each account
        for account in accounts.data:
            balance = account.get("balance") or 0

            snapshot_data = {
                "user_id": user_id,
                "simplefin_account_id": account["id"],
                "snapshot_date": snapshot_date.isoformat(),
                "balance": float(balance),
                "updated_at": datetime.now(timezone.utc).isoformat(),
            }

            self.db.client.table("account_balance_history") \
                .upsert(snapshot_data, on_conflict="user_id,simplefin_account_id,snapshot_date") \
                .execute()

    async def get_snapshots(
        self,
        user_id: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        granularity: str = "day"
    ) -> List[dict]:
        """
        Get net worth snapshots by summing all account balances per date.

        Calculates net worth on-the-fly by aggregating account_balance_history.

        Args:
            user_id: User ID
            start_date: Start date (defaults based on granularity)
            end_date: End date (defaults to today)
            granularity: 'day', 'week', 'month', or 'year'

        Returns:
            List of {date, balance} dicts representing net worth over time

        Raises:
            InsufficientDataError: If less than 50% of requested dates have data
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
                result = self.db.client.table("account_balance_history") \
                    .select("snapshot_date") \
                    .eq("user_id", user_id) \
                    .order("snapshot_date", desc=False) \
                    .limit(1) \
                    .execute()
                if result.data:
                    start_date = datetime.fromisoformat(result.data[0]["snapshot_date"]).date()
                else:
                    start_date = end_date

        # Fetch all account balances in date range
        result = self.db.client.table("account_balance_history") \
            .select("snapshot_date, balance") \
            .eq("user_id", user_id) \
            .gte("snapshot_date", start_date.isoformat()) \
            .lte("snapshot_date", end_date.isoformat()) \
            .order("snapshot_date", desc=False) \
            .execute()

        # Check data sufficiency
        expected_days = (end_date - start_date).days + 1
        unique_dates = set(row["snapshot_date"] for row in result.data)
        coverage_pct = (len(unique_dates) / expected_days * 100) if expected_days > 0 else 0

        if coverage_pct < 50:
            min_date = min((datetime.fromisoformat(d).date() for d in unique_dates), default=None)
            max_date = max((datetime.fromisoformat(d).date() for d in unique_dates), default=None)
            raise InsufficientDataError(
                f"Insufficient data: only {coverage_pct:.1f}% coverage",
                coverage_pct=coverage_pct,
                min_date=min_date,
                max_date=max_date
            )

        # Group by date and sum balances (net worth = sum of all accounts)
        daily_net_worth: Dict[str, Decimal] = {}
        for row in result.data:
            snapshot_date = row["snapshot_date"]
            balance = Decimal(str(row["balance"]))

            if snapshot_date not in daily_net_worth:
                daily_net_worth[snapshot_date] = Decimal("0")
            daily_net_worth[snapshot_date] += balance

        # Convert to list of dicts
        daily_snapshots = [
            {"date": date_str, "balance": float(balance)}
            for date_str, balance in sorted(daily_net_worth.items())
        ]

        if granularity == "day":
            return daily_snapshots

        # Aggregate by granularity (take last balance in each period)
        aggregated = {}
        for snapshot in daily_snapshots:
            snapshot_dt = datetime.fromisoformat(snapshot["date"])

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
                "balance": snapshot["balance"]
            }

        return sorted(aggregated.values(), key=lambda x: x["date"])

    async def get_account_snapshots(
        self,
        user_id: str,
        account_id: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        granularity: str = "day"
    ) -> List[dict]:
        """
        Get balance snapshots for a specific account.

        Args:
            user_id: User ID
            account_id: SimpleFin account ID
            start_date: Start date (defaults based on granularity)
            end_date: End date (defaults to today)
            granularity: 'day', 'week', 'month', or 'year'

        Returns:
            List of {date, balance} dicts for the account

        Raises:
            InsufficientDataError: If less than 50% of requested dates have data
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
                result = self.db.client.table("account_balance_history") \
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

        # Fetch all daily snapshots for this account
        result = self.db.client.table("account_balance_history") \
            .select("snapshot_date, balance") \
            .eq("user_id", user_id) \
            .eq("simplefin_account_id", account_id) \
            .gte("snapshot_date", start_date.isoformat()) \
            .lte("snapshot_date", end_date.isoformat()) \
            .order("snapshot_date", desc=False) \
            .execute()

        # Check data sufficiency
        expected_days = (end_date - start_date).days + 1
        coverage_pct = (len(result.data) / expected_days * 100) if expected_days > 0 else 0

        if coverage_pct < 50:
            min_date = min((datetime.fromisoformat(row["snapshot_date"]).date() for row in result.data), default=None)
            max_date = max((datetime.fromisoformat(row["snapshot_date"]).date() for row in result.data), default=None)
            raise InsufficientDataError(
                f"Insufficient data: only {coverage_pct:.1f}% coverage",
                coverage_pct=coverage_pct,
                min_date=min_date,
                max_date=max_date
            )

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
