-- ============================================================================
-- Clear Budget + Category Tables Script
-- ============================================================================
-- Clears budget and category data so you can start fresh without losing
-- transactions or SimpleFin connections.
-- ============================================================================

-- WARNING: This will DELETE all budget and category data!
-- Transactions will have their category/subcategory fields set to NULL (via ON DELETE SET NULL).
-- SimpleFin connections and account data are NOT affected.

-- ============================================================================
-- Clear Tables (in reverse dependency order)
-- ============================================================================

-- Budget tables (depend on categories)
DELETE FROM public.budget_months;
DELETE FROM public.budget_line_items;
DELETE FROM public.budget_accounts;
DELETE FROM public.budgets;

-- Categorization rules (depend on categories/subcategories)
DELETE FROM public.categorization_rules;

-- Subcategories before categories (foreign key order)
DELETE FROM public.subcategories;
DELETE FROM public.categories;

-- ============================================================================
-- Verification
-- ============================================================================

SELECT
    'budgets'               AS table_name, COUNT(*) AS remaining_rows FROM public.budgets
UNION ALL
SELECT
    'budget_line_items',    COUNT(*) FROM public.budget_line_items
UNION ALL
SELECT
    'budget_accounts',      COUNT(*) FROM public.budget_accounts
UNION ALL
SELECT
    'budget_months',        COUNT(*) FROM public.budget_months
UNION ALL
SELECT
    'categorization_rules', COUNT(*) FROM public.categorization_rules
UNION ALL
SELECT
    'subcategories',        COUNT(*) FROM public.subcategories
UNION ALL
SELECT
    'categories',           COUNT(*) FROM public.categories;

-- All rows should be 0 if successful
SELECT '✅ Budget and category tables cleared. SimpleFin connections and transactions are untouched.' AS status;
