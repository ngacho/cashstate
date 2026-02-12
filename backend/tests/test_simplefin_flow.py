"""
Complete SimpleFin integration test.

Tests the full SimpleFin integration flow:
1. Login with test user
2. Exchange SimpleFin setup token
3. List SimpleFin items
4. Fetch accounts (preview)
5. Trigger transaction sync
6. Fetch transactions
7. Delete SimpleFin item
"""

import os
import pytest
from unittest.mock import patch


# Mock SimpleFin responses
MOCK_ACCESS_URL = "https://testuser:testpass@beta-bridge.simplefin.org/simplefin/accounts"

MOCK_ACCOUNTS_RESPONSE = {
    "accounts": [
        {
            "id": "2309482039482039482034",
            "name": "Checking Account",
            "currency": "USD",
            "balance": "1203.52",
            "balance-date": 1234567890,
            "transactions": [
                {
                    "id": "12394871239",
                    "posted": "2024-01-15",
                    "amount": -45.67,
                    "description": "Coffee Shop",
                    "payee": "Local Coffee Shop"
                },
                {
                    "id": "12394871240",
                    "posted": "2024-01-14",
                    "amount": -120.00,
                    "description": "Grocery Store",
                    "payee": "SuperMart"
                },
                {
                    "id": "12394871241",
                    "posted": "2024-01-13",
                    "amount": 2500.00,
                    "description": "Paycheck",
                    "payee": "Employer Inc"
                }
            ]
        },
        {
            "id": "2309482039482039482035",
            "name": "Savings Account",
            "currency": "USD",
            "balance": "5420.10",
            "balance-date": 1234567890,
            "transactions": [
                {
                    "id": "12394871242",
                    "posted": "2024-01-10",
                    "amount": 100.00,
                    "description": "Transfer from checking",
                    "payee": "Self"
                }
            ]
        }
    ],
    "errors": []
}


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
                "display_name": "SimpleFin Tester",
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
    @patch("app.services.simplefin_service.claim_access_url")
    def test_03_exchange_setup_token(self, mock_claim):
        """Exchange a SimpleFin setup token for access."""
        if not self.access_token:
            pytest.skip("No access token")

        # Mock the SimpleFin claim_access_url call
        mock_claim.return_value = MOCK_ACCESS_URL

        # Create a fake setup token (base64 encoded URL)
        import base64
        fake_claim_url = "https://beta-bridge.simplefin.org/claim/test123"
        setup_token = base64.b64encode(fake_claim_url.encode()).decode()

        response = self.client.post(
            f"{self.base_url}/simplefin/setup",
            headers=self.get_headers(),
            json={
                "setup_token": setup_token,
                "institution_name": "Test Bank",
            },
        )

        assert response.status_code == 200, f"Setup failed: {response.json()}"
        data = response.json()
        TestCompleteSimplefinFlow.simplefin_item_id = data["item_id"]
        print(f"Setup complete, item_id={data['item_id']}")
        print(f"Institution: {data['institution_name']}")

        # Verify mock was called
        mock_claim.assert_called_once_with(setup_token)

    # =========================================
    # Step 4: List SimpleFin items
    # =========================================
    def test_04_list_simplefin_items(self):
        """Verify our SimpleFin item shows up."""
        if not self.access_token:
            pytest.skip("No access token")

        response = self.client.get(
            f"{self.base_url}/simplefin/items",
            headers=self.get_headers(),
        )

        assert response.status_code == 200
        items = response.json()
        assert len(items) >= 1
        print(f"Found {len(items)} SimpleFin item(s)")

        # Find our item
        our_item = next((i for i in items if i["id"] == self.simplefin_item_id), None)
        if our_item:
            assert our_item["status"] == "active"
            assert our_item["institution_name"] == "Test Bank"
            print(f"Item status: {our_item['status']}")

    # =========================================
    # Step 5: Fetch accounts (preview)
    # =========================================
    @patch("app.services.simplefin_service.fetch_accounts")
    def test_05_fetch_accounts(self, mock_fetch):
        """Fetch raw account data from SimpleFin."""
        if not self.access_token or not self.simplefin_item_id:
            pytest.skip("No SimpleFin item")

        # Mock the fetch_accounts call
        mock_fetch.return_value = MOCK_ACCOUNTS_RESPONSE

        response = self.client.get(
            f"{self.base_url}/simplefin/accounts/{self.simplefin_item_id}",
            headers=self.get_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        assert "accounts" in data
        assert len(data["accounts"]) == 2
        print(f"Fetched {len(data['accounts'])} accounts")

        # Check account structure
        account = data["accounts"][0]
        print(f"Sample account: {account['name']} - {account['currency']} {account['balance']}")
        assert account["name"] == "Checking Account"
        assert len(account["transactions"]) == 3

    # =========================================
    # Step 6: Trigger sync
    # =========================================
    @patch("app.services.simplefin_service.fetch_accounts")
    def test_06_trigger_sync(self, mock_fetch):
        """Trigger transaction sync for our SimpleFin item."""
        if not self.access_token or not self.simplefin_item_id:
            pytest.skip("No SimpleFin item to sync")

        # Mock the fetch_accounts call
        mock_fetch.return_value = MOCK_ACCOUNTS_RESPONSE

        response = self.client.post(
            f"{self.base_url}/simplefin/sync/{self.simplefin_item_id}",
            headers=self.get_headers(),
        )

        assert response.status_code == 200, f"Sync failed: {response.json()}"
        data = response.json()
        assert data["success"] is True
        TestCompleteSimplefinFlow.sync_job_id = data["sync_job_id"]
        print(f"Sync completed, job_id={data['sync_job_id']}")
        print(f"Transactions added: {data['transactions_added']}")
        assert data["transactions_added"] == 4  # 3 + 1 from two accounts

    # =========================================
    # Step 7: Check sync job status
    # =========================================
    def test_07_check_sync_status(self):
        """Check the sync job completed."""
        if not self.access_token or not self.sync_job_id:
            pytest.skip("No sync job to check")

        response = self.client.get(
            f"{self.base_url}/sync/status/{self.sync_job_id}",
            headers=self.get_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        print(f"Sync job status: {data['status']}")
        print(f"  Added: {data['transactions_added']}")
        print(f"  Modified: {data['transactions_modified']}")
        print(f"  Removed: {data['transactions_removed']}")

        assert data["status"] == "completed"
        assert data["transactions_added"] == 4

    # =========================================
    # Step 8: List all sync jobs
    # =========================================
    def test_08_list_sync_jobs(self):
        """List all sync jobs for the user."""
        if not self.access_token:
            pytest.skip("No access token")

        response = self.client.get(
            f"{self.base_url}/sync/status",
            headers=self.get_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        # Should have at least our SimpleFin sync job
        assert len(data["jobs"]) >= 1
        print(f"Total sync jobs: {len(data['jobs'])}")

        # Find our SimpleFin sync job
        sf_jobs = [j for j in data["jobs"] if j.get("source") == "simplefin"]
        print(f"SimpleFin sync jobs: {len(sf_jobs)}")

    # =========================================
    # Step 9: Fetch transactions
    # =========================================
    def test_09_list_transactions(self):
        """Fetch synced transactions (including SimpleFin)."""
        if not self.access_token:
            pytest.skip("No access token")

        response = self.client.get(
            f"{self.base_url}/transactions",
            headers=self.get_headers(),
            params={"limit": 10},
        )

        assert response.status_code == 200
        data = response.json()
        print(f"Total transactions: {data['total']}")
        print(f"Returned: {len(data['items'])}")

        # Should have SimpleFin transactions
        assert data["total"] >= 4, "Expected at least 4 transactions from SimpleFin"
        assert len(data["items"]) > 0

        # Check for SimpleFin transactions
        sf_transactions = [t for t in data["items"] if t.get("source") == "simplefin"]
        print(f"SimpleFin transactions: {len(sf_transactions)}")

        if sf_transactions:
            txn = sf_transactions[0]
            print("Sample SimpleFin transaction:")
            print(f"  Name: {txn['name']}")
            print(f"  Amount: {txn['amount']} {txn.get('iso_currency_code', 'USD')}")
            print(f"  Date: {txn['date']}")
            print(f"  Source: {txn['source']}")

            assert txn["name"] is not None
            assert txn["amount"] is not None
            assert txn["date"] is not None
            assert txn["source"] == "simplefin"

    # =========================================
    # Step 10: Get single transaction
    # =========================================
    def test_10_get_single_transaction(self):
        """Fetch a single SimpleFin transaction by ID."""
        if not self.access_token:
            pytest.skip("No access token")

        # First get a SimpleFin transaction ID
        list_response = self.client.get(
            f"{self.base_url}/transactions",
            headers=self.get_headers(),
            params={"limit": 10},
        )
        items = list_response.json()["items"]
        sf_transactions = [t for t in items if t.get("source") == "simplefin"]

        if not sf_transactions:
            pytest.skip("No SimpleFin transactions to fetch")

        txn_id = sf_transactions[0]["id"]

        response = self.client.get(
            f"{self.base_url}/transactions/{txn_id}",
            headers=self.get_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == txn_id
        assert data["source"] == "simplefin"
        print(f"Got SimpleFin transaction {txn_id}: {data['name']} ${data['amount']}")

    # =========================================
    # Step 11: Test date filtering
    # =========================================
    def test_11_filter_transactions_by_date(self):
        """Test transaction date filtering for SimpleFin."""
        if not self.access_token:
            pytest.skip("No access token")

        # Filter to January 2024
        response = self.client.get(
            f"{self.base_url}/transactions",
            headers=self.get_headers(),
            params={
                "date_from": "2024-01-01",
                "date_to": "2024-01-31",
                "limit": 10,
            },
        )

        assert response.status_code == 200
        data = response.json()
        print(f"Transactions in Jan 2024: {data['total']}")

        # Should include our SimpleFin transactions from Jan 2024
        assert data["total"] >= 4

    # =========================================
    # Step 12: Delete SimpleFin item
    # =========================================
    def test_12_delete_simplefin_item(self):
        """Delete the SimpleFin item."""
        if not self.access_token or not self.simplefin_item_id:
            pytest.skip("No SimpleFin item to delete")

        response = self.client.delete(
            f"{self.base_url}/simplefin/items/{self.simplefin_item_id}",
            headers=self.get_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        print(f"Deleted SimpleFin item: {data['message']}")

        # Verify it's gone
        list_response = self.client.get(
            f"{self.base_url}/simplefin/items",
            headers=self.get_headers(),
        )
        items = list_response.json()
        our_item = next((i for i in items if i["id"] == self.simplefin_item_id), None)
        assert our_item is None, "Item should be deleted"
        print("Verified item was deleted")

    # =========================================
    # Step 13: Verify transactions were cascaded
    # =========================================
    def test_13_verify_transactions_deleted(self):
        """Verify SimpleFin transactions were deleted with the item."""
        if not self.access_token:
            pytest.skip("No access token")

        response = self.client.get(
            f"{self.base_url}/transactions",
            headers=self.get_headers(),
            params={"limit": 100},
        )

        assert response.status_code == 200
        data = response.json()

        # Check for SimpleFin transactions from our deleted item
        sf_transactions = [
            t for t in data["items"]
            if t.get("source") == "simplefin" and t.get("simplefin_item_id") == self.simplefin_item_id
        ]

        assert len(sf_transactions) == 0, "SimpleFin transactions should be deleted"
        print("Verified transactions were cascaded on delete")
