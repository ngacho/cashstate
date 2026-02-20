Plan to implement                                                            │
│                                                                              │
│ UI Design Language Port: Match Budget View's Clean Aesthetic                 │
│                                                                              │
│ Context                                                                      │
│                                                                              │
│ The BudgetView has a clean, modern design language with flat category lists, │
│  minimal card usage, consistent section headers, and subtle visual           │
│ hierarchy. Other views (HomeView, GoalsView, AccountDetailView,              │
│ TransactionsView, AccountsView) use heavier card-per-item patterns and       │
│ inconsistent typography. The goal is to unify the entire app's look to match │
│  the budget view's cleaner style.                                            │
│                                                                              │
│ Key Design Principles (from BudgetView)                                      │
│                                                                              │
│ 1. Flat rows over individual cards - Items in lists share a single container │
│  with dividers, not individual cards with shadows                            │
│ 2. ALL CAPS section headers - .font(.caption).fontWeight(.semibold).foregrou │
│ ndColor(Theme.Colors.textSecondary)                                          │
│ 3. Emoji icons in colored circle borders - Not filled background circles     │
│ 4. Thin progress bars - 4-6px height, rounded, subtle                        │
│ 5. Minimal shadows - Only on section-level containers, not per-item          │
│ 6. Large bold amounts - For primary values, caption for labels               │
│ 7. Consistent Theme.Colors.background page backgrounds                       │
│                                                                              │
│ Files to Modify                                                              │
│                                                                              │
│ 1. HomeView.swift — HomeView (overview tab)                                  │
│                                                                              │
│ Changes:                                                                     │
│ - Add ALL CAPS section header for accounts ("ACCOUNTS" label above groups)   │
│ - Keep hero net worth card (already good)                                    │
│ - Keep chart section (already good)                                          │
│ - Account groups already use flat list pattern — no change needed here       │
│ - Remove NavigationView → use NavigationStack for consistency                │
│                                                                              │
│ 2. MainView.swift — TransactionsView, AccountsView, InsightsView             │
│                                                                              │
│ TransactionsView changes:                                                    │
│ - Add ALL CAPS section header label ("TRANSACTIONS")                         │
│ - Transaction rows are already in a flat list with dividers — keep this      │
│ pattern                                                                      │
│ - Currently good, minor header consistency                                   │
│                                                                              │
│ AccountsView changes:                                                        │
│ - Add ALL CAPS section headers ("CONNECTION", "ACCOUNT")                     │
│ - The connection card and sign-out section are already clean                 │
│ - Minor typography alignment                                                 │
│                                                                              │
│ InsightsView changes:                                                        │
│ - Remove individual SummaryCard components (heavy card-per-stat)             │
│ - Replace with an inline HStack summary row (like StatCard in AccountDetail  │
│ but in a single row/container)                                               │
│ - Clean up the donut chart section headers to use ALL CAPS pattern           │
│ - Transaction preview section header cleanup                                 │
│                                                                              │
│ 3. GoalsView.swift — GoalCard, GoalsList                                     │
│                                                                              │
│ Changes:                                                                     │
│ - Major: Change from individual GoalCards (card+shadow per goal) to a flat   │
│ list pattern                                                                 │
│ - Goals listed in a single container with dividers between them              │
│ - Keep goal content (name, progress bar, type badge, target date) but remove │
│  per-item card wrapping                                                      │
│ - Reduce padding and shadow — single container card for the entire list      │
│                                                                              │
│ 4. GoalDetailView.swift                                                      │
│                                                                              │
│ Changes:                                                                     │
│ - Section headers → ALL CAPS pattern ("PROGRESS OVER TIME", "LINKED          │
│ ACCOUNTS")                                                                   │
│ - Already uses cards for sections — keep these (they're section-level, not   │
│ per-item)                                                                    │
│ - Minor typography alignment                                                 │
│                                                                              │
│ 5. HomeView.swift — AccountDetailView                                        │
│                                                                              │
│ Changes:                                                                     │
│ - Major: Replace 3 separate StatCard components with a single inline stats   │
│ row (all in one container)                                                   │
│ - Stats become a single HStack with dividers, inside one card — same pattern │
│  as CategoryTransactionsView's stats area                                    │
│ - Transaction listing already uses flat list pattern — keep                  │
│ - Section headers → ALL CAPS pattern ("SPENDING BREAKDOWN", "TRANSACTIONS")  │
│ - Clean up the TransactionRow to match MintTransactionRow pattern (use       │
│ circle icon with colored background, not just the SF Symbol)                 │
│                                                                              │
│ 6. CreateGoalView.swift & EditGoalView.swift                                 │
│                                                                              │
│ Changes:                                                                     │
│ - Section headers already use .font(.headline) — change to ALL CAPS          │
│ .font(.caption).fontWeight(.semibold) for consistency                        │
│ - These are form-style views, keep the card-wrapped input fields             │
│ - Minor typography alignment                                                 │
│                                                                              │
│ 7. LoginView.swift                                                           │
│                                                                              │
│ - Already clean — no changes needed                                          │
│                                                                              │
│ 8. SimplefinSetupView.swift                                                  │
│                                                                              │
│ - Uses native Form — no changes needed                                       │
│                                                                              │
│ 9. TransactionDetailView.swift                                               │
│                                                                              │
│ - Already clean with card sections — no changes needed                       │
│                                                                              │
│ 10. CategoryBudgetView.swift                                                 │
│                                                                              │
│ - Already clean — no changes needed                                          │
│                                                                              │
│ 11. SpendingCompareView.swift                                                │
│                                                                              │
│ - Already clean — minor section header consistency                           │
│                                                                              │
│ Detailed Changes                                                             │
│                                                                              │
│ A. GoalsView — Flat list pattern (biggest visual change)                     │
│                                                                              │
│ BEFORE: Individual GoalCard per goal (each with card bg + shadow)            │
│ AFTER:  Single container card with all goals as rows, dividers between       │
│ - Remove shadow/cornerRadius from GoalCard                                   │
│ - Wrap the ForEach in a single VStack with cardBackground + cornerRadius +   │
│ shadow                                                                       │
│ - Add dividers between items                                                 │
│ - Keep the progress bar, badge, amounts inside each row                      │
│ - Keep swipe-to-delete                                                       │
│                                                                              │
│ B. AccountDetailView — Unified stats row                                     │
│                                                                              │
│ BEFORE: 3 separate StatCard boxes (Spent/Credit/Net)                         │
│ AFTER:  Single card with 3 columns separated by dividers                     │
│ - Replace HStack(spacing: sm) { StatCard() StatCard() StatCard() } with a    │
│ single card containing an HStack with Dividers                               │
│                                                                              │
│ C. TransactionRow unification                                                │
│                                                                              │
│ - TransactionRow (in HomeView.swift) uses bare SF Symbol icons               │
│ - MintTransactionRow (in MainView.swift) uses circle-background icons        │
│ - Unify: make TransactionRow use the same circle-background pattern as       │
│ MintTransactionRow                                                           │
│                                                                              │
│ D. Section header consistency                                                │
│                                                                              │
│ All views that show section labels should use:                               │
│ Text("SECTION NAME")                                                         │
│     .font(.caption)                                                          │
│     .fontWeight(.semibold)                                                   │
│     .foregroundColor(Theme.Colors.textSecondary)                             │
│                                                                              │
│ Verification                                                                 │
│                                                                              │
│ 1. Build in Xcode — no compile errors                                        │
│ 2. Visual check: All tabs (Overview, Budget, Goals, Settings) should feel    │
│ unified                                                                      │
│ 3. Interactions: Navigation, swipe-to-delete, pull-to-refresh all still work │
│ 4. No functionality changes — purely visual