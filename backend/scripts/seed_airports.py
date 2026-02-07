#!/usr/bin/env python3
"""Seed database with airport, checkpoint, and gate data."""

import os
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from dotenv import load_dotenv
from supabase import create_client

load_dotenv()


def get_client():
    """Get Supabase client."""
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_SECRET_KEY")

    if not url or not key:
        print("Error: SUPABASE_URL and SUPABASE_SECRET_KEY must be set")
        sys.exit(1)

    return create_client(url, key)


# Sample airport data (major US airports)
AIRPORTS = [
    {
        "code": "LAX",
        "name": "Los Angeles International Airport",
        "city": "Los Angeles",
        "country": "USA",
        "timezone": "America/Los_Angeles",
        "latitude": 33.9425,
        "longitude": -118.4081,
        "geofence_radius": 5000,
    },
    {
        "code": "JFK",
        "name": "John F. Kennedy International Airport",
        "city": "New York",
        "country": "USA",
        "timezone": "America/New_York",
        "latitude": 40.6413,
        "longitude": -73.7781,
        "geofence_radius": 5000,
    },
    {
        "code": "SFO",
        "name": "San Francisco International Airport",
        "city": "San Francisco",
        "country": "USA",
        "timezone": "America/Los_Angeles",
        "latitude": 37.6213,
        "longitude": -122.3790,
        "geofence_radius": 4000,
    },
    {
        "code": "ORD",
        "name": "O'Hare International Airport",
        "city": "Chicago",
        "country": "USA",
        "timezone": "America/Chicago",
        "latitude": 41.9742,
        "longitude": -87.9073,
        "geofence_radius": 5000,
    },
    {
        "code": "DFW",
        "name": "Dallas/Fort Worth International Airport",
        "city": "Dallas",
        "country": "USA",
        "timezone": "America/Chicago",
        "latitude": 32.8998,
        "longitude": -97.0403,
        "geofence_radius": 6000,
    },
    {
        "code": "DEN",
        "name": "Denver International Airport",
        "city": "Denver",
        "country": "USA",
        "timezone": "America/Denver",
        "latitude": 39.8561,
        "longitude": -104.6737,
        "geofence_radius": 5000,
    },
    {
        "code": "SEA",
        "name": "Seattle-Tacoma International Airport",
        "city": "Seattle",
        "country": "USA",
        "timezone": "America/Los_Angeles",
        "latitude": 47.4502,
        "longitude": -122.3088,
        "geofence_radius": 4000,
    },
    {
        "code": "ATL",
        "name": "Hartsfield-Jackson Atlanta International Airport",
        "city": "Atlanta",
        "country": "USA",
        "timezone": "America/New_York",
        "latitude": 33.6407,
        "longitude": -84.4277,
        "geofence_radius": 5000,
    },
]

# Sample checkpoints for each airport
def get_checkpoints(airport_code: str, airport_lat: float, airport_lon: float) -> list:
    """Generate checkpoint data for an airport."""
    # Small offsets for checkpoint locations within airport
    offsets = [
        (0.001, 0.001, "Terminal 1", "standard"),
        (0.001, -0.001, "Terminal 2", "standard"),
        (-0.001, 0.001, "Terminal 1 PreCheck", "precheck"),
        (-0.001, -0.001, "Terminal 2 PreCheck", "precheck"),
        (0.0015, 0, "CLEAR Lane", "clear"),
    ]

    checkpoints = []
    for lat_off, lon_off, name, cp_type in offsets:
        checkpoints.append({
            "airport_code": airport_code,
            "name": f"{airport_code} {name}",
            "terminal": name.split()[0] if "Terminal" in name else "Main",
            "checkpoint_type": cp_type,
            "latitude": airport_lat + lat_off,
            "longitude": airport_lon + lon_off,
            "geofence_radius": 100,
            "is_active": True,
        })

    return checkpoints


# Sample gates for each airport
def get_gates(airport_code: str, airport_lat: float, airport_lon: float) -> list:
    """Generate gate data for an airport."""
    gates = []

    terminals = ["A", "B", "C"]
    for terminal in terminals:
        for gate_num in range(1, 11):  # 10 gates per terminal
            # Spread gates across the airport
            lat_offset = (ord(terminal) - ord("A") - 1) * 0.002
            lon_offset = (gate_num - 5) * 0.0005

            gates.append({
                "airport_code": airport_code,
                "terminal": terminal,
                "gate_number": f"{terminal}{gate_num}",
                "latitude": airport_lat + lat_offset,
                "longitude": airport_lon + lon_offset,
                "geofence_radius": 50,
            })

    return gates


def seed_airports(client):
    """Seed airport data."""
    print("Seeding airports...")

    for airport in AIRPORTS:
        try:
            # Check if airport exists
            result = client.table("airports").select("code").eq("code", airport["code"]).execute()

            if result.data:
                print(f"  Airport {airport['code']} already exists, updating...")
                client.table("airports").update(airport).eq("code", airport["code"]).execute()
            else:
                print(f"  Creating airport {airport['code']}...")
                client.table("airports").insert(airport).execute()

        except Exception as e:
            print(f"  Error seeding airport {airport['code']}: {e}")

    print(f"  Seeded {len(AIRPORTS)} airports")


def seed_checkpoints(client):
    """Seed checkpoint data."""
    print("Seeding checkpoints...")

    total = 0
    for airport in AIRPORTS:
        checkpoints = get_checkpoints(
            airport["code"],
            airport["latitude"],
            airport["longitude"],
        )

        for checkpoint in checkpoints:
            try:
                # Check if checkpoint exists by name and airport
                result = (
                    client.table("checkpoints")
                    .select("id")
                    .eq("airport_code", checkpoint["airport_code"])
                    .eq("name", checkpoint["name"])
                    .execute()
                )

                if result.data:
                    # Update existing
                    client.table("checkpoints").update(checkpoint).eq("id", result.data[0]["id"]).execute()
                else:
                    # Insert new
                    client.table("checkpoints").insert(checkpoint).execute()
                    total += 1

            except Exception as e:
                print(f"  Error seeding checkpoint {checkpoint['name']}: {e}")

    print(f"  Seeded {total} new checkpoints")


def seed_gates(client):
    """Seed gate data."""
    print("Seeding gates...")

    total = 0
    for airport in AIRPORTS:
        gates = get_gates(
            airport["code"],
            airport["latitude"],
            airport["longitude"],
        )

        for gate in gates:
            try:
                # Check if gate exists
                result = (
                    client.table("gates")
                    .select("id")
                    .eq("airport_code", gate["airport_code"])
                    .eq("terminal", gate["terminal"])
                    .eq("gate_number", gate["gate_number"])
                    .execute()
                )

                if result.data:
                    # Update existing
                    client.table("gates").update(gate).eq("id", result.data[0]["id"]).execute()
                else:
                    # Insert new
                    client.table("gates").insert(gate).execute()
                    total += 1

            except Exception as e:
                print(f"  Error seeding gate {gate['gate_number']}: {e}")

    print(f"  Seeded {total} new gates")


def main():
    """Main entry point."""
    print("Airport Quest - Database Seeder")
    print("=" * 40)

    client = get_client()

    seed_airports(client)
    seed_checkpoints(client)
    seed_gates(client)

    print("=" * 40)
    print("Seeding complete!")


if __name__ == "__main__":
    main()
