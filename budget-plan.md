# Budget & Categorization Full Rebuild — Implementation Plan

> **SOURCE OF TRUTH**: This document is the authoritative plan. After every phase of implementation, refer back here to track progress and pick up the next phase. Do not add files, schemas, endpoints, or logic not listed here. If something is unclear, add it to **Open Questions** at the bottom — do not guess.

---

## Context

The existing budgeting/categorization implementation has a working skeleton but is misaligned with the spec in several structural ways. Rather than patch it, this plan performs a clean rebuild per the spec. **Data loss is acceptable — no backwards compatibility needed.**

---

## Current State Audit (What Exists)

### Backend
- `budget_templates` router + schema (not `budgets`) — templates concept differs from spec
- `budget_template_accounts` — no uniqueness constraint across templates (spec requires ONE account → ONE budget)
- `budget_categories` + `budget_subcategories` — two tables instead of unified `budget_line_items`
- `budget_templates.total_amount` — stored, not derived (spec says derived)
- `categories`, `subcategories` — solid, mostly spec-aligned. Uses `is_system` (rename to `is_default`)
- AI categorization service (ClaudeCategorizationService) — works, keep it
- **MISSING**: `categorization_rules` table + endpoints
- **MISSING**: `categorization_source` field on transactions (ai/rule/manual/uncategorized)

### iOS
- `BudgetView.swift` — **UI is solid and must be preserved**: donut chart, month navigation, uncategorized card, AI categorization, progress bar, expandable category rows, transaction drill-down. Only `loadData()` needs to be rewired to the new API.
- `BudgetModels.swift` — view-layer models (`BudgetCategory`, `BudgetSubcategory`, `ColorPalette`) are good; API-layer models (`BudgetTemplate`, `CategoryBudget`, `SubcategoryBudget`, `MonthlyBudget`, `BudgetPeriodModel`) need replacing
- `CategoryBudgetView.swift`, `SubcategoryBudgetView.swift` — functional; just update which API endpoint the PATCH calls hit
- Onboarding flow in `BudgetEmptyState.swift` — functional two-step wizard; backend onboarding service updated to new schema, iOS flow unchanged
- No goals iOS integration (goals are out of scope for this feature)

### Database (`001_complete_schema.sql`)
- Tables to **rename/restructure**: `budget_templates` → `budgets`, `budget_template_accounts` → `budget_accounts`, `budget_categories` + `budget_subcategories` → `budget_line_items`, `budget_periods` → `budget_months`
- Tables to **ADD**: `categorization_rules`
- Columns to **ADD to transactions**: `categorization_source` (enum: ai, rule, manual, uncategorized)
- `budget_templates.total_amount` — DROP (spec: actuals are computed, not stored)
- `budget_accounts` — ADD UNIQUE constraint on `account_id` alone (not just per-template)

---

## Confirmed Decisions

1. **Data reset**: All budget/category tables will be dropped and recreated. All existing data wiped. ✅
2. **Goals**: Leave as-is — out of scope for this rebuild. ✅
3. **Account constraint**: Hard UNIQUE constraint on `account_id` in `budget_accounts`. Moving an account from one budget to another removes it from the old one. API returns 409 with conflict info. ✅
4. **`budget_months.month` format**: Stored as `DATE` (`YYYY-MM-01`) internally, exposed as `"YYYY-MM"` string at API layer. ✅
5. **`is_system` → `is_default`**: Renamed to `is_default`. All user-visible categories are `user_id`-owned; `is_default = true` means seeded from defaults but still user-editable/deletable. ✅
6. **SimpleFin Accounts**: Budget account references point to `simplefin_accounts.id`. ✅

---

## What to DELETE

