# Database Schema Fix Summary

## Changes Made

### 1. Fixed `001_complete_schema.sql`

**Issue:** The database schema didn't provide the fields expected by the `/transactions` API endpoint. The `TransactionResponse` schema expected fields like `account_id`, `account_name`, `simplefin_item_id`, `date`, and `posted`, but the raw `simplefin_transactions` table only had `simplefin_account_id`, `posted_date` (Unix timestamp), and `transaction_date` (Unix timestamp).

**Solution:** Created a database view called `transactions_view` that:
- Joins `simplefin_transactions` with `simplefin_accounts`
- Provides all fields needed by `TransactionResponse`:
  - `account_id` (aliased from `simplefin_account_id`)
  - `account_name` (from `simplefin_accounts.name`)
  - `simplefin_item_id` (from `simplefin_accounts.simplefin_item_id`)
  - `date` (formatted as YYYY-MM-DD string from `transaction_date`)
  - `posted` (converted from Unix timestamp to timestamptz)
- Inherits RLS policies from the underlying `simplefin_transactions` table

**Removed:** Duplicate "-- Categories Table" comment at line 392

### 2. Updated `database.py`

**Added two new methods:**
- `get_user_transactions_with_account_info()` - Queries from `transactions_view` with string date filters (YYYY-MM-DD format)
- `count_user_transactions_with_account_info()` - Counts transactions from the view

**Kept existing methods:**
- `get_user_simplefin_transactions()` - Still queries raw table with Unix timestamps (used by `/simplefin/transactions`)
- `count_user_simplefin_transactions()` - Still counts from raw table

### 3. Updated `transactions.py` Router

**Changed:**
- `list_transactions()` - Now uses `get_user_transactions_with_account_info()` from the view
- `get_transaction()` - Now queries `transactions_view` directly to get joined data

**Why:** The `/transactions` endpoint returns `TransactionResponse` which requires joined account data. The `/simplefin/transactions` endpoint returns `SimplefinTransactionResponse` which matches the raw table structure.

## API Endpoint Differences

### `/app/v1/transactions` (Updated)
- **Response:** `TransactionResponse` with joined account info
- **Date Format:** YYYY-MM-DD strings
- **Data Source:** `transactions_view` (joined data)
- **Use Case:** User-facing transaction list with full context

### `/app/v1/simplefin/transactions` (Unchanged)
- **Response:** `SimplefinTransactionResponse` with raw DB fields
- **Date Format:** Unix timestamps (integers)
- **Data Source:** `simplefin_transactions` table (raw data)
- **Use Case:** SimpleFin-specific operations, internal tools

## Migration Steps

### For New Databases:
1. Go to Supabase Dashboard > SQL Editor
2. Run `supabase/migrations/001_complete_schema.sql` (includes the secure view)
3. Run `supabase/migrations/003_default_categories_and_budgets.sql`

### For Existing Databases:
1. Go to Supabase Dashboard > SQL Editor
2. Run `FIX_TRANSACTIONS_VIEW_RLS.sql` (in project root) OR run this SQL:

```sql
-- CRITICAL: Must include security_invoker = true to enforce RLS!
DROP VIEW IF EXISTS public.transactions_view;

CREATE VIEW public.transactions_view
WITH (security_invoker = true)
AS
SELECT
    t.id,
    t.user_id,
    a.simplefin_item_id,
    t.simplefin_transaction_id,
    t.simplefin_account_id AS account_id,
    a.name AS account_name,
    t.amount,
    t.currency,
    to_char(to_timestamp(t.transaction_date), 'YYYY-MM-DD') AS date,
    to_timestamp(t.posted_date) AS posted,
    t.description,
    t.payee,
    t.pending,
    t.category_id,
    t.subcategory_id,
    t.created_at,
    t.updated_at
FROM public.simplefin_transactions t
JOIN public.simplefin_accounts a ON t.simplefin_account_id = a.id;
```

3. Done! The `security_invoker = true` setting ensures RLS policies are enforced.

## 🔒 CRITICAL SECURITY NOTE

**Without `security_invoker = true`, the view bypasses RLS and exposes ALL users' transactions!**

- ✅ **WITH** `security_invoker = true`: View runs with caller's permissions → RLS enforced
- ❌ **WITHOUT** `security_invoker = true`: View runs with creator's permissions → RLS bypassed → SECURITY BREACH

The fixed schema now includes this setting by default.

## Testing

After applying the migration, test the endpoints:

```bash
# Start the backend
uv run uvicorn app.main:app --reload

# In another terminal, run tests
uv run pytest tests/test_complete_simplefin.py -v -s
```

## What This Fixes

1. **TransactionResponse Schema Mismatch:** The `/transactions` endpoint now returns data in the correct format
2. **Missing Fields:** `account_name`, `simplefin_item_id`, and properly formatted dates are now available
3. **Type Safety:** Date filters work with YYYY-MM-DD strings as documented
4. **Backward Compatibility:** The `/simplefin/transactions` endpoint continues to work with raw DB fields

## Files Changed

- ✅ `backend/supabase/migrations/001_complete_schema.sql` - Added transactions_view
- ✅ `backend/app/database.py` - Added new query methods for the view
- ✅ `backend/app/routers/transactions.py` - Updated to use new methods

## No Changes Needed

- ❌ `backend/app/schemas/transaction.py` - Already correct
- ❌ `backend/app/schemas/simplefin.py` - Already correct
- ❌ `backend/app/routers/simplefin.py` - Still uses raw table (correct)
