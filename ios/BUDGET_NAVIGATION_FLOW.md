# Budget Feature - Navigation Flow

## App Structure

```
MainView (TabView)
├── Overview Tab (HomeView)
├── Budget Tab (BudgetView) ← NEW! Replaces Transactions
├── Insights Tab (InsightsView)
└── Settings Tab (AccountsView)
```

## Budget Tab Navigation Tree

```
BudgetView
│
├─→ Edit Budget (Sheet)
│   │
│   └── EditBudgetView
│       │
│       ├─→ Category Selection (Sheet)
│       │   │
│       │   └── CategorySelectionView
│       │       │
│       │       └─→ Add New Category (Sheet)
│       │           │
│       │           └── AddCategoryView
│       │
│       └── [Save Changes] → Dismiss
│
├─→ All Budgets (Sheet)
│   │
│   └── AllBudgetsView
│       └── [List of all budgets]
│
└─→ Category Detail (Sheet)
    │
    └── CategoryDetailView
        └── [Shows subcategories & spending]
```

## Screen-by-Screen Breakdown

### 1. BudgetView (Main Screen)
**Purpose:** Budget overview and spending visualization

**Elements:**
- 📅 Month navigation (← February 2025 →)
- 💰 Budget card (Total, Spent, Remaining)
- 📊 Progress bar
- 🏷️ Category chips (horizontal scroll)
- 🍩 Donut chart (total spending visualization)
- 📝 Category list (with progress bars)
- ➕ Add budget button (top-right)

**Actions:**
- Tap "All Budgets" → Opens AllBudgetsView
- Tap "Edit Budget" → Opens EditBudgetView
- Tap category → Opens CategoryDetailView
- Tap ➕ → Opens EditBudgetView (new budget)

**Mock Data:**
- $4,200 total budget
- $3,364.99 spent (80%)
- $835.01 remaining
- 6 categories with spending

---

### 2. EditBudgetView (Budget Editor)
**Purpose:** Create or modify budget configuration

**Elements:**
- 🔄 Budget type toggle (Expense ↔ Savings)
- ✏️ Budget name input
- 💵 Amount input ($)
- 📅 Period selector (1 month, 3 months, etc.)
- 🎨 Color picker (8 colors)
- 🔘 Transaction filters (Default, Income, Expense, etc.)
- 🏦 Account filters (All Accounts, Bank, etc.)
- 🗂️ "Set Category Spending Goals" button
- 📋 Selected categories preview
- ❌ Excluded categories preview
- 💾 Save Changes button

**Actions:**
- Toggle Expense/Savings → Updates UI
- Tap period → Opens dropdown
- Tap color → Selects color
- Tap filter chip → Toggles selection
- Tap "Set Category Spending Goals" → Opens CategorySelectionView
- Tap "Save Changes" → Saves & dismisses
- Tap "Cancel" → Dismisses without saving
- Tap 🗑️ (trash) → Deletes budget

**Flow:**
```
Open → Select Type → Enter Name → Set Amount → Choose Period
  → Pick Color → Filter Transactions → Filter Accounts
  → Select Categories → Save
```

---

### 3. CategorySelectionView (Category Picker)
**Purpose:** Select which categories to include/exclude in budget

**Elements:**
- ⚡ Quick actions ("All categories", "No categories")
- 🗂️ Category grid (4 columns)
- ✓ Include indicator (green checkmark)
- ✗ Exclude indicator (red X)
- ➕ "New" category button
- 📋 Excluded categories section (if any)

**Actions:**
- Tap "All categories" → Selects all
- Tap "No categories" → Deselects all
- Tap category once → Include (green ✓)
- Tap category twice → Exclude (red ✗)
- Tap category thrice → Deselect
- Tap "New" → Opens AddCategoryView
- Tap "Done" → Saves & returns to EditBudgetView

**Visual States:**
- **Included:** Category icon with green border + checkmark
- **Excluded:** Category icon with red border + X mark
- **Neutral:** Category icon with gray background

---

### 4. AddCategoryView (Category Creator)
**Purpose:** Create new spending/income categories

