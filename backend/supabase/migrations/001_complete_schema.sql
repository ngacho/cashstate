-- CashState - Complete Database Schema
-- SimpleFin + Daily Account Balance History
-- Run this after ensuring auth.users table exists

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SimpleFin Items Table (Connection/Credential Storage)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.simplefin_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    access_url TEXT NOT NULL,  -- Encrypted SimpleFin access URL
    institution_name TEXT,     -- User-provided name for this connection
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'error')),
    last_synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.simplefin_items ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.simplefin_items TO authenticated;

CREATE POLICY "Users can manage own simplefin items"
    ON public.simplefin_items FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE INDEX idx_simplefin_items_user_id ON public.simplefin_items(user_id);
CREATE INDEX idx_simplefin_items_status ON public.simplefin_items(status);

CREATE TRIGGER simplefin_items_updated_at
    BEFORE UPDATE ON public.simplefin_items
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- SimpleFin Accounts Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.simplefin_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    simplefin_item_id UUID NOT NULL REFERENCES public.simplefin_items(id) ON DELETE CASCADE,
    simplefin_account_id TEXT NOT NULL,  -- SimpleFin's account ID (e.g., "ACT-xxx")

    -- Account details
    name TEXT NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',

    -- Balance info (updated on each sync)
    balance NUMERIC(15, 2),
    available_balance NUMERIC(15, 2),
    balance_date BIGINT,  -- Unix timestamp

    -- Organization/Institution info
    organization_name TEXT,
    organization_domain TEXT,
    organization_sfin_url TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(user_id, simplefin_item_id, simplefin_account_id)
);

ALTER TABLE public.simplefin_accounts ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.simplefin_accounts TO authenticated;

CREATE POLICY "Users can manage own simplefin accounts"
    ON public.simplefin_accounts FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE INDEX idx_simplefin_accounts_user_id ON public.simplefin_accounts(user_id);
CREATE INDEX idx_simplefin_accounts_item_id ON public.simplefin_accounts(simplefin_item_id);
CREATE INDEX idx_simplefin_accounts_account_id ON public.simplefin_accounts(simplefin_account_id);

CREATE TRIGGER simplefin_accounts_updated_at
    BEFORE UPDATE ON public.simplefin_accounts
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- SimpleFin Transactions Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.simplefin_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    simplefin_account_id UUID NOT NULL REFERENCES public.simplefin_accounts(id) ON DELETE CASCADE,
    simplefin_transaction_id TEXT NOT NULL UNIQUE,  -- SimpleFin's transaction ID

    -- Transaction details
    amount NUMERIC(12, 2) NOT NULL,  -- Signed (negative = expense, positive = income)
    currency TEXT NOT NULL DEFAULT 'USD',

    -- Date fields
    posted_date BIGINT NOT NULL,      -- Unix timestamp when posted
    transaction_date BIGINT NOT NULL, -- Unix timestamp when occurred

    -- Description fields
    description TEXT NOT NULL,
    payee TEXT,
    memo TEXT,

    pending BOOLEAN NOT NULL DEFAULT FALSE,

    -- Categorization
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    subcategory_id UUID REFERENCES public.subcategories(id) ON DELETE SET NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.simplefin_transactions ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.simplefin_transactions TO authenticated;

CREATE POLICY "Users can manage own simplefin transactions"
    ON public.simplefin_transactions FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE INDEX idx_simplefin_transactions_user_id ON public.simplefin_transactions(user_id);
