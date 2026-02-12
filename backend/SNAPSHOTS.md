# Snapshot System

CashState uses two separate snapshot tables for tracking financial data over time:

## 1. Net Snapshots (`net_snapshots`)
**Purpose**: Overall net worth tracking across all accounts
**Used by**: Overview/Home page
**Endpoint**: `GET /app/v1/snapshots`

### What it tracks:
- **total_balance**: Total net worth across all accounts
- **cash_balance**: Sum of all checking/savings accounts
- **credit_balance**: Sum of all credit card balances
- **daily_spent**: Total spending across all accounts for that day
- **daily_income**: Total income across all accounts for that day
- **mtd_spent**: Month-to-date spending
- **ytd_spent**: Year-to-date spending

### Example Response:
```json
{
  "start_date": "2024-02-01",
  "end_date": "2024-02-12",
  "granularity": "day",
  "data": [
    {
      "date": "2024-02-01",
      "balance": 5240.50,
      "spent": 125.30,
      "income": 2000.00,
      "net": 1874.70,
      "transaction_count": 15
    }
  ]
}
```

### Usage:
```bash
# Last 7 days (daily)
GET /app/v1/snapshots?granularity=day

# Last month (weekly)
GET /app/v1/snapshots?granularity=week

# Specific date range
GET /app/v1/snapshots?start_date=2024-01-01&end_date=2024-01-31&granularity=month
```

## 2. Transaction Snapshots (`transaction_snapshots`)
**Purpose**: Per-account balance history
**Used by**: Individual account detail pages
**Endpoint**: `GET /app/v1/snapshots/account/{account_id}`

### What it tracks:
- **balance**: Balance for this specific account
- **daily_spent**: Spending from this account for that day
- **daily_income**: Income to this account for that day
- **transaction_count**: Number of transactions on this account

### Example Response:
```json
{
  "start_date": "2024-02-01",
  "end_date": "2024-02-12",
  "granularity": "day",
  "data": [
    {
      "date": "2024-02-01",
      "balance": 1540.25,
      "spent": 45.00,
      "income": 0.00,
      "net": -45.00,
      "transaction_count": 3
    }
  ]
}
```

### Usage:
```bash
# Last 7 days for specific account
GET /app/v1/snapshots/account/abc-123?granularity=day

# Last month for specific account
GET /app/v1/snapshots/account/abc-123?granularity=week

# Specific date range
GET /app/v1/snapshots/account/abc-123?start_date=2024-01-01&end_date=2024-01-31&granularity=month
```

## Granularity Options

Both endpoints support four granularity levels:

- **day**: Individual daily snapshots
- **week**: Aggregated by week (Monday-Sunday, ISO week)
- **month**: Aggregated by month
- **year**: Aggregated by year

When using aggregation (week/month/year):
- `spent`, `income`, `net`, and `transaction_count` are summed
- `balance` shows the last day's balance in that period

## Calculation

### When snapshots are calculated:

1. **Automatically** after each SimpleFin transaction sync
2. **Via cron job** every 24 hours (updates yesterday and today)
3. **Manually** via `POST /app/v1/snapshots/calculate`

### How calculation works:

**Net Snapshots (User-level):**
1. Get all user's accounts
2. Get all transactions across all accounts for the date
3. Calculate daily totals (spent, income, net)
4. Calculate running balances by account type (cash vs credit)
5. Calculate MTD/YTD totals
6. Store in `net_snapshots` table

**Transaction Snapshots (Account-level):**
1. For each account the user owns
2. Get all transactions for that account on the date
3. Calculate daily totals for that account
4. Calculate running balance from all transactions up to that date
5. Store in `transaction_snapshots` table

## Database Schema

### net_snapshots
```sql
CREATE TABLE public.net_snapshots (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    snapshot_date DATE NOT NULL,
    total_balance NUMERIC(12, 2),
    cash_balance NUMERIC(12, 2),
    credit_balance NUMERIC(12, 2),
    daily_spent NUMERIC(12, 2),
    daily_income NUMERIC(12, 2),
    daily_net NUMERIC(12, 2),
    transaction_count INTEGER,
    mtd_spent NUMERIC(12, 2),
    ytd_spent NUMERIC(12, 2),
    is_finalized BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    UNIQUE(user_id, snapshot_date)
);
```

### transaction_snapshots
```sql
CREATE TABLE public.transaction_snapshots (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    simplefin_account_id UUID REFERENCES simplefin_accounts(id),
    snapshot_date DATE NOT NULL,
    balance NUMERIC(12, 2),
    daily_spent NUMERIC(12, 2),
    daily_income NUMERIC(12, 2),
    daily_net NUMERIC(12, 2),
    transaction_count INTEGER,
    is_finalized BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    UNIQUE(user_id, simplefin_account_id, snapshot_date)
);
```

## iOS Integration

### HomeView (Overview)
Uses `GET /app/v1/snapshots` to show net worth chart:
```swift
let snapshots = try await apiClient.getSnapshots(
    startDate: startDate,
    endDate: endDate,
    granularity: timeRange.rawValue
)
```

### AccountDetailView (Individual Account)
Uses `GET /app/v1/snapshots/account/{account_id}` to show balance trend:
```swift
let snapshots = try await apiClient.getAccountSnapshots(
    accountId: account.id,
    startDate: startDate,
    endDate: endDate,
    granularity: timeRange.rawValue
)
```

## Migration

To set up both tables, run the complete schema migration:

```sql
-- In Supabase SQL Editor
-- Run: backend/supabase/migrations/001_complete_schema.sql
```

This creates:
- `net_snapshots` table with RLS policies
- `transaction_snapshots` table with RLS policies
- Indexes for fast queries
- Triggers for updated_at timestamps

## Performance

### Indexes
Both tables have compound indexes for fast queries:
- `net_snapshots`: `(user_id, snapshot_date DESC)`
- `transaction_snapshots`: `(user_id, simplefin_account_id, snapshot_date DESC)`

### Storage
- Each user generates ~365 net snapshots per year (1 per day)
- Each user generates ~365 * N transaction snapshots per year (N = number of accounts)
- Average: ~5 accounts = ~1,825 rows per user per year
- At 1000 users: ~1.8M rows per year (very manageable for Postgres)

## Troubleshooting

### Missing snapshots
If snapshots are missing:
1. Check that transactions exist for that date
2. Run manual calculation: `POST /app/v1/snapshots/calculate`
3. Check cron job logs for errors

### Incorrect balances
If balances don't match:
1. Verify SimpleFin account balances are current
2. Recalculate snapshots: `POST /app/v1/snapshots/calculate`
3. Check for transaction data issues

### Slow queries
If snapshot queries are slow:
1. Verify indexes exist: `\d net_snapshots`, `\d transaction_snapshots`
2. Check query plans: `EXPLAIN ANALYZE SELECT...`
3. Consider adding more specific indexes for your query patterns