**Elements:**
- 🔄 Type toggle (Expense ↔ Income)
- 🎨 Large icon preview (100x100)
- ✏️ Category name input
- 🌈 Color selector (8 colors, horizontal scroll)
- 😀 Icon grid (24 emojis, 6 columns)
- 🗂️ "Main Category" button
- 📊 Subcategory section with examples
- ℹ️ Info button (explains subcategories)
- 💾 "Set Name" button

**Subcategory Examples:**
- ☕ Drinks → Coffee, Bubble Tea, Soda
- 🎭 Entertainment → Movies, Music, Activities
- 🚊 Transport → Gas, Public Transit, Rideshare
- ❤️ Personal & Medical → Healthcare, Fitness, Personal Care

**Actions:**
- Toggle Expense/Income → Updates UI
- Tap icon → Selects icon & updates preview
- Tap color → Selects color
- Type name → Updates preview
- Tap ℹ️ → Shows subcategory explanation
- Tap "Main Category" → (Future: subcategory selection)
- Tap "Set Name" → Creates category & dismisses

**Validation:**
- "Set Name" disabled if name is empty
- Background color matches selected color

---

### 5. AllBudgetsView (Budget List)
**Purpose:** View all budgets

**Elements:**
- 📋 List of budgets
- Budget name
- Amount & period

**Actions:**
- Tap budget → (Future: opens budget detail)
- Tap "Done" → Dismisses

---

### 6. CategoryDetailView (Category Info)
**Purpose:** View category spending breakdown

**Elements:**
- 🎨 Large category icon
- 📊 Spending stats ($X of $Y)
- 📝 Subcategory list
- Subcategory icons & amounts

**Actions:**
- Tap "Done" → Dismisses

---

## Key Interactions

### Creating a Budget
1. BudgetView → Tap ➕
2. EditBudgetView → Enter details
3. Tap "Set Category Spending Goals"
4. CategorySelectionView → Select categories
5. Tap "Done" → Back to EditBudgetView
6. Tap "Save Changes" → Back to BudgetView

### Adding a Category
1. BudgetView → Tap "Edit Budget"
2. EditBudgetView → Tap "Set Category Spending Goals"
3. CategorySelectionView → Tap "New"
4. AddCategoryView → Design category
5. Tap "Set Name" → Back to CategorySelectionView
6. New category appears in grid

### Viewing Category Details
1. BudgetView → Tap any category
2. CategoryDetailView → View subcategories
3. Tap "Done" → Back to BudgetView

---

## Data Flow

```
Mock Data (BudgetModels.swift)
    ├── BudgetCategory.mockCategories (6 categories)
    └── Budget.mockBudgets (2 budgets)

    ↓ Loaded by

BudgetView
    ├── @State categories: [BudgetCategory]
    ├── @State currentBudget: Budget
    └── Passes to child views via Binding

    ↓ When integrated

API Client
    ├── GET /budgets → [Budget]
    ├── GET /categories → [BudgetCategory]
    ├── POST /categories → BudgetCategory
    └── PUT /budgets/{id} → Budget
```

---

## Color Coding

- **Blue** (#60A5FA) - Primary category color
- **Purple** (#A78BFA) - Home & Utilities
- **Pink** (#F472B6) - Personal & Medical
- **Orange** (#FB923C) - Food
- **Yellow** (#FBBF24) - Shopping
- **Green** - Savings/Income
- **Teal** - Transport
- **Red** - Over budget indicator

---

## Responsive Features

- Horizontal scroll for category chips (small screens)
- Grid layout for categories (4 columns, responsive)
- Flow layout for filter chips (wraps automatically)
- Donut chart scales to container size

---

## Animation & Feedback

- Progress bars animate on load
- Category selection shows immediate visual feedback
- Color selection has ring indicator
- Icon selection highlights with border
- Chips toggle smoothly
- Sheets slide up from bottom

---

## Accessibility

- All buttons have clear labels
- Icons use SF Symbols where possible
- Color not the only indicator (also uses shapes/text)
- Large touch targets (44pt minimum)
- High contrast text
- Semantic colors from Theme system