| File/Table | Reason |
|---|---|
| `budget_templates` table | Renamed to `budgets` |
| `budget_template_accounts` table | Renamed to `budget_accounts` with stricter constraint |
| `budget_categories` table | Merged into `budget_line_items` |
| `budget_subcategories` table | Merged into `budget_line_items` |
| `budget_periods` table | Renamed to `budget_months` |
| `budget_templates.total_amount` column | Spec: derived, not stored |
| `backend/app/routers/budget_templates.py` | Replaced by new `budgets.py` router |
| `backend/app/schemas/budget_template.py` | Replaced by new `budget.py` schema |
| iOS `BudgetTemplate` API model | Replaced by `Budget` API model (view-layer `BudgetCategory` kept) |
| iOS `CategoryBudget`/`SubcategoryBudget` API models | Replaced by `BudgetLineItem` (view-layer `BudgetCategory`/`BudgetSubcategory` kept) |
| iOS `BudgetPeriodModel` | Replaced by `BudgetMonth` |

## What to KEEP

| Component | Notes |
|---|---|
| `categories` table | Minor changes: rename `is_system` → `is_default`, keep color/icon/display_order |
| `subcategories` table | Minor changes: rename `is_system` → `is_default` |
| `ClaudeCategorizationService` | Keep; rules-first pipeline wraps it |
| `onboarding_service.py` | Keep default category seeds; update budget seeding to new schema |
| `batch_update_transaction_categories()` RPC | Keep this SQL function; update signature to include `categorization_source` |
| `transactions_view` | Add `categorization_source` to view |
| All SimpleFin sync infrastructure | Not touched |
| Goals backend | Left as-is (out of scope) |

---

## Implementation Plan (Ordered)

### Phase 1: Schema (`001_complete_schema.sql`)

Modify the single SQL file with:

1. **Rename `is_system` → `is_default`** on `categories` and `subcategories`; update all RLS policies referencing it.

2. **Add `categorization_source` to `simplefin_transactions`**:
   ```sql
   categorization_source TEXT DEFAULT 'uncategorized'
     CHECK (categorization_source IN ('ai', 'rule', 'manual', 'uncategorized'))
   ```

3. **Add `categorization_rules` table**:
   ```sql
   categorization_rules (
     id UUID PK,
     user_id FK auth.users,
     match_field TEXT ('payee' | 'description' | 'memo'),
     match_value TEXT,              -- case-insensitive substring match
     category_id FK categories,
     subcategory_id FK subcategories (nullable),
     created_at TIMESTAMPTZ
   )
   -- RLS: users manage own rules
   -- Index: (user_id), (user_id, category_id)
   ```

4. **DROP**: `budget_templates`, `budget_template_accounts`, `budget_categories`, `budget_subcategories`, `budget_periods`

5. **CREATE `budgets`**:
   ```sql
   budgets (
     id UUID PK,
     user_id FK auth.users,
     name TEXT,
     is_default BOOLEAN DEFAULT FALSE,
     created_at, updated_at
   )
   -- Unique partial index: one default per user (WHERE is_default = TRUE)
   ```

6. **CREATE `budget_accounts`**:
   ```sql
   budget_accounts (
     budget_id FK budgets,
     account_id FK simplefin_accounts UNIQUE,  -- KEY: one account → one budget
     created_at
   )
   ```

7. **CREATE `budget_line_items`**:
   ```sql
   budget_line_items (
     id UUID PK,
     budget_id FK budgets,
     category_id FK categories,
     subcategory_id FK subcategories (nullable),
     amount NUMERIC(12,2) DEFAULT 0 CHECK >= 0,
     created_at, updated_at
   )
   -- Unique: (budget_id, category_id) WHERE subcategory_id IS NULL
   -- Unique: (budget_id, subcategory_id) WHERE subcategory_id IS NOT NULL
   ```

8. **CREATE `budget_months`**:
   ```sql
   budget_months (
     id UUID PK,
     budget_id FK budgets,
     user_id FK auth.users,
     month DATE,                    -- stored as YYYY-MM-01
     created_at
   )
   -- Unique: (user_id, month)
   ```

9. **UPDATE `batch_update_transaction_categories()`** to include `categorization_source` parameter (with default `'ai'` for backwards compatibility).

10. **UPDATE `transactions_view`** to include `categorization_source`.

> **After this phase**: Delete all budget/category tables in Supabase dashboard and re-run migration.

---

