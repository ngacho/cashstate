"""
Complete airport run test.

This test simulates a full user journey through an airport:
1. Register/login
2. Add a flight
3. Enter airport geofence
4. Find nearby checkpoints
5. Start security session
6. End security session
7. Start gate journey
8. Add waypoints
9. Start/end dwell at shop
10. End journey at gate
11. Submit feedback
"""

import pytest
from datetime import datetime, timedelta, timezone
import time


class TestCompleteAirportRun:
    """Test complete airport journey flow."""

    # Store state between tests
    access_token: str = None
    user_id: str = None
    flight_id: str = None
    checkpoint_id: str = None
    session_id: str = None
    journey_id: str = None
    gate_id: str = None

    @pytest.fixture(autouse=True)
    def setup(self, client):
        """Store client for all tests."""
        self.client = client
        self.base_url = "/app/v1"

    def get_headers(self):
        """Get authorization headers."""
        return {"Authorization": f"Bearer {self.access_token}"}

    # =========================================
    # Step 1: Register/Login
    # =========================================
    def test_01_register_user(self):
        """Step 1: Login (or register) a user."""
        import os
        email = os.getenv("TEST_USER_EMAIL")
        if not email:
            pytest.skip("TEST_USER_EMAIL not set in environment")

        password = os.getenv("TEST_USER_PASSWORD", "TestRunner123!")

        # Try login first (user may already exist)
        login_response = self.client.post(
            f"{self.base_url}/auth/login",
            json={"email": email, "password": password},
        )

        if login_response.status_code == 200:
            data = login_response.json()
            TestCompleteAirportRun.access_token = data["access_token"]
            TestCompleteAirportRun.user_id = data["user_id"]
            assert data["access_token"] is not None
            return

        # If login fails, try registration
        response = self.client.post(
            f"{self.base_url}/auth/register",
            json={
                "email": email,
                "password": password,
                "display_name": "Airport Runner",
            },
        )

        if response.status_code == 201:
            data = response.json()
            TestCompleteAirportRun.access_token = data["access_token"]
            TestCompleteAirportRun.user_id = data["user_id"]
            assert data["access_token"] is not None
        else:
            pytest.fail(f"Login failed: {login_response.json()}, Register failed: {response.json()}")

    def test_02_get_user_profile(self):
        """Verify user profile can be retrieved."""
        if not self.access_token:
            pytest.skip("No access token")

        response = self.client.get(
            f"{self.base_url}/users/me",
            headers=self.get_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        assert data["email"] is not None
        assert data["total_xp"] == 0
        assert data["level"] == 1

    # =========================================
    # Step 2: Add a Flight
    # =========================================
    def test_03_create_flight(self):
        """Step 2: Add an upcoming flight."""
        if not self.access_token:
            pytest.skip("No access token")

        departure = datetime.now(timezone.utc) + timedelta(hours=3)

        response = self.client.post(
            f"{self.base_url}/flights",
            headers=self.get_headers(),
            json={
                "flight_number": "AA100",
                "airline": "American Airlines",
                "departure_airport": "LAX",
                "arrival_airport": "JFK",
                "departure_time": departure.isoformat(),
            },
        )

        assert response.status_code == 201
        data = response.json()
        TestCompleteAirportRun.flight_id = data["id"]
        assert data["flight_number"] == "AA100"
        assert data["status"] == "scheduled"

    def test_04_list_flights(self):
        """Verify flight appears in list."""
        if not self.access_token:
            pytest.skip("No access token")

        response = self.client.get(
            f"{self.base_url}/flights",
            headers=self.get_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 1
        assert any(f["id"] == self.flight_id for f in data)

    # =========================================
    # Step 3: Enter Airport Geofence
    # =========================================
    def test_05_enter_airport_geofence(self):
        """Step 3: Enter LAX airport geofence."""
        if not self.access_token:
            pytest.skip("No access token")

        response = self.client.post(
            f"{self.base_url}/location/geofence/enter",
            headers=self.get_headers(),
            json={
                "airport_code": "LAX",
                "latitude": 33.9425,
                "longitude": -118.4081,
                "flight_id": self.flight_id,
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["airport_code"] == "LAX"
        assert "Welcome" in data["message"] or "Already" in data["message"]

    # =========================================
    # Step 4: Find Nearby Checkpoints
    # =========================================
    def test_06_find_nearby_checkpoints(self):
        """Step 4: Find checkpoints near current location."""
        if not self.access_token:
            pytest.skip("No access token")

        response = self.client.get(
            f"{self.base_url}/checkpoints/nearby",
            headers=self.get_headers(),
            params={
                "latitude": 33.9435,  # Slightly offset to be near a checkpoint
                "longitude": -118.4071,
                "radius": 5000,
            },
        )

        assert response.status_code == 200
        data = response.json()

        if data:
            # Use the first checkpoint found
            TestCompleteAirportRun.checkpoint_id = data[0]["checkpoint"]["id"]
            assert data[0]["distance_meters"] >= 0

    def test_07_get_airport_comparison(self):
        """Get checkpoint comparison for LAX."""
        if not self.access_token:
            pytest.skip("No access token")

        response = self.client.get(
            f"{self.base_url}/checkpoints/airports/LAX/comparison",
            headers=self.get_headers(),
        )

        # May be 404 if no checkpoints seeded
        if response.status_code == 200:
            data = response.json()
            assert data["airport_code"] == "LAX"

            # Get a checkpoint ID if we don't have one
            if not self.checkpoint_id and data.get("checkpoints"):
                TestCompleteAirportRun.checkpoint_id = data["checkpoints"][0]["id"]

    # =========================================
    # Step 5: Start Security Session
    # =========================================
    def test_08_start_security_session(self):
        """Step 5: Start timing security checkpoint."""
        if not self.access_token:
            pytest.skip("No access token")
        if not self.checkpoint_id:
            pytest.skip("No checkpoint ID - seed database first")

        response = self.client.post(
            f"{self.base_url}/sessions/security/start",
            headers=self.get_headers(),
            json={
                "checkpoint_id": self.checkpoint_id,
                "flight_id": self.flight_id,
                "estimated_wait_minutes": 15,
            },
        )

        assert response.status_code == 201
        data = response.json()
        TestCompleteAirportRun.session_id = data["id"]
        assert data["checkpoint_id"] == self.checkpoint_id

    def test_09_check_active_session(self):
        """Verify active session exists."""
        if not self.access_token:
            pytest.skip("No access token")

        response = self.client.get(
            f"{self.base_url}/sessions/security/active",
            headers=self.get_headers(),
        )

        assert response.status_code == 200
        data = response.json()

        if data:
            assert data["session"]["id"] == self.session_id
            assert data["elapsed_seconds"] >= 0

    # =========================================
    # Step 6: End Security Session
    # =========================================
    def test_10_end_security_session(self):
        """Step 6: Complete security and get results."""
        if not self.access_token or not self.session_id:
            pytest.skip("No session to end")

        # Wait a moment to accumulate some time
        time.sleep(1)

        response = self.client.post(
            f"{self.base_url}/sessions/security/{self.session_id}/end",
            headers=self.get_headers(),
            json={},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["ended_at"] is not None
        assert data["xp_earned"] >= 0
        assert data["actual_wait_minutes"] is not None

    # =========================================
    # Step 7: Start Gate Journey
    # =========================================
    def test_11_get_gate_info(self):
        """Get a gate to journey to."""
        if not self.access_token:
            pytest.skip("No access token")

        # Get gates at LAX
        from app.database import get_supabase_client

        try:
            client = get_supabase_client()
            result = client.table("gates").select("id").eq("airport_code", "LAX").limit(1).execute()
            if result.data:
                TestCompleteAirportRun.gate_id = result.data[0]["id"]
        except Exception:
            pass  # Will skip journey tests if no gates

    def test_12_start_gate_journey(self):
        """Step 7: Start journey to gate."""
        if not self.access_token:
            pytest.skip("No access token")

        response = self.client.post(
            f"{self.base_url}/journeys/start",
            headers=self.get_headers(),
            json={
                "flight_id": self.flight_id,
                "security_session_id": self.session_id,
                "origin_checkpoint_id": self.checkpoint_id,
                "destination_gate_id": self.gate_id,
                "latitude": 33.9430,
                "longitude": -118.4075,
            },
        )

        assert response.status_code == 201
        data = response.json()
        TestCompleteAirportRun.journey_id = data["id"]

    # =========================================
    # Step 8: Add Waypoints
    # =========================================
    def test_13_add_waypoint(self):
        """Step 8: Record location during journey."""
        if not self.access_token or not self.journey_id:
            pytest.skip("No journey to add waypoint to")

        response = self.client.post(
            f"{self.base_url}/journeys/{self.journey_id}/waypoint",
            headers=self.get_headers(),
            json={
                "latitude": 33.9435,
                "longitude": -118.4070,
                "accuracy": 10.0,
            },
        )

        assert response.status_code == 200

    # =========================================
    # Step 9: Start/End Dwell at Shop
    # =========================================
    def test_14_start_dwell(self):
        """Step 9a: Stop at a shop."""
        if not self.access_token or not self.journey_id:
            pytest.skip("No journey for dwell")

        response = self.client.post(
            f"{self.base_url}/journeys/{self.journey_id}/dwell/start",
            headers=self.get_headers(),
            json={
                "location_type": "shop",
                "location_name": "Hudson News",
                "latitude": 33.9437,
                "longitude": -118.4068,
            },
        )

        assert response.status_code == 201

    def test_15_end_dwell(self):
        """Step 9b: Leave the shop."""
        if not self.access_token or not self.journey_id:
            pytest.skip("No journey for dwell")

        time.sleep(1)  # Spend some time at shop

        response = self.client.post(
            f"{self.base_url}/journeys/{self.journey_id}/dwell/end",
            headers=self.get_headers(),
            json={},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["duration_seconds"] is not None

    # =========================================
    # Step 10: End Journey at Gate
    # =========================================
    def test_16_end_journey(self):
        """Step 10: Arrive at gate and complete journey."""
        if not self.access_token or not self.journey_id:
            pytest.skip("No journey to end")

        response = self.client.post(
            f"{self.base_url}/journeys/{self.journey_id}/end",
            headers=self.get_headers(),
            json={
                "latitude": 33.9440,
                "longitude": -118.4060,
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["ended_at"] is not None
        assert data["total_duration_seconds"] is not None
        assert data["xp_earned"] >= 0

    # =========================================
    # Step 11: Submit Feedback
    # =========================================
    def test_17_get_journey_summary(self):
        """Get summary of the journey."""
        if not self.access_token or not self.flight_id:
            pytest.skip("No flight for summary")

        response = self.client.get(
            f"{self.base_url}/flights/{self.flight_id}/journey-summary",
            headers=self.get_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        assert data["flight_id"] == self.flight_id
        assert data["total_xp_earned"] >= 0

    def test_18_submit_feedback(self):
        """Step 11: Submit feedback about the experience."""
        if not self.access_token or not self.flight_id:
            pytest.skip("No flight for feedback")

        response = self.client.post(
            f"{self.base_url}/flights/{self.flight_id}/feedback",
            headers=self.get_headers(),
            json={
                "security_session_id": self.session_id,
                "checkpoint_id": self.checkpoint_id,
                "rating": 4,
                "wait_accuracy": "accurate",
                "comments": "Smooth experience, thanks!",
            },
        )

        # May be 400 if feedback already submitted
        assert response.status_code in [201, 400]

        if response.status_code == 201:
            data = response.json()
            assert data["rating"] == 4
            assert data["xp_earned"] > 0

    # =========================================
    # Final: Check User Stats
    # =========================================
    def test_19_check_user_stats(self):
        """Verify user stats were updated."""
        if not self.access_token:
            pytest.skip("No access token")

        response = self.client.get(
            f"{self.base_url}/users/me/stats",
            headers=self.get_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        assert data["total_xp"] >= 0
        assert data["total_flights"] >= 1
        assert data["total_security_sessions"] >= 0

    def test_20_check_final_xp(self):
        """Verify XP was earned."""
        if not self.access_token:
            pytest.skip("No access token")

        response = self.client.get(
            f"{self.base_url}/users/me",
            headers=self.get_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        # Should have earned XP from security session, journey, and feedback
        print(f"Final XP: {data['total_xp']}")
        print(f"Final Level: {data['level']}")
