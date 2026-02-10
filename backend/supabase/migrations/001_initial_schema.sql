-- CashState initial schema

-- Users table (extends Supabase auth.users)
create table if not exists public.users (
    id uuid primary key references auth.users(id) on delete cascade,
    email text not null,
    display_name text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.users enable row level security;

-- Grant table-level permissions to authenticated users
grant select, insert, update on public.users to authenticated;

create policy "Users can read own profile"
    on public.users for select
    using ((select auth.uid()) = id);

create policy "Users can insert own profile"
    on public.users for insert
    with check ((select auth.uid()) = id);

create policy "Users can update own profile"
    on public.users for update
    using ((select auth.uid()) = id);

-- Plaid items table
create table if not exists public.plaid_items (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    plaid_item_id text not null unique,
    access_token text not null,
    institution_id text,
    institution_name text,
    status text not null default 'active' check (status in ('active', 'inactive', 'error')),
    cursor text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.plaid_items enable row level security;

-- Grant table-level permissions to authenticated users
grant select, insert, update on public.plaid_items to authenticated;

create policy "Users can read own plaid items"
    on public.plaid_items for select
    using ((select auth.uid()) = user_id);

create policy "Users can insert own plaid items"
    on public.plaid_items for insert
    with check ((select auth.uid()) = user_id);

create policy "Users can update own plaid items"
    on public.plaid_items for update
    using ((select auth.uid()) = user_id);

create index idx_plaid_items_user_id on public.plaid_items(user_id);
create index idx_plaid_items_status on public.plaid_items(status);

-- Transactions table
create table if not exists public.transactions (
    id uuid primary key default gen_random_uuid(),
    plaid_item_id uuid not null references public.plaid_items(id) on delete cascade,
    plaid_transaction_id text not null unique,
    account_id text not null,
    amount numeric(12, 2) not null,
    iso_currency_code text,
    date date not null,
    name text not null,
    merchant_name text,
    category jsonb,
    pending boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.transactions enable row level security;

-- Grant table-level permissions to authenticated users
grant select, insert, update, delete on public.transactions to authenticated;

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

create index idx_transactions_plaid_item_id on public.transactions(plaid_item_id);
create index idx_transactions_date on public.transactions(date desc);
create index idx_transactions_plaid_transaction_id on public.transactions(plaid_transaction_id);

-- Sync jobs table
create table if not exists public.sync_jobs (
    id uuid primary key default gen_random_uuid(),
    plaid_item_id uuid not null references public.plaid_items(id) on delete cascade,
    status text not null default 'pending' check (status in ('pending', 'in_progress', 'completed', 'failed')),
    started_at timestamptz,
    completed_at timestamptz,
    error_message text,
    transactions_added integer not null default 0,
    transactions_modified integer not null default 0,
    transactions_removed integer not null default 0,
    created_at timestamptz not null default now()
);

alter table public.sync_jobs enable row level security;

-- Grant table-level permissions to authenticated users
grant select, insert, update on public.sync_jobs to authenticated;

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

create index idx_sync_jobs_plaid_item_id on public.sync_jobs(plaid_item_id);
create index idx_sync_jobs_created_at on public.sync_jobs(created_at desc);

-- Auto-update updated_at timestamps
create or replace function public.handle_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

create trigger users_updated_at
    before update on public.users
    for each row execute function public.handle_updated_at();

create trigger plaid_items_updated_at
    before update on public.plaid_items
    for each row execute function public.handle_updated_at();

create trigger transactions_updated_at
    before update on public.transactions
    for each row execute function public.handle_updated_at();
