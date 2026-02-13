# CashState

A Mint-inspired personal finance tracker with bank account integration via Plaid. Track your spending, visualize insights, and manage budgets across iOS and web.

## Architecture

- **Backend**: FastAPI + Supabase + Plaid API
- **iOS App**: SwiftUI with Clean Architecture + MVVM
- **Security**: User JWT + Row Level Security (RLS), encrypted Plaid tokens

## Quick Start

### Backend

#### Linux/ARM Prerequisites (Ubuntu/Debian/Raspberry Pi)

If you're on Linux (especially ARM devices like Raspberry Pi), install these system dependencies first:

```bash
sudo apt-get update
sudo apt-get install -y \
    python3-dev \
    build-essential \
    libffi-dev \
    libssl-dev \
    pkg-config
```

**For ARM devices (Raspberry Pi), you may also need Rust:**
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

**Other Linux distributions:**
- **Fedora/RHEL/CentOS**: `sudo dnf install python3-devel gcc libffi-devel openssl-devel pkgconfig`
- **Arch Linux**: `sudo pacman -S base-devel libffi openssl`

1. **Install dependencies:**
   ```bash
   cd backend
   uv sync
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your credentials:
   # - Supabase URL and anon key
   # - Plaid credentials
   # - Encryption key (generate with: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
   ```

3. **Run database migrations:**
   ```bash
   # Apply the complete schema via Supabase dashboard SQL editor:
   # backend/migrations/001_complete_schema.sql (all tables: SimpleFin + Snapshots)

   # This creates:
   # - simplefin_items, simplefin_accounts, simplefin_transactions, simplefin_sync_jobs
   # - daily_snapshots (for net worth tracking)
   # All tables linked via user_id for simplicity
   ```

4. **Start the server:**
   ```bash
   # On macOS/Linux (non-ARM):
   uv run uvicorn app.main:app --reload

   # On Raspberry Pi (ARM) - activate environment first:
   source .venv/bin/activate
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```

   The API will be available at `http://localhost:8000`
   - API docs: `http://localhost:8000/docs`
   - OpenAPI spec: `http://localhost:8000/openapi.json`

5. **Run tests:**
   ```bash
   uv run pytest tests/test_complete_run.py -v
   ```

6. **Run linter:**
   ```bash
   uv run ruff check .
   ```

### Backend with ngrok (for iOS testing)

To test the iOS app with a remote backend:

```bash
# Terminal 1: Start backend
cd backend
uv run uvicorn app.main:app --reload

# Terminal 2: Start ngrok
ngrok http 8000

# Copy the ngrok URL (e.g., https://abc123.ngrok.io)
# Update ios/App/Config.swift with this URL
```

### iOS App

1. **Prerequisites:**
   - macOS with Xcode 15+
   - iOS 17+ deployment target
   - Backend running (locally or via ngrok)

2. **Configure backend URL:**
   ```bash
   # Edit ios/CashState/Config.swift and update:
   # - backendURL (your ngrok URL)
   # - supabaseURL (your Supabase project URL)
   # - supabasePublishableKey (your Supabase anon key)
   ```

3. **Open and run:**
   ```bash
   cd ios
   open CashState.xcodeproj
   # In Xcode:
   # 1. Select target device/simulator
   # 2. Press Cmd + R to build and run
   ```

4. **Test the app:**
   - Login with your backend credentials
   - View transactions from connected Plaid accounts
   - Check spending insights with charts and breakdowns

## Project Structure

```
cashstate/
├── backend/                 # FastAPI backend
│   ├── app/
│   │   ├── routers/        # API endpoints (auth, plaid, sync, transactions)
│   │   ├── services/       # Business logic (auth, plaid, sync)
│   │   ├── schemas/        # Pydantic models
│   │   ├── utils/          # Encryption, helpers
│   │   ├── database.py     # Supabase + PostgREST client
│   │   ├── config.py       # Settings
│   │   ├── dependencies.py # Auth & DB injection
│   │   └── main.py         # App entry point
│   └── tests/              # E2E tests
├── ios/                     # iOS SwiftUI app
│   └── CashState/
│       ├── CashStateApp.swift # App entry point
│       ├── ContentView.swift  # Root view (login/main router)
│       ├── Config.swift       # Backend & Supabase URLs
│       ├── Theme.swift        # Design system (colors, spacing)
│       ├── Models.swift       # Transaction, Auth models
│       ├── APIClient.swift    # HTTP client with auth
│       ├── LoginView.swift    # Authentication UI
│       ├── HomeView.swift     # Dashboard (budget, trends, top spending)
│       └── MainView.swift     # Tab bar container (all views)
└── supabase/
    └── migrations/         # Database schema
```

