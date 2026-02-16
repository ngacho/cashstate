# Transaction Categorization Feature

## Overview

Added transaction categorization functionality with two methods:
1. **Manual Categorization** - Swipeable UI similar to dating apps for categorizing transactions
2. **AI Categorization** - Automated categorization using merchant name recognition and patterns

## Implementation Status

✅ **Completed**:
- iOS UI components for manual and AI categorization
- Swipeable transaction card interface
- Uncategorized transactions prompt card in Budget view
- Mock data for testing the UX
- Category and subcategory selection flows

⏳ **Pending** (requires database changes):
- Backend API endpoints
- Database schema updates
- Persistent storage of categorizations
- Real AI/ML categorization logic

## Features

### 1. Uncategorized Transactions Card

Located in **BudgetView**, this card appears when there are uncategorized transactions:

```swift
UncategorizedTransactionsCard(
    uncategorizedCount: 15,
    showManualCategorization: $showManual,
    showAICategorization: $showAI
)
```

**Features**:
- Shows count of uncategorized transactions
- Two action buttons: "Manual" and "AI Categorize"
- Warning-style design to draw attention
- Automatically hidden when all transactions are categorized

### 2. Manual Categorization (Swipeable)

**File**: `CategorizationViews.swift` → `SwipeableCategorization`

**User Flow**:
1. User taps "Manual" button
2. Full-screen modal shows one transaction at a time
3. Transaction card shows:
   - Amount (large, color-coded)
   - Merchant name
   - Date and description
4. User can:
   - **Swipe left/right** to select a category
   - **Tap category chip** below the card
   - **Tap confirm (✓)** to apply and move to next
   - **Tap skip (✗)** to skip this transaction
5. Progress bar shows X of Y categorized
6. If category has subcategories, subcategory picker modal appears
7. Completion screen when all done

**Design Features**:
- Card stack preview (shows next card beneath current)
- Smooth swipe animations with rotation
- Visual swipe indicators showing category being selected
- Category chips (scrollable horizontal) below card
- Large, clear typography for amounts and merchants
- Progress tracking with percentage

**Mirrors**: `@ios/design/swiping_transact.mov` design

### 3. AI Categorization

**File**: `CategorizationViews.swift` → `AICategorization`

**User Flow**:
1. User taps "AI Categorize" button
2. Start screen explains the feature with:
   - Transaction count
   - Feature list (smart recognition, learning patterns, review)
   - "Start AI Categorization" button
3. Processing screen with:
   - Animated sparkle icon
   - Progress bar
   - "Analyzing Transactions..." message
4. Review screen shows all categorizations:
   - List of transactions with assigned categories
   - Each row shows: merchant, amount, category icon/name, subcategory
   - User can review suggestions
5. "Apply Categorizations" button to confirm all

**Current Implementation**:
- Uses rule-based logic for demo (matches keywords)
- Rules:
  - "coffee", "starbucks" → Food > Coffee
  - "grocery", "market" → Food > Groceries
  - "gas", "fuel" → Transport > Gas
  - "rent" or amount > $1000 → Home & Utilities > Rent
  - Default → Entertainment

**Future Enhancement**:
- OpenAI API integration for smarter categorization
- User preference learning from manual categorizations
- Per-user categorization rules

## Data Models

### CategorizableTransaction

```swift
struct CategorizableTransaction: Identifiable {
    let id: String
    let merchantName: String
    let amount: Double
    let date: Date
    let description: String
    var categoryId: String?        // Links to BudgetCategory
    var subcategoryId: String?     // Links to BudgetSubcategory
}
```

**Mock Data**: `CategorizableTransaction.mockUncategorized` (5 sample transactions)

### Integration with Existing Models

Uses existing `BudgetCategory` and `BudgetSubcategory` from `BudgetModels.swift`.

## Files Added/Modified

### New Files
- `ios/CashState/CategorizationViews.swift` - All categorization UI components

### Modified Files
- `ios/CashState/BudgetView.swift`:
  - Added state for uncategorized transactions
  - Added state for showing categorization sheets
  - Added `UncategorizedTransactionsCard` in scroll view
  - Added sheet modifiers for categorization views

### Documentation
- `CATEGORIZATION_PLAN.md` - Backend implementation plan
- `CATEGORIZATION_FEATURE.md` - This file (iOS feature documentation)

## Components in CategorizationViews.swift

