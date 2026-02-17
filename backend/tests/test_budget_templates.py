"""Test budget templates system (Phase 2)."""

import pytest
from fastapi.testclient import TestClient


@pytest.fixture(scope="class")
def setup_user(client: TestClient):
    """Create and login a test user."""
    # Register
    register_resp = client.post(
        "/app/v1/auth/register",
        json={
            "email": "budget_template_test@example.com",
            "password": "testpass123",
        },
    )
    assert register_resp.status_code == 201
    user_data = register_resp.json()

    return {
        "access_token": user_data["access_token"],
        "user_id": user_data["user"]["id"],
        "headers": {"Authorization": f"Bearer {user_data['access_token']}"},
    }


class TestBudgetTemplates:
    """Test budget template CRUD operations."""

    @pytest.fixture(autouse=True)
    def setup(self, client: TestClient, setup_user):
        """Set up test fixtures."""
        self.client = client
        self.user = setup_user
        self.headers = setup_user["headers"]

    def test_01_create_template(self):
        """Test creating a budget template."""
        response = self.client.post(
            "/app/v1/budget-templates",
            headers=self.headers,
            json={
                "name": "Regular Budget",
                "total_amount": 3000.00,
                "is_default": True,
                "account_ids": [],
            },
        )
        assert response.status_code == 201
        data = response.json()

        assert data["name"] == "Regular Budget"
        assert data["total_amount"] == 3000.00
        assert data["is_default"] is True
        assert data["account_ids"] == []

        # Store for later tests
        self.__class__.template_id = data["id"]

    def test_02_list_templates(self):
        """Test listing budget templates."""
        response = self.client.get(
            "/app/v1/budget-templates",
            headers=self.headers,
        )
        assert response.status_code == 200
        data = response.json()

        assert data["total"] >= 1
        assert len(data["items"]) >= 1
        assert data["items"][0]["name"] == "Regular Budget"

    def test_03_get_template(self):
        """Test getting a single template with categories."""
        response = self.client.get(
            f"/app/v1/budget-templates/{self.template_id}",
            headers=self.headers,
        )
        assert response.status_code == 200
        data = response.json()

        assert data["id"] == self.template_id
        assert data["name"] == "Regular Budget"
        assert "categories" in data
        assert "subcategories" in data

    def test_04_update_template(self):
        """Test updating a template."""
        response = self.client.patch(
            f"/app/v1/budget-templates/{self.template_id}",
            headers=self.headers,
            json={
                "name": "Updated Budget",
                "total_amount": 3500.00,
            },
        )
        assert response.status_code == 200
        data = response.json()

        assert data["name"] == "Updated Budget"
        assert data["total_amount"] == 3500.00

    def test_05_create_second_template(self):
        """Test creating a second (non-default) template."""
        response = self.client.post(
            "/app/v1/budget-templates",
            headers=self.headers,
            json={
                "name": "Vacation Budget",
                "total_amount": 5000.00,
                "is_default": False,
                "account_ids": [],
            },
        )
        assert response.status_code == 201
        data = response.json()

        assert data["name"] == "Vacation Budget"
        assert data["is_default"] is False

        self.__class__.vacation_template_id = data["id"]

    def test_06_set_default_template(self):
        """Test setting a template as default."""
        response = self.client.post(
            f"/app/v1/budget-templates/{self.vacation_template_id}/set-default",
            headers=self.headers,
        )
        assert response.status_code == 200
        data = response.json()

        assert data["is_default"] is True

        # Verify first template is no longer default
        first_resp = self.client.get(
            f"/app/v1/budget-templates/{self.template_id}",
            headers=self.headers,
        )
        assert first_resp.json()["is_default"] is False


class TestBudgetCategories:
    """Test budget category operations within templates."""

    @pytest.fixture(autouse=True)
    def setup(self, client: TestClient, setup_user):
        """Set up test fixtures."""
        self.client = client
        self.user = setup_user
        self.headers = setup_user["headers"]

        # Create a template
        template_resp = client.post(
            "/app/v1/budget-templates",
            headers=self.headers,
            json={
                "name": "Category Test Budget",
                "total_amount": 2000.00,
                "is_default": False,
                "account_ids": [],
            },
        )
        self.template_id = template_resp.json()["id"]

        # Create a category
        category_resp = client.post(
            "/app/v1/categories",
            headers=self.headers,
            json={
                "name": "Test Food",
                "icon": "🍔",
                "color": "#FF0000",
            },
        )
        self.category_id = category_resp.json()["id"]

    def test_01_add_category_budget(self):
        """Test adding a category budget to a template."""
        response = self.client.post(
            f"/app/v1/budget-templates/{self.template_id}/categories",
            headers=self.headers,
            json={
                "category_id": self.category_id,
                "amount": 500.00,
            },
        )
        assert response.status_code == 201
        data = response.json()

        assert data["category_id"] == self.category_id
        assert data["amount"] == 500.00

        self.__class__.category_budget_id = data["id"]

    def test_02_update_category_budget(self):
        """Test updating a category budget."""
        response = self.client.patch(
            f"/app/v1/budget-templates/{self.template_id}/categories/{self.category_budget_id}",
            headers=self.headers,
            json={
                "amount": 600.00,
            },
        )
        assert response.status_code == 200
        data = response.json()

        assert data["amount"] == 600.00

    def test_03_delete_category_budget(self):
        """Test deleting a category budget."""
        response = self.client.delete(
            f"/app/v1/budget-templates/{self.template_id}/categories/{self.category_budget_id}",
            headers=self.headers,
        )
        assert response.status_code == 200


