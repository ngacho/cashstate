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
-- Categories Table
-- ============================================================================
-- Stores top-level categories (e.g., Food & Dining, Transportation, Shopping)
-- Supports both default-seeded and user-custom categories
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,  -- NULL for system categories
    name TEXT NOT NULL,
    icon TEXT,          -- Emoji character (e.g., "🍽️") - cross-platform
    color TEXT,         -- Hex color code (e.g., "#FF5733")
    is_default BOOLEAN NOT NULL DEFAULT FALSE,  -- seeded from defaults but user-editable/deletable
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
    WITH CHECK ((SELECT auth.uid()) = user_id);

-- Users can only update their own categories
CREATE POLICY "Users can update own categories"
    ON public.categories FOR UPDATE
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

-- Users can only delete their own categories
CREATE POLICY "Users can delete own categories"
    ON public.categories FOR DELETE
    USING ((SELECT auth.uid()) = user_id);

CREATE INDEX idx_categories_user_id ON public.categories(user_id);
CREATE INDEX idx_categories_is_default ON public.categories(is_default);
CREATE INDEX idx_categories_display_order ON public.categories(display_order);

CREATE TRIGGER categories_updated_at
    BEFORE UPDATE ON public.categories
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- Subcategories Table
-- ============================================================================
-- Stores subcategories under parent categories (e.g., Restaurants, Groceries under Food)
-- Supports both default-seeded and user-custom subcategories
CREATE TABLE IF NOT EXISTS public.subcategories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,  -- NULL for system subcategories
    name TEXT NOT NULL,
    icon TEXT,          -- Emoji character (e.g., "🍽️") - cross-platform
    is_default BOOLEAN NOT NULL DEFAULT FALSE,  -- seeded from defaults but user-editable/deletable
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
    WITH CHECK ((SELECT auth.uid()) = user_id);

-- Users can only update their own subcategories
CREATE POLICY "Users can update own subcategories"
    ON public.subcategories FOR UPDATE
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

-- Users can only delete their own subcategories
CREATE POLICY "Users can delete own subcategories"
    ON public.subcategories FOR DELETE
    USING ((SELECT auth.uid()) = user_id);

CREATE INDEX idx_subcategories_category_id ON public.subcategories(category_id);
CREATE INDEX idx_subcategories_user_id ON public.subcategories(user_id);
CREATE INDEX idx_subcategories_is_default ON public.subcategories(is_default);
CREATE INDEX idx_subcategories_display_order ON public.subcategories(category_id, display_order);

