# CashState Backend

Budget tracking with financial data syncing via Plaid and SimpleFin.

## Tech Stack

- **Framework**: FastAPI (Python 3.11+)
- **Database**: Supabase (PostgreSQL)
- **Auth**: Supabase Auth (JWT-based)
- **Financial Data**: Plaid API & SimpleFin Bridge
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
- `SIMPLEFIN_ACCESS_URL` (optional) - Pre-claimed SimpleFin access URL for development/testing

**AI Categorization (optional):**
- `CATEGORIZATION_PROVIDER` - Provider to use: `claude` (default) or `openrouter`
- `ANTHROPIC_API_KEY` - Anthropic API key for Claude AI categorization (required if provider=claude)
- `CLAUDE_MODEL` - Claude model (default: `claude-3-5-sonnet-20241022`)
- `OPENROUTER_API_KEY` - OpenRouter API key for cheaper categorization (required if provider=openrouter)
- `OPENROUTER_MODEL` - OpenRouter model (default: `meta-llama/llama-3.1-8b-instruct:free`)

### 3. Set Up Database

**NEW DATABASES:**
1. Go to Supabase Dashboard > SQL Editor
2. Run `supabase/migrations/001_complete_schema.sql`
3. Run `supabase/migrations/003_default_categories_and_budgets.sql`

**EXISTING DATABASES:**
1. Go to Supabase Dashboard > SQL Editor
2. Run `supabase/migrations/003_default_categories_and_budgets.sql`

This creates the following tables with RLS policies:
- `simplefin_items` - SimpleFin connections (encrypted access URLs)
- `simplefin_accounts` - Account details with balances and institution info
- `simplefin_transactions` - Transactions with all SimpleFin fields
- `simplefin_sync_jobs` - Sync operation tracking
- `account_balance_history` - Daily account balance snapshots for net worth tracking
- `categories` - Transaction categories (20 system defaults + user-custom)
- `subcategories` - Subcategories under parent categories (100+ defaults)
- `budgets` - User budget allocations per category

**Default Data Included:**
- 20 system categories (Income, Housing, Food, Shopping, etc.)
- 100+ subcategories (Rent, Groceries, Gas, Restaurants, etc.)
- Budget tracking structure

**Detailed Instructions:** See `supabase/migrations/MIGRATION_GUIDE.md`

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

# 4. Set up database (run migration in Supabase SQL Editor)
# - supabase/migrations/001_simplefin_schema.sql

# 5. Run server
uv run uvicorn app.main:app --reload

# Or activate venv first, then run without uv
source .venv/bin/activate
uvicorn app.main:app --reload
```

## AI Categorization Configuration

CashState supports two AI providers for automatic transaction categorization:

### Claude (Anthropic) - Production Recommended

Best accuracy and reliability using Claude 3.5 Sonnet.

```bash
# .env
CATEGORIZATION_PROVIDER=claude
ANTHROPIC_API_KEY=sk-ant-...
CLAUDE_MODEL=claude-3-5-sonnet-20241022  # Optional, this is the default
```

### OpenRouter - Budget-Friendly

Access to 300+ models including free options. Lower cost but may have reduced accuracy.

```bash
# .env
CATEGORIZATION_PROVIDER=openrouter
OPENROUTER_API_KEY=sk-or-...
OPENROUTER_MODEL=meta-llama/llama-3.1-8b-instruct:free  # Free tier model
# Or use Claude via OpenRouter: anthropic/claude-3.5-sonnet
```

**Get API Keys:**
- Claude: [console.anthropic.com](https://console.anthropic.com)
- OpenRouter: [openrouter.ai/settings/keys](https://openrouter.ai/settings/keys)

**Available OpenRouter Models:**
- Free: `meta-llama/llama-3.1-8b-instruct:free`, `google/gemma-2-9b-it:free`
- Paid (Claude via OpenRouter): `anthropic/claude-3.5-sonnet`
- See all models: [openrouter.ai/models](https://openrouter.ai/models)

### Categorize All Transactions

After setting up AI categorization, run all your transactions through the service:

**Option 1: Python Script (Recommended)**
```bash
# Make sure backend is running
uv run uvicorn app.main:app --reload

# In another terminal
cd backend
uv run python scripts/categorize_all_transactions.py
```

**Option 2: API Endpoint**
```bash
# Get access token first
curl -X POST http://localhost:8000/app/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "password"}'

