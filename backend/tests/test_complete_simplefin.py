"""
Complete SimpleFin integration test.

Tests the full SimpleFin integration flow:
1. Login with test user
2. Health check
3. Exchange SimpleFin setup token for access URL
4. Verify SimpleFin item stored in DB
5. Sync accounts and transactions from 2025-12-31
6. Verify accounts were saved
7. Verify transactions were saved
"""

import os
import pytest


class TestCompleteSimplefinFlow:
    """Test complete SimpleFin integration flow."""

    access_token: str = None
    user_id: str = None
    simplefin_item_id: str = None
    sync_job_id: str = None

    @pytest.fixture(autouse=True)
    def setup(self, client):
        self.client = client
        self.base_url = "/app/v1"

    def get_headers(self):
        return {"Authorization": f"Bearer {self.access_token}"}

    # =========================================
    # Step 1: Login
    # =========================================
    def test_01_login(self):
        """Login with the test user."""
        email = os.getenv("TEST_USER_EMAIL")
        password = os.getenv("TEST_USER_PASSWORD", "TestRunner123!")

        if not email:
            pytest.skip("TEST_USER_EMAIL not set")

        # Try login first
        response = self.client.post(
            f"{self.base_url}/auth/login",
            json={"email": email, "password": password},
        )

        if response.status_code == 200:
            data = response.json()
            TestCompleteSimplefinFlow.access_token = data["access_token"]
            TestCompleteSimplefinFlow.user_id = data["user_id"]
            print(f"Logged in as {email}, user_id={data['user_id']}")
            return

        # Try register
        response = self.client.post(
            f"{self.base_url}/auth/register",
            json={
                "email": email,
                "password": password,
                "display_name": "CashState Tester",
            },
        )

        if response.status_code == 201:
            data = response.json()
            TestCompleteSimplefinFlow.access_token = data["access_token"]
            TestCompleteSimplefinFlow.user_id = data["user_id"]
            print(f"Registered as {email}, user_id={data['user_id']}")
        else:
            pytest.fail(f"Could not login or register: {response.json()}")

    # =========================================
    # Step 2: Health check
    # =========================================
    def test_02_health_check(self):
        """Verify server is healthy."""
        response = self.client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["app"] == "CashState"
        print(f"Health: {data}")

    # =========================================
    # Step 3: Exchange SimpleFin setup token
    # =========================================
    def test_03_setup_token(self):
        """Exchange SimpleFin setup token for access URL."""
        setup_token = os.getenv("SIMPLEFIN_TOKEN")

        if not setup_token:
            pytest.skip("SIMPLEFIN_TOKEN not set in environment")

        response = self.client.post(
            f"{self.base_url}/simplefin/setup",
            json={
                "setup_token": setup_token,
                "institution_name": "Test SimpleFin Bank"
            },
            headers=self.get_headers(),
        )

        # Should succeed (201) or return existing item (200)
        assert response.status_code in [200, 201], f"Setup failed: {response.json()}"

        data = response.json()
        assert "item_id" in data
        assert "institution_name" in data

        TestCompleteSimplefinFlow.simplefin_item_id = data["item_id"]
        print(f"SimpleFin item ID: {data['item_id']}")
        print(f"Institution: {data['institution_name']}")

    # =========================================
    # Step 4: Verify SimpleFin item stored in DB
    # =========================================
    def test_04_verify_item_stored(self):
        """Verify SimpleFin item was stored in database."""
        response = self.client.get(
            f"{self.base_url}/simplefin/items",
            headers=self.get_headers(),
        )

        assert response.status_code == 200, f"Failed to get items: {response.json()}"

        items = response.json()
        assert len(items) > 0, "No SimpleFin items found"
        assert any(item["id"] == self.simplefin_item_id for item in items)

        item = next(item for item in items if item["id"] == self.simplefin_item_id)
        assert item["status"] == "active"
        assert item["institution_name"] is not None

        print(f"Found SimpleFin item: {item['institution_name']}")
        print(f"Created at: {item['created_at']}")

    # =========================================
    # Step 5: Sync accounts and transactions from 2025-12-31
    # =========================================
    def test_05_sync_accounts_transactions(self):
        """Sync accounts and transactions from SimpleFin starting from 2025-12-31."""
        import datetime

        # Calculate start date: December 31, 2025
        start_date = datetime.datetime(2025, 12, 31)
        start_timestamp = int(start_date.timestamp())

        print(f"Syncing from {start_date.date()} (timestamp: {start_timestamp})")

        response = self.client.post(
            f"{self.base_url}/simplefin/sync/{self.simplefin_item_id}",
            params={"start_date": start_timestamp, "force_sync": "true"},
            headers=self.get_headers(),
        )

        assert response.status_code == 200, f"Sync failed: {response.json()}"

        data = response.json()
        assert data["success"] is True
        assert "sync_job_id" in data
        assert data["accounts_synced"] >= 0
        assert data["transactions_added"] >= 0

        TestCompleteSimplefinFlow.sync_job_id = data["sync_job_id"]

        print(f"Sync job ID: {data['sync_job_id']}")
        print(f"Accounts synced: {data['accounts_synced']}")
        print(f"Transactions added: {data['transactions_added']}")

        if data.get("errors"):
            print(f"⚠️  Errors: {data['errors']}")

    # =========================================
    # Step 6: Verify accounts were saved
    # =========================================
    def test_06_list_accounts(self):
        """List accounts for the SimpleFin item."""
        response = self.client.get(
            f"{self.base_url}/simplefin/accounts/{self.simplefin_item_id}",
            headers=self.get_headers(),
        )

        assert response.status_code == 200, f"Failed to get accounts: {response.json()}"

        accounts = response.json()
        assert len(accounts) > 0, "No accounts found after sync"

        print(f"\nFound {len(accounts)} account(s):")
        for account in accounts:
            print(f"  - {account['name']}: {account['currency']} {account['balance']}")
            print(f"    SimpleFin ID: {account['simplefin_account_id']}")
            if account.get('organization_name'):
                print(f"    Organization: {account['organization_name']}")

    # =========================================
    # Step 7: Verify transactions were saved
    # =========================================
    def test_07_list_transactions(self):
        """List SimpleFin transactions for the user."""
        import datetime

        # Get transactions from 2025-12-31
        start_date = datetime.datetime(2025, 12, 31)
        start_timestamp = int(start_date.timestamp())

        response = self.client.get(
            f"{self.base_url}/simplefin/transactions",
            params={
                "date_from": start_timestamp,
                "limit": 100,
                "offset": 0,
            },
            headers=self.get_headers(),
        )

        assert response.status_code == 200, f"Failed to get transactions: {response.json()}"

        transactions = response.json()
        assert len(transactions) > 0, "No transactions found after sync"

        print(f"\nFound {len(transactions)} transaction(s):")
        for txn in transactions[:10]:  # Show first 10
            posted_date = datetime.datetime.fromtimestamp(txn['posted_date'])
            amount = txn['amount']
            description = txn['description']
            payee = txn.get('payee', 'N/A')
            print(f"  - {posted_date.date()} | {amount:>8} | {payee or description}")

    # =========================================
    # Step 8: Store account balance snapshots
    # =========================================
    def test_08_store_snapshots(self):
        """Store current account balances as daily snapshots for the past 7 days."""
        import datetime

        if not self.access_token:
            pytest.skip("Not logged in - run test_01_login first")

        # Store snapshots for the past 7 days to ensure we have enough data for tests
        today = datetime.date.today()
        print(f"\nStoring account balance snapshots for past 7 days...")

        for days_ago in range(7):
            snapshot_date = today - datetime.timedelta(days=days_ago)

            response = self.client.post(
                f"{self.base_url}/snapshots/store",
                params={"snapshot_date": snapshot_date.isoformat()},
                headers=self.get_headers(),
            )

            assert response.status_code == 200, f"Store snapshots failed for {snapshot_date}: {response.json()}"
            print(f"  ✅ Stored snapshot for {snapshot_date}")

        print(f"✅ Stored 7 days of account balance snapshots")

    # =========================================
    # Step 9: Verify daily snapshots
    # =========================================
    def test_09_get_daily_snapshots(self):
        """Get daily snapshots (last 7 days)."""
        import datetime

        if not self.access_token:
            pytest.skip("Not logged in - run test_01_login first")

        end_date = datetime.date.today()
        start_date = end_date - datetime.timedelta(days=6)

        print(f"\nGetting daily snapshots from {start_date} to {end_date}")

        response = self.client.get(
            f"{self.base_url}/snapshots",
            params={
                "start_date": start_date.isoformat(),
                "end_date": end_date.isoformat(),
                "granularity": "day",
            },
            headers=self.get_headers(),
        )

        assert response.status_code == 200, f"Failed to get snapshots: {response.json()}"

        data = response.json()
        assert "data" in data
        assert data["granularity"] == "day"

        snapshots = data["data"]
        print(f"Found {len(snapshots)} daily snapshot(s)")

        if snapshots:
            print("\nDaily snapshots (last 7 days):")
            for snapshot in snapshots:
                date = snapshot["date"]
                balance = snapshot["balance"]
                print(f"  {date}: Balance=${balance:,.2f}")

    # =========================================
    # Step 10: Verify weekly snapshots
    # =========================================
    def test_10_get_weekly_snapshots(self):
        """Get weekly aggregated snapshots (last 12 weeks)."""
        import datetime

        if not self.access_token:
            pytest.skip("Not logged in - run test_01_login first")

        end_date = datetime.date.today()
        start_date = end_date - datetime.timedelta(days=83)

        print(f"\nGetting weekly snapshots from {start_date} to {end_date}")

        response = self.client.get(
            f"{self.base_url}/snapshots",
            params={
                "start_date": start_date.isoformat(),
                "end_date": end_date.isoformat(),
                "granularity": "week",
            },
            headers=self.get_headers(),
        )

        # Accept both success and insufficient data error
        if response.status_code == 422:
            error = response.json()
            if error.get("detail", {}).get("error") == "INSUFFICIENT_DATA":
                print(f"⚠️  Insufficient data: {error['detail']['message']}")
                print(f"   Coverage: {error['detail']['coverage_pct']:.1f}%")
                pytest.skip("Not enough data for weekly snapshots (expected in tests)")
            else:
                pytest.fail(f"Unexpected error: {error}")

        assert response.status_code == 200, f"Failed to get snapshots: {response.json()}"

        data = response.json()
        assert "data" in data
        assert data["granularity"] == "week"

        snapshots = data["data"]
        print(f"Found {len(snapshots)} weekly snapshot(s)")

        if snapshots:
            print("\nWeekly snapshots:")
            for snapshot in snapshots:
                print(f"  Week of {snapshot['date']}: ${snapshot['balance']:,.2f}")

    # =========================================
    # Step 11: Verify monthly snapshots
    # =========================================
    def test_11_get_monthly_snapshots(self):
        """Get monthly aggregated snapshots (last 12 months)."""
        import datetime

        if not self.access_token:
            pytest.skip("Not logged in - run test_01_login first")

        end_date = datetime.date.today()
        start_date = end_date - datetime.timedelta(days=365)

        print(f"\nGetting monthly snapshots from {start_date} to {end_date}")

        response = self.client.get(
            f"{self.base_url}/snapshots",
            params={
                "start_date": start_date.isoformat(),
                "end_date": end_date.isoformat(),
                "granularity": "month",
            },
            headers=self.get_headers(),
        )

        # Accept both success and insufficient data error
        if response.status_code == 422:
            error = response.json()
            if error.get("detail", {}).get("error") == "INSUFFICIENT_DATA":
                print(f"⚠️  Insufficient data: {error['detail']['message']}")
                print(f"   Coverage: {error['detail']['coverage_pct']:.1f}%")
                pytest.skip("Not enough data for monthly snapshots (expected in tests)")
            else:
                pytest.fail(f"Unexpected error: {error}")

        assert response.status_code == 200, f"Failed to get snapshots: {response.json()}"

        data = response.json()
        assert "data" in data
        assert data["granularity"] == "month"

        snapshots = data["data"]
        print(f"Found {len(snapshots)} monthly snapshot(s)")

        if snapshots:
            print("\nMonthly snapshots:")
            for snapshot in snapshots:
                print(f"  {snapshot['date']}: ${snapshot['balance']:,.2f}")

    # =========================================
    # Step 12: Test net worth trend
    # =========================================
    def test_12_verify_net_worth_trend(self):
        """Verify net worth data can be used for charting."""
        import datetime

        if not self.access_token:
            pytest.skip("Not logged in - run test_01_login first")

        # Get last 7 days (we only stored 7 days in test_08)
        end_date = datetime.date.today()
        start_date = end_date - datetime.timedelta(days=6)

        response = self.client.get(
            f"{self.base_url}/snapshots",
            params={
                "start_date": start_date.isoformat(),
                "end_date": end_date.isoformat(),
                "granularity": "day",
            },
            headers=self.get_headers(),
        )

        assert response.status_code == 200, f"Failed to get snapshots: {response.json()}"

        data = response.json()
        snapshots = data["data"]

        if len(snapshots) > 1:
            # Calculate net worth change
            first_balance = snapshots[0]["balance"]
            last_balance = snapshots[-1]["balance"]
            change = last_balance - first_balance
            change_pct = (change / first_balance * 100) if first_balance != 0 else 0

            print("\n📈 Net Worth Trend (7 days):")
            print(f"   Start: ${first_balance:,.2f}")
            print(f"   End:   ${last_balance:,.2f}")
            print(f"   Change: ${change:+,.2f} ({change_pct:+.1f}%)")

            # Verify data structure is suitable for charting
            for snapshot in snapshots:
                assert "date" in snapshot
                assert "balance" in snapshot
                assert isinstance(snapshot["balance"], (int, float))

            print(f"   ✅ {len(snapshots)} data points ready for line chart")
        else:
            print(f"\n📈 Net Worth: ${snapshots[0]['balance']:,.2f} (single data point)")

    # =========================================
    # Step 13: Test transaction snapshots (per-account)
    # =========================================
    def test_13_get_account_snapshots(self):
        """Get transaction snapshots for a specific account."""
        import datetime

        if not self.access_token:
            pytest.skip("Not logged in - run test_01_login first")

        # First, get an account ID
        response = self.client.get(
            f"{self.base_url}/simplefin/accounts/{self.simplefin_item_id}",
            headers=self.get_headers(),
        )

        assert response.status_code == 200
        accounts = response.json()

        if not accounts:
            pytest.skip("No accounts found to test transaction snapshots")

        account_id = accounts[0]["id"]
        account_name = accounts[0]["name"]

        print(f"\n💳 Testing account snapshots for: {account_name}")

        # Get account snapshots
        end_date = datetime.date.today()
        start_date = end_date - datetime.timedelta(days=6)

        response = self.client.get(
            f"{self.base_url}/snapshots/account/{account_id}",
            params={
                "start_date": start_date.isoformat(),
                "end_date": end_date.isoformat(),
                "granularity": "day",
            },
            headers=self.get_headers(),
        )

        assert response.status_code == 200, f"Failed to get account snapshots: {response.json()}"

        data = response.json()
        assert "data" in data
        assert data["granularity"] == "day"

        snapshots = data["data"]
        print(f"Found {len(snapshots)} account snapshot(s) for {account_name}")

        if snapshots:
            print("\nAccount snapshots (last 7 days):")
            for snapshot in snapshots:
                date = snapshot["date"]
                balance = snapshot["balance"]
                print(f"  {date}: Balance=${balance:,.2f}")

            # Verify data structure
            for snapshot in snapshots:
                assert "date" in snapshot
                assert "balance" in snapshot
                assert isinstance(snapshot["balance"], (int, float))

            print(f"   ✅ {len(snapshots)} data points ready for account chart")
