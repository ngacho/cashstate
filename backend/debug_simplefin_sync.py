"""
Debug script that replicates what dailySync + _syncInternal do.
Fetches accounts and transactions from SimpleFin and prints them for inspection.

Usage:
    python debug_simplefin_sync.py --token <setup_token> [--start-date YYYY-MM-DD]
    python debug_simplefin_sync.py --access-url <access_url> [--start-date YYYY-MM-DD]

    --token: Base64 SimpleFin setup token (claimed to get access URL, like setup action)
    --access-url: Already-claimed access URL (with credentials embedded)
    --start-date: Optional start date filter (defaults to last day of previous month, like dailySync)
"""

import argparse
import json
import sys
from base64 import b64encode
from datetime import datetime, timezone
from urllib.parse import urlparse

import requests


def get_start_of_last_month_end() -> int:
    """Replicates dailySync's startDate logic: last day of previous month at midnight."""
    now = datetime.now()
    # First day of current month
    first_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    # Go back one day to get last day of previous month
    from datetime import timedelta
    last_day_prev = first_of_month - timedelta(days=1)
    last_day_prev = last_day_prev.replace(hour=0, minute=0, second=0, microsecond=0)
    return int(last_day_prev.timestamp())


def claim_access_url(setup_token: str) -> str:
    """Exchange a setup token for an access URL (replicates setup action)."""
    import base64

    claim_url = base64.b64decode(setup_token).decode("utf-8")
    print(f"[claim] Decoded claim URL: {claim_url}")
    print("[claim] POSTing to claim URL...")

    resp = requests.post(claim_url)
    if not resp.ok:
        print(f"[claim] ERROR: {resp.status_code} {resp.reason}")
        print(resp.text)
        sys.exit(1)

    access_url = resp.text.strip()
    print(f"[claim] Got access URL: {access_url}")
    print(f"\n*** SAVE THIS ACCESS URL — the token is now spent and cannot be reused ***\n")
    return access_url


def fetch_simplefin(access_url: str, start_date: int | None = None) -> dict:
    """Fetch accounts/transactions from SimpleFin API."""
    parsed = urlparse(access_url)
    base_url = f"{parsed.scheme}://{parsed.hostname}{parsed.path}"
    if parsed.port:
        base_url = f"{parsed.scheme}://{parsed.hostname}:{parsed.port}{parsed.path}"

    credentials = b64encode(f"{parsed.username}:{parsed.password}".encode()).decode()
    auth_header = f"Basic {credentials}"

    api_url = f"{base_url}/accounts"
    params = {}
    if start_date is not None:
        params["start-date"] = str(start_date)

    print(f"[fetch] GET {api_url}")
    if start_date:
        print(f"[fetch] start-date={start_date} ({datetime.fromtimestamp(start_date, tz=timezone.utc).isoformat()})")

    resp = requests.get(api_url, headers={"Authorization": auth_header}, params=params)
    if not resp.ok:
        print(f"[fetch] ERROR: {resp.status_code} {resp.reason}")
        print(resp.text)
        sys.exit(1)

    return resp.json()


def process_accounts(data: dict) -> None:
    """Process and display accounts + transactions like _syncInternal does."""
    accounts = data.get("accounts", [])
    print(f"\n{'='*80}")
    print(f"SimpleFin returned {len(accounts)} accounts")
    print(f"{'='*80}\n")

    total_tx = 0
    for acc in accounts:
        acc_id = acc.get("id", "?")
        name = acc.get("name", "Unknown Account")
        currency = acc.get("currency", "USD")
        balance = acc.get("balance")
        available = acc.get("available-balance")
        balance_date = acc.get("balance-date")
        org_name = acc.get("org", {}).get("name", "?")
        transactions = acc.get("transactions", [])

        print(f"--- Account: {name} ---")
        print(f"  simplefinAccountId: {acc_id}")
        print(f"  org: {org_name}")
        print(f"  currency: {currency}")
        print(f"  balance: {balance}")
        print(f"  available-balance: {available}")
        if balance_date:
            print(f"  balance-date: {datetime.fromtimestamp(balance_date, tz=timezone.utc).isoformat()}")
        print(f"  transactions: {len(transactions)}")
        print()

        total_tx += len(transactions)

        # Map transactions like _syncInternal does
        for i, tx in enumerate(transactions):
            tx_id = tx.get("id", "?")
            amount = float(tx.get("amount", 0))
            posted = tx.get("posted", 0)
            transacted_at = tx.get("transacted_at")
            description = tx.get("description", "")
            payee = tx.get("payee", "")
            pending = tx.get("pending", False)

            posted_dt = datetime.fromtimestamp(posted, tz=timezone.utc).isoformat() if posted else "?"
            transacted_dt = datetime.fromtimestamp(transacted_at, tz=timezone.utc).isoformat() if transacted_at else "N/A"

            print(f"  tx[{i}]: id={tx_id}")
            print(f"    amount={amount}, currency={currency}")
            print(f"    posted={posted_dt} (epoch={posted})")
            print(f"    transacted_at={transacted_dt}")
            print(f"    description=\"{description}\"")
            print(f"    payee=\"{payee}\"")
            print(f"    pending={pending}")

            # Show what _syncInternal would store (date = posted * 1000 ms)
            print(f"    -> stored date (ms): {posted * 1000}")
            if transacted_at:
                print(f"    -> stored transactedAt (ms): {transacted_at * 1000}")
            print()

        if not transactions:
            print("  (no transactions)\n")

    print(f"{'='*80}")
    print(f"TOTALS: {len(accounts)} accounts, {total_tx} transactions")
    print(f"{'='*80}")


def dump_raw(data: dict, path: str) -> None:
    """Save raw API response to file for inspection."""
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
    print(f"\nRaw response saved to {path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Debug SimpleFin sync (replicates dailySync + _syncInternal)")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--token", help="Base64 SimpleFin setup token (will be claimed)")
    group.add_argument("--access-url", help="Already-claimed SimpleFin access URL")
    parser.add_argument(
        "--start-date",
        help="Start date filter (YYYY-MM-DD). Defaults to last day of previous month.",
        default=None,
    )
    parser.add_argument("--no-start-date", action="store_true", help="Fetch all transactions (no start-date filter)")
    parser.add_argument("--dump-raw", help="Save raw JSON response to this file path", default=None)
    args = parser.parse_args()

    # Get access URL
    if args.token:
        access_url = claim_access_url(args.token)
    else:
        access_url = args.access_url

    # Determine start date
    if args.no_start_date:
        start_date = None
        print("[config] No start-date filter (fetching all)")
    elif args.start_date:
        dt = datetime.strptime(args.start_date, "%Y-%m-%d")
        start_date = int(dt.timestamp())
        print(f"[config] start-date: {args.start_date} (epoch={start_date})")
    else:
        start_date = get_start_of_last_month_end()
        dt = datetime.fromtimestamp(start_date, tz=timezone.utc)
        print(f"[config] Using dailySync default start-date: {dt.date().isoformat()} (epoch={start_date})")

    # Fetch
    data = fetch_simplefin(access_url, start_date)

    # Dump raw if requested
    if args.dump_raw:
        dump_raw(data, args.dump_raw)

    # Process and display
    process_accounts(data)


if __name__ == "__main__":
    main()
