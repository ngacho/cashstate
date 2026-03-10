# CashState

Personal finance tracker with bank sync via SimpleFin, budget management, goals, and AI transaction categorization.

**Stack:** Convex (backend) + SwiftUI (iOS) + Clerk (auth) + SvelteKit (web/landing)

## Prerequisites

- [Node.js](https://nodejs.org/) 18+
- Xcode 16+ (iOS 18+ target)
- A [SimpleFin](https://beta-bridge.simplefin.org) account (for bank sync)
- [Clerk](https://clerk.com) account (for auth)
- (Optional) [OpenRouter](https://openrouter.ai) API key (for AI categorization)
- Apple Developer Program membership (for TestFlight)

## Quick Start

### 1. Set up Convex backend

```bash
npm install
npx convex dev
```

On first run, Convex CLI will prompt you to create a project. Follow the prompts — the schema deploys automatically.

### 2. Configure environment variables

Set these in the Convex dashboard (Settings → Environment Variables):

| Variable | Required | Description |
|---|---|---|
| `CLERK_JWT_ISSUER_DOMAIN` | **Yes** | Clerk JWT issuer domain |
| `CLERK_WEBHOOK_SECRET` | **Yes** | Clerk webhook signing secret |
| `ENCRYPTION_KEY` | **Yes** | For encrypting SimpleFin access URLs. Generate: `openssl rand -base64 32` |
| `OPENROUTER_API_KEY` | No | For AI transaction categorization |

### 3. Configure iOS app

Edit `ios/CashState/Config.swift`:

```swift
static let convexURL = "https://YOUR-DEPLOYMENT.convex.cloud"
static let clerkPublishableKey = "pk_test_YOUR_KEY"
```

Find your deployment URL at: [Convex Dashboard](https://dashboard.convex.dev) → your project → Settings

### 4. Run iOS app

```bash
open ios/CashState.xcodeproj
# Select target device/simulator → Cmd+R
```

Or via CLI (simulator):

```bash
xcodebuild -project ios/CashState.xcodeproj -scheme CashState -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Auth

The app uses **Clerk** for authentication (email/password + Apple Sign-In + Google OAuth).

- Clerk handles sign-up/sign-in flows
- ConvexMobile SDK handles JWT transport to the backend
- Users are created in Convex **only via Clerk webhook** (`user.created` event)
- Webhook endpoint: `https://YOUR-DEPLOYMENT.convex.site/clerk-webhook`

### Clerk webhook setup

1. Go to Clerk Dashboard → Webhooks → Add Endpoint
2. Set URL to `https://YOUR-DEPLOYMENT.convex.site/clerk-webhook`
3. Subscribe to: `user.created`, `user.updated`, `user.deleted`
4. Copy the Signing Secret → set as `CLERK_WEBHOOK_SECRET` env var in Convex

## iOS Build & TestFlight

All commands run from the **project root** directory.

### Debug build (simulator)

```bash
xcodebuild -project ios/CashState.xcodeproj -scheme CashState -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build
```

### Release archive (for TestFlight)

**Step 1: Archive**

```bash
xcodebuild -project ios/CashState.xcodeproj -scheme CashState -destination generic/platform=iOS -configuration Release archive -archivePath ios/build/CashState.xcarchive -allowProvisioningUpdates
```

**Step 2: Export & upload to TestFlight**

```bash
xcodebuild -exportArchive -archivePath ios/build/CashState.xcarchive -exportPath ios/build/export -exportOptionsPlist ios/ExportOptions.plist -allowProvisioningUpdates
```

**Step 3: (If auto-upload didn't work) Manual upload**

```bash
xcrun altool --upload-app -f ios/build/export/CashState.ipa -t ios -u YOUR_APPLE_ID -p YOUR_APP_SPECIFIC_PASSWORD
```

**All-in-one (clean, archive, export):**

```bash
rm -rf ios/build && xcodebuild -project ios/CashState.xcodeproj -scheme CashState -destination generic/platform=iOS -configuration Release archive -archivePath ios/build/CashState.xcarchive -allowProvisioningUpdates && xcodebuild -exportArchive -archivePath ios/build/CashState.xcarchive -exportPath ios/build/export -exportOptionsPlist ios/ExportOptions.plist -allowProvisioningUpdates
```

### Clean build artifacts

```bash
rm -rf ios/build
```

## Convex Deploy

### Development

```bash
npx convex dev
```

### Production

```bash
npx convex deploy --prod
```

Set production env vars in the Convex dashboard under the Production deployment, or use:

```bash
npx convex env set VARIABLE_NAME "value" --prod
```

## Web (Landing Page)

Deployed via Cloudflare on merge to main.

```bash
cd web
npm install
npm run dev
```

## Project Structure

```
convex/                         # Convex backend
├── schema.ts                   # Database schema (13+ tables)
├── functions.ts                # userQuery/userMutation middleware (auth)
├── users.ts                    # Webhook-only user mutations
├── usersHelpers.ts             # _getByClerkId internal query
├── http.ts                     # Clerk webhook handler + /user-exists
├── auth.config.ts              # Clerk JWT provider config
├── helpers.ts                  # Shared helpers
├── transactions.ts             # Transaction queries (paginated)
├── categories.ts               # Categories CRUD + rules
├── budgets.ts                  # Budgets CRUD + summary + line items
├── goals.ts                    # Goals CRUD with progress tracking
├── accounts.ts                 # SimpleFin items/accounts
├── snapshots.ts                # Balance history snapshots
├── crons.ts                    # Daily sync + daily snapshot cron jobs
├── cronHandlers.ts             # Cron job handlers
├── simplefinSyncHelpers.ts     # Sync helper mutations
└── actions/
    ├── simplefinSync.ts        # SimpleFin API sync (Node action)
    └── aiCategorize.ts         # AI categorization via OpenRouter

ios/CashState/                  # SwiftUI iOS app
├── Config.swift                # Convex URL + Clerk key config
├── APIClient.swift             # ConvexMobile SDK wrapper
├── CashStateApp.swift          # App entry point + Clerk configure
├── ContentView.swift           # Auth routing (login vs main)
├── LoginView.swift             # Clerk auth (email + Apple + Google)
├── MainView.swift              # Tab bar navigation
├── HomeView.swift              # Dashboard overview
├── BudgetView.swift            # Budget management
├── GoalsView.swift             # Goals tracking
├── Models.swift                # Data models
├── Theme.swift                 # Design system
└── ExportOptions.plist         # TestFlight export config

web/                            # SvelteKit landing page (Cloudflare)

backend/                        # Legacy FastAPI backend (deprecated)
```

## App Store / TestFlight Readiness

### Assets Checklist

| Asset | Status | Notes |
|---|---|---|
| App Icon (1024x1024) | Done | `AppIcon.appiconset/appicon_1024.png` |
| AccentColor | TODO | Set brand green in `AccentColor.colorset` |
| Launch Screen | TODO | Auto-generated blank. Add branded launch screen with logo |
| cashstate-logo 2x/3x | TODO | Only 1x exists, will look blurry on Retina. Add 2x (160px) and 3x (240px) |
| Dark mode app icon | TODO | Currently reuses light icon. Add dark-background variant |

### App Store Connect Requirements

| Requirement | Status | Notes |
|---|---|---|
| App name + bundle ID | Done | "CashState" / `com.cashstate.CashState` |
| Screenshots (6.7" iPhone) | TODO | Required for public TestFlight / App Store |
| Screenshots (6.5" iPhone) | TODO | Required for App Store |
| Screenshots (12.9" iPad) | TODO | Required if supporting iPad |
| Privacy Policy URL | TODO | Host on web landing page, link in App Store Connect |
| App Description | TODO | Add in App Store Connect |
| App Subtitle | TODO | Short tagline for App Store listing |
| Keywords | TODO | For App Store search optimization |
| Support URL | TODO | Link to support/contact page |

### Signing Requirements

| Requirement | Status | Notes |
|---|---|---|
| Apple Developer Program ($99/yr) | Done | Team: Peter Opondo |
| Apple Development Certificate | Done | 9BLX42THT5 |
| Apple Distribution Certificate | Done | Created 3/9/26 |
| Provisioning Profile | Done | Xcode Managed |
| Sign in with Apple capability | Done | Enabled in Xcode + Apple Developer Portal |

## Features

- **Bank Sync**: Connect banks via SimpleFin, auto-sync transactions daily (2 AM UTC cron)
- **Budgets**: Create budgets with category line items, track spending vs budget per month
- **Goals**: Savings and debt payment goals linked to accounts with progress tracking
- **Categories**: Default categories with subcategories, custom categories, auto-categorization rules
- **AI Categorization**: Rules-first pipeline (substring match), then OpenRouter AI for uncategorized
- **Net Worth Snapshots**: Daily balance snapshots (11:55 PM UTC cron) with historical charts
- **Apple Sign-In**: Native iOS Sign in with Apple via Clerk