# Categorize all transactions
curl -X POST http://localhost:8000/app/v1/categories/ai/categorize \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"force": true}'
```

**Option 3: Swagger UI**
1. Go to http://localhost:8000/docs
2. Authorize with your credentials
3. Use `POST /app/v1/categories/ai/categorize`
4. Request body: `{"force": true}`

**Note:** The service processes up to 200 transactions per request. For large datasets, you may need to run it multiple times or modify the limit in the service code.

## New User Onboarding

CashState provides a streamlined onboarding experience for new users to get started with budget tracking.

### Seed Default Categories

When a new user signs up, they can get started immediately with 20 comprehensive default categories and 100+ subcategories:

**Via API:**
```bash
curl -X POST http://localhost:8000/app/v1/categories/seed-defaults \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

**Via Swagger UI:**
1. Go to http://localhost:8000/docs
2. Authorize with your credentials
3. Use `POST /app/v1/categories/seed-defaults`

**Response:**
```json
{
  "message": "Seeded 20 categories and 107 subcategories"
}
```

**Default Categories Include:**
- **Income & Transfers** (2): Income, Transfers
- **Essential Expenses** (6): Housing, Transportation, Food & Dining, Utilities, Healthcare, Insurance
- **Lifestyle** (5): Shopping, Entertainment, Personal Care, Education, Subscriptions
- **Financial** (4): Savings & Investments, Debt Payments, Taxes, Fees & Charges
- **Other** (3): Gifts & Donations, Travel, Business Expenses
- **Uncategorized** (1): Default for uncategorized transactions

Each category includes relevant subcategories (e.g., Food & Dining → Groceries, Restaurants, Coffee Shops, etc.).

**iOS Integration:**
The iOS app automatically detects when users have no categories and presents an onboarding screen with:
- "Use Default Categories" button (one-click setup)
- "Create Custom Category" button (manual setup)

See [`ONBOARDING_COMPLETE.md`](../ONBOARDING_COMPLETE.md) for full details.

## Documentation

- **API Docs (Swagger UI)**: `http://localhost:8000/docs`
- **API Docs (ReDoc)**: `http://localhost:8000/redoc`
- **SimpleFin Integration Guide**: [`SIMPLEFIN_INTEGRATION_GUIDE.md`](./SIMPLEFIN_INTEGRATION_GUIDE.md) - Complete SimpleFin setup, architecture, and API reference

## API Endpoints

Base URL: `/app/v1`

### Authentication
- `POST /auth/register` - Register new user
- `POST /auth/login` - Login
- `POST /auth/refresh` - Refresh token

### Plaid
- `POST /plaid/create-link-token` - Create Plaid Link token for frontend
- `POST /plaid/exchange-token` - Exchange public token, store Plaid item
- `GET /plaid/items` - List connected Plaid institutions

### SimpleFin
- `POST /simplefin/setup` - Exchange SimpleFin setup token for access URL
- `GET /simplefin/items` - List connected SimpleFin institutions
- `DELETE /simplefin/items/{item_id}` - Delete a SimpleFin connection (cascades to accounts & transactions)
- `GET /simplefin/accounts/{item_id}` - List stored accounts for an item (with balances)
- `GET /simplefin/transactions` - List all SimpleFin transactions (with filters)
- `POST /simplefin/sync/{item_id}` - Sync accounts and transactions from SimpleFin
- `GET /simplefin/raw-accounts/{item_id}` - Fetch raw SimpleFin API response (debug/preview)

### Sync
- `POST /sync/trigger` - Sync all connected accounts
- `POST /sync/trigger/{item_id}` - Sync a specific account
- `GET /sync/status` - List sync jobs
- `GET /sync/status/{job_id}` - Get sync job details

### Transactions
- `GET /transactions` - List transactions (with date filters, pagination)
- `GET /transactions/{id}` - Get single transaction