class TestBudgetPeriods:
    """Test budget period operations (monthly overrides)."""

    @pytest.fixture(autouse=True)
    def setup(self, client: TestClient, setup_user):
        """Set up test fixtures."""
        self.client = client
        self.user = setup_user
        self.headers = setup_user["headers"]

        # Create default template
        default_resp = client.post(
            "/app/v1/budget-templates",
            headers=self.headers,
            json={
                "name": "Default Monthly",
                "total_amount": 3000.00,
                "is_default": True,
                "account_ids": [],
            },
        )
        self.default_template_id = default_resp.json()["id"]

        # Create vacation template
        vacation_resp = client.post(
            "/app/v1/budget-templates",
            headers=self.headers,
            json={
                "name": "Vacation Override",
                "total_amount": 5000.00,
                "is_default": False,
                "account_ids": [],
            },
        )
        self.vacation_template_id = vacation_resp.json()["id"]

    def test_01_create_period_override(self):
        """Test applying a template to a specific month."""
        response = self.client.post(
            "/app/v1/budget-templates/periods",
            headers=self.headers,
            json={
                "template_id": self.vacation_template_id,
                "period_month": "2026-03",  # March 2026
            },
        )
        assert response.status_code == 201
        data = response.json()

        assert data["template_id"] == self.vacation_template_id
        assert "2026-03" in data["period_month"]

        self.__class__.period_id = data["id"]

    def test_02_list_periods(self):
        """Test listing budget periods."""
        response = self.client.get(
            "/app/v1/budget-templates/periods",
            headers=self.headers,
        )
        assert response.status_code == 200
        data = response.json()

        assert data["total"] >= 1
        assert len(data["items"]) >= 1

    def test_03_get_budget_for_overridden_month(self):
        """Test getting budget for a month with override."""
        response = self.client.get(
            "/app/v1/budget-templates/for-month",
            headers=self.headers,
            params={
                "year": 2026,
                "month": 3,  # March - has override
            },
        )
        assert response.status_code == 200
        data = response.json()

        # Should use vacation template
        assert data["template"]["id"] == self.vacation_template_id
        assert data["template"]["name"] == "Vacation Override"
        assert data["has_override"] is True
        assert "total_spent" in data
        assert "categories" in data

    def test_04_get_budget_for_default_month(self):
        """Test getting budget for a month without override."""
        response = self.client.get(
            "/app/v1/budget-templates/for-month",
            headers=self.headers,
            params={
                "year": 2026,
                "month": 2,  # February - no override
            },
        )
        assert response.status_code == 200
        data = response.json()

        # Should use default template
        assert data["template"]["id"] == self.default_template_id
        assert data["template"]["name"] == "Default Monthly"
        assert data["has_override"] is False

    def test_05_delete_period(self):
        """Test deleting a period override (revert to default)."""
        response = self.client.delete(
            f"/app/v1/budget-templates/periods/{self.period_id}",
            headers=self.headers,
        )
        assert response.status_code == 200

        # Verify March now uses default
        march_resp = self.client.get(
            "/app/v1/budget-templates/for-month",
            headers=self.headers,
            params={"year": 2026, "month": 3},
        )
        assert march_resp.json()["template"]["id"] == self.default_template_id


class TestDeprecatedBudgets:
    """Test that old /budgets endpoints return deprecation errors."""

    @pytest.fixture(autouse=True)
    def setup(self, client: TestClient, setup_user):
        """Set up test fixtures."""
        self.client = client
        self.headers = setup_user["headers"]

    def test_list_budgets_deprecated(self):
        """Test that listing budgets returns deprecation error."""
        response = self.client.get(
            "/app/v1/budgets",
            headers=self.headers,
        )
        assert response.status_code == 410
        data = response.json()
        assert "deprecated" in data["detail"]["error"].lower()

    def test_create_budget_deprecated(self):
        """Test that creating budget returns deprecation error."""
        response = self.client.post(
            "/app/v1/budgets",
            headers=self.headers,
            json={
                "category_id": "fake-id",
                "amount": 100.00,
            },
        )
        assert response.status_code == 410
        data = response.json()
        assert "deprecated" in data["detail"]["error"].lower()
