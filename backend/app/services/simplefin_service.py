"""SimpleFin API service wrapper.

SimpleFin Bridge provides a simpler alternative to Plaid for fetching financial data.
It uses Basic Auth embedded in the access URL and has a single endpoint for all data.

Documentation: https://beta-bridge.simplefin.org/info/developers
"""

import base64
from typing import Any
from urllib.parse import urlparse
from decimal import Decimal

import httpx


def decode_setup_token(setup_token: str) -> str:
    """
    Decode a SimpleFin setup token to get the claim URL.

    Args:
        setup_token: Base64-encoded setup token from SimpleFin.

    Returns:
        The decoded claim URL.
    """
    return base64.b64decode(setup_token).decode("utf-8")


def claim_access_url(setup_token: str) -> str:
    """
    Exchange a SimpleFin setup token for an access URL.

    This can only be done once per setup token. The access URL contains
    the credentials needed for all subsequent API calls.

    Args:
        setup_token: Base64-encoded setup token from SimpleFin.

    Returns:
        The access URL (contains embedded credentials).

    Raises:
        httpx.HTTPError: If the claim request fails.
    """
    claim_url = decode_setup_token(setup_token)

    # POST to the claim URL to get the access URL
    # SimpleFin requires Content-Length: 0 for empty POST
    with httpx.Client() as client:
        response = client.post(
            claim_url,
            headers={"Content-Length": "0"},
            timeout=30
        )
        response.raise_for_status()

    # The response body is the access URL
    access_url = response.text.strip()
    return access_url


def fetch_accounts(
    access_url: str,
    start_date: int | None = None,
    end_date: int | None = None,
) -> dict[str, Any]:
    """
    Fetch all accounts and transactions from SimpleFin.

    Args:
        access_url: The SimpleFin access URL (contains embedded credentials).
                   Format: https://username:password@host/simplefin
        start_date: Optional start date for transactions (Unix timestamp in seconds since epoch).
                   Example: 1704067200 for 2024-01-01.
                   Default: SimpleFin returns recent transactions only.
        end_date: Optional end date for transactions (Unix timestamp in seconds since epoch).

    Returns:
        Dict containing:
            - accounts: List of account objects with transactions
            - errors: List of error messages (if any)

    Raises:
        httpx.HTTPError: If the API request fails.
    """
    # SimpleFin access URL has credentials embedded
    # Just append /accounts and httpx handles Basic Auth automatically
    params = {}
    if start_date:
        params["start-date"] = start_date
    if end_date:
        params["end-date"] = end_date

    with httpx.Client() as client:
        response = client.get(
            f"{access_url}/accounts",
            params=params,
            timeout=30
        )
        response.raise_for_status()

    data = response.json()
    return data


def parse_simplefin_accounts(
    accounts_data: dict[str, Any],
    simplefin_item_id: str,
    user_id: str,
) -> list[dict[str, Any]]:
    """
    Parse SimpleFin account data into our account format.

    Args:
        accounts_data: Raw data from SimpleFin fetch_accounts().
        simplefin_item_id: Our internal SimpleFin item ID.
        user_id: User UUID who owns these accounts.

    Returns:
        List of account dicts ready for database insertion.
    """
    accounts = []

    for account in accounts_data.get("accounts", []):
        org = account.get("org", {})

        account_dict = {
            "user_id": user_id,
            "simplefin_item_id": simplefin_item_id,
            "simplefin_account_id": account.get("id"),
            "name": account.get("name", "Unknown Account"),
            "currency": account.get("currency", "USD"),
            "balance": float(Decimal(account.get("balance", "0"))),
            "available_balance": float(Decimal(account.get("available-balance", "0"))),
            "balance_date": account.get("balance-date"),
            "organization_name": org.get("name"),
            "organization_domain": org.get("domain"),
            "organization_sfin_url": org.get("sfin-url"),
        }
        accounts.append(account_dict)

    return accounts


def parse_simplefin_transactions(
    accounts_data: dict[str, Any],
    account_id_map: dict[str, str],
    user_id: str,
) -> list[dict[str, Any]]:
    """
    Parse SimpleFin transaction data into our transaction format.

    Args:
        accounts_data: Raw data from SimpleFin fetch_accounts().
        account_id_map: Mapping of SimpleFin account IDs to our internal account UUIDs.
                       Format: {"ACT-xxx": "uuid-xxx"}
        user_id: User UUID who owns these transactions.

    Returns:
        List of transaction dicts ready for database insertion.
    """
    transactions = []

    for account in accounts_data.get("accounts", []):
        simplefin_account_id = account.get("id")

        # Skip if we don't have a mapping for this account
        if simplefin_account_id not in account_id_map:
            continue

        our_account_id = account_id_map[simplefin_account_id]
        account_currency = account.get("currency", "USD")

        for txn in account.get("transactions", []):
            # SimpleFin provides clean merchant names in 'payee' field
            # Amount is already signed (negative = expense, positive = income)
            transaction = {
                "user_id": user_id,
                "simplefin_account_id": our_account_id,
                "simplefin_transaction_id": txn.get("id"),
                "amount": float(Decimal(txn.get("amount", "0"))),
                "currency": account_currency,
                "posted_date": txn.get("posted"),
                "transaction_date": txn.get("transacted_at"),
                "description": txn.get("description", ""),
                "payee": txn.get("payee") or None,  # Convert empty string to None
                "memo": txn.get("memo") or None,    # Convert empty string to None
                "pending": False,  # SimpleFin only returns posted transactions
            }
            transactions.append(transaction)

    return transactions


def validate_access_url(access_url: str) -> bool:
    """
    Validate that an access URL is properly formatted.

    Args:
        access_url: The SimpleFin access URL to validate.

    Returns:
        True if valid, False otherwise.
    """
    try:
        parsed = urlparse(access_url)
        # Must have scheme, netloc, username, and password
        return all([
            parsed.scheme in ("https", "http"),
            parsed.netloc,
            parsed.username,
            parsed.password,
        ])
    except Exception:
        return False
