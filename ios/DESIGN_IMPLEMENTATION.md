# iOS App Design Implementation

## Design Reference
Based on `ios/design/home_screen.png` - a Mint-inspired financial tracking app.

## Implemented Features

### 🏠 Home Screen (HomeView.swift)

#### 1. Budget Card (Top Section)
- **Left to Spend**: Large prominent display of remaining budget
- **Budget Info**: Shows total budget ("of $4000")
- **Spent Amount**: Displays total spent this month
- **Progress Bar**: Visual indicator (teal when safe, red when >90% spent)
- Color-coded warnings when budget is exceeded

#### 2. Spending Trend Chart
- **Line Chart**: Shows daily spending over the current month
- **Data Points**: Circles on each day with spending data
- **Y-Axis**: Auto-scales based on max spending amount
- **X-Axis**: Day numbers (1-10 or up to current day)
- **Styling**: Teal line matching brand color

#### 3. Top Spending Categories
- **Top 3 Categories**: Automatically calculated from transactions
- **Color-Coded**: Each category has unique color (red, purple, blue, etc.)
- **Icons**: Smart category icons:
  - Food & Dining → fork.knife
  - Shopping → bag
  - Transportation → car.fill
  - Entertainment → tv
  - Groceries → cart
- **Amount Display**: Shows total spent per category
- **Time Period**: "This month" label

### 📋 Transactions Screen (TransactionsView.swift)
- Full transaction list with details
- Pull-to-refresh
- Shows merchant name, date, amount
- Color-coded (red for expenses, green for income)
- "Pending" badge for pending transactions

### 📊 Budgets Screen (BudgetsView.swift)
- Placeholder for future budget management
- Will allow setting category-specific budgets

### 💳 Accounts Screen (AccountsView.swift)
- Connected accounts list (placeholder)
- Settings section
- Sign out functionality

## Tab Bar Navigation

Matches the reference design:
- **Home** (house icon) - Primary view with budget & insights
- **Transactions** (list icon) - Full transaction history
- **Budgets** (pie chart icon) - Budget management
- **Accounts** (wallet icon) - Account settings & sign out

## Design System (Theme.swift)

### Colors
- **Primary**: `#00D09C` (Teal) - Mint-inspired brand color
- **Background**: `#F7F8FA` (Light gray)
- **Text Primary**: `#2E3E4E` (Dark blue-gray)
- **Text Secondary**: `#6B7280` (Medium gray)
- **Income**: `#10B981` (Green)
- **Expense**: `#EF4444` (Red)
- **Category Colors**: `#FF6B6B`, `#9B59B6`, `#3498DB`, `#F39C12`, `#1ABC9C`

### Spacing
- Small: 12pt
- Medium: 16pt
- Large: 24pt

## Data Flow

1. **Login** → User authenticates via backend
2. **Token Storage** → Access token stored in APIClient
3. **Data Fetch** → Pull transactions from backend (`/transactions?limit=200`)
4. **Calculations**:
   - Filter transactions by current month
   - Calculate total spent (negative amounts)
   - Group by category for top spending
   - Aggregate by day for trend chart
   - Calculate budget remaining

## Key Features

✅ **Real-time Budget Tracking**: Calculates remaining budget from actual transactions
✅ **Visual Spending Trends**: Line chart shows spending patterns
✅ **Category Intelligence**: Auto-categorizes with smart icons
✅ **Progress Indicators**: Visual bars and progress tracking
✅ **Responsive Design**: Adapts to different screen sizes
✅ **Pull-to-Refresh**: Update data anytime
✅ **Error Handling**: Graceful failures with retry

## Current Limitations

⏳ **Budget Configuration**: Currently hardcoded to $4000 (needs user settings)
⏳ **Historical Data**: Chart shows up to 10 days (can be extended)
⏳ **Category Mapping**: Basic category detection (can be improved)
⏳ **Plaid Integration**: Backend ready, iOS UI pending

## Files Structure

```
ios/CashState/
├── CashStateApp.swift          # App entry point
├── ContentView.swift           # Root view (login/main router)
├── Config.swift                # Backend & Supabase URLs
├── Theme.swift                 # Design system (colors, spacing)
├── Models.swift                # Data models (Transaction, Auth)
├── APIClient.swift             # HTTP client with auth
├── LoginView.swift             # Authentication screen
├── HomeView.swift              # 🆕 Main dashboard (budget, trends, top spending)
└── MainView.swift              # Tab bar container with all views
```

## Next Steps

1. **User Budget Settings**: Allow users to set custom monthly budgets
2. **Category Customization**: Let users edit transaction categories
3. **Extended Charts**: Add weekly/monthly views beyond daily
4. **Plaid Link**: Add bank connection UI
5. **Notifications**: Budget alerts and spending warnings
6. **Export Data**: CSV/PDF export functionality
