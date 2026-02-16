# Transactions in Categories Feature

## Overview

Added transaction viewing within budget categories and subcategories, allowing users to see exactly which transactions contribute to their spending in each area.

## New Features

### 1. Transaction Counts
- Each subcategory now displays transaction count
- Format: "X transaction(s)" next to spending amount
- Helps users understand spending patterns at a glance

### 2. View Subcategory Transactions
- **Tap any subcategory** → Opens transaction list for that subcategory
- Shows all transactions categorized under that subcategory
- Displays merchant name, date, amount, and pending status
- Real-time spending totals

### 3. View Category Transactions
- **"View All Transactions" button** in expanded category
- Shows all transactions across all subcategories in that category
- Aggregated view of category spending

### 4. Transaction Details
Each transaction shows:
- Merchant name
- Transaction date
- Amount (with expense formatting)
- Pending status badge
- Additional description (if available)
- Category-colored icon

## UI Flow

### Viewing Subcategory Transactions
```
Budget View
    ↓ Tap category to expand
🍿 Entertainment (expanded)
    ├── 🍿 Movies - $45/$100 • 3 transactions
    │       ↓ Tap
    ├── CategoryTransactionsView opens
    │   ├── Header: Movies icon, 3 Transactions, $45 Total
    │   └── Transaction List:
    │       ├── AMC Theatres - $25.00
    │       ├── Regal Cinemas - $15.00
    │       └── Movie Theater - $5.00
```

### Viewing All Category Transactions
```
🍿 Entertainment (expanded)
    ├── Subcategories (3)
    │   ├── Movies
    │   ├── Music
    │   └── Activities
    ├── + Add Subcategory
    └── 📄 View All Transactions
            ↓ Tap
        CategoryTransactionsView opens
            ├── Shows 9 total transactions
            └── Across all 3 subcategories
```

## Mock Data

### Transaction Counts by Subcategory
```
Entertainment:
  🍿 Movies           3 transactions    $45.00
  🎵 Music            1 transaction     $9.99
  🎳 Activities       5 transactions    $120.00

Food:
  🛒 Groceries        28 transactions   $450.00
  🍽️ Dining Out       12 transactions   $230.00
  ☕ Coffee           18 transactions   $85.00

Transport:
  ⛽ Gas             8 transactions    $180.00
  🚊 Public Transit   22 transactions   $45.00
  🚕 Rideshare       4 transactions    $60.00
```

### Sample Transactions
Entertainment - Movies (3):
- AMC Theatres - $25.00 (2 days ago)
- Regal Cinemas - $15.00 (5 days ago)
- Movie Theater - $5.00 (10 days ago)

Food - Coffee (first 5 of 18):
- Starbucks - $6.75 (1 day ago)
- Local Cafe - $4.50 (2 days ago)
- Starbucks - $8.25 (3 days ago)
- Peet's Coffee - $5.50 (5 days ago)
- Coffee Shop - $7.00 (6 days ago)

## Files Modified/Added

### New Files
- **CategoryTransactionsView.swift** - Transaction list view

### Modified Files
- **BudgetModels.swift**:
  - Added `transactionCount` to `BudgetSubcategory`
  - Added `CategoryTransaction` model
  - Added mock transactions (22 sample transactions)
  - Added helper method `transactions(for:subcategoryId:)`

- **BudgetView.swift**:
  - Updated `SubcategoryRow` to show transaction count
  - Added tap gesture to view subcategory transactions
  - Added "View All Transactions" button to expanded category
  - Added sheets for transaction viewing

## Interaction Details

### Subcategory Row
Two tappable areas:
1. **Left side** (icon + name + spending) → Opens transactions
2. **Right side** (percentage/"Set Budget") → Opens budget editor
3. Transaction count displayed automatically

### Category Level
When expanded:
- "View All Transactions" button at bottom
- Shows all transactions across all subcategories
- Useful for seeing complete category spending

## Components

### CategoryTransactionsView
Features:
- **Header**: Large icon, transaction count, total amount
- **Empty State**: Friendly message when no transactions
- **Transaction List**: Scrollable list with all transactions
- **Navigation**: "Done" button to dismiss

