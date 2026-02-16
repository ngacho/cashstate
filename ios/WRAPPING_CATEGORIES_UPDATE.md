# Wrapping Categories - No More Horizontal Scroll

## What Changed

Replaced horizontal scrolling category/subcategory chips with a **wrapping grid layout** that shows up to 2 rows, with a "Show More" option if needed.

## Before vs After

### Before (Horizontal Scroll) ❌
```
Select Category
[🍿] [🍔] [🚗] [🏠] [❤️] [🛍️] → (scroll to see more)
```
**Problems**:
- Hidden categories require scrolling
- User doesn't know how many categories exist
- Easy to miss options

### After (Wrapping Grid) ✅
```
Select Category
[🍿] [🍔] [🚗] [🏠]
[❤️] [🛍️] [💼] [✈️]
        [More ▼]
```
**Benefits**:
- See up to 8 categories at once (~2 rows)
- "More" button indicates additional options
- Expands to show all when tapped
- No horizontal scrolling needed

## Implementation

### WrappingHStack Component

Simple wrapper around `LazyVGrid` with adaptive columns:

```swift
struct WrappingHStack<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 80), spacing: spacing)]

        LazyVGrid(columns: columns, spacing: spacing) {
            content
        }
    }
}
```

**How it works**:
- `GridItem(.adaptive(minimum: 80))` - Fits as many 80pt+ items per row as possible
- Automatically wraps to new rows
- Responsive to card width

### Category Section

```swift
@State private var expandedCategories = false
private let maxCategoriesBeforeExpand = 8  // ~2 rows of 4 chips

// In body:
let expenseCategories = categories.filter { $0.type == .expense }
let displayedCategories = expandedCategories
    ? expenseCategories
    : Array(expenseCategories.prefix(maxCategoriesBeforeExpand))
let hasMore = expenseCategories.count > maxCategoriesBeforeExpand

WrappingHStack(spacing: Theme.Spacing.sm) {
    ForEach(displayedCategories) { category in
        CategoryChip(...)
    }

    // Show More button
    if hasMore {
        Button {
            withAnimation(.spring(response: 0.3)) {
                expandedCategories.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: expandedCategories ? "chevron.up" : "chevron.down")
                Text(expandedCategories ? "Less" : "More")
            }
            // ... styling
        }
    }
}
```

### Subcategory Section

Same logic applied to subcategories:
```swift
@State private var expandedSubcategories = false

// Same pattern with "More" button for subcategories
```

## Visual Examples

### 6 Categories (fits in 2 rows)
```
┌─────────────────────────────┐
│ Select Category             │
│ [🍿 Enter.] [🍔 Food]       │
│ [🚗 Trans.] [🏠 Home]       │
│ [❤️ Personal] [🛍️ Shop]     │
└─────────────────────────────┘
```
No "More" button needed - all visible

### 12 Categories (needs expansion)
```
┌─────────────────────────────┐
│ Select Category             │
│ [🍿] [🍔] [🚗] [🏠]         │
│ [❤️] [🛍️] [💼] [✈️]         │
│        [More ▼]             │
└─────────────────────────────┘
```
Tapping "More" expands:
```
┌─────────────────────────────┐
│ Select Category             │
│ [🍿] [🍔] [🚗] [🏠]         │
│ [❤️] [🛍️] [💼] [✈️]         │
│ [🎮] [📚] [🎵] [🏃]         │
│        [Less ▲]             │
└─────────────────────────────┘
```

## Expand Button Styling

```swift
HStack(spacing: 4) {
    Image(systemName: expandedCategories ? "chevron.up" : "chevron.down")
        .font(.caption2)
    Text(expandedCategories ? "Less" : "More")
        .font(.caption)
        .fontWeight(.medium)
}
.padding(.horizontal, Theme.Spacing.sm)
.padding(.vertical, 6)
.background(Color.gray.opacity(0.1))
.foregroundColor(Theme.Colors.textSecondary)
.cornerRadius(20)
```

