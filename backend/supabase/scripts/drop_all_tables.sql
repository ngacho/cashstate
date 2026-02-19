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

-- Goals tables
DROP TABLE IF EXISTS public.goal_accounts CASCADE;
DROP TABLE IF EXISTS public.goals CASCADE;

-- Budget tables (new schema)
DROP TABLE IF EXISTS public.budget_months CASCADE;
DROP TABLE IF EXISTS public.budget_line_items CASCADE;
DROP TABLE IF EXISTS public.budget_accounts CASCADE;
DROP TABLE IF EXISTS public.budgets CASCADE;

-- Categorization tables
DROP TABLE IF EXISTS public.categorization_rules CASCADE;
DROP TABLE IF EXISTS public.categorization_feedback CASCADE;
DROP TABLE IF EXISTS public.subcategories CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;

-- SimpleFin tables (most dependent first)
DROP TABLE IF EXISTS public.simplefin_sync_jobs CASCADE;
DROP TABLE IF EXISTS public.account_balance_history CASCADE;
DROP TABLE IF EXISTS public.simplefin_transactions CASCADE;
DROP TABLE IF EXISTS public.simplefin_accounts CASCADE;
DROP TABLE IF EXISTS public.simplefin_items CASCADE;

-- Old Budget Template tables (from previous schema - safe to drop if they exist)
DROP TABLE IF EXISTS public.budget_periods CASCADE;
DROP TABLE IF EXISTS public.budget_subcategories CASCADE;
DROP TABLE IF EXISTS public.budget_categories CASCADE;
DROP TABLE IF EXISTS public.budget_template_accounts CASCADE;
DROP TABLE IF EXISTS public.budget_templates CASCADE;

-- ============================================================================
-- Drop Functions
-- ============================================================================

DROP FUNCTION IF EXISTS public.batch_update_transaction_categories(UUID[], UUID[], UUID[]) CASCADE;
DROP FUNCTION IF EXISTS public.batch_update_transaction_categories(UUID[], UUID[], UUID[], TEXT[]) CASCADE;
DROP FUNCTION IF EXISTS public.handle_updated_at() CASCADE;

-- ============================================================================
-- Verification
-- ============================================================================

-- Check that all tables are dropped (should return 0 rows)
SELECT
    tablename
FROM pg_tables
WHERE schemaname = 'public'
    AND tablename IN (
        -- Goals tables
        'goal_accounts',
        'goals',
        -- Budget tables (new schema)
        'budget_months',
        'budget_line_items',
        'budget_accounts',
        'budgets',
        -- Categorization tables
        'categorization_rules',
        'subcategories',
        'categories',
        -- SimpleFin tables
        'simplefin_sync_jobs',
        'account_balance_history',
        'simplefin_transactions',
        'simplefin_accounts',
        'simplefin_items'
    );

-- If this returns no rows, all tables are successfully dropped
-- If it returns rows, those tables still exist

SELECT '✅ All tables dropped successfully. Ready to run 001_complete_schema.sql' AS status;
