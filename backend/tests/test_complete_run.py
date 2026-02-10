"""
Complete CashState integration test.

Tests the full Plaid integration flow against the sandbox:
1. Login with test user
2. Create a sandbox public token (bypasses Link UI)
3. Exchange it via our API
4. Trigger a transaction sync
5. Fetch transactions
"""

import os
import pytest
import plaid
from plaid.api import plaid_api
from plaid.model.sandbox_public_token_create_request import SandboxPublicTokenCreateRequest
from plaid.model.products import Products


class TestCompletePlaidFlow:
    """Test complete Plaid integration flow."""

    access_token: str = None
    user_id: str = None
    plaid_item_id: str = None
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
            TestCompletePlaidFlow.access_token = data["access_token"]
            TestCompletePlaidFlow.user_id = data["user_id"]
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
            TestCompletePlaidFlow.access_token = data["access_token"]
            TestCompletePlaidFlow.user_id = data["user_id"]
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
    # Step 3: Create sandbox public token directly via Plaid SDK
    # =========================================
    def test_03_create_sandbox_token_and_exchange(self):
        """Create a Plaid sandbox public token and exchange it."""
        if not self.access_token:
            pytest.skip("No access token")

        client_id = os.getenv("PLAID_CLIENT_ID")
        secret = os.getenv("PLAID_SECRET")

        if not client_id or not secret:
            pytest.skip("PLAID_CLIENT_ID or PLAID_SECRET not set")

        # Create sandbox public token directly via Plaid API
        configuration = plaid.Configuration(
            host=plaid.Environment.Sandbox,
            api_key={
                "clientId": client_id,
                "secret": secret,
            },
        )
        api_client = plaid.ApiClient(configuration)
        plaid_client = plaid_api.PlaidApi(api_client)

        # Use sandbox institution "First Platypus Bank"
        request = SandboxPublicTokenCreateRequest(
            institution_id="ins_109508",
            initial_products=[Products("transactions")],
        )
        response = plaid_client.sandbox_public_token_create(request)
        public_token = response.public_token
        print(f"Got sandbox public_token: {public_token[:20]}...")

        # Exchange via our API
        exchange_response = self.client.post(
            f"{self.base_url}/plaid/exchange-token",
            headers=self.get_headers(),
            json={
                "public_token": public_token,
                "institution_id": "ins_109508",
                "institution_name": "First Platypus Bank",
            },
        )

        assert exchange_response.status_code == 200, f"Exchange failed: {exchange_response.json()}"
        data = exchange_response.json()
        TestCompletePlaidFlow.plaid_item_id = data["item_id"]
        print(f"Exchanged token, item_id={data['item_id']}")
        print(f"Institution: {data['institution_name']}")

    # =========================================
    # Step 4: List Plaid items
    # =========================================
    def test_04_list_plaid_items(self):
        """Verify our Plaid item shows up."""
        if not self.access_token:
            pytest.skip("No access token")

        response = self.client.get(
            f"{self.base_url}/plaid/items",
            headers=self.get_headers(),
        )

        assert response.status_code == 200
        items = response.json()
        assert len(items) >= 1
        print(f"Found {len(items)} Plaid item(s)")

        # Find our item
        our_item = next((i for i in items if i["id"] == self.plaid_item_id), None)
        if our_item:
            assert our_item["status"] == "active"
            assert our_item["institution_name"] == "First Platypus Bank"
            print(f"Item status: {our_item['status']}")

    # =========================================
    # Step 5: Trigger sync
    # =========================================
    def test_05_trigger_sync(self):
        """Trigger transaction sync for our Plaid item."""
        if not self.access_token or not self.plaid_item_id:
            pytest.skip("No Plaid item to sync")

        response = self.client.post(
            f"{self.base_url}/sync/trigger/{self.plaid_item_id}",
            headers=self.get_headers(),
        )

        assert response.status_code == 200, f"Sync trigger failed: {response.json()}"
        data = response.json()
        assert len(data["job_ids"]) == 1
        TestCompletePlaidFlow.sync_job_id = data["job_ids"][0]
        print(f"Sync triggered, job_id={data['job_ids'][0]}")
        print(f"Message: {data['message']}")

    # =========================================
    # Step 6: Check sync status
    # =========================================
    def test_06_check_sync_status(self):
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
        assert data["transactions_added"] > 0, "Expected sandbox to provide transactions"

    # =========================================
    # Step 7: List all sync jobs
    # =========================================
    def test_07_list_sync_jobs(self):
        """List all sync jobs for the user."""
        if not self.access_token:
            pytest.skip("No access token")

        response = self.client.get(
            f"{self.base_url}/sync/status",
            headers=self.get_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        assert len(data["jobs"]) >= 1
        print(f"Total sync jobs: {len(data['jobs'])}")

    # =========================================
    # Step 8: Fetch transactions
    # =========================================
    def test_08_list_transactions(self):
        """Fetch synced transactions."""
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
        assert data["total"] > 0, "Expected transactions from sandbox sync"
        assert len(data["items"]) > 0

        # Check first transaction has expected fields
        txn = data["items"][0]
        print("Sample transaction:")
        print(f"  Name: {txn['name']}")
        print(f"  Amount: {txn['amount']} {txn.get('iso_currency_code', 'USD')}")
        print(f"  Date: {txn['date']}")
        print(f"  Merchant: {txn.get('merchant_name', 'N/A')}")
        print(f"  Pending: {txn['pending']}")

        assert txn["name"] is not None
        assert txn["amount"] is not None
        assert txn["date"] is not None

    # =========================================
    # Step 9: Get single transaction
    # =========================================
    def test_09_get_single_transaction(self):
        """Fetch a single transaction by ID."""
        if not self.access_token:
            pytest.skip("No access token")

        # First get a transaction ID
        list_response = self.client.get(
            f"{self.base_url}/transactions",
            headers=self.get_headers(),
            params={"limit": 1},
        )
        items = list_response.json()["items"]
        if not items:
            pytest.skip("No transactions to fetch")

        txn_id = items[0]["id"]

        response = self.client.get(
            f"{self.base_url}/transactions/{txn_id}",
            headers=self.get_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == txn_id
        print(f"Got transaction {txn_id}: {data['name']} ${data['amount']}")

    # =========================================
    # Step 10: Test date filtering
    # =========================================
    def test_10_filter_transactions_by_date(self):
        """Test transaction date filtering."""
        if not self.access_token:
            pytest.skip("No access token")

        # Filter to a narrow date range that should return fewer results
        response = self.client.get(
            f"{self.base_url}/transactions",
            headers=self.get_headers(),
            params={
                "date_from": "2024-01-01",
                "date_to": "2024-01-31",
                "limit": 5,
            },
        )

        assert response.status_code == 200
        data = response.json()
        print(f"Transactions in Jan 2024: {data['total']}")

    # =========================================
    # Step 11: Trigger sync-all
    # =========================================
    def test_11_trigger_sync_all(self):
        """Trigger sync for all items."""
        if not self.access_token:
            pytest.skip("No access token")

        response = self.client.post(
            f"{self.base_url}/sync/trigger",
            headers=self.get_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        print(f"Sync-all: {data['message']}")
        print(f"Job IDs: {data['job_ids']}")