### CategoryTransactionRow
Displays:
- Category-colored icon with up arrow
- Merchant name (bold)
- Date, pending status, description
- Amount in red (expense format)
- Matches main transaction list styling

## Data Model

### CategoryTransaction
```swift
struct CategoryTransaction: Identifiable {
    let id: String
    let categoryId: String
    let subcategoryId: String?
    let merchantName: String
    let amount: Double
    let date: Date
    let description: String
    let pending: Bool
}
```

### Helper Method
```swift
static func transactions(for categoryId: String, subcategoryId: String? = nil) -> [CategoryTransaction]
```
- Filters transactions by category and optionally by subcategory
- Returns sorted array (newest first)

## Visual Design

### Transaction Row Styling
- **Icon**: Category color + circular background
- **Merchant**: Bold, primary text color
- **Metadata**: Small, secondary text (date, status)
- **Amount**: Red (expense), right-aligned, bold
- **Dividers**: Between transactions (left-offset)

### Header Stats
- Two-column layout (Transactions | Total Spent)
- Large numbers (title3, semibold)
- Small labels (caption, secondary)
- Card background with shadow

## Next Steps - Backend Integration

### Database Schema
Already exists in `transactions` table, needs:
- Category/subcategory assignment
- Categorization logic

### API Endpoints
```python
# Get transactions by category
GET /app/v1/categories/{category_id}/transactions
→ [CategoryTransaction]

# Get transactions by subcategory
GET /app/v1/categories/{category_id}/subcategories/{subcategory_id}/transactions
→ [CategoryTransaction]

# Update transaction category
PUT /app/v1/transactions/{transaction_id}/category
{
    "category_id": "...",
    "subcategory_id": "..."
}
```

### iOS Integration
Replace mock data with API calls:
```swift
// In CategoryTransactionsView
.task {
    if let sub = subcategory {
        transactions = try await apiClient.getSubcategoryTransactions(
            categoryId: category.id,
            subcategoryId: sub.id
        )
    } else {
        transactions = try await apiClient.getCategoryTransactions(
            categoryId: category.id
        )
    }
}
```

### Auto-Categorization
Future enhancement:
- ML-based transaction categorization
- Rule-based categorization (merchant patterns)
- Manual category assignment
- Bulk re-categorization

## Testing Checklist

### Subcategory Transactions
- [ ] Tap subcategory opens transaction list
- [ ] Shows correct number of transactions
- [ ] Total amount matches subcategory spending
- [ ] Transaction count displays correctly
- [ ] Empty state shows when no transactions

### Category Transactions
- [ ] "View All Transactions" button appears when expanded
- [ ] Shows all subcategory transactions combined
- [ ] Total count is sum of all subcategories
- [ ] Total amount matches category spending

### Transaction Display
- [ ] Merchant names display correctly
- [ ] Dates format properly
- [ ] Pending badge shows for pending transactions
- [ ] Amounts show with 2 decimal places
- [ ] Category color applies to icons
- [ ] Scrolling works smoothly

### Navigation
- [ ] Can open transactions from multiple subcategories
- [ ] Can switch between transaction views
- [ ] "Done" button dismisses sheet
- [ ] Back navigation works
- [ ] Sheets stack properly

## Known Limitations (Mock Data)

- ✗ Only 22 sample transactions (not comprehensive)
- ✗ Only Entertainment (9) and Food (13) have full mock data
- ✗ Other categories show count but no actual transactions
- ✗ Transactions are static (don't update with budget changes)
- ✗ No search/filter functionality
- ✗ No date range filtering
- ✗ Can't edit transaction categories

## File Sizes

- **BudgetModels.swift**: ~15KB (+7KB for transactions)
- **CategoryTransactionsView.swift**: ~8KB (new)
- **BudgetView.swift**: ~30KB (+5KB for transaction integration)

Total new code: ~12KB

## Summary

✅ Transaction counts on all subcategories
✅ Tap subcategories to view their transactions
✅ "View All Transactions" for entire categories
✅ 22 realistic mock transactions
✅ Clean transaction list UI
✅ Category-colored transaction icons
✅ Pending status indicators
✅ Merchant names and dates
✅ Empty states for no transactions

Users can now drill down into their spending and see exactly where their money is going at both the category and subcategory level!
