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
        """Calculate snapshot for a specific date."""
        # Get all transactions for this date
        start_timestamp = int(datetime.combine(snapshot_date, datetime.min.time()).timestamp())
        end_timestamp = int(datetime.combine(snapshot_date, datetime.max.time()).timestamp())

        daily_txns = self.db.client.table("simplefin_transactions") \
            .select("amount") \
            .eq("user_id", user_id) \
            .gte("posted_date", start_timestamp) \
            .lte("posted_date", end_timestamp) \
            .execute()

        # Calculate daily totals
        daily_spent = Decimal(0)
        daily_income = Decimal(0)
        transaction_count = len(daily_txns.data)

        for txn in daily_txns.data:
            amount = Decimal(str(txn["amount"]))
            if amount < 0:
                daily_spent += abs(amount)
            else:
                daily_income += amount

        daily_net = daily_income - daily_spent

        # Get running balance (all transactions up to end of this date)
        all_txns = self.db.client.table("simplefin_transactions") \
            .select("amount") \
            .eq("user_id", user_id) \
            .lte("posted_date", end_timestamp) \
            .execute()

        total_balance = sum(Decimal(str(t["amount"])) for t in all_txns.data)

        # Get accounts and calculate cash/credit balance
        accounts = self.db.client.table("simplefin_accounts") \
            .select("name, balance") \
            .eq("user_id", user_id) \
            .execute()

        cash_balance = Decimal(0)
        credit_balance = Decimal(0)

        for account in accounts.data:
            name = account["name"].lower()
            balance = Decimal(str(account.get("balance") or 0))

            if "credit" in name or "card" in name:
                credit_balance += balance
            else:
                cash_balance += balance

        # Calculate MTD (month-to-date) spent
        month_start = snapshot_date.replace(day=1)
        month_start_timestamp = int(datetime.combine(month_start, datetime.min.time()).timestamp())

        mtd_txns = self.db.client.table("simplefin_transactions") \
            .select("amount") \
            .eq("user_id", user_id) \
            .gte("posted_date", month_start_timestamp) \
            .lte("posted_date", end_timestamp) \
            .execute()

        mtd_spent = sum(abs(Decimal(str(t["amount"]))) for t in mtd_txns.data if Decimal(str(t["amount"])) < 0)

        # Calculate YTD (year-to-date) spent
        year_start = snapshot_date.replace(month=1, day=1)
        year_start_timestamp = int(datetime.combine(year_start, datetime.min.time()).timestamp())

        ytd_txns = self.db.client.table("simplefin_transactions") \
            .select("amount") \
            .eq("user_id", user_id) \
            .gte("posted_date", year_start_timestamp) \
            .lte("posted_date", end_timestamp) \
            .execute()

        ytd_spent = sum(abs(Decimal(str(t["amount"]))) for t in ytd_txns.data if Decimal(str(t["amount"])) < 0)

        # Upsert snapshot
        snapshot_data = {
            "user_id": user_id,
            "snapshot_date": snapshot_date.isoformat(),
            "total_balance": float(total_balance),
            "cash_balance": float(cash_balance),
            "credit_balance": float(credit_balance),
            "daily_spent": float(daily_spent),
            "daily_income": float(daily_income),
            "daily_net": float(daily_net),
            "transaction_count": transaction_count,
            "mtd_spent": float(mtd_spent),
            "ytd_spent": float(ytd_spent),
            "is_finalized": snapshot_date < date.today(),
            "updated_at": datetime.utcnow().isoformat(),
        }

        # Upsert (update if exists, insert if not)
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
        Get snapshots with flexible date range and granularity.

        Args:
            user_id: User ID
            start_date: Start date (defaults based on granularity)
            end_date: End date (defaults to today)
            granularity: 'day', 'week', 'month', or 'year'
        """
        if not end_date:
            end_date = date.today()

        if not start_date:
            # Default based on granularity
            if granularity == "day":
                start_date = end_date - timedelta(days=7)
            elif granularity == "week":
                start_date = end_date - timedelta(days=30)
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

        # Query based on granularity
        if granularity == "day":
            # Return daily snapshots
            result = self.db.client.table("net_snapshots") \
                .select("snapshot_date, total_balance, daily_spent, daily_income, daily_net, transaction_count") \
                .eq("user_id", user_id) \
                .gte("snapshot_date", start_date.isoformat()) \
                .lte("snapshot_date", end_date.isoformat()) \
                .order("snapshot_date", desc=False) \
                .execute()

            return [
                {
                    "date": row["snapshot_date"],
                    "balance": float(row["total_balance"]),
                    "spent": float(row["daily_spent"]),
                    "income": float(row["daily_income"]),
                    "net": float(row["daily_net"]),
                    "transaction_count": row["transaction_count"]
                }
                for row in result.data
            ]

        else:
            # For week/month/year, we need to aggregate in Python
            # (Supabase doesn't support GROUP BY with date_trunc directly via the Python client)
            all_snapshots = self.db.client.table("net_snapshots") \
                .select("snapshot_date, total_balance, daily_spent, daily_income, daily_net, transaction_count") \
                .eq("user_id", user_id) \
                .gte("snapshot_date", start_date.isoformat()) \
                .lte("snapshot_date", end_date.isoformat()) \
                .order("snapshot_date", desc=False) \
                .execute()

            # Aggregate by granularity
            aggregated = {}
            for row in all_snapshots.data:
                snapshot_dt = datetime.fromisoformat(row["snapshot_date"])

                # Determine the grouping key
                if granularity == "week":
                    # ISO week (Monday as first day)
                    key = snapshot_dt.isocalendar()[:2]  # (year, week)
                    key_date = datetime.strptime(f"{key[0]}-W{key[1]:02d}-1", "%G-W%W-%u").date()
                elif granularity == "month":
                    key = (snapshot_dt.year, snapshot_dt.month)
                    key_date = date(key[0], key[1], 1)
                else:  # year
                    key = snapshot_dt.year
                    key_date = date(key, 1, 1)

                if key not in aggregated:
                    aggregated[key] = {
                        "date": key_date.isoformat(),
                        "balance": float(row["total_balance"]),  # Use last day's balance
                        "spent": 0,
                        "income": 0,
                        "net": 0,
                        "transaction_count": 0
                    }

                # Sum up the values
                aggregated[key]["spent"] += float(row["daily_spent"])
                aggregated[key]["income"] += float(row["daily_income"])
                aggregated[key]["net"] += float(row["daily_net"])
                aggregated[key]["transaction_count"] += row["transaction_count"]
                # Update balance to the latest
                aggregated[key]["balance"] = float(row["total_balance"])

            # Sort by date
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
        """Calculate snapshot for a specific account on a specific date."""
        # Get transactions for this account on this date
        start_timestamp = int(datetime.combine(snapshot_date, datetime.min.time()).timestamp())
        end_timestamp = int(datetime.combine(snapshot_date, datetime.max.time()).timestamp())

        daily_txns = self.db.client.table("simplefin_transactions") \
            .select("amount") \
            .eq("user_id", user_id) \
            .eq("simplefin_account_id", account_id) \
            .gte("posted_date", start_timestamp) \
            .lte("posted_date", end_timestamp) \
            .execute()

        # Calculate daily totals
        daily_spent = Decimal(0)
        daily_income = Decimal(0)
        transaction_count = len(daily_txns.data)

        for txn in daily_txns.data:
            amount = Decimal(str(txn["amount"]))
            if amount < 0:
                daily_spent += abs(amount)
            else:
                daily_income += amount

        daily_net = daily_income - daily_spent

        # Calculate running balance (work backwards from current balance)
        # Get all transactions for this account up to end of this date
        all_txns = self.db.client.table("simplefin_transactions") \
            .select("amount") \
            .eq("user_id", user_id) \
            .eq("simplefin_account_id", account_id) \
            .lte("posted_date", end_timestamp) \
            .execute()

        # Running balance = sum of all transactions up to this date
        running_balance = sum(Decimal(str(t["amount"])) for t in all_txns.data)

        # Upsert snapshot
        snapshot_data = {
            "user_id": user_id,
            "simplefin_account_id": account_id,
            "snapshot_date": snapshot_date.isoformat(),
            "balance": float(running_balance),
            "daily_spent": float(daily_spent),
            "daily_income": float(daily_income),
            "daily_net": float(daily_net),
            "transaction_count": transaction_count,
            "is_finalized": snapshot_date < date.today(),
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
        Get snapshots for a specific account.

        Args:
            user_id: User ID
            account_id: SimpleFin account ID (UUID)
            start_date: Start date (defaults based on granularity)
            end_date: End date (defaults to today)
            granularity: 'day', 'week', 'month', or 'year'
        """
        if not end_date:
            end_date = date.today()

        if not start_date:
            # Default based on granularity
            if granularity == "day":
                start_date = end_date - timedelta(days=7)
            elif granularity == "week":
                start_date = end_date - timedelta(days=30)
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

        # Query snapshots
        if granularity == "day":
            result = self.db.client.table("transaction_snapshots") \
                .select("snapshot_date, balance, daily_spent, daily_income, daily_net, transaction_count") \
                .eq("user_id", user_id) \
                .eq("simplefin_account_id", account_id) \
                .gte("snapshot_date", start_date.isoformat()) \
                .lte("snapshot_date", end_date.isoformat()) \
                .order("snapshot_date", desc=False) \
                .execute()

            return [
                {
                    "date": row["snapshot_date"],
                    "balance": float(row["balance"]),
                    "spent": float(row["daily_spent"]),
                    "income": float(row["daily_income"]),
                    "net": float(row["daily_net"]),
                    "transaction_count": row["transaction_count"]
                }
                for row in result.data
            ]

        else:
            # Aggregate for week/month/year
            all_snapshots = self.db.client.table("transaction_snapshots") \
                .select("snapshot_date, balance, daily_spent, daily_income, daily_net, transaction_count") \
                .eq("user_id", user_id) \
                .eq("simplefin_account_id", account_id) \
                .gte("snapshot_date", start_date.isoformat()) \
                .lte("snapshot_date", end_date.isoformat()) \
                .order("snapshot_date", desc=False) \
                .execute()

            # Aggregate by granularity (same logic as user-level snapshots)
            aggregated = {}
            for row in all_snapshots.data:
                snapshot_dt = datetime.fromisoformat(row["snapshot_date"])

                if granularity == "week":
                    key = snapshot_dt.isocalendar()[:2]
                    key_date = datetime.strptime(f"{key[0]}-W{key[1]:02d}-1", "%G-W%W-%u").date()
                elif granularity == "month":
                    key = (snapshot_dt.year, snapshot_dt.month)
                    key_date = date(key[0], key[1], 1)
                else:  # year
                    key = snapshot_dt.year
                    key_date = date(key, 1, 1)

                if key not in aggregated:
                    aggregated[key] = {
                        "date": key_date.isoformat(),
                        "balance": float(row["balance"]),
                        "spent": 0,
                        "income": 0,
                        "net": 0,
                        "transaction_count": 0
                    }

                aggregated[key]["spent"] += float(row["daily_spent"])
                aggregated[key]["income"] += float(row["daily_income"])
                aggregated[key]["net"] += float(row["daily_net"])
                aggregated[key]["transaction_count"] += row["transaction_count"]
                aggregated[key]["balance"] = float(row["balance"])

            return sorted(aggregated.values(), key=lambda x: x["date"])