CREATE INDEX idx_simplefin_transactions_account_id ON public.simplefin_transactions(simplefin_account_id);
CREATE INDEX idx_simplefin_transactions_transaction_id ON public.simplefin_transactions(simplefin_transaction_id);
CREATE INDEX idx_simplefin_transactions_posted_date ON public.simplefin_transactions(user_id, posted_date DESC);
CREATE INDEX idx_simplefin_transactions_transaction_date ON public.simplefin_transactions(user_id, transaction_date DESC);
CREATE INDEX idx_simplefin_transactions_amount ON public.simplefin_transactions(amount);
CREATE INDEX idx_simplefin_transactions_category_id ON public.simplefin_transactions(category_id);
CREATE INDEX idx_simplefin_transactions_subcategory_id ON public.simplefin_transactions(subcategory_id);
CREATE INDEX idx_simplefin_transactions_user_category ON public.simplefin_transactions(user_id, category_id);

CREATE TRIGGER simplefin_transactions_updated_at
    BEFORE UPDATE ON public.simplefin_transactions
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- SimpleFin Sync Jobs Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.simplefin_sync_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    simplefin_item_id UUID NOT NULL REFERENCES public.simplefin_items(id) ON DELETE CASCADE,

    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed')),

    -- Sync results
    accounts_synced INT NOT NULL DEFAULT 0,
    transactions_added INT NOT NULL DEFAULT 0,
    transactions_updated INT NOT NULL DEFAULT 0,

    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

ALTER TABLE public.simplefin_sync_jobs ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.simplefin_sync_jobs TO authenticated;

CREATE POLICY "Users can manage own simplefin sync jobs"
    ON public.simplefin_sync_jobs FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE INDEX idx_simplefin_sync_jobs_user_id ON public.simplefin_sync_jobs(user_id);
CREATE INDEX idx_simplefin_sync_jobs_item_id ON public.simplefin_sync_jobs(simplefin_item_id);
CREATE INDEX idx_simplefin_sync_jobs_status ON public.simplefin_sync_jobs(status);
CREATE INDEX idx_simplefin_sync_jobs_created_at ON public.simplefin_sync_jobs(created_at DESC);

-- ============================================================================
-- Account Balance History Table
-- ============================================================================
-- Stores daily balance snapshots for each account
-- Net worth is calculated on-the-fly by summing all account balances per date
CREATE TABLE IF NOT EXISTS public.account_balance_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    simplefin_account_id UUID NOT NULL REFERENCES public.simplefin_accounts(id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL,
    balance NUMERIC(12, 2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(user_id, simplefin_account_id, snapshot_date)
);

ALTER TABLE public.account_balance_history ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.account_balance_history TO authenticated;

CREATE POLICY "Users can manage own account balance history"
    ON public.account_balance_history FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE INDEX idx_account_balance_history_user_account_date ON public.account_balance_history(user_id, simplefin_account_id, snapshot_date DESC);
CREATE INDEX idx_account_balance_history_account_date ON public.account_balance_history(simplefin_account_id, snapshot_date DESC);
CREATE INDEX idx_account_balance_history_user_date ON public.account_balance_history(user_id, snapshot_date DESC);

CREATE TRIGGER account_balance_history_updated_at
    BEFORE UPDATE ON public.account_balance_history
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- Categories Table
-- ============================================================================
-- Stores top-level categories (e.g., Food & Dining, Transportation, Shopping)
-- Supports both system-provided and user-custom categories
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,  -- NULL for system categories
    name TEXT NOT NULL,
    icon TEXT,          -- SF Symbol name for iOS (e.g., "fork.knife")
    color TEXT,         -- Hex color code (e.g., "#FF5733")
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Ensure unique names per user (and for system categories)
    UNIQUE NULLS NOT DISTINCT (user_id, name)
);

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.categories TO authenticated;

-- Users can view system categories OR their own categories
CREATE POLICY "Users can view system and own categories"
    ON public.categories FOR SELECT
    USING (user_id IS NULL OR (SELECT auth.uid()) = user_id);

-- Users can only insert their own categories (not system ones)
CREATE POLICY "Users can insert own categories"
    ON public.categories FOR INSERT
    WITH CHECK ((SELECT auth.uid()) = user_id AND is_system = FALSE);