1. **CategorizableTransaction** - Data model for transactions to categorize
2. **UncategorizedTransactionsCard** - Alert card for BudgetView
3. **SwipeableCategorization** - Main manual categorization view
4. **TransactionCardView** - Individual transaction card
5. **SwipeIndicator** - Visual feedback during swipe
6. **CategoryChip** - Category selection chips
7. **SubcategoryPickerView** - Modal for subcategory selection
8. **CompletionView** - Success screen after categorization
9. **AICategorization** - Main AI categorization view
10. **ProcessingView** - AI processing animation
11. **StartView** - AI intro/start screen
12. **ReviewView** - Review AI suggestions
13. **ReviewTransactionRow** - Individual transaction in review list
14. **FeatureRow** - Feature bullet points

## Usage

### In BudgetView

```swift
@State private var uncategorizedTransactions: [CategorizableTransaction] =
    CategorizableTransaction.mockUncategorized
@State private var showManualCategorization = false
@State private var showAICategorization = false

// In body
if !uncategorizedTransactions.isEmpty {
    UncategorizedTransactionsCard(
        uncategorizedCount: uncategorizedTransactions.count,
        showManualCategorization: $showManualCategorization,
        showAICategorization: $showAICategorization
    )
}

// Sheet modifiers
.sheet(isPresented: $showManualCategorization) {
    SwipeableCategorization(
        isPresented: $showManualCategorization,
        transactions: $uncategorizedTransactions,
        categories: categories
    )
}
.sheet(isPresented: $showAICategorization) {
    AICategorization(
        isPresented: $showAICategorization,
        transactions: $uncategorizedTransactions,
        categories: categories
    )
}
```

### Testing with Mock Data

Currently uses `CategorizableTransaction.mockUncategorized` which includes:
- Starbucks ($5.50)
- Whole Foods ($85.30)
- Shell Gas Station ($45.00)
- AMC Theatres ($28.50)
- Target ($156.78)

## SwiftUI Previews

Three previews available in `CategorizationViews.swift`:
1. `#Preview("Uncategorized Card")` - Shows the alert card
2. `#Preview("Swipeable Categorization")` - Full manual flow
3. `#Preview("AI Categorization")` - Full AI flow

## Design Principles

### Visual Hierarchy
- Large amounts draw attention
- Color-coded (red for expenses, green for income)
- Clear merchant names as primary identifier
- Secondary information (date, description) in smaller text

### Interaction Patterns
- Swipe gestures feel natural and fast
- Tap for precision when needed
- Clear progress indicators
- Undo-friendly (skip instead of delete)

### Accessibility
- High contrast color choices
- Large touch targets (60pt minimum)
- Clear labels on all buttons
- Progress communicated visually and textually

### Performance
- Smooth animations (Spring with 0.3s response)
- Lazy loading in lists
- Efficient state updates

## Next Steps (Backend Integration)

When ready to integrate with backend:

1. **Update Transaction Model** in `Models.swift`:
   ```swift
   struct Transaction {
       // Add these fields
       var categoryId: String?
       var subcategoryId: String?
   }
   ```

2. **Add API Client Methods** in `APIClient.swift`:
   ```swift
   func getUncategorizedTransactions() async throws -> [Transaction]
   func categorizeTransaction(id: String, categoryId: String, subcategoryId: String?) async throws
   func aiCategorizeTransactions(transactionIds: [String]) async throws -> [(String, String, String?)]
   ```

3. **Replace Mock Data**:
   - Fetch real uncategorized transactions from backend
   - Update state after categorization
   - Sync with backend on each categorization

4. **Add Real AI**:
   - OpenAI API for merchant categorization
   - Store user preferences for learning
   - Confidence scores for suggestions

## Design Inspiration

The swipeable interface mirrors the design shown in `@ios/design/swiping_transact.mov`:
- One transaction per screen
- Large, readable information
- Quick swipe gestures
- Clear visual feedback
- Progress tracking

## User Experience Benefits

1. **Fast Manual Categorization**: Swipe through transactions quickly
2. **Bulk AI Processing**: Categorize dozens of transactions in seconds
3. **Review Before Apply**: AI suggestions can be reviewed and modified
4. **Progressive Disclosure**: Only show what's needed (subcategories only when selected)
5. **Clear Progress**: Always know how many remain
6. **Flexible Options**: Choose manual for precision, AI for speed

## Known Limitations (Current Mock Implementation)

- Mock data only (not persisted)
- Simple keyword-based AI (not real ML)
- No backend integration
- No learning from user behavior
- Cannot edit categorizations after applying (in mock)

These will be addressed when backend integration is complete.
