#!/usr/bin/env python3
"""Script to categorize all transactions using AI."""

import os
import sys
import httpx
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configuration
BASE_URL = os.getenv("BACKEND_URL", "http://localhost:8000")
API_PREFIX = "/app/v1"
EMAIL = os.getenv("TEST_USER_EMAIL")
PASSWORD = os.getenv("TEST_USER_PASSWORD")


def login(email: str, password: str) -> str:
    """Login and get access token."""
    print("🔐 Logging in...")
    response = httpx.post(
        f"{BASE_URL}{API_PREFIX}/auth/login",
        json={"email": email, "password": password},
    )
    response.raise_for_status()
    data = response.json()
    print(f"✅ Logged in as {email}")
    return data["access_token"]


def categorize_all_transactions(token: str, force: bool = True):
    """Categorize all transactions using AI.

    Args:
        token: Access token
        force: If True, re-categorize already categorized transactions
    """
    print(f"\n🤖 Starting AI categorization (force={force})...")

    headers = {"Authorization": f"Bearer {token}"}

    # Call categorization endpoint
    # Note: This processes up to 200 transactions at a time
    response = httpx.post(
        f"{BASE_URL}{API_PREFIX}/categories/ai/categorize",
        json={"force": force},
        headers=headers,
        timeout=120.0,  # AI calls can take a while
    )

    if response.status_code != 200:
        print(f"❌ Error: {response.status_code}")
        print(response.json())
        sys.exit(1)

    result = response.json()

    print("\n📊 Results:")
    print(f"   ✅ Categorized: {result['categorized_count']}")
    print(f"   ❌ Failed: {result['failed_count']}")
    print(f"   📝 Total processed: {len(result['results'])}")

    # Show sample results
    if result["results"]:
        print("\n📋 Sample categorizations (first 5):")
        for i, cat_result in enumerate(result["results"][:5], 1):
            print(f"\n   {i}. Transaction: {cat_result['transaction_id'][:12]}...")
            print(f"      Category ID: {cat_result.get('category_id', 'None')}")
            print(f"      Subcategory ID: {cat_result.get('subcategory_id', 'None')}")
            print(f"      Confidence: {cat_result.get('confidence', 0):.2%}")
            if cat_result.get('reasoning'):
                print(f"      Reasoning: {cat_result['reasoning']}")

    return result


def main():
    """Main function."""
    if not EMAIL or not PASSWORD:
        print("❌ Error: Set TEST_USER_EMAIL and TEST_USER_PASSWORD in .env")
        sys.exit(1)

    # Check if AI service is configured
    provider = os.getenv("CATEGORIZATION_PROVIDER", "claude")
    print(f"\n🔧 AI Provider: {provider}")

    if provider == "claude":
        if not os.getenv("ANTHROPIC_API_KEY"):
            print("❌ Error: ANTHROPIC_API_KEY not set in .env")
            sys.exit(1)
        print(f"   Model: {os.getenv('CLAUDE_MODEL', 'claude-3-5-sonnet-20241022')}")
    elif provider == "openrouter":
        if not os.getenv("OPENROUTER_API_KEY"):
            print("❌ Error: OPENROUTER_API_KEY not set in .env")
            sys.exit(1)
        print(f"   Model: {os.getenv('OPENROUTER_MODEL', 'meta-llama/llama-3.1-8b-instruct:free')}")

    try:
        # Login
        token = login(EMAIL, PASSWORD)

        # Categorize all transactions
        categorize_all_transactions(token, force=True)

        print("\n✨ Done!")

    except httpx.HTTPStatusError as e:
        print(f"\n❌ HTTP Error: {e}")
        print(e.response.text)
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
