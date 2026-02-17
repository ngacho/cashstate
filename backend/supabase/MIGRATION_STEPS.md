# Database Migration Steps

Complete guide for migrating your CashState database to include Phase 1 changes (budget account selection).

## ⚠️ Before You Begin

**IMPORTANT:** This will delete all existing data. Make sure to:
1. Export/backup any data you want to keep
2. Understand that this is a destructive operation
3. Have your Supabase dashboard open and ready

## Step 1: Drop Existing Tables

Go to **Supabase Dashboard > SQL Editor** and run:

```
backend/supabase/scripts/drop_all_tables.sql
```

**What this does:**
- Drops all CashState tables
- Drops views and functions
- Cleans the slate for fresh schema

**Verification:**
The script outputs: `✅ All tables dropped successfully. Ready to run 001_complete_schema.sql`

## Step 2: Run Complete Schema

In the same **Supabase SQL Editor**, run:

```
backend/supabase/migrations/001_complete_schema.sql
```

**What this creates:**
- All CashState tables with RLS policies
- New `budget_accounts` table for Phase 1
- Helper functions and triggers
- Proper indexes and constraints

## Step 3: Verify Tables

Run this query to verify all tables exist:

```sql
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

**Expected tables:**
- account_balance_history
- budget_accounts ← **NEW in Phase 1**
- budgets
- categories
- simplefin_accounts
- simplefin_items
- simplefin_sync_jobs
- simplefin_transactions
- subcategories

## Step 4: Test Backend

```bash
cd backend
uv run pytest tests/test_budget_accounts.py -v
```

All 5 budget account tests should pass.

## Quick Reference

### Single Command (All at Once)

If you want to run everything in one go, copy this into Supabase SQL Editor:

```sql
-- Step 1: Drop all tables
\i backend/supabase/scripts/drop_all_tables.sql

-- Step 2: Create fresh schema
\i backend/supabase/migrations/001_complete_schema.sql
```

**Note:** The `\i` command only works in psql CLI, not Supabase web editor. In web editor, copy/paste each file's contents one at a time.

## Rollback

If something goes wrong, you can always:
1. Re-run `drop_all_tables.sql`
2. Re-run `001_complete_schema.sql`
3. Start fresh

## Need Help?

- Check Supabase logs: Dashboard > Database > Logs
- Verify RLS policies: Dashboard > Authentication > Policies
- Check table structure: Dashboard > Table Editor
