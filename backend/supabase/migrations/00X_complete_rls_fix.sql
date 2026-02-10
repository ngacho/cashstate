-- ============================================================================
-- COMPLETE RLS FIX - Run this ONE script to fix everything
-- ============================================================================
-- This script:
-- 1. Removes duplicate/conflicting "Service role" policies
-- 2. Grants proper table-level permissions to authenticated users
-- 3. Recreates all RLS policies with performance optimization (select auth.uid())
-- ============================================================================

-- ============================================================================
-- STEP 1: Clean up ALL existing policies (duplicate and old ones)
-- ============================================================================

-- Users table
drop policy if exists "Service role has full access to users" on public.users;
drop policy if exists "Users can read own profile" on public.users;
drop policy if exists "Users can insert own profile" on public.users;
drop policy if exists "Users can update own profile" on public.users;
drop policy if exists "Enable insert for authenticated users only" on public.users;

-- Plaid items table
drop policy if exists "Service role has full access to plaid_items" on public.plaid_items;
drop policy if exists "Users can read own plaid items" on public.plaid_items;
drop policy if exists "Users can insert own plaid items" on public.plaid_items;
drop policy if exists "Users can update own plaid items" on public.plaid_items;
drop policy if exists "Enable insert for authenticated users only" on public.plaid_items;

-- Transactions table
drop policy if exists "Service role has full access to transactions" on public.transactions;
drop policy if exists "Users can read own transactions" on public.transactions;
drop policy if exists "Users can insert own transactions" on public.transactions;
drop policy if exists "Users can update own transactions" on public.transactions;
drop policy if exists "Users can delete own transactions" on public.transactions;
drop policy if exists "Enable insert for authenticated users only" on public.transactions;

-- Sync jobs table
drop policy if exists "Service role has full access to sync_jobs" on public.sync_jobs;
drop policy if exists "Users can read own sync jobs" on public.sync_jobs;
drop policy if exists "Users can insert own sync jobs" on public.sync_jobs;
drop policy if exists "Users can update own sync jobs" on public.sync_jobs;
drop policy if exists "Enable insert for authenticated users only" on public.sync_jobs;

-- ============================================================================
-- STEP 2: Grant table-level permissions to authenticated users
-- ============================================================================

grant select, insert, update on public.users to authenticated;
grant select, insert, update on public.plaid_items to authenticated;
grant select, insert, update, delete on public.transactions to authenticated;
grant select, insert, update on public.sync_jobs to authenticated;

-- ============================================================================
-- STEP 3: Create optimized RLS policies with (select auth.uid())
-- ============================================================================

-- Users table policies
create policy "Users can read own profile"
    on public.users for select
    using ((select auth.uid()) = id);

create policy "Users can insert own profile"
    on public.users for insert
    with check ((select auth.uid()) = id);

create policy "Users can update own profile"
    on public.users for update
    using ((select auth.uid()) = id);

-- Plaid items table policies
create policy "Users can read own plaid items"
    on public.plaid_items for select
    using ((select auth.uid()) = user_id);

create policy "Users can insert own plaid items"
    on public.plaid_items for insert
    with check ((select auth.uid()) = user_id);

create policy "Users can update own plaid items"
    on public.plaid_items for update
    using ((select auth.uid()) = user_id);

-- Transactions table policies
create policy "Users can read own transactions"
    on public.transactions for select
    using (
        plaid_item_id in (
            select id from public.plaid_items where user_id = (select auth.uid())
        )
    );

create policy "Users can insert own transactions"
    on public.transactions for insert
    with check (
        plaid_item_id in (
            select id from public.plaid_items where user_id = (select auth.uid())
        )
    );

create policy "Users can update own transactions"
    on public.transactions for update
    using (
        plaid_item_id in (
            select id from public.plaid_items where user_id = (select auth.uid())
        )
    );

create policy "Users can delete own transactions"
    on public.transactions for delete
    using (
        plaid_item_id in (
            select id from public.plaid_items where user_id = (select auth.uid())
        )
    );

-- Sync jobs table policies
create policy "Users can read own sync jobs"
    on public.sync_jobs for select
    using (
        plaid_item_id in (
            select id from public.plaid_items where user_id = (select auth.uid())
        )
    );

create policy "Users can insert own sync jobs"
    on public.sync_jobs for insert
    with check (
        plaid_item_id in (
            select id from public.plaid_items where user_id = (select auth.uid())
        )
    );

create policy "Users can update own sync jobs"
    on public.sync_jobs for update
    using (
        plaid_item_id in (
            select id from public.plaid_items where user_id = (select auth.uid())
        )
    );

-- ============================================================================
-- DONE! All RLS policies are now optimized and duplicate policies removed
-- ============================================================================
