# Database Migration Guide

## What Changed

The database schema has been simplified so **all tables now have a direct `user_id` column** for easier querying and better performance.

### Before (Complex Relationships)
- **simplefin_transactions**: No user_id → Required joining through simplefin_accounts
- **simplefin_sync_jobs**: No user_id → Required joining through simplefin_items
- Queries needed complex subqueries or multiple lookups

### After (Simplified)
- **simplefin_transactions**: Has user_id + simplefin_account_id
- **simplefin_sync_jobs**: Has user_id + simplefin_item_id
- Queries can filter directly with `.eq("user_id", user_id)`

## Files Updated

### Backend Code
1. **backend/migrations/001_complete_schema.sql** (NEW)
   - Complete database schema from scratch
   - All tables: simplefin_items, simplefin_accounts, simplefin_transactions, simplefin_sync_jobs, daily_snapshots
   - All tables have user_id column
   - RLS policies use direct user_id checks

2. **backend/app/database.py**
   - Simplified `get_user_simplefin_transactions()` - now queries directly with user_id
   - Simplified `count_user_simplefin_transactions()` - now queries directly with user_id
   - Simplified `get_simplefin_sync_jobs_for_user()` - now queries directly with user_id
   - Removed helper methods `_get_user_simplefin_item_ids()` and `_get_user_simplefin_account_ids()`

3. **backend/app/services/snapshot_service.py**
   - All transaction queries now use `.eq("user_id", user_id)`
   - Removed complex account_ids lookups
   - Simpler, more performant code

4. **backend/app/services/simplefin_service.py**
   - `parse_simplefin_transactions()` now accepts `user_id` parameter
   - Includes `user_id` in transaction dictionaries

5. **backend/app/routers/simplefin.py**
   - Sync job creation now includes `user_id`
   - Calls `parse_simplefin_transactions()` with `user_id`

6. **backend/README.md**
   - Updated migration instructions to reference new complete schema

## Migration Steps

### ⚠️ IMPORTANT: This is a destructive migration - you will lose existing data!

1. **Backup your data** (if needed)
   - Export transactions from Supabase dashboard
   - Save any important sync job history

2. **Delete all existing tables** in Supabase:
   ```sql
   DROP TABLE IF EXISTS public.daily_snapshots CASCADE;
   DROP TABLE IF EXISTS public.simplefin_sync_jobs CASCADE;
   DROP TABLE IF EXISTS public.simplefin_transactions CASCADE;
   DROP TABLE IF EXISTS public.simplefin_accounts CASCADE;
   DROP TABLE IF EXISTS public.simplefin_items CASCADE;
   ```

3. **Run the new migration**:
   - Go to Supabase Dashboard → SQL Editor
   - Copy entire contents of `backend/migrations/001_complete_schema.sql`
   - Execute the script

4. **Verify tables created**:
   - Check that all 5 tables exist: simplefin_items, simplefin_accounts, simplefin_transactions, simplefin_sync_jobs, daily_snapshots
   - Check that RLS is enabled on all tables
   - Check that indexes are created

5. **Test the backend**:
   ```bash
   cd backend
   uv run pytest tests/test_complete_simplefin.py -v
   ```

## Schema Comparison

### simplefin_transactions

**Old:**
```sql
CREATE TABLE simplefin_transactions (
    id UUID PRIMARY KEY,
    simplefin_account_id UUID REFERENCES simplefin_accounts(id),
    -- NO user_id column
    amount NUMERIC,
    ...
);
```

**New:**
```sql
CREATE TABLE simplefin_transactions (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),  -- ✅ Direct link
    simplefin_account_id UUID REFERENCES simplefin_accounts(id),
    amount NUMERIC,
    ...
);
```

### simplefin_sync_jobs

**Old:**
```sql
CREATE TABLE simplefin_sync_jobs (
    id UUID PRIMARY KEY,
    simplefin_item_id UUID REFERENCES simplefin_items(id),
    -- NO user_id column
    status TEXT,
    ...
);
```

**New:**
```sql
CREATE TABLE simplefin_sync_jobs (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),  -- ✅ Direct link
    simplefin_item_id UUID REFERENCES simplefin_items(id),
    status TEXT,
    ...
);
```

## Benefits

1. **Simpler Queries**: No more complex joins or subqueries
2. **Better Performance**: Direct index on user_id instead of nested lookups
3. **Easier RLS**: Policies can use `(SELECT auth.uid()) = user_id` directly
4. **Less Code**: Removed helper methods, simplified service layers
5. **Consistent Pattern**: All user data accessible via user_id

## Testing

After migration, verify:

1. ✅ User registration/login works
2. ✅ SimpleFin token exchange works
3. ✅ Transaction sync includes user_id in all records
4. ✅ Sync jobs include user_id
5. ✅ Snapshots calculate correctly from transactions
6. ✅ All RLS policies enforce user data isolation

Run full test suite:
```bash
uv run pytest tests/test_complete_simplefin.py -v
```

Expected: All 12 tests should pass.