**Design**:
- Matches chip style (rounded, subtle background)
- Clear chevron indicator (up/down)
- Text changes based on state
- Secondary styling (doesn't compete with category chips)

## Animation

```swift
withAnimation(.spring(response: 0.3)) {
    expandedCategories.toggle()
}
```

- Smooth spring animation
- Content expands/collapses naturally
- Grid reflows automatically

## Adaptive Layout

The grid adapts to available width:

**Narrow card** (e.g., iPhone SE):
```
[🍿] [🍔] [🚗]
[🏠] [❤️] [🛍️]
```
~3 per row

**Wide card** (e.g., iPhone 15 Pro Max):
```
[🍿] [🍔] [🚗] [🏠]
[❤️] [🛍️] [💼] [✈️]
```
~4 per row

**Tablet** (future):
```
[🍿] [🍔] [🚗] [🏠] [❤️] [🛍️]
[💼] [✈️]
```
~6+ per row

## User Experience Improvements

### Before (Horizontal Scroll)
1. User sees first 2-3 categories
2. Might not realize there are more
3. Has to scroll right to discover options
4. Hidden categories might be the best match
5. Awkward scroll interaction on mobile

### After (Wrapping Grid)
1. User sees first 8 categories immediately
2. "More" button clearly indicates additional options
3. One tap to reveal all
4. All categories within thumb reach (no scrolling)
5. Natural top-to-bottom flow

## Performance

- **LazyVGrid**: Only renders visible items (lazy loading)
- **State management**: Simple boolean toggle
- **Animation**: Hardware-accelerated spring animation
- **Memory**: Minimal overhead (just filtering array)

## Accessibility

- **VoiceOver**: Grid announces "X of Y" for items
- **Dynamic Type**: Chips resize with text size
- **Touch Targets**: No change (chips already 44pt+)
- **Clear Labels**: "More" and "Less" are explicit

## Edge Cases Handled

### Exactly 8 Categories
- No "More" button shown
- All fit in 2 rows perfectly

### 1-7 Categories
- No "More" button
- Takes up 1-2 rows as needed

### 9+ Categories
- Shows 8 + "More" button
- Expands to show all
- "Less" button appears when expanded

### Subcategories
- Same logic applies
- Independent state (`expandedSubcategories`)
- Can expand categories and subcategories separately

## State Management

```swift
@State private var expandedCategories = false
@State private var expandedSubcategories = false
```

**Separate states** because:
- Categories and subcategories expand independently
- User might want to browse all categories but not all subcategories
- Clearer UX (each section controls its own expansion)

## Why LazyVGrid?

Alternatives considered:
1. **Custom wrapping layout** - Complex, more code
2. **FlowLayout** - Not native to SwiftUI
3. **LazyVGrid** - ✅ Native, simple, performant

`LazyVGrid` with `.adaptive(minimum: 80)`:
- Automatically calculates columns based on width
- Wraps naturally
- Lazy loading built-in
- Well-tested by Apple

## Configuration

```swift
private let maxCategoriesBeforeExpand = 8  // ~2 rows of 4 chips each
```

Easy to adjust:
- Change to `6` for ~1.5 rows
- Change to `12` for ~3 rows
- Depends on desired balance between visibility and expansion

## Future Enhancements

1. **Smart Ordering**: Show most-used categories first
2. **Search**: Add search bar when 20+ categories
3. **Favorites**: Pin frequently used categories to top
4. **Custom Groups**: Let users organize categories into groups
5. **Compact Mode**: Option for smaller chips (more per row)

## Summary

✅ **No more horizontal scrolling**
✅ **See up to 8 categories at once**
✅ **Clear "More" indicator**
✅ **Smooth expand/collapse**
✅ **Responsive to card width**
✅ **Same improvement for subcategories**

The wrapping grid provides a much better UX - users can see their options at a glance and quickly make selections without hunting through hidden categories.
