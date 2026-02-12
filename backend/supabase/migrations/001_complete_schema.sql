-- CashState - Complete Database Schema
-- SimpleFin + Daily Snapshots - All tables linked via user_id for simplicity
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
-- Net Snapshots Table (Overview Page - Overall Net Worth Tracking)
-- ============================================================================
-- Tracks overall net worth across all accounts for the overview/home page
CREATE TABLE IF NOT EXISTS public.net_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL,
    total_balance NUMERIC(12, 2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(user_id, snapshot_date)
);

ALTER TABLE public.net_snapshots ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.net_snapshots TO authenticated;

CREATE POLICY "Users can manage own user snapshots"
    ON public.net_snapshots FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE INDEX idx_net_snapshots_user_date ON public.net_snapshots(user_id, snapshot_date DESC);

CREATE TRIGGER net_snapshots_updated_at
    BEFORE UPDATE ON public.net_snapshots
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- Transaction Snapshots Table (Individual Account Page - Per-Account Balance History)
-- ============================================================================
-- Tracks balance history for each individual account for detail pages
CREATE TABLE IF NOT EXISTS public.transaction_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    simplefin_account_id UUID NOT NULL REFERENCES public.simplefin_accounts(id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL,
    balance NUMERIC(12, 2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(user_id, simplefin_account_id, snapshot_date)
);

ALTER TABLE public.transaction_snapshots ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.transaction_snapshots TO authenticated;

CREATE POLICY "Users can manage own account snapshots"
    ON public.transaction_snapshots FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE INDEX idx_transaction_snapshots_user_account_date ON public.transaction_snapshots(user_id, simplefin_account_id, snapshot_date DESC);
CREATE INDEX idx_transaction_snapshots_account_date ON public.transaction_snapshots(simplefin_account_id, snapshot_date DESC);

CREATE TRIGGER transaction_snapshots_updated_at
    BEFORE UPDATE ON public.transaction_snapshots
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