### Categories & AI Categorization
- `POST /categories/seed-defaults` - **NEW!** Seed default categories for new users (one-time setup)
- `GET /categories` - List all categories (system + user's own)
- `GET /categories/tree` - Get categories with nested subcategories
- `POST /categories` - Create a new user category
- `GET /categories/{id}` - Get category details
- `PATCH /categories/{id}` - Update a user category
- `DELETE /categories/{id}` - Delete a user category
- `GET /categories/{id}/subcategories` - List subcategories for a category
- `POST /categories/{id}/subcategories` - Create a new subcategory
- `GET /categories/subcategories/{id}` - Get subcategory details
- `PATCH /categories/subcategories/{id}` - Update a subcategory
- `DELETE /categories/subcategories/{id}` - Delete a subcategory
- `POST /categories/ai/categorize` - Categorize transactions using Claude AI

### Budgets
- `GET /budgets` - List all budgets for the user (optional query param: `category_id`)
- `POST /budgets` - Create a new budget
- `PATCH /budgets/{id}` - Update a budget
- `DELETE /budgets/{id}` - Delete a budget

## Linting

Flake8 with Google Python Style Guide:

```bash
# Run linter
uv run flake8 app/

# Run linter with auto-fix suggestions
uv run flake8 app/ --show-source
```

Configuration: `.flake8` (Google style, 88 char line length)

## Testing

Integration tests for both Plaid and SimpleFin flows.

### Prerequisites

1. Complete the [Setup](#setup) steps (database migrations, `.env` configured)
2. Add test user credentials to `.env`:
   ```
   TEST_USER_EMAIL=your-email@example.com
   TEST_USER_PASSWORD=password
   ```
3. For Plaid tests: `PLAID_ENV` must be `sandbox`
4. For real SimpleFin integration tests: Add `SIMPLEFIN_TOKEN` or `SIMPLEFIN_ACCESS_URL` to `.env`

### Run all tests

```bash
# Run all tests (Plaid + SimpleFin)
uv run pytest tests/ -v -s

# Run only Plaid tests
uv run pytest tests/test_complete_run.py -v -s

# Run only SimpleFin tests (mocked - no real SimpleFin account needed)
uv run pytest tests/test_simplefin_flow.py -v -s

# Run SimpleFin integration tests (requires real SimpleFin setup token)
uv run pytest tests/test_complete_simplefin.py -v -s
```

### Run tests and stop at first failure

```bash
uv run pytest tests/ -v -s -x
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

### Plaid Test Flow (`test_complete_run.py`)

1. Logs in (or registers) the test user
2. Creates a sandbox public token via Plaid SDK (bypasses Link UI)
3. Exchanges it through `POST /plaid/exchange-token`
4. Triggers a transaction sync via `POST /sync/trigger/{item_id}`
5. Verifies sync job completed with transactions added
6. Fetches and validates transactions via `GET /transactions`
7. Tests single transaction fetch and date filtering
8. Triggers a sync-all via `POST /sync/trigger`

### SimpleFin Test Flow (Mocked - `test_simplefin_flow.py`)

Uses mocked SimpleFin API responses (no real SimpleFin account needed):

1. Logs in (or registers) the test user
2. Exchanges SimpleFin setup token via `POST /simplefin/setup` (mocked)
3. Lists SimpleFin items via `GET /simplefin/items`
4. Fetches raw account data via `GET /simplefin/accounts/{item_id}` (mocked)
5. Triggers transaction sync via `POST /simplefin/sync/{item_id}` (mocked)
6. Verifies sync job completed with transactions
7. Fetches and validates transactions (mixed Plaid + SimpleFin)
8. Tests single transaction fetch and date filtering
9. Deletes SimpleFin item via `DELETE /simplefin/items/{item_id}`
10. Verifies transactions were cascaded on delete

### SimpleFin Integration Test (Real API - `test_complete_simplefin.py`)

Tests the complete SimpleFin flow with a real SimpleFin account:

1. Logs in (or registers) the test user
2. Health check
3. Exchanges SimpleFin setup token via `POST /simplefin/setup` (real API)
4. Verifies SimpleFin item stored in DB
5. Syncs accounts and transactions from 2025-12-31 via `POST /simplefin/sync/{item_id}`
6. Lists and verifies accounts saved via `GET /simplefin/accounts/{item_id}`
7. Lists and verifies transactions saved via `GET /simplefin/transactions`

**Prerequisites for real SimpleFin tests:**
- Add `SIMPLEFIN_TOKEN` or `SIMPLEFIN_ACCESS_URL` to `.env`
- Get a setup token from [SimpleFin Bridge](https://beta-bridge.simplefin.org)
- Setup tokens can only be claimed once (save the access URL for reuse)

## Raspberry Pi Deployment

### Important: Activate Environment First

Due to package conflicts (mmh3, httptools) on ARM devices, **activate the virtual environment** before running commands:

```bash
cd ~/cashstate/backend
source .venv/bin/activate

# Now run uvicorn directly (not with 'uv run')
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Running Backend in Background

**Quick Start (using &):**
```bash
cd ~/cashstate/backend
source .venv/bin/activate
uvicorn app.main:app --port 8000 &
```

**With Logging (nohup - persists after logout):**
```bash
cd ~/cashstate/backend
source .venv/bin/activate
nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/cashstate.log 2>&1 &
```

> **Note:** Using `&` runs in background but stops when terminal closes. Using `nohup` keeps it running after logout. For persistent service, use systemd (see below).

### Check if Running

```bash
# Check if backend is running
ps aux | grep "[u]vicorn" && echo "✅ Backend is running" || echo "❌ Backend not running"

# Check if API is responding
curl -s http://localhost:8000/health && echo "✅ API responding" || echo "❌ API not responding"

# Check what's using port 8000 (requires lsof)
sudo lsof -i :8000

# Or with netstat
sudo netstat -tulpn | grep :8000
```

### View Logs

```bash
# View nohup logs
tail -f /tmp/cashstate.log

# Or if using systemd
sudo journalctl -u cashstate -f
```

### Stop Backend

```bash
# Kill uvicorn process (simplest)
pkill uvicorn

# Or force kill
pkill -9 uvicorn

# Or find PID and kill
ps aux | grep uvicorn  # Find PID
kill <PID>

# With lsof (if installed)
sudo kill $(sudo lsof -ti :8000)

# With fuser
sudo fuser -k 8000/tcp
```

### Production Setup (systemd)

**Create Service File:**
```bash
sudo nano /etc/systemd/system/cashstate.service
```

**Add Configuration:**
```ini
[Unit]
Description=CashState Backend API
After=network.target

[Service]
Type=simple
User=ngacho
WorkingDirectory=/home/ngacho/cashstate/backend
Environment="PATH=/home/ngacho/cashstate/backend/.venv/bin:/home/ngacho/.cargo/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/home/ngacho/cashstate/backend/.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Note:** Update `User=ngacho` and paths to match your username and installation directory.

**Manage Service:**
```bash
# Reload systemd
sudo systemctl daemon-reload

# Start service
sudo systemctl start cashstate

# Enable auto-start on boot
sudo systemctl enable cashstate

# Check status
sudo systemctl status cashstate

# View logs
sudo journalctl -u cashstate -f

# Restart service
sudo systemctl restart cashstate

# Stop service
sudo systemctl stop cashstate
```

### Access from Other Devices

```bash
# Find Raspberry Pi IP address
hostname -I

# Backend will be available at:
# http://<PI_IP>:8000

# Update iOS app Config.swift with:
# static let backendURL = "http://<PI_IP>:8000"
```

### Monitoring & Maintenance

```bash
# Check all running processes (install htop first: sudo apt-get install htop)
htop  # Press F4 and type "uvicorn" to filter

# Check memory/CPU usage
ps aux | grep uvicorn

# Check disk space
df -h

# View all background jobs
jobs -l

# Check cron job logs (if enabled)
sudo journalctl -u cashstate -f | grep CRON
```

### Quick Restart

```bash
# Kill old, start new with nohup
pkill uvicorn
cd ~/cashstate/backend
source .venv/bin/activate
nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/cashstate.log 2>&1 &
```

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
│   │   ├── budget.py
│   │   ├── category.py
│   │   ├── common.py
│   │   ├── plaid.py
│   │   ├── simplefin.py
│   │   ├── sync.py
│   │   └── transaction.py
│   ├── routers/          # API routes
│   │   ├── auth.py
│   │   ├── budgets.py
│   │   ├── categories.py
│   │   ├── plaid.py
│   │   ├── simplefin.py
│   │   ├── snapshots.py
│   │   ├── sync.py
│   │   └── transactions.py
│   ├── services/         # Business logic
│   │   ├── auth_service.py
│   │   ├── categorization_service.py
│   │   ├── plaid_service.py
│   │   ├── simplefin_service.py
│   │   └── sync_service.py
│   └── utils/
│       └── encryption.py   # Fernet encryption for sensitive tokens
│   └── utils/
├── supabase/
│   └── migrations/
│       ├── 001_complete_schema.sql     # Full schema (for new databases)
│       ├── 002_add_categories.sql      # Add categories (for existing databases)
│       └── README.md                    # Migration instructions
├── tests/
│   ├── conftest.py                 # Pytest configuration
│   ├── test_complete_run.py        # Plaid integration tests (real sandbox)
│   ├── test_simplefin_flow.py      # SimpleFin tests (mocked responses)
│   └── test_complete_simplefin.py  # SimpleFin integration tests (real API)
├── SIMPLEFIN_INTEGRATION_GUIDE.md  # Complete SimpleFin documentation
├── pyproject.toml
├── uv.lock
└── .env.example
```
