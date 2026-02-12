-- CashState - SimpleFin-Optimized Schema
-- Clean implementation designed specifically for SimpleFin's data structure
-- Run this after ensuring users table exists

-- ============================================================================
-- SimpleFin Items Table (Connection/Credential Storage)
-- ============================================================================
-- Stores the encrypted access URL for each SimpleFin connection

create table if not exists public.simplefin_items (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    access_url text not null,  -- Encrypted SimpleFin access URL (contains embedded credentials)
    institution_name text,     -- User-provided name for this connection
    status text not null default 'active' check (status in ('active', 'inactive', 'error')),
    last_synced_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.simplefin_items enable row level security;
grant select, insert, update, delete on public.simplefin_items to authenticated;

create policy "Users can manage own simplefin items"
    on public.simplefin_items for all
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);

create index idx_simplefin_items_user_id on public.simplefin_items(user_id);
create index idx_simplefin_items_status on public.simplefin_items(status);

-- ============================================================================
-- SimpleFin Accounts Table
-- ============================================================================
-- Stores account-level data from SimpleFin (balance, institution, etc.)
-- SimpleFin returns this data in each sync response

create table if not exists public.simplefin_accounts (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    simplefin_item_id uuid not null references public.simplefin_items(id) on delete cascade,
    simplefin_account_id text not null,  -- SimpleFin's account ID (e.g., "ACT-xxx")

    -- Account details
    name text not null,                   -- e.g., "credit (2537)"
    currency text not null default 'USD',

    -- Balance info (updated on each sync)
    balance numeric(15, 2),               -- Current balance (negative for credit cards in debt)
    available_balance numeric(15, 2),    -- Available balance
    balance_date bigint,                  -- Unix timestamp when balance was last updated

    -- Organization/Institution info from SimpleFin
    organization_name text,               -- e.g., "Bank of America"
    organization_domain text,             -- e.g., "www.bankofamerica.com"
    organization_sfin_url text,           -- SimpleFin bridge URL

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    -- Ensure we don't duplicate accounts per user
    unique(user_id, simplefin_item_id, simplefin_account_id)
);

alter table public.simplefin_accounts enable row level security;
grant select, insert, update, delete on public.simplefin_accounts to authenticated;

create policy "Users can manage own simplefin accounts"
    on public.simplefin_accounts for all
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);

create index idx_simplefin_accounts_user_id on public.simplefin_accounts(user_id);
create index idx_simplefin_accounts_item_id on public.simplefin_accounts(simplefin_item_id);
create index idx_simplefin_accounts_account_id on public.simplefin_accounts(simplefin_account_id);

-- ============================================================================
-- SimpleFin Transactions Table
-- ============================================================================
-- Stores transaction data from SimpleFin with all available fields

create table if not exists public.simplefin_transactions (
    id uuid primary key default gen_random_uuid(),
    simplefin_account_id uuid not null references public.simplefin_accounts(id) on delete cascade,
    simplefin_transaction_id text not null unique,  -- SimpleFin's transaction ID (e.g., "TRN-xxx")

    -- Transaction details
    amount numeric(12, 2) not null,       -- Signed amount (negative = expense, positive = income)
    currency text not null default 'USD',

    -- Date fields (SimpleFin provides both)
    posted_date bigint not null,          -- Unix timestamp when transaction posted to account
    transaction_date bigint not null,     -- Unix timestamp when transaction actually occurred

    -- Description fields
    description text not null,            -- Raw merchant description from bank
    payee text,                           -- SimpleFin's cleaned-up merchant name
    memo text,                            -- Additional notes (often empty)

    -- SimpleFin only returns posted transactions
    pending boolean not null default false,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.simplefin_transactions enable row level security;
grant select, insert, update, delete on public.simplefin_transactions to authenticated;

create policy "Users can manage own simplefin transactions"
    on public.simplefin_transactions for all
    using (
        simplefin_account_id in (
            select id from public.simplefin_accounts where user_id = (select auth.uid())
        )
    )
    with check (
        simplefin_account_id in (
            select id from public.simplefin_accounts where user_id = (select auth.uid())
        )
    );

create index idx_simplefin_transactions_account_id on public.simplefin_transactions(simplefin_account_id);
create index idx_simplefin_transactions_transaction_id on public.simplefin_transactions(simplefin_transaction_id);
create index idx_simplefin_transactions_posted_date on public.simplefin_transactions(posted_date desc);
create index idx_simplefin_transactions_transaction_date on public.simplefin_transactions(transaction_date desc);
create index idx_simplefin_transactions_amount on public.simplefin_transactions(amount);

-- ============================================================================
-- SimpleFin Sync Jobs Table
-- ============================================================================
-- Tracks sync operations for monitoring and debugging

create table if not exists public.simplefin_sync_jobs (
    id uuid primary key default gen_random_uuid(),
    simplefin_item_id uuid not null references public.simplefin_items(id) on delete cascade,

    status text not null default 'pending' check (status in ('pending', 'running', 'completed', 'failed')),

    -- Sync results
    accounts_synced int not null default 0,
    transactions_added int not null default 0,
    transactions_updated int not null default 0,

    error_message text,
    created_at timestamptz not null default now(),
    completed_at timestamptz
);

alter table public.simplefin_sync_jobs enable row level security;
grant select, insert, update, delete on public.simplefin_sync_jobs to authenticated;

create policy "Users can manage own simplefin sync jobs"
    on public.simplefin_sync_jobs for all
    using (
        simplefin_item_id in (
            select id from public.simplefin_items where user_id = (select auth.uid())
        )
    )
    with check (
        simplefin_item_id in (
            select id from public.simplefin_items where user_id = (select auth.uid())
        )
    );

create index idx_simplefin_sync_jobs_item_id on public.simplefin_sync_jobs(simplefin_item_id);
create index idx_simplefin_sync_jobs_status on public.simplefin_sync_jobs(status);
create index idx_simplefin_sync_jobs_created_at on public.simplefin_sync_jobs(created_at desc);

-- ============================================================================
-- Triggers for updated_at timestamps
-- ============================================================================

create trigger simplefin_items_updated_at
    before update on public.simplefin_items
    for each row execute function public.handle_updated_at();

create trigger simplefin_accounts_updated_at
    before update on public.simplefin_accounts
    for each row execute function public.handle_updated_at();

create trigger simplefin_transactions_updated_at
    before update on public.simplefin_transactions
    for each row execute function public.handle_updated_at();
