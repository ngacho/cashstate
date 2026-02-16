# Content-Sized Chips - No Fixed Widths

## What Changed

Replaced fixed-width grid with a **true wrapping layout** where each chip sizes itself based on its content (icon + text).

## Before vs After

### Before (Fixed Width) ❌
```
[🍿  Entertainment  ]  [🍔    Food    ]
[🚗   Transport    ]  [🏠    Home    ]
```
- All chips same width (80pt minimum)
- Wasted space for short names
- Cramped space for long names

### After (Content-Sized) ✅
```
[🍿 Entertain.] [🍔 Food] [🚗 Transport]
[🏠 Home] [❤️ Personal] [🛍️ Shopping]
```
- Each chip fits its content perfectly
- More chips fit per row
- Natural, balanced appearance

## Implementation

### Custom Layout Protocol

Using SwiftUI's `Layout` protocol (iOS 16+) for true flexbox-style wrapping:

```swift
struct WrappingHStack: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // Calculate total size needed
        let result = FlexboxLayout(...)
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)  // ← Natural size!
            result.add(width: size.width, height: size.height)
        }
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Place each subview at calculated position
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)  // ← Natural size!
            let position = result.add(width: size.width, height: size.height)
            subview.place(at: position, proposal: ProposedViewSize(size))
        }
    }
}
```

### FlexboxLayout Helper

```swift
class FlexboxLayout {
    let containerWidth: CGFloat
    private var currentX: CGFloat = 0
    private var currentY: CGFloat = 0
    private var lineHeight: CGFloat = 0

    func add(width: CGFloat, height: CGFloat) -> CGPoint {
        // If item doesn't fit on current row, wrap to next
        if currentX + width > containerWidth && currentX > 0 {
            currentX = 0
            currentY += lineHeight + verticalSpacing
            lineHeight = 0
        }

        let position = CGPoint(x: currentX, y: currentY)
        currentX += width + horizontalSpacing
        lineHeight = max(lineHeight, height)

        return position
    }
}
```

**How it works**:
1. Each chip requests its natural size (`.unspecified`)
2. Layout calculates if chip fits on current row
3. If yes → place it; if no → wrap to next row
4. Tracks line height to handle varying chip heights

## Benefits

### 1. Optimal Space Usage
**Short names** (e.g., "Food"):
```
[🍔 Food]  ← 60pt wide
```

**Long names** (e.g., "Entertainment"):
```
[🍿 Entertainment]  ← 140pt wide
```

Each uses exactly what it needs!

### 2. More Chips Per Row
**Before** (fixed 80pt):
```
[    🍿 Ent.    ] [    🍔 Food    ] [    🚗 Trans.    ]
                     (3 per row)
```

**After** (content-sized):
```
[🍿 Entertain.] [🍔 Food] [🚗 Transport] [🏠 Home]
                  (4+ per row)
```

### 3. Natural Appearance
Chips look balanced and proportional, not forced into artificial sizes.

### 4. Better for Different Languages
```
English: [🍔 Food]           (60pt)
Spanish: [🍔 Comida]         (75pt)
German:  [🍔 Essen]          (65pt)
French:  [🍔 Nourriture]     (95pt)
```
Each language gets the space it needs!

## Visual Examples

### Category Row (Mixed Lengths)
```
┌─────────────────────────────────┐
│ Select Category                 │
│ [🍿 Entertain.] [🍔 Food]       │
│ [🚗 Transport] [🏠 Home & Util.]│
│ [❤️ Personal] [🛍️ Shop]         │
└─────────────────────────────────┘
```

Notice:
- "Food" is compact
- "Home & Utilities" takes more space
- Everything fits naturally

### Subcategory Row (Similar Lengths)
```
┌─────────────────────────────────┐
│ Select Subcategory (Optional)   │
│ [None] [🛒 Groceries]           │
│ [🍽️ Dining] [☕ Coffee]          │
└─────────────────────────────────┘
```

Notice:
- All similar lengths
- Evenly distributed
- No wasted space

## Comparison

### Fixed-Width Grid
```swift
LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))]) {
    // All items ≥80pt wide
}
```
❌ Minimum width constraint
❌ Wasted space
❌ Fewer items per row

### Content-Sized Wrapping
```swift
WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
    // Each item sizes itself
}
```
✅ Natural sizing
✅ Optimal space usage
✅ More items per row

## Edge Cases Handled

### Very Long Category Name
```
[🎓 Education & Professional Development]
```
- Takes full row width if needed
- Doesn't break other chips

### Very Short Category Name
```
[🍔 F]  [🚗 T]  [🏠 H]
```
- Uses minimal space
- More fit per row

### Mixed Heights (if different fonts/sizes)
```
[Regular] [BOLD] [italic]
```
- Line height adjusts to tallest item
- Aligned baseline (if needed)

### Dynamic Type (Accessibility)
User increases font size:
```
Before: [🍔 Food] [🚗 Transport] [🏠 Home]
After:  [🍔 Food]
        [🚗 Transport]
        [🏠 Home]
```
- Automatically wraps more
- Maintains readability

## Performance

### Layout Calculation
- **O(n)** where n = number of chips
- One pass to calculate sizes
- One pass to place items
- Very efficient for 8-20 items

### Compared to Grid
- Grid: Pre-calculates columns, then fits items
- Wrapping: Sizes each item, then places naturally
- Similar performance, better UX

## iOS Version Requirement

**Requires iOS 16+** for `Layout` protocol.

For iOS 15 support, alternative approach:
```swift
// Use GeometryReader + manual calculation
// More complex but same result
```

Current implementation assumes iOS 16+ (standard for modern apps).

## Usage

```swift
WrappingHStack(horizontalSpacing: Theme.Spacing.sm, verticalSpacing: Theme.Spacing.sm) {
    ForEach(categories) { category in
        CategoryChip(category: category, ...)
    }

    if hasMore {
        ExpandButton(...)
    }
}
```

**Parameters**:
- `horizontalSpacing`: Gap between chips in same row
- `verticalSpacing`: Gap between rows

## Debugging

To visualize layout:
```swift
WrappingHStack(...) {
    // content
}
.border(Color.red)  // See container bounds
```

Each chip can also show its bounds:
```swift
CategoryChip(...)
    .border(Color.blue)  // See chip bounds
```

## Future Enhancements

1. **Justify Content**: Spread chips evenly across row
2. **Alignment**: Left, center, right alignment options
3. **Min/Max Constraints**: Optional min/max widths per chip
4. **Priority**: Let some chips expand more than others
5. **Animation**: Animate layout changes smoothly

## Summary

✅ **Content-sized chips** - each fits its content
✅ **True wrapping** - like CSS flexbox
✅ **Optimal space usage** - no wasted space
✅ **More items visible** - fits more per row
✅ **Natural appearance** - balanced and proportional
✅ **Accessible** - adapts to font sizes

The wrapping layout now works like a **professional tag/chip system** - each item takes exactly the space it needs, and items flow naturally across rows.