-- Users can only update their own categories (not system ones)
CREATE POLICY "Users can update own categories"
    ON public.categories FOR UPDATE
    USING ((SELECT auth.uid()) = user_id AND is_system = FALSE)
    WITH CHECK ((SELECT auth.uid()) = user_id AND is_system = FALSE);

-- Users can only delete their own categories (not system ones)
CREATE POLICY "Users can delete own categories"
    ON public.categories FOR DELETE
    USING ((SELECT auth.uid()) = user_id AND is_system = FALSE);

CREATE INDEX idx_categories_user_id ON public.categories(user_id);
CREATE INDEX idx_categories_is_system ON public.categories(is_system);
CREATE INDEX idx_categories_display_order ON public.categories(display_order);

CREATE TRIGGER categories_updated_at
    BEFORE UPDATE ON public.categories
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- Subcategories Table
-- ============================================================================
-- Stores subcategories under parent categories (e.g., Restaurants, Groceries under Food)
-- Supports both system-provided and user-custom subcategories
CREATE TABLE IF NOT EXISTS public.subcategories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,  -- NULL for system subcategories
    name TEXT NOT NULL,
    icon TEXT,          -- SF Symbol name for iOS (e.g., "fork.knife.circle")
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Ensure unique names per category per user
    UNIQUE NULLS NOT DISTINCT (category_id, user_id, name)
);

ALTER TABLE public.subcategories ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.subcategories TO authenticated;

-- Users can view system subcategories OR their own subcategories
CREATE POLICY "Users can view system and own subcategories"
    ON public.subcategories FOR SELECT
    USING (user_id IS NULL OR (SELECT auth.uid()) = user_id);

-- Users can only insert their own subcategories (not system ones)
CREATE POLICY "Users can insert own subcategories"
    ON public.subcategories FOR INSERT
    WITH CHECK ((SELECT auth.uid()) = user_id AND is_system = FALSE);

-- Users can only update their own subcategories (not system ones)
CREATE POLICY "Users can update own subcategories"
    ON public.subcategories FOR UPDATE
    USING ((SELECT auth.uid()) = user_id AND is_system = FALSE)
    WITH CHECK ((SELECT auth.uid()) = user_id AND is_system = FALSE);

-- Users can only delete their own subcategories (not system ones)
CREATE POLICY "Users can delete own subcategories"
    ON public.subcategories FOR DELETE
    USING ((SELECT auth.uid()) = user_id AND is_system = FALSE);

CREATE INDEX idx_subcategories_category_id ON public.subcategories(category_id);
CREATE INDEX idx_subcategories_user_id ON public.subcategories(user_id);
CREATE INDEX idx_subcategories_is_system ON public.subcategories(is_system);
CREATE INDEX idx_subcategories_display_order ON public.subcategories(category_id, display_order);

CREATE TRIGGER subcategories_updated_at
    BEFORE UPDATE ON public.subcategories
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- Budgets Table
-- ============================================================================
-- Stores user-specific budget allocations per category
CREATE TABLE IF NOT EXISTS public.budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,

    -- Budget amount (monthly)
    amount NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (amount >= 0),

    -- Time period
    period TEXT NOT NULL DEFAULT 'monthly' CHECK (period IN ('weekly', 'monthly', 'yearly')),

    -- Active/inactive
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- One budget per category per user per period
    UNIQUE(user_id, category_id, period)
);

ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.budgets TO authenticated;

CREATE POLICY "Users can manage own budgets"
    ON public.budgets FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE INDEX idx_budgets_user_id ON public.budgets(user_id);
CREATE INDEX idx_budgets_category_id ON public.budgets(category_id);
CREATE INDEX idx_budgets_user_category ON public.budgets(user_id, category_id);
CREATE INDEX idx_budgets_is_active ON public.budgets(is_active);

CREATE TRIGGER budgets_updated_at
    BEFORE UPDATE ON public.budgets
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
