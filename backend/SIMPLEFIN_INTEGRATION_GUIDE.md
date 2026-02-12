# SimpleFin Integration Guide

Complete guide for CashState's SimpleFin integration.

## Overview

SimpleFin Bridge is a direct bank connection service that provides a simpler alternative to Plaid. Unlike Plaid, SimpleFin:
- Uses embedded Basic Auth (no OAuth flow)
- Returns all data in a single API call
- Provides cleaned merchant names in the `payee` field
- Is limited to 24 requests per day per connection
- Has no sandbox environment (production only)

## Architecture

### Database Schema

We use a 3-table structure optimized for SimpleFin's data model:

1. **simplefin_items** - Stores encrypted access URLs (credentials)
2. **simplefin_accounts** - Stores account details with balance and institution info
3. **simplefin_transactions** - Stores transactions with all SimpleFin fields

```
simplefin_items
  ↓
simplefin_accounts (1:N)
  ↓
simplefin_transactions (1:N)
```

### Key Design Decisions

1. **Account-based structure** - Transactions reference accounts (not items), matching SimpleFin's nested structure
2. **Balance tracking** - Account balances are updated on each sync
3. **Organization info** - Institution details stored at account level (from SimpleFin's `org` field)
4. **Date fields** - Store both `posted_date` and `transaction_date` as Unix timestamps
5. **Merchant names** - Preserve both raw `description` and cleaned `payee` field

## Data Flow

### Setup Flow

```
User gets setup token from SimpleFin
  ↓
POST /simplefin/setup {setup_token}
  ↓
Decode token → Claim access URL → Encrypt → Store in simplefin_items
```

### Sync Flow

```
POST /simplefin/sync/{item_id}
  ↓
Decrypt access URL
  ↓
Fetch from SimpleFin API
  ↓
Parse accounts → Upsert to simplefin_accounts (updates balances)
  ↓
Parse transactions → Upsert to simplefin_transactions
  ↓
Update sync job + item last_synced_at
```

## SimpleFin Data Structure

### Raw API Response

```json
{
  "errors": [],
  "accounts": [
    {
      "id": "ACT-xxx",
      "name": "credit (2537)",
      "currency": "USD",
      "balance": "-354.22",
      "available-balance": "0.00",
      "balance-date": 1770788894,
      "transactions": [
        {
          "id": "TRN-xxx",
          "posted": 1770638400,
          "amount": "-22.11",
          "description": "CURSOR, AI POWERED IDE   CURSOR.COM   NY",
          "payee": "Cursor",
          "memo": "",
          "transacted_at": 1770552000
        }
      ],
      "org": {
        "domain": "www.bankofamerica.com",
        "name": "Bank of America",
        "sfin-url": "https://beta-bridge.simplefin.org/simplefin",
        "url": "https://www.bankofamerica.com",
        "id": "www.bankofamerica.com"
      }
    }
  ]
}
```

### Our Database Mapping

#### Accounts Table

| SimpleFin Field | Our Field | Notes |
|----------------|-----------|-------|
| `id` | `simplefin_account_id` | e.g., "ACT-xxx" |
| `name` | `name` | e.g., "credit (2537)" |
| `currency` | `currency` | Always "USD" in US |
| `balance` | `balance` | Converted to numeric |
| `available-balance` | `available_balance` | Converted to numeric |
| `balance-date` | `balance_date` | Unix timestamp |
| `org.name` | `organization_name` | Bank name |
| `org.domain` | `organization_domain` | Bank domain |

#### Transactions Table

| SimpleFin Field | Our Field | Notes |
|----------------|-----------|-------|
| `id` | `simplefin_transaction_id` | e.g., "TRN-xxx" |
| `amount` | `amount` | **Signed** (negative = expense) |
| `currency` | `currency` | From parent account |
| `posted` | `posted_date` | Unix timestamp |
| `transacted_at` | `transaction_date` | Unix timestamp |
| `description` | `description` | Raw merchant string |
| `payee` | `payee` | **Cleaned merchant name** |
| `memo` | `memo` | Additional notes (often empty) |
| - | `pending` | Always `false` for SimpleFin |

## API Endpoints

### `POST /simplefin/setup`

Exchange a SimpleFin setup token for an access URL.

**Request:**
```json
{
  "setup_token": "base64-encoded-token",
  "institution_name": "My Bank"
}
```

**Response:**
```json
{
  "item_id": "uuid",
  "institution_name": "My Bank"
}
```

**Notes:**
- Setup tokens can only be claimed once
- Access URL is encrypted with Fernet before storage
- In development, can bypass claim with `SIMPLEFIN_ACCESS_URL` env var

### `GET /simplefin/items`

List all SimpleFin connections for the current user.

**Response:**
```json
[
  {
    "id": "uuid",
    "institution_name": "My Bank",
    "status": "active",
    "last_synced_at": "2024-01-15T10:30:00Z",
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-15T10:30:00Z"
  }
]
```

### `GET /simplefin/accounts/{item_id}`

Get stored accounts for a SimpleFin item.

**Response:**
```json
[
  {
    "id": "uuid",
    "simplefin_account_id": "ACT-xxx",
    "name": "credit (2537)",
    "currency": "USD",
    "balance": -354.22,
    "available_balance": 0.00,
    "balance_date": 1770788894,
    "organization_name": "Bank of America",
    "organization_domain": "www.bankofamerica.com",
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-15T10:30:00Z"
  }
]
```

### `POST /simplefin/sync/{item_id}?start_date=1704067200`

Sync accounts and transactions from SimpleFin.

**Query Parameters:**
- `start_date` (optional): Unix timestamp in seconds (e.g., `1704067200` for 2024-01-01)

**Response:**
```json
{
  "success": true,
  "sync_job_id": "uuid",
  "accounts_synced": 2,
  "transactions_added": 143,
  "transactions_updated": 0,
  "errors": []
}
```

**Notes:**
- Rate limited to 24 requests per day by SimpleFin
- If `start_date` not provided, SimpleFin returns recent transactions only
- Accounts are upserted (balances updated on each sync)
- Transactions are upserted by `simplefin_transaction_id`

### `GET /simplefin/transactions`

List transactions across all SimpleFin accounts.

**Query Parameters:**
- `date_from` (optional): Unix timestamp
- `date_to` (optional): Unix timestamp
- `limit` (optional, default 50): Max results
- `offset` (optional, default 0): Pagination offset

**Response:**
```json
[
  {
    "id": "uuid",
    "simplefin_account_id": "uuid",
    "simplefin_transaction_id": "TRN-xxx",
    "amount": -22.11,
    "currency": "USD",
    "posted_date": 1770638400,
    "transaction_date": 1770552000,
    "description": "CURSOR, AI POWERED IDE   CURSOR.COM   NY",
    "payee": "Cursor",
    "memo": null,
    "pending": false,
    "created_at": "2024-01-15T10:30:00Z",
    "updated_at": "2024-01-15T10:30:00Z"
  }
]
```

### `GET /simplefin/raw-accounts/{item_id}`

Fetch raw SimpleFin API response (for debugging).

**Response:**
```json
{
  "accounts": [...],  // Raw SimpleFin format
  "errors": []
}
```

**Notes:**
- Does NOT store data (use `/sync` for that)
- Useful for debugging and previewing data before sync

### `DELETE /simplefin/items/{item_id}`

Delete a SimpleFin connection and all associated data.

**Response:**
```json
{
  "success": true,
  "message": "SimpleFin item deleted"
}
```

**Notes:**
- Cascades to accounts and transactions (via FK constraints)
- Cannot be undone

## Service Functions

### `simplefin_service.py`

```python
def claim_access_url(setup_token: str) -> str
    """Exchange setup token for access URL (one-time operation)."""

def fetch_accounts(access_url: str, start_date: int | None = None) -> dict
    """Fetch all accounts and transactions from SimpleFin API."""

def parse_simplefin_accounts(accounts_data: dict, item_id: str) -> list[dict]
    """Parse API response into account dicts for DB insertion."""

def parse_simplefin_transactions(accounts_data: dict, account_id_map: dict) -> list[dict]
    """Parse API response into transaction dicts for DB insertion."""

def validate_access_url(access_url: str) -> bool
    """Validate access URL format (must have embedded credentials)."""
```

## Security

### Encryption

- Access URLs contain embedded credentials (`https://user:pass@host/simplefin`)
- Encrypted using Fernet (symmetric encryption) before storage
- Key stored in `ENCRYPTION_KEY` environment variable
- Same encryption used for Plaid access tokens

### Row Level Security (RLS)

All tables have RLS policies that:
- Restrict access to authenticated users
- Filter by user ownership (via `simplefin_items.user_id`)
- Use `(select auth.uid())` for performance (prevents re-evaluation)

### Access Control Flow

```
User makes request with JWT
  ↓
FastAPI validates JWT (get_current_user dependency)
  ↓
PostgREST client uses user's JWT for DB operations
  ↓
RLS policies filter data by auth.uid()
  ↓
Only user's own data is accessible
```

## Testing

See `tests/test_simplefin_flow.py` for integration tests.

**Note:** SimpleFin has no sandbox, so tests use mocked responses.

```bash
# Run SimpleFin tests
uv run pytest tests/test_simplefin_flow.py -v -s
```

## Common Issues

### "Invalid access URL"

- Check that access URL has embedded credentials
- Format: `https://username:password@host/simplefin`
- Ensure no URL encoding issues

### "Rate limit exceeded"

- SimpleFin limits to 24 requests per day
- Implement client-side debouncing
- Show last sync time to users

### "Account not found"

- Transactions reference accounts table
- Ensure accounts are synced before transactions
- Check foreign key constraints

## Development Tips

### Using Pre-Claimed Access URL

For development/testing without claiming a new token:

```bash
# .env
SIMPLEFIN_ACCESS_URL=https://user:pass@beta-bridge.simplefin.org/simplefin/abcdef
```

When `APP_ENV=development`, the `/setup` endpoint will use this instead of claiming.

### Testing with Real Data

1. Get a SimpleFin account at https://beta-bridge.simplefin.org
2. Generate a setup token
3. Claim it via `POST /simplefin/setup`
4. Sync data via `POST /simplefin/sync/{item_id}`
5. View data at `http://localhost:8000/docs`

### Debugging Sync Issues

Check sync jobs table:
```sql
SELECT * FROM simplefin_sync_jobs
ORDER BY created_at DESC
LIMIT 10;
```

Check for error messages:
```sql
SELECT id, status, error_message, created_at
FROM simplefin_sync_jobs
WHERE status = 'failed'
ORDER BY created_at DESC;
```

## Comparison: SimpleFin vs Plaid

| Feature | SimpleFin | Plaid |
|---------|-----------|-------|
| Auth | Basic Auth (embedded in URL) | OAuth tokens |
| Sandbox | No (production only) | Yes (free) |
| Rate Limits | 24 requests/day | 100-1000/day (tier-based) |
| Merchant Names | Cleaned (`payee` field) | Raw only |
| Categorization | No | Yes (AI-powered) |
| Cost | $15-20/month per user | $0.24-1.00 per item/month |
| Sync Model | Full sync each time | Incremental with cursors |
| Date Fields | `posted` + `transacted_at` | `date` + `authorized_date` |

## Next Steps

1. **Category Enrichment** - Add ML categorization for SimpleFin transactions
2. **Webhooks** - SimpleFin doesn't support webhooks, implement scheduled syncs
3. **Balance Tracking** - Build charts using `simplefin_accounts.balance` history
4. **Institution Logos** - Use `organization_domain` to fetch bank logos
5. **Duplicate Detection** - Match SimpleFin + Plaid transactions from same account

## Resources

- [SimpleFin Bridge Documentation](https://beta-bridge.simplefin.org/info/developers)
- [SimpleFin Website](https://simplefin.org)
- [Create SimpleFin Account](https://beta-bridge.simplefin.org)
