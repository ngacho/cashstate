-- ============================================================================
-- Reset Categorizations Script
-- ============================================================================
-- This script removes all categorization data to start fresh
-- Run this in your Supabase SQL editor
-- ============================================================================

-- OPTION 1: SOFT RESET (Recommended for testing)
-- Clears assignments but keeps categories/budgets structure
-- ============================================================================

-- Remove all category assignments from transactions
UPDATE public.simplefin_transactions
SET category_id = NULL,
    subcategory_id = NULL,
    updated_at = NOW();

-- Clear categorization feedback (if table exists)
-- DROP TABLE IF EXISTS public.categorization_feedback CASCADE;

SELECT 'SOFT RESET COMPLETE: All transactions uncategorized' AS status;

-- ============================================================================
-- OPTION 2: HARD RESET (Clean slate)
-- Deletes everything: budgets, user categories, and clears assignments
-- WARNING: This will delete all user-created categories and budgets!
-- ============================================================================


-- Delete all budgets
DELETE FROM public.budgets;

-- Delete all user-created subcategories (keep system ones)
DELETE FROM public.subcategories WHERE is_system = FALSE;

-- Delete all user-created categories (keep system ones)
DELETE FROM public.categories WHERE is_system = FALSE;

-- Clear all transaction categorizations
UPDATE public.simplefin_transactions
SET category_id = NULL,
    subcategory_id = NULL,
    updated_at = NOW();

-- Drop categorization feedback table if exists
DROP TABLE IF EXISTS public.categorization_feedback CASCADE;

SELECT 'HARD RESET COMPLETE: All budgets, user categories, and assignments deleted' AS status;


-- ============================================================================
-- Verification Queries
-- ============================================================================

-- Check uncategorized transactions
SELECT COUNT(*) as uncategorized_transactions
FROM public.simplefin_transactions
WHERE category_id IS NULL;

-- Check remaining categories
SELECT
    COUNT(*) FILTER (WHERE is_system = TRUE) as system_categories,
    COUNT(*) FILTER (WHERE is_system = FALSE) as user_categories
FROM public.categories;

-- Check remaining budgets
SELECT COUNT(*) as remaining_budgets
FROM public.budgets;