### Phase 2: Backend — Categories & Categorization

**Files to modify/create:**
- `backend/app/schemas/category.py` — rename `is_system` → `is_default`, add `CategorizationRule` schemas, add `ManualCategorizationRequest`
- `backend/app/routers/categories.py` — add rule CRUD endpoints, fix `is_system` references, add manual recategorization endpoint
- `backend/app/services/categorization_service.py` — add rules-first pipeline
- `backend/app/database.py` — add categorization_rules DB methods, update `update_transaction_category` to accept source

**Changes:**

1. **Rename `is_system` → `is_default`** in all DB queries, router logic, and schema models.

2. **Add categorization_rules CRUD endpoints** (`GET/POST/DELETE /categories/rules`):
   - `GET /categories/rules` — list user's rules
   - `POST /categories/rules` — create rule
   - `DELETE /categories/rules/{rule_id}` — delete rule

3. **Update AI categorization pipeline** to apply user rules FIRST:
   - Fetch all user's `categorization_rules`
   - Apply rules to incoming transactions (case-insensitive substring match on payee/description/memo)
   - Mark matched transactions as `categorization_source = 'rule'`
   - Send remaining transactions to Claude AI service
   - Mark AI-categorized as `categorization_source = 'ai'`
   - Remaining → `categorization_source = 'uncategorized'`

4. **Manual re-categorization endpoint** — `PATCH /categories/transactions/{transaction_id}/categorize`:
   - Updates `category_id`, `subcategory_id`, sets `categorization_source = 'manual'`
   - Optionally creates a rule if `create_rule = true` in request body

5. **On category delete**: Set all transactions with that `category_id` to the user's "Uncategorized" category (find by `name = 'Uncategorized'` for the user). The `categories` router `delete_category` endpoint handles this.

6. **On subcategory delete**: Null out `subcategory_id` on all transactions with that subcategory.

7. **Update `onboarding_service.py`**: Change `is_system: False` → `is_default: True` when seeding default categories.

---

### Phase 3: Backend — Budgets

**Files to create:**
- `backend/app/routers/budgets.py` (replaces `budget_templates.py`)
- `backend/app/schemas/budget.py` (replaces `budget_template.py`)
- `backend/app/services/budget_service.py` (new — extracts budget summary logic)

**Files to delete:**
- `backend/app/routers/budget_templates.py`
- `backend/app/schemas/budget_template.py`

**`main.py`**: Remove `budget_templates_router`, add `budgets_router`.
**`routers/__init__.py`**: Same swap.
**`database.py`**: Remove old budget template methods, add new budget methods.

**Endpoints (`/app/v1/budgets`):**
- `GET /budgets` — List all user budgets
- `POST /budgets` — Create budget (name, is_default, account_ids, line_items)
- `GET /budgets/{budget_id}` — Get budget with line items
- `PATCH /budgets/{budget_id}` — Update name, default status
- `DELETE /budgets/{budget_id}` — Delete (cascades in DB)
- `POST /budgets/{budget_id}/set-default` — Set as default budget
- `GET /budgets/{budget_id}/accounts` — List linked accounts
- `POST /budgets/{budget_id}/accounts` — Add account (enforce uniqueness; if already in another budget, return 409 with conflict details)
- `DELETE /budgets/{budget_id}/accounts/{account_id}` — Remove account
- `GET /budgets/{budget_id}/line-items` — List line items
- `POST /budgets/{budget_id}/line-items` — Add line item (category + optional subcategory + amount)
- `PATCH /budgets/{budget_id}/line-items/{item_id}` — Update amount
- `DELETE /budgets/{budget_id}/line-items/{item_id}` — Remove line item
- `GET /budgets/months` — List budget_months overrides
- `POST /budgets/months` — Assign budget to month (body: `{budget_id, month: "YYYY-MM"}`)
- `DELETE /budgets/months/{month_id}` — Remove override (falls back to default)
- `GET /budgets/summary?month=2025-07` — **Key endpoint**: resolve active budget for month, compute actuals

