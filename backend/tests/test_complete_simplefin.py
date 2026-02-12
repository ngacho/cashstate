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
            params={"start_date": start_timestamp},
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