## Features

### Backend API (17 endpoints)

**Authentication:**
- POST `/app/v1/auth/register` - Create account
- POST `/app/v1/auth/login` - Sign in
- POST `/app/v1/auth/refresh` - Refresh token

**Plaid Integration:**
- POST `/app/v1/plaid/create-link-token` - Get Plaid Link token
- POST `/app/v1/plaid/exchange-token` - Exchange public token
- GET `/app/v1/plaid/items` - List connected accounts

**Transactions:**
- GET `/app/v1/transactions` - List with filters (date, category, pagination)
- GET `/app/v1/transactions/{id}` - Get transaction details

**Sync:**
- POST `/app/v1/sync/trigger` - Sync all accounts
- POST `/app/v1/sync/trigger/{item_id}` - Sync specific account
- GET `/app/v1/sync/status` - Get sync status
- GET `/app/v1/sync/status/{job_id}` - Get job status

**Snapshots (Net Worth Tracking):**
- GET `/app/v1/snapshots` - Get historical snapshots with flexible date ranges
  - Query params: `start_date`, `end_date`, `granularity` (day/week/month/year)
  - Example: `/snapshots?start_date=2024-01-01&end_date=2024-01-31&granularity=week`
- POST `/app/v1/snapshots/calculate` - Calculate/recalculate snapshots
  - Automatically called after transaction sync
  - Can be triggered manually to rebuild history

**Scheduled Tasks (Cron Jobs):**
- **Auto-sync SimpleFin transactions** - Runs every 24 hours
  - Automatically syncs all active SimpleFin items
  - Respects 24-hour rate limit per item
  - Fetches transactions from last 30 days
- **Update daily snapshots** - Runs every 24 hours
  - Calculates snapshots for all users with active items
  - Updates yesterday and today to ensure fresh data
- **Control**: Set `ENABLE_CRON_JOBS=false` in `.env` to disable

### iOS App

**Current Features:**
- ✅ **Home Dashboard** (Mint-inspired design):
  - **Smooth net worth line chart** with interactive time periods (Week/Month/Year)
  - Teal gradient hero card showing total balance
  - Grouped accounts by type (Cash, Credit Cards, Investments)
  - Color-coded account icons
  - Sync button integrated in header
- ✅ **Net Worth Tracking**:
  - Daily snapshots stored for historical trends
  - Flexible time ranges (week/month/year views)
  - Smooth Catmull-Rom interpolation for line charts
  - Automatic granularity adjustment (daily → weekly → monthly)
- ✅ **Analytics View**:
  - Donut chart for spending breakdown
  - Toggle between chart and bar graph
  - Top spending categories with colored segments
  - Time period selector in toolbar
- ✅ **Transactions View**:
  - Clean list with circular icons
  - Amount highlighting (red for expenses, green for income)
  - Pending transaction indicators
- ✅ **SimpleFin Integration**:
  - Connect bank accounts via SimpleFin
  - Automatic transaction sync
  - Force sync with date range selection
- ✅ **Authentication** (Login via backend API)
- ✅ **Tab Bar Navigation**: Overview, Transactions, Insights, Settings
- ✅ **Real-time Calculations**: All metrics calculated from live data
- ✅ **Error Handling**: Graceful empty states and error messages
- ⏳ Registration UI (backend ready, iOS pending)
- ⏳ Budget configuration (currently hardcoded)