**Budget Summary Logic (`budget_service.py`):**
```
1. For requested month ("YYYY-MM"), parse to YYYY-MM-01
2. Check budget_months table → get explicit budget_id
3. If not found → use is_default = true budget
4. If no default → 404
5. Get all line_items for that budget
6. Get all linked accounts (budget_accounts)
7. Call get_spending_by_category(account_ids, month_start, month_end)
8. For each line_item: match spending, compute remaining
9. Find categories with spending but NO line_item → "Unbudgeted" section
10. Compute totals
11. Return structured BudgetSummary response
```

Reuse existing: `database.py:get_spending_by_category()` — already does the right query.

**Also update `onboarding_service.py`** to use new `budgets` + `budget_line_items` tables instead of `budget_templates` + `budget_categories`.

---

### Phase 4: iOS — Categories

**Files to modify:**
- `ios/CashState/CategoryModels.swift` — rename `isSystem` → `isDefault`, add `CategorizationRule` model
- `ios/CashState/CategorizationViews.swift` — wire to `categorization_source`, add "Make this a rule" prompt on manual categorization
- `ios/CashState/AddCategoryView.swift` — minor: use `isDefault` not `isSystem`
- `ios/CashState/APIClient.swift` — add rule CRUD methods; add manual categorization method; update `isSystem` → `isDefault` references

**New files:**
- `ios/CashState/CategorizationRulesView.swift` — List, edit, delete rules (accessible from settings/profile)

**Key flows:**
- After manual recategorization in `TransactionDetailView`: show alert "Apply this to all future [merchant] transactions?" → creates rule via API
- `CategorizationRulesView` accessible from `ProfileView` settings section

---

### Phase 5: iOS — Budgets

#### What to PRESERVE (do not touch the visuals)

`BudgetView.swift` has solid, working UI that must be kept as-is:
- **Month navigation** (prev/next chevrons, month/year label, "days left" subtitle)
- **Uncategorized transactions card** with AI categorization trigger and progress animation
- **Budget overview card** (remaining amount, "spent this month", progress bar)
- **`InteractiveBudgetDonutView`** — donut chart of category spending (keep component intact)
- **`ExpandableCategoryCard`** — expandable rows with subcategory drill-down (keep intact)
- **Navigation** to `CategoryTransactionsNavigableView` for transaction list per category
- **`AllBudgetsView`** sheet, **`AddCategoryView`** sheet, `showIncomeInBudget` toggle

The **view-layer models** (`BudgetCategory`, `BudgetSubcategory` in `BudgetModels.swift`) are also fine — they are UI structs, not API models. Keep them.

#### What to CHANGE (data layer only)

**`BudgetModels.swift`:**
- Remove API-layer models that no longer match the backend: `BudgetTemplate`, `BudgetTemplateWithAllocations`, `CategoryBudget`, `SubcategoryBudget`, `MonthlyBudget`, `BudgetPeriodModel`, `BudgetPeriodListResponse`
- Add new API-layer models: `Budget`, `BudgetListResponse`, `BudgetLineItem`, `BudgetLineItemListResponse`, `BudgetMonth`, `BudgetMonthListResponse`, `BudgetSummary`, `BudgetSummaryLineItem`, `UnbudgetedCategory`

