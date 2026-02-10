# CashState

A Mint-inspired personal finance tracker with bank account integration via Plaid. Track your spending, visualize insights, and manage budgets across iOS and web.

## Architecture

- **Backend**: FastAPI + Supabase + Plaid API
- **iOS App**: SwiftUI with Clean Architecture + MVVM
- **Security**: User JWT + Row Level Security (RLS), encrypted Plaid tokens

## Quick Start

### Backend

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
   # Apply migrations via Supabase dashboard SQL editor
   # Use supabase/migrations/001_initial_schema.sql for new projects
   # Or 00X_complete_rls_fix.sql to fix existing databases
   ```

4. **Start the server:**
   ```bash
   uv run uvicorn app.main:app --reload
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

### Backend API (14 endpoints)

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

### iOS App

**Current Features:**
- ✅ **Home Dashboard** (Mint-inspired design):
  - Budget tracker with progress bar
  - "Left to Spend" prominent display
  - Spending trend line chart (daily view)
  - Top 3 spending categories with color coding
  - Smart category icons and amounts
- ✅ **Authentication** (Login via backend API)
- ✅ **Transaction List** with pull-to-refresh
- ✅ **Tab Bar Navigation**: Home, Transactions, Budgets, Accounts
- ✅ **Real-time Calculations**: Budget tracking from live transaction data
- ✅ **Error Handling**: User-friendly messages and loading states
- ⏳ Plaid Link integration (backend ready, iOS pending)
- ⏳ Registration UI (backend ready, iOS pending)
- ⏳ Budget configuration (currently hardcoded)

**UI/UX:**
- 🎨 Mint-inspired design (teal primary color #00D09C)
- 📊 Visual spending trends with line charts
- 🎯 Budget progress indicators
- 🏷️ Smart category icons and color coding
- 📱 Native SwiftUI with async/await networking
- 🔄 Pull-to-refresh on all data views
- ⚡ Smooth animations and transitions

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