CREATE TRIGGER subcategories_updated_at
    BEFORE UPDATE ON public.subcategories
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- Categorization Rules Table
-- ============================================================================
-- User-defined rules for auto-categorizing transactions (applied before AI)
CREATE TABLE IF NOT EXISTS public.categorization_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    match_field TEXT NOT NULL CHECK (match_field IN ('payee', 'description', 'memo')),
    match_value TEXT NOT NULL,              -- case-insensitive substring match
    category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
    subcategory_id UUID REFERENCES public.subcategories(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.categorization_rules ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, DELETE ON public.categorization_rules TO authenticated;

CREATE POLICY "Users can manage own categorization rules"
    ON public.categorization_rules FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE INDEX idx_categorization_rules_user_id ON public.categorization_rules(user_id);
CREATE INDEX idx_categorization_rules_user_category ON public.categorization_rules(user_id, category_id);

-- ============================================================================
-- Budgets Table
-- ============================================================================
-- Reusable budget structures; one can be default (applied to months without explicit override)
CREATE TABLE IF NOT EXISTS public.budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.budgets TO authenticated;

CREATE POLICY "Users can manage own budgets"
    ON public.budgets FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE INDEX idx_budgets_user_id ON public.budgets(user_id);
CREATE INDEX idx_budgets_is_default ON public.budgets(user_id, is_default);

-- One default budget per user
CREATE UNIQUE INDEX idx_budgets_default
    ON public.budgets(user_id)
    WHERE is_default = TRUE;

CREATE TRIGGER budgets_updated_at
    BEFORE UPDATE ON public.budgets
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- Budget Accounts Table
-- ============================================================================
-- Links budgets to specific accounts for tracking
-- KEY constraint: one account can only belong to ONE budget
CREATE TABLE IF NOT EXISTS public.budget_accounts (
    budget_id UUID NOT NULL REFERENCES public.budgets(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES public.simplefin_accounts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (budget_id, account_id),
    UNIQUE(account_id)  -- KEY: one account → one budget globally
);

ALTER TABLE public.budget_accounts ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, DELETE ON public.budget_accounts TO authenticated;

CREATE POLICY "Users can manage own budget accounts"
    ON public.budget_accounts FOR ALL
    USING (
        budget_id IN (
            SELECT id FROM public.budgets WHERE user_id = (SELECT auth.uid())
        )
    );

CREATE INDEX idx_budget_accounts_budget_id ON public.budget_accounts(budget_id);
CREATE INDEX idx_budget_accounts_account_id ON public.budget_accounts(account_id);

-- ============================================================================
-- Budget Line Items Table
-- ============================================================================
-- Category or subcategory-level budget amounts within a budget
CREATE TABLE IF NOT EXISTS public.budget_line_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id UUID NOT NULL REFERENCES public.budgets(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
    subcategory_id UUID REFERENCES public.subcategories(id) ON DELETE CASCADE,
    amount NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (amount >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.budget_line_items ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.budget_line_items TO authenticated;

CREATE POLICY "Users can manage own budget line items"
    ON public.budget_line_items FOR ALL
    USING (
        budget_id IN (
            SELECT id FROM public.budgets WHERE user_id = (SELECT auth.uid())
        )
    );

-- Unique: one line item per category per budget (where not subcategory-level)
CREATE UNIQUE INDEX idx_budget_line_items_category
    ON public.budget_line_items(budget_id, category_id)
    WHERE subcategory_id IS NULL;

-- Unique: one line item per subcategory per budget
CREATE UNIQUE INDEX idx_budget_line_items_subcategory
    ON public.budget_line_items(budget_id, subcategory_id)
    WHERE subcategory_id IS NOT NULL;

CREATE INDEX idx_budget_line_items_budget_id ON public.budget_line_items(budget_id);
CREATE INDEX idx_budget_line_items_category_id ON public.budget_line_items(category_id);

CREATE TRIGGER budget_line_items_updated_at
    BEFORE UPDATE ON public.budget_line_items
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- Budget Months Table
-- ============================================================================
-- Assign a specific budget to a specific month (override default)
CREATE TABLE IF NOT EXISTS public.budget_months (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id UUID NOT NULL REFERENCES public.budgets(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    month DATE NOT NULL,   -- stored as YYYY-MM-01
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- One budget per month per user
    UNIQUE(user_id, month)
);

ALTER TABLE public.budget_months ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, DELETE ON public.budget_months TO authenticated;

CREATE POLICY "Users can manage own budget months"
    ON public.budget_months FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE INDEX idx_budget_months_user_month ON public.budget_months(user_id, month DESC);
CREATE INDEX idx_budget_months_budget_id ON public.budget_months(budget_id);

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
    categorization_source TEXT NOT NULL DEFAULT 'uncategorized'
        CHECK (categorization_source IN ('ai', 'rule', 'manual', 'uncategorized')),

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
-- Batch Update Function (must be after simplefin_transactions table)
-- ============================================================================
-- Function for batch updating transaction categories
-- Updates category_id, subcategory_id, and categorization_source for multiple transactions in ONE query
CREATE OR REPLACE FUNCTION public.batch_update_transaction_categories(
    transaction_ids UUID[],
    category_ids UUID[],
    subcategory_ids UUID[],
    categorization_sources TEXT[] DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    -- Update transactions using unnest to join arrays
    WITH updates AS (
        SELECT
            unnest(transaction_ids) AS id,
            unnest(category_ids) AS category_id,
            unnest(subcategory_ids) AS subcategory_id,
            CASE
                WHEN categorization_sources IS NOT NULL
                THEN unnest(categorization_sources)
                ELSE 'ai'
            END AS categorization_source
    )
    UPDATE public.simplefin_transactions t
    SET
        category_id = u.category_id,
        subcategory_id = u.subcategory_id,
        categorization_source = u.categorization_source,
        updated_at = NOW()
    FROM updates u
    WHERE t.id = u.id;

    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

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
-- Transactions View (for API consumption)
-- ============================================================================
-- Creates a view that joins transactions with accounts to provide all needed fields
-- for the TransactionResponse schema
CREATE OR REPLACE VIEW public.transactions_view
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
    t.categorization_source,
    t.created_at,
    t.updated_at
FROM public.simplefin_transactions t
JOIN public.simplefin_accounts a ON t.simplefin_account_id = a.id;

-- CRITICAL SECURITY: security_invoker = true ensures the view runs with the
-- caller's permissions, not the view creator's permissions. This makes RLS
-- policies from simplefin_transactions and simplefin_accounts apply properly.
-- Without this, the view would bypass RLS and expose all users' data!

-- ============================================================================
-- Goals Table
-- ============================================================================
-- Financial targets: savings goals or debt payoff goals
-- Progress tracked via account_balance_history × allocation_percentage
CREATE TABLE IF NOT EXISTS public.goals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    goal_type TEXT NOT NULL DEFAULT 'savings' CHECK (goal_type IN ('savings', 'debt_payment')),
    target_amount NUMERIC(12, 2) NOT NULL CHECK (target_amount > 0),
    target_date DATE,
    is_completed BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.goals TO authenticated;

CREATE POLICY "Users can manage own goals"
    ON public.goals FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE INDEX idx_goals_user_id ON public.goals(user_id);
CREATE INDEX idx_goals_user_type ON public.goals(user_id, goal_type);

CREATE TRIGGER goals_updated_at
    BEFORE UPDATE ON public.goals
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- Goal Accounts Table
-- ============================================================================
-- Links goals to specific accounts with an allocation percentage
-- e.g., 50% of "Chase Savings" goes toward "Emergency Fund" goal
CREATE TABLE IF NOT EXISTS public.goal_accounts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    goal_id UUID NOT NULL REFERENCES public.goals(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    simplefin_account_id UUID NOT NULL REFERENCES public.simplefin_accounts(id) ON DELETE CASCADE,
    -- savings goals: % of account balance attributed to this goal (e.g. 50%)
    -- debt_payment goals: always 100 (whole account), not shown in UI
    allocation_percentage NUMERIC(5, 2) NOT NULL DEFAULT 100 CHECK (allocation_percentage > 0 AND allocation_percentage <= 100),
    -- debt_payment goals: balance at goal creation time, used to compute amount paid off
    starting_balance NUMERIC(12, 2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(goal_id, simplefin_account_id)
);

ALTER TABLE public.goal_accounts ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.goal_accounts TO authenticated;

CREATE POLICY "Users can manage own goal accounts"
    ON public.goal_accounts FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE INDEX idx_goal_accounts_goal_id ON public.goal_accounts(goal_id);
CREATE INDEX idx_goal_accounts_user_id ON public.goal_accounts(user_id);
CREATE INDEX idx_goal_accounts_account_id ON public.goal_accounts(simplefin_account_id);

CREATE TRIGGER goal_accounts_updated_at
    BEFORE UPDATE ON public.goal_accounts
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
