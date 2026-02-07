"""Plaid API service wrapper."""

import plaid
from plaid.api import plaid_api
from plaid.model.link_token_create_request import LinkTokenCreateRequest
from plaid.model.link_token_create_request_user import LinkTokenCreateRequestUser
from plaid.model.item_public_token_exchange_request import ItemPublicTokenExchangeRequest
from plaid.model.transactions_sync_request import TransactionsSyncRequest
from plaid.model.country_code import CountryCode
from plaid.model.products import Products

from app.config import get_settings


def _get_plaid_client() -> plaid_api.PlaidApi:
    """Create a Plaid API client."""
    settings = get_settings()

    env_map = {
        "sandbox": plaid.Environment.Sandbox,
        "development": plaid.Environment.Development,
        "production": plaid.Environment.Production,
    }

    configuration = plaid.Configuration(
        host=env_map.get(settings.plaid_env, plaid.Environment.Sandbox),
        api_key={
            "clientId": settings.plaid_client_id,
            "secret": settings.plaid_secret,
        },
    )

    api_client = plaid.ApiClient(configuration)
    return plaid_api.PlaidApi(api_client)


def create_link_token(user_id: str) -> dict:
    """
    Create a Plaid Link token for the frontend.

    Args:
        user_id: The authenticated user's ID.

    Returns:
        Dict with link_token and expiration.
    """
    client = _get_plaid_client()

    request = LinkTokenCreateRequest(
        user=LinkTokenCreateRequestUser(client_user_id=user_id),
        client_name=get_settings().app_name,
        products=[Products("transactions")],
        country_codes=[CountryCode("US")],
        language="en",
    )

    response = client.link_token_create(request)
    return {
        "link_token": response.link_token,
        "expiration": response.expiration,
    }


def exchange_public_token(public_token: str) -> dict:
    """
    Exchange a Plaid public token for an access token and item ID.

    Args:
        public_token: The public token from Plaid Link.

    Returns:
        Dict with access_token and item_id.
    """
    client = _get_plaid_client()

    request = ItemPublicTokenExchangeRequest(public_token=public_token)
    response = client.item_public_token_exchange(request)

    return {
        "access_token": response.access_token,
        "item_id": response.item_id,
    }


def sync_transactions(access_token: str, cursor: str | None = None) -> dict:
    """
    Sync transactions using Plaid's transactions.sync endpoint.

    Args:
        access_token: The Plaid access token for the item.
        cursor: Optional cursor from a previous sync call.

    Returns:
        Dict with added, modified, removed transactions, new cursor, and has_more flag.
    """
    client = _get_plaid_client()

    request_kwargs = {"access_token": access_token}
    if cursor:
        request_kwargs["cursor"] = cursor

    request = TransactionsSyncRequest(**request_kwargs)
    response = client.transactions_sync(request)

    added = []
    for txn in response.added:
        added.append({
            "plaid_transaction_id": txn.transaction_id,
            "account_id": txn.account_id,
            "amount": txn.amount,
            "iso_currency_code": txn.iso_currency_code,
            "date": str(txn.date),
            "name": txn.name,
            "merchant_name": txn.merchant_name,
            "category": txn.category,
            "pending": txn.pending,
        })

    modified = []
    for txn in response.modified:
        modified.append({
            "plaid_transaction_id": txn.transaction_id,
            "account_id": txn.account_id,
            "amount": txn.amount,
            "iso_currency_code": txn.iso_currency_code,
            "date": str(txn.date),
            "name": txn.name,
            "merchant_name": txn.merchant_name,
            "category": txn.category,
            "pending": txn.pending,
        })

    removed = []
    for txn in response.removed:
        removed.append(txn.transaction_id)

    return {
        "added": added,
        "modified": modified,
        "removed": removed,
        "next_cursor": response.next_cursor,
        "has_more": response.has_more,
    }
