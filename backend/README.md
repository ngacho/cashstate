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

### 3. Set Up Database

Run the migration SQL file in your Supabase SQL Editor:

1. Go to Supabase Dashboard > SQL Editor
2. Copy contents of `supabase/migrations/001_simplefin_schema.sql` and execute

This creates the following tables with RLS policies:
- `simplefin_items` - SimpleFin connections (encrypted access URLs)
- `simplefin_accounts` - Account details with balances and institution info
- `simplefin_transactions` - Transactions with all SimpleFin fields
- `simplefin_sync_jobs` - Sync operation tracking

**Note:** This migration assumes the `users` table exists (created by Supabase Auth). If you need Plaid integration, see the Plaid migration files.

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
│   │   ├── common.py
│   │   ├── plaid.py
│   │   ├── simplefin.py
│   │   ├── sync.py
│   │   └── transaction.py
│   ├── routers/          # API routes
│   │   ├── auth.py
│   │   ├── plaid.py
│   │   ├── simplefin.py
│   │   ├── sync.py
│   │   └── transactions.py
│   ├── services/         # Business logic
│   │   ├── auth_service.py
│   │   ├── plaid_service.py
│   │   ├── simplefin_service.py
│   │   └── sync_service.py
│   └── utils/
│       └── encryption.py   # Fernet encryption for sensitive tokens
│   └── utils/
├── supabase/
│   └── migrations/
│       └── 001_simplefin_schema.sql
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
