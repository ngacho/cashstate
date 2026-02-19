# CashState

Personal finance tracker with bank sync via SimpleFin, budget management, goals, and AI transaction categorization.

**Stack:** Convex (backend) + SwiftUI (iOS)

## Prerequisites

- [Node.js](https://nodejs.org/) 18+
- Xcode 15+ (for iOS, iOS 17+ target)
- A [SimpleFin](https://beta-bridge.simplefin.org) account (for bank sync)
- (Optional) [OpenRouter](https://openrouter.ai) API key (for AI categorization)

## Quick Start

### 1. Set up Convex backend

```bash
npm init
npx convex dev
```

On first run, Convex CLI will prompt you to create a project. Follow the prompts — the schema deploys automatically.

### 2. Configure environment variables

```bash
# From the project root
cp .env.example .env
```

Edit `.env` and fill in your values:

| Variable | Required | Description |
|---|---|---|
| `SIMPLEFIN_BASE_URL` | No | Defaults to `https://beta-bridge.simplefin.org` |
| `OPENROUTER_API_KEY` | No | For AI transaction categorization |
| `OPENROUTER_MODEL` | No | Defaults to `meta-llama/llama-3.1-8b-instruct:free` |
| `ENCRYPTION_KEY` | **Yes** | For encrypting SimpleFin access URLs. Generate: `openssl rand -base64 32` |

Push env vars to Convex:

```bash
chmod +x scripts/push-convex-env.sh
./scripts/push-convex-env.sh
```

Or set them individually:

```bash
cd convex
npx convex env set ENCRYPTION_KEY "$(openssl rand -base64 32)"
npx convex env set OPENROUTER_API_KEY "sk-or-..."
```

### 3. Configure iOS app

Edit `ios/CashState/Config.swift` and set your Convex deployment URL:

```swift
static let convexURL = "https://YOUR-DEPLOYMENT.convex.cloud"
```

Find your deployment URL at: [Convex Dashboard](https://dashboard.convex.dev) > your project > Settings

### 4. Run iOS app

```bash
open ios/CashState.xcodeproj
# Select target device/simulator → Cmd+R
```

## Auth (Dev Mode)

The app uses a **naive dev auth** system (`devUsers` table with plaintext username/password). This is for development/testing only.

- **Register**: enter any username + password on the login screen and tap "Create Account"
- **Login**: use the same credentials
- The userId is stored in UserDefaults and auto-injected into every Convex call

**For production:** Replace with [Clerk](https://clerk.com):
1. Add Clerk iOS SDK via SPM
2. Configure `convex/auth.config.ts` with your Clerk issuer URL
3. Swap `getUserId(args)` calls in Convex functions → `ctx.auth.getUserIdentity()`

## Project Structure

```
convex/                         # Convex backend
├── schema.ts                   # Database schema (13 tables)
├── devAuth.ts                  # Dev-only auth (register/login)
├── helpers.ts                  # Shared getUserId() helper
├── transactions.ts             # Transaction queries (paginated)
├── categories.ts               # Categories CRUD + rules + seedDefaults
├── budgets.ts                  # Budgets CRUD + summary + line items
├── goals.ts                    # Goals CRUD with progress tracking
├── accounts.ts                 # SimpleFin items/accounts + disconnect
├── snapshots.ts                # Balance history snapshots
├── crons.ts                    # Daily sync + daily snapshot cron jobs
└── actions/
    ├── simplefinSync.ts        # SimpleFin API sync (Node action)
    └── aiCategorize.ts         # AI categorization via OpenRouter

ios/CashState/                  # SwiftUI iOS app
├── Config.swift                # Convex URL config
├── APIClient.swift             # Convex HTTP API client (auto-injects userId)
├── ContentView.swift           # Auth routing (login vs main)
├── LoginView.swift             # Dev auth login/register
├── MainView.swift              # Tab bar + transactions + insights + accounts
├── HomeView.swift              # Dashboard overview
├── BudgetView.swift            # Budget management
├── GoalsView.swift             # Goals tracking
├── Models.swift                # Data models (Transaction, Account, etc.)
├── CategoryModels.swift        # Category/Subcategory models
├── BudgetModels.swift          # Budget models
└── Theme.swift                 # Design system (colors, spacing)

scripts/
└── push-convex-env.sh          # Push .env to Convex environment
```

## Common Commands

```bash
# Start Convex dev server (watches for changes, auto-deploys)
cd convex && npx convex dev

# Push env vars from .env to Convex
./scripts/push-convex-env.sh

# Set a single env var
cd convex && npx convex env set KEY value

# Open Convex dashboard
cd convex && npx convex dashboard

# Deploy to production
cd convex && npx convex deploy
```

## Features

- **Bank Sync**: Connect banks via SimpleFin, auto-sync transactions daily (2 AM UTC cron)
- **Budgets**: Create budgets with category line items, track spending vs budget per month
- **Goals**: Savings and debt payment goals linked to accounts with progress tracking
- **Categories**: 10 default categories with subcategories, custom categories, auto-categorization rules
- **AI Categorization**: Rules-first pipeline (substring match), then OpenRouter AI for uncategorized
- **Net Worth Snapshots**: Daily balance snapshots (11:55 PM UTC cron) with historical charts
- **Pagination**: Cursor-based pagination for transaction lists

## End-to-End Flow

1. Register/Login on the iOS app
2. Go to Settings tab → Connect SimpleFin (paste your claim URL)
3. Sync will run automatically, pulling accounts + transactions
4. Categories are seeded on first budget creation (via `seedDefaults`)
5. Create budgets, set line items per category, track spending
6. Create savings/debt goals linked to specific accounts
7. View net worth trends via snapshots (auto-captured daily)

## Legacy Backend

The old FastAPI + Supabase backend is still in `backend/` for reference but is no longer used. All functionality has been migrated to Convex.

```bash
# Old backend (deprecated)
cd backend && uv run uvicorn app.main:app --reload
cd backend && uv run pytest tests/test_complete_run.py -v
cd backend && uv run ruff check .
```
