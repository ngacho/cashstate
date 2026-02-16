# Where to Add Categories & Subcategories

## Adding a New Category

### Location
**BudgetView → Edit Budget → Category Selection**

### Navigation Path
```
1. Open BudgetView (Budget tab)
2. Tap "Edit Budget" button (top right)
   OR
   Tap pencil icon on any category
3. In EditBudgetView, there's a category section
4. Tap "Categories" or similar option
5. See CategorySelectionView with existing categories
6. Tap the "+ New" button
7. AddCategoryView opens
```

### In CategorySelectionView
There's a grid of category buttons, and at the end:

```
┌────┬────┬────┬────┐
│ 🍿 │ 🍔 │ 🚗 │ 🏠 │
├────┼────┼────┼────┤
│ ❤️ │ 🛍️ │ ✈️ │ ➕ │  ← "New" button
└────┴────┴────┴────┘
```

**Code location**:
- File: `CategorySelectionView.swift`
- Lines: 73-92
- Button with `+` icon and "New" text

### AddCategoryView Features
Once opened, you can:
1. **Select Type**: Expense or Income
2. **Choose Icon**: From 24 emoji options
3. **Pick Color**: From 8 color options (blue, purple, pink, orange, yellow, green, teal, red)
4. **Enter Name**: Custom category name
5. **See Examples**: Shows subcategory suggestions for inspiration
6. **Save**: Tap "Set Name" button

## Adding a Subcategory

### Location
**BudgetView → Expand Category → Add Subcategory**

### Navigation Path
```
1. Open BudgetView (Budget tab)
2. Find the category you want to add a subcategory to
3. Tap to expand the category (shows subcategories)
4. Tap "Add Subcategory" button
```

### In BudgetView (ExpandableCategoryCard)
When category is expanded, at the bottom:

```
┌─────────────────────────────┐
│ 🍔 Food               95%  │
├─────────────────────────────┤
│ SUBCATEGORIES          3    │
│ [🛒 Groceries]    $450/500  │
│ [🍽️ Dining Out]   $230/200  │
│ [☕ Coffee]        $85/100   │
│                             │
│ ➕ Add Subcategory          │  ← This button
│ 📋 View All Transactions    │
└─────────────────────────────┘
```

**Code location**:
- File: `BudgetView.swift`
- Component: `ExpandableCategoryCard`
- Lines: 613-625
- Button with text "Add Subcategory"

### Current Status
**Note**: The "Add Subcategory" button exists but the action is empty:
```swift
Button {
    // Add new subcategory
} label: {
    HStack(spacing: Theme.Spacing.xs) {
        Image(systemName: "plus.circle.fill")
        Text("Add Subcategory")
    }
}
```

**TODO**: This needs to open a subcategory creation view.

## What's Missing

### 1. Add Subcategory View
Currently there's no dedicated view for adding subcategories. We need to create:

**Option A**: Reuse `AddCategoryView` with a parent parameter
```swift
AddCategoryView(
    isPresented: $showAddSubcategory,
    parentCategory: category,  // NEW
    onSave: { newSubcategory in
        // Add to parent's subcategories
    }
)
```

**Option B**: Create separate `AddSubcategoryView`
```swift
struct AddSubcategoryView: View {
    let parentCategory: BudgetCategory
    @Binding var isPresented: Bool
    var onSave: ((BudgetSubcategory) -> Void)?

    // Similar UI to AddCategoryView but simpler
    // - No type selection (inherits from parent)
    // - Uses parent's color
    // - Only icon and name
}
```

### 2. Direct Access from Budget View
Currently you need to go through EditBudgetView → CategorySelection to add a category. Consider adding:

**Quick Add Button** in BudgetView toolbar:
```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Menu {
            Button {
                showAddCategory = true
            } label: {
                Label("Add Category", systemImage: "folder.badge.plus")
            }

            Button {
                showEditBudget = true
            } label: {
                Label("Edit Budget", systemImage: "slider.horizontal.3")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
        }
    }
}
```

## Quick Access Summary

### Current Access Points

| Action | Location | Status |
|--------|----------|--------|
| **Add Category** | CategorySelectionView → "+ New" button | ✅ Working |
| **Add Subcategory** | BudgetView → Expand Category → "Add Subcategory" | ⚠️ Button exists, no action |
| **Edit Category** | BudgetView → Category → Pencil icon | ✅ Working (opens CategoryBudgetView) |
| **Edit Subcategory** | BudgetView → Subcategory → Tap | ✅ Working (opens SubcategoryBudgetView) |

### Recommended Improvements

1. **Implement Add Subcategory**
   - Create `AddSubcategoryView` or extend `AddCategoryView`
   - Connect to "Add Subcategory" button in `ExpandableCategoryCard`

2. **Add Quick Access**
   - Menu button in BudgetView toolbar
   - Direct "Add Category" option
   - No need to go through EditBudget first

3. **Context Menus**
   - Long-press on category → "Add Subcategory" option
   - Long-press on subcategory → "Edit" or "Delete" options

## Code Examples

### Implementing Add Subcategory

**Step 1**: Create AddSubcategoryView (simple approach)
```swift
struct AddSubcategoryView: View {
    let parentCategory: BudgetCategory
    @Binding var isPresented: Bool
    var onSave: ((BudgetSubcategory) -> Void)?

    @State private var name: String = ""
    @State private var icon: String = "📁"
    @State private var budgetAmount: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)

                    // Icon picker (similar to AddCategoryView)
                    LazyVGrid(...) {
                        // Icon selection
                    }
                }

                Section("Budget (Optional)") {
                    TextField("Amount", text: $budgetAmount)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Button("Save") {
                        saveSubcategory()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .navigationTitle("Add Subcategory")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func saveSubcategory() {
        let newSub = BudgetSubcategory(
            id: UUID().uuidString,
            name: name,
            icon: icon,
            budgetAmount: Double(budgetAmount),
            spentAmount: 0.0,
            transactionCount: 0
        )
        onSave?(newSub)
        isPresented = false
    }
}
```

**Step 2**: Connect to BudgetView
```swift
// In ExpandableCategoryCard
@State private var showAddSubcategory = false

// In body
Button {
    showAddSubcategory = true  // Instead of empty action
} label: {
    HStack(spacing: Theme.Spacing.xs) {
        Image(systemName: "plus.circle.fill")
        Text("Add Subcategory")
    }
}
.sheet(isPresented: $showAddSubcategory) {
    AddSubcategoryView(
        parentCategory: category,
        isPresented: $showAddSubcategory
    ) { newSubcategory in
        category.subcategories.append(newSubcategory)
    }
}
```

## Summary

✅ **Add Category** - Working, accessible via CategorySelectionView
⚠️ **Add Subcategory** - Button exists but needs implementation
📋 **Edit Category/Subcategory** - Working

**To fully enable category management**, implement the Add Subcategory functionality using one of the approaches above.