**UI/UX:**
- 🎨 Mint-inspired design (teal primary color #00A699)
- 📈 Smooth line charts with gradients (Swift Charts)
- 🍩 Interactive donut charts for spending breakdown
- 📊 Visual trends with flexible time periods
- 🎯 Color-coded account types and categories
- 🏷️ Circular icons with meaningful backgrounds
- 📱 Native SwiftUI with async/await networking
- 🔄 Pull-to-refresh on all data views
- ⚡ Smooth animations and Catmull-Rom interpolation
- 🎭 Graceful empty states (no scary error messages)

## Security

- **Authentication**: Supabase Auth with JWT (RS256/ES256 via JWKS)
- **Authorization**: Row Level Security (RLS) on all tables
- **Database Access**: User JWT + PostgREST (no service_role key in app)
- **Encryption**: Plaid access tokens encrypted with Fernet
- **iOS**: Tokens stored in Keychain (not UserDefaults)

## Testing

### Backend

Run all tests:
```bash
cd backend
uv run pytest tests/ -v
```

Run specific test:
```bash
uv run pytest tests/test_complete_run.py::test_register_user -v
```

All 11 E2E tests passing with user JWT + RLS.

### iOS

- Use SwiftUI Previews for UI development
- Integration tests with live backend
- Memory leak testing via BaseViewModel deinit logs

## Development Workflow

1. **Backend changes:**
   - Make changes
   - Run linter: `uv run ruff check .`
   - Run tests: `uv run pytest tests/test_complete_run.py -v`
   - Fix any linter errors

2. **iOS changes:**
   - Make changes in Xcode
   - Test with simulator
   - Verify API integration with backend

3. **Database changes:**
   - Create migration SQL file
   - Apply via Supabase dashboard
   - Update backend models/queries
   - Run tests

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
uvicorn app.main:app --host 0.0.0.0 --port 8000 &
```

**With Logging (nohup):**
```bash
cd ~/cashstate/backend
source .venv/bin/activate
nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/cashstate.log 2>&1 &
```

> **Note:** Using `&` runs in background but stops when terminal closes. Using `nohup` keeps it running after logout. For persistent service, use systemd (see below).

**Check if Running:**
```bash
# Check if backend is running
ps aux | grep "[u]vicorn" && echo "✅ Backend is running" || echo "❌ Backend not running"

# Check if API is responding
curl -s http://localhost:8000/health && echo "✅ API responding" || echo "❌ API not responding"

# Check what's using port 8000
sudo lsof -i :8000
```

**View Logs:**
```bash
# View nohup logs
tail -f /tmp/cashstate.log

# Or if using systemd
sudo journalctl -u cashstate -f
```

**Stop Backend:**
```bash
# Kill uvicorn process
pkill uvicorn

# Or kill by PID
ps aux | grep uvicorn  # Find PID
kill <PID>
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
# Check all running processes
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

## Configuration

### Backend (.env)

```env
# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key

# Plaid
PLAID_CLIENT_ID=your-client-id
PLAID_SECRET=your-secret
PLAID_ENV=sandbox

# App
SECRET_KEY=your-secret-key
ENCRYPTION_KEY=your-fernet-key

# Database
DATABASE_URL=postgresql://user:pass@host:5432/db
```

### iOS (ios/CashState/Config.swift)

```swift
static let backendURL = "https://your-ngrok-url.ngrok-free.app"
static let supabaseURL = "https://your-project.supabase.co"
static let supabasePublishableKey = "your-anon-key"
```

## Dependencies

### Backend

- **fastapi** - Web framework
- **supabase** - Supabase client
- **plaid-python** - Plaid API
- **pyjwt** - JWT verification
- **cryptography** - Token encryption
- **pydantic-settings** - Configuration
- **uv** - Package manager

### iOS

- **Native URLSession** - HTTP networking with async/await
- **SwiftUI** - Declarative UI framework
- **Foundation** - Date formatting, JSON encoding/decoding
- Future additions:
  - **Supabase Swift SDK** - Direct auth (optional)
  - **Plaid Link iOS** - Bank linking UI
  - **Swift Charts** - Native charting library

## API Documentation

Interactive API docs available at: `http://localhost:8000/docs`

## Troubleshooting

### Backend

**Installation fails on Linux (cffi, mmh3, cryptography errors):**
- Install system dependencies: `sudo apt-get install -y python3-dev build-essential libffi-dev libssl-dev pkg-config`
- On ARM devices (Raspberry Pi): Also install Rust compiler
- See "Linux/ARM Prerequisites" section above for details

**Tests failing:**
- Verify `.env` has correct Supabase credentials
- Check database migrations are applied
- Ensure RLS policies are correct

**Linter errors:**
- Run: `uv run ruff check . --fix` to auto-fix

### iOS

**Build errors:**
- Clean build folder (Cmd + Shift + K)
- Ensure all files added to target
- Check Swift Package dependencies loaded

**Network errors:**
- Verify backend URL in Config.swift
- Check backend is running
- Test API endpoint in browser or Postman

**Keychain errors:**
- Reset simulator

## License

MIT

## Support

For issues or questions:
1. Check troubleshooting section
2. Review API docs at `/docs`
3. Check iOS SETUP.md
4. Review test files for examples
