-- ============================================================================
-- Drop All Tables Script
-- ============================================================================
-- Run this in Supabase SQL Editor BEFORE running 001_complete_schema.sql
-- This ensures a clean slate for the complete schema
-- ============================================================================

-- WARNING: This will DELETE ALL DATA in these tables!
-- Make sure you have backups if you need to preserve any data

-- ============================================================================
-- Drop Views First
-- ============================================================================

DROP VIEW IF EXISTS public.transactions_view CASCADE;

-- ============================================================================
-- Drop Tables (in reverse dependency order)
-- ============================================================================

-- Budget-related tables
DROP TABLE IF EXISTS public.budget_accounts CASCADE;
DROP TABLE IF EXISTS public.budget_subcategories CASCADE;  -- Future phase
DROP TABLE IF EXISTS public.budget_periods CASCADE;        -- Future phase
DROP TABLE IF EXISTS public.budgets CASCADE;

-- Categorization tables
DROP TABLE IF EXISTS public.categorization_feedback CASCADE;  -- Future phase
DROP TABLE IF EXISTS public.subcategories CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;

-- SimpleFin tables (most dependent first)
DROP TABLE IF EXISTS public.simplefin_sync_jobs CASCADE;
DROP TABLE IF EXISTS public.simplefin_transactions CASCADE;
DROP TABLE IF EXISTS public.account_balance_history CASCADE;
DROP TABLE IF EXISTS public.simplefin_accounts CASCADE;
DROP TABLE IF EXISTS public.simplefin_items CASCADE;

-- ============================================================================
-- Drop Functions
-- ============================================================================

DROP FUNCTION IF EXISTS public.batch_update_transaction_categories(UUID[], UUID[], UUID[]) CASCADE;
DROP FUNCTION IF EXISTS public.handle_updated_at() CASCADE;

-- ============================================================================
-- Verification
-- ============================================================================

-- Check that all tables are dropped
SELECT
    tablename
FROM pg_tables
WHERE schemaname = 'public'
    AND tablename IN (
        'budget_accounts',
        'budget_subcategories',
        'budget_periods',
        'budgets',
        'categorization_feedback',
        'subcategories',
        'categories',
        'simplefin_sync_jobs',
        'simplefin_transactions',
        'account_balance_history',
        'simplefin_accounts',
        'simplefin_items'
    );

-- If this returns no rows, all tables are successfully dropped
-- If it returns rows, those tables still exist

SELECT '✅ All tables dropped successfully. Ready to run 001_complete_schema.sql' AS status;
