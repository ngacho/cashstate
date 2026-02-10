# CashState Backend

Budget tracking with Plaid-powered financial data syncing.

## Tech Stack

- **Framework**: FastAPI (Python 3.11+)
- **Database**: Supabase (PostgreSQL)
- **Auth**: Supabase Auth (JWT-based)
- **Financial Data**: Plaid API
- **Package Manager**: uv

## Prerequisites

- Python 3.11+
- [uv](https://docs.astral.sh/uv/) - Fast Python package manager
- A [Supabase](https://supabase.com) project
- A [Plaid](https://plaid.com) account (sandbox is free)

### Install uv

```bash
# macOS/Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Or with Homebrew
brew install uv
```

## Setup

### 1. Install Dependencies

```bash
uv sync
```

### 2. Configure Environment

Copy `.env.example` to `.env` and fill in your credentials:

```bash
cp .env.example .env
```

Required variables:
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_SECRET_KEY` - Secret API key (`sb_secret_...`) from Project Settings > API
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key (`sb_service_role_...`) from Project Settings > API
- `SUPABASE_PUBLISHABLE_KEY` - Publishable API key (`sb_publishable_...`) from Project Settings > API
- `PLAID_CLIENT_ID` - From Plaid Dashboard > Keys
- `PLAID_SECRET` - From Plaid Dashboard > Keys
- `PLAID_ENV` - `sandbox`, `development`, or `production`
- `ENCRYPTION_KEY` - Fernet encryption key (generate with: `python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"`)

### 3. Set Up Database

Run the migration SQL in your Supabase SQL Editor:

1. Go to Supabase Dashboard > SQL Editor
2. Copy contents of `supabase/migrations/001_initial_schema.sql`
3. Execute the SQL

This creates the `users`, `plaid_items`, `transactions`, and `sync_jobs` tables with RLS policies.

### 4. Activate Virtual Environment (Optional)

```bash
source .venv/bin/activate
```

Or let `uv` handle it automatically with `uv run` commands.

### 5. Run the Server

```bash
uv run uvicorn app.main:app --reload
```

API available at `http://localhost:8000`

## Quick Start (All Steps)

```bash
# 1. Install dependencies
uv sync

# 2. Configure environment
cp .env.example .env
# Edit .env with your Supabase + Plaid credentials

# 3. Generate encryption key
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
# Add the output to .env as ENCRYPTION_KEY

# 4. Set up database (run supabase/migrations/001_initial_schema.sql in Supabase SQL Editor)

# 5. Run server
uv run uvicorn app.main:app --reload

# Or activate venv first, then run without uv
source .venv/bin/activate
uvicorn app.main:app --reload
```

## API Documentation

- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## API Endpoints

Base URL: `/app/v1`

### Authentication
- `POST /auth/register` - Register new user
- `POST /auth/login` - Login
- `POST /auth/refresh` - Refresh token

### Plaid
- `POST /plaid/create-link-token` - Create Plaid Link token for frontend
- `POST /plaid/exchange-token` - Exchange public token, store Plaid item
- `GET /plaid/items` - List connected institutions

### Sync
- `POST /sync/trigger` - Sync all connected accounts
- `POST /sync/trigger/{item_id}` - Sync a specific account
- `GET /sync/status` - List sync jobs
- `GET /sync/status/{job_id}` - Get sync job details

### Transactions
- `GET /transactions` - List transactions (with date filters, pagination)
- `GET /transactions/{id}` - Get single transaction

## Testing

The integration test runs the full Plaid flow against the sandbox — no Link UI needed.

### Prerequisites

1. Complete the [Setup](#setup) steps (database migration, `.env` configured)
2. Add test user credentials to `.env`:
   ```
   TEST_USER_EMAIL=your-email@example.com
   TEST_USER_PASSWORD=password
   ```
3. `PLAID_ENV` must be `sandbox`

### Run all tests

```bash
uv run pytest tests/test_complete_run.py -v -s
```

### Run tests and stop at first failure

```bash
uv run pytest tests/test_complete_run.py -v -s -x
```

### Run specific tests

```bash
# Single test
uv run pytest tests/test_complete_run.py::TestCompletePlaidFlow::test_01_login -v -s

# Multiple tests (note: later tests depend on earlier ones for shared state)
uv run pytest tests/test_complete_run.py -v -s -k "test_01 or test_02 or test_03"
```

**Flags:**
- `-v` — verbose output (shows each test name)
- `-s` — shows print output so you can see transaction details as each step runs
- `-x` — stop at first failure
- `-k "expr"` — run only tests matching the expression

### What the test does

1. Logs in (or registers) the test user
2. Creates a sandbox public token via Plaid SDK (bypasses Link UI)
3. Exchanges it through `POST /plaid/exchange-token`
4. Triggers a transaction sync via `POST /sync/trigger/{item_id}`
5. Verifies sync job completed with transactions added
6. Fetches and validates transactions via `GET /transactions`
7. Tests single transaction fetch and date filtering
8. Triggers a sync-all via `POST /sync/trigger`

## Project Structure

```
cashstate-backend/
├── app/
│   ├── main.py           # FastAPI app
│   ├── config.py         # Settings (Supabase + Plaid)
│   ├── database.py       # Supabase client + Database class
│   ├── dependencies.py   # Auth + DB dependency injection
│   ├── schemas/          # Request/response models
│   │   ├── auth.py
│   │   ├── common.py
│   │   ├── plaid.py
│   │   ├── sync.py
│   │   └── transaction.py
│   ├── routers/          # API routes
│   │   ├── auth.py
│   │   ├── plaid.py
│   │   ├── sync.py
│   │   └── transactions.py
│   ├── services/         # Business logic
│   │   ├── auth_service.py
│   │   ├── plaid_service.py
│   │   └── sync_service.py
│   └── utils/
├── supabase/
│   └── migrations/
│       └── 001_initial_schema.sql
├── pyproject.toml
├── uv.lock
└── .env.example
```