**`BudgetView.swift` — `loadData()` only:**
- Replace call to `apiClient.getBudgetForMonth(year:month:)` with `apiClient.getBudgetSummary(month:)` (new `/budgets/summary?month=YYYY-MM` endpoint)
- Update the mapping from API response → `BudgetCategory` view model to match new `BudgetSummary` shape:
  - `summary.lineItems` → `BudgetCategory` (budgetAmount = item.amount, spentAmount = item.spent, budgetId = item.id, budget's ID instead of templateId)
  - `summary.unbudgetedCategories` → `BudgetCategory` entries with `budgetAmount = nil` (shown in "Unbudgeted" section)
- `hasPreviousData` logic: keep as-is (driven by transaction history response)

**`CategoryBudgetView.swift`:**
- Update amount PATCH calls to use `/budgets/{budget_id}/line-items/{item_id}` instead of `/budget-templates/{template_id}/categories/{category_budget_id}`
- `budgetId` on `BudgetCategory` now refers to the line-item ID; `templateId` replaced by the budget's ID (stored separately)

**`BudgetEmptyState.swift`:**
- `seedDefaults()` stays the same (calls `apiClient.seedDefaultCategories`)
- `onboarding_service.py` on the backend is updated to use new budget tables — no iOS onboarding flow changes needed

**`APIClient.swift`:**
- Remove: `getBudgetForMonth(year:month:)`, `createBudgetTemplate(...)`, `updateBudgetTemplate(...)`, `deleteBudgetTemplate(...)`, `createCategoryBudget(...)`, `updateCategoryBudget(...)`, `deleteCategoryBudget(...)`, `createBudgetPeriod(...)`, `deleteBudgetPeriod(...)`
- Add: `getBudgetSummary(month:)`, `listBudgets()`, `createBudget(...)`, `updateBudget(...)`, `deleteBudget(...)`, `setBudgetDefault(...)`, `addBudgetAccount(...)`, `removeBudgetAccount(...)`, `addBudgetLineItem(...)`, `updateBudgetLineItem(...)`, `deleteBudgetLineItem(...)`, `listBudgetMonths()`, `assignBudgetMonth(...)`, `deleteBudgetMonth(...)`

**New section in BudgetView — "Unbudgeted":**
After the existing category list in `budgetContentView`, add an "Unbudgeted" section that renders `BudgetCategory` entries where `budgetAmount == nil` but `spentAmount > 0`. These come from `summary.unbudgetedCategories`. Reuse the same `ExpandableCategoryCard` component with a visual treatment indicating "not in budget."

**Key data shape mapping:**
```swift
// New BudgetSummary from GET /budgets/summary?month=YYYY-MM
struct BudgetSummary {
    let budgetId: String
    let budgetName: String
    let month: String          // "YYYY-MM"
    let totalBudgeted: Double  // sum of line item amounts
    let totalSpent: Double
    let lineItems: [BudgetSummaryLineItem]
    let unbudgetedCategories: [UnbudgetedCategory]
}

struct BudgetSummaryLineItem {
    let id: String             // line item ID (for PATCH/DELETE)
    let budgetId: String
    let categoryId: String
    let subcategoryId: String?
    let amount: Double         // budgeted
    let spent: Double          // actual (computed by backend)
    let remaining: Double      // amount - spent
}

struct UnbudgetedCategory {
    let categoryId: String
    let spent: Double
}
```

---

### Phase 5b: iOS — Compare Tab (Month-over-Month Spending)

**Purpose:** Let users compare categorized spending between two months side-by-side using a stacked bar chart.

**New file:** `ios/CashState/SpendingCompareView.swift`

**Where it lives:** This feature **replaces the current Budget tab** entirely. `MainView.swift` keeps its 4-tab structure (Overview, Budget, Goals, Accounts) — no new top-level tab is added. Inside `BudgetView`, a segmented control at the very top switches between "Budget" and "Compare". The existing budget UI (donut, categories, progress bars) lives under "Budget"; the new stacked bar chart lives under "Compare". The combined Budget+Compare experience IS the Budget tab.

**Backend needed:**
- No new endpoint required. The existing `GET /budgets/summary?month=YYYY-MM` endpoint returns spending per category for any month. Call it twice (current month + comparison month) and diff the results client-side.

**iOS implementation:**
- `SpendingCompareView` takes `apiClient`, defaults to current month vs last month
- Picker/stepper to choose which two months to compare (default: current month vs prior month)
- Loads two `BudgetSummary` responses concurrently (`async let`)
- Renders a **grouped/stacked bar chart** using `Swift Charts` (already available in the project):
  - X-axis: category names (top N by spending, or all, with scroll)
  - Y-axis: dollar amount
  - Two bars per category: "This month" (solid fill) vs "Last month" (lighter/hatched fill)
  - Color per bar matches the category's `colorHex`
- Below the chart: a summary list showing each category, this month's spend, last month's spend, and the delta (arrow + amount, green if down, red if up)
- Handle the case where a category only has spending in one of the two months (bar just shows one side)

**Data shape:**
```swift
// Derived client-side from two BudgetSummary responses
struct CategoryComparison {
    let categoryId: String
    let categoryName: String
    let colorHex: String
    let icon: String
    let thisMonth: Double
    let lastMonth: Double
    var delta: Double { thisMonth - lastMonth }  // positive = spent more this month
}
```

**UI structure:**
```
[Budget] [Compare]          ← segmented control at top of Budget screen

Compare Spending
Feb 2026  ←→  Jan 2026      ← month pickers (tappable, show month picker sheet)

[Stacked bar chart - Swift Charts]
  Each category = two bars side by side
  Legend: ■ Feb 2026  □ Jan 2026

Category          Feb      Jan     Change
─────────────────────────────────────────
🍽️ Food & Dining  $420    $380    ↑ $40
🚗 Transportation $215    $240    ↓ $25
🏠 Housing        $1,800  $1,800  —
...
```

**Files to modify:**
- `ios/CashState/BudgetView.swift` — add segmented control at top; show `SpendingCompareView` when "Compare" is selected
- `ios/CashState/APIClient.swift` — `getBudgetSummary` already added in Phase 5; no new API calls needed

---

### Phase 6: Backend Tests & Lint

Run after each backend phase:
```bash
cd backend && uv run pytest tests/test_complete_run.py -v
uv run ruff check . && uv run ruff format --check .
```

New test coverage needed:
- `categorization_rules` CRUD
- Budget CRUD (create, update, delete)
- Budget summary computation (verify actuals match transaction data)
- Account conflict (assign account already in another budget → 409)

---

## Critical Files

| File | Action |
|---|---|
| `backend/supabase/migrations/001_complete_schema.sql` | MODIFY (schema rebuild) |
| `backend/app/routers/budget_templates.py` | DELETE → replaced by `budgets.py` |
| `backend/app/schemas/budget_template.py` | DELETE → replaced by `budget.py` |
| `backend/app/routers/categories.py` | MODIFY (add rules endpoints, fix is_system refs) |
| `backend/app/schemas/category.py` | MODIFY (rename is_system → is_default, add rule schemas) |
| `backend/app/services/categorization_service.py` | MODIFY (rules-first pipeline) |
| `backend/app/services/onboarding_service.py` | MODIFY (use new budget tables, is_default) |
| `backend/app/database.py` | MODIFY (add rules methods, replace budget template methods) |
| `backend/app/main.py` | MODIFY (swap router registration) |
| `backend/app/routers/__init__.py` | MODIFY (swap router import) |
| `ios/CashState/BudgetView.swift` | MODIFY (fix broken data loading) |
| `ios/CashState/BudgetModels.swift` | MODIFY (rename to match new API) |
| `ios/CashState/APIClient.swift` | MODIFY (update budget endpoints, add rules endpoints) |
| `ios/CashState/BudgetEmptyState.swift` | MODIFY (update onboarding) |
| `ios/CashState/CategoryModels.swift` | MODIFY (add rule models, rename isSystem) |
| `ios/CashState/CategorizationViews.swift` | MODIFY (add rule creation flow) |

---

## Verification Checklist

1. `uv run pytest tests/test_complete_run.py -v` → all existing tests pass
2. `uv run ruff check .` → no errors
3. Start backend: `cd backend && uv run uvicorn app.main:app --reload`
4. Reset DB: delete all budget/category/transaction tables in Supabase dashboard, re-run `001_complete_schema.sql`
5. Test budget summary endpoint with real transactions — verify actuals match
6. Run iOS app in simulator — verify BudgetView loads real data, onboarding flow creates budget
7. Test categorization rule: create rule → import transaction → verify auto-categorized with `categorization_source = 'rule'`

---

## Open Questions

> Add questions here during implementation. Do not proceed with assumptions — wait for the answer.
> Format: `Q: <question>` → `__answer__: <answer>`
