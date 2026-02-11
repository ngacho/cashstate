#!/usr/bin/env python3
"""Test SimpleFin directly using their documented flow."""

import os
import base64
import datetime
import requests
from dotenv import load_dotenv

# Load environment variables
load_dotenv()


def ts_to_datetime(ts):
    """Convert Unix timestamp to datetime."""
    return datetime.datetime.fromtimestamp(ts)


def main():
    """Run SimpleFin direct test."""
    # Get credentials from environment
    simplefin_token = os.getenv("SIMPLEFIN_TOKEN")
    simplefin_access_url = os.getenv("SIMPLEFIN_ACCESS_URL")

    if not simplefin_token and not simplefin_access_url:
        print("❌ Need either SIMPLEFIN_TOKEN (to claim) or SIMPLEFIN_ACCESS_URL (already claimed)")
        return

    print("=" * 60)
    print("SimpleFin Direct Test (Python 3)")
    print("=" * 60)

    access_url = None

    # Check if we already have an access URL
    if simplefin_access_url:
        print("\n[1] Using existing access URL from .env")
        access_url = simplefin_access_url
        print(f"✅ Access URL: {access_url[:60]}...")
    else:
        # Step 1: Decode setup token to get claim URL
        print("\n[1] Decoding setup token...")
        claim_url = base64.b64decode(simplefin_token).decode('utf-8')
        print(f"✅ Claim URL: {claim_url}")

        # Step 2: Claim an Access URL (ONE-TIME ONLY!)
        print("\n[2] Claiming access URL (ONE-TIME ONLY!)...")
        print("⚠️  This can only be done ONCE per setup token!")
        try:
            response = requests.post(claim_url)
            response.raise_for_status()
            access_url = response.text.strip()
            print(f"✅ Access URL: {access_url[:60]}...")
            print(f"\n⚠️  SAVE THIS ACCESS URL! Add to your .env:")
            print(f"SIMPLEFIN_ACCESS_URL='{access_url}'")
            print()
        except Exception as e:
            print(f"❌ Claim failed: {e}")
            print("   (If already claimed, add SIMPLEFIN_ACCESS_URL to .env instead)")
            return

    # Step 3: Parse access URL and fetch data
    print("\n[3] Fetching account data...")
    try:

        # Fetch accounts
        response = requests.get(f"{access_url}/accounts")
        response.raise_for_status()
        data = response.json()

        print(f"✅ Found {len(data.get('accounts', []))} accounts")

        # Display account data
        for account in data.get('accounts', []):
            balance_date = ts_to_datetime(account['balance-date'])
            print(f"\n{balance_date} {account['balance']:>8} {account['name']}")
            print('-' * 60)

            for transaction in account.get('transactions', []):
                posted = ts_to_datetime(transaction['posted'])
                print(f"{posted} {transaction['amount']:>8} {transaction['description']}")

        # Show errors if any
        if data.get('errors'):
            print(f"\n⚠️  Errors: {data['errors']}")

        print("\n" + "=" * 60)
        print("✅ SimpleFin integration working!")
        print("=" * 60)

    except Exception as e:
        print(f"❌ Fetch failed: {e}")
        import traceback
        traceback.print_exc()
        return


if __name__ == "__main__":
    main()
