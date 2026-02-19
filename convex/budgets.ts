import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { validateUser, getMonthDateRange } from "./helpers";

export const list = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    return await ctx.db
      .query("budgets")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();
  },
});

export const create = mutation({
  args: {
    userId: v.id("users"),
    name: v.string(),
    isDefault: v.boolean(),
    emoji: v.optional(v.string()),
    color: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);

    // If setting as default, unset other defaults
    if (args.isDefault) {
      const existing = await ctx.db
        .query("budgets")
        .withIndex("by_userId_isDefault", (q) =>
          q.eq("userId", args.userId).eq("isDefault", true)
        )
        .collect();
      for (const b of existing) {
        await ctx.db.patch(b._id, { isDefault: false });
      }
    }

    const id = await ctx.db.insert("budgets", {
      userId: args.userId,
      name: args.name,
      isDefault: args.isDefault,
      emoji: args.emoji,
      color: args.color,
      accountIds: [],
    });
    return await ctx.db.get(id);
  },
});

export const update = mutation({
  args: {
    userId: v.id("users"),
    id: v.id("budgets"),
    name: v.optional(v.string()),
    isDefault: v.optional(v.boolean()),
    emoji: v.optional(v.string()),
    color: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    const budget = await ctx.db.get(args.id);
    if (!budget || budget.userId !== args.userId) {
      throw new Error("Budget not found or access denied");
    }

    // If setting as default, unset other defaults
    if (args.isDefault) {
      const existing = await ctx.db
        .query("budgets")
        .withIndex("by_userId_isDefault", (q) =>
          q.eq("userId", args.userId).eq("isDefault", true)
        )
        .collect();
      for (const b of existing) {
        if (b._id !== args.id) {
          await ctx.db.patch(b._id, { isDefault: false });
        }
      }
    }

    const patch: Record<string, unknown> = {};
    if (args.name !== undefined) patch.name = args.name;
    if (args.isDefault !== undefined) patch.isDefault = args.isDefault;
    if (args.emoji !== undefined) patch.emoji = args.emoji;
    if (args.color !== undefined) patch.color = args.color;
    await ctx.db.patch(args.id, patch);
    return await ctx.db.get(args.id);
  },
});

export const deleteBudget = mutation({
  args: {
    userId: v.id("users"),
    id: v.id("budgets"),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    const budget = await ctx.db.get(args.id);
    if (!budget || budget.userId !== args.userId) {
      throw new Error("Budget not found or access denied");
    }

    // Delete line items
    const lineItems = await ctx.db
      .query("budgetLineItems")
      .withIndex("by_budgetId", (q) => q.eq("budgetId", args.id))
      .collect();
    for (const li of lineItems) {
      await ctx.db.delete(li._id);
    }

    // Delete months
    const months = await ctx.db
      .query("budgetMonths")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .filter((q) => q.eq(q.field("budgetId"), args.id))
      .collect();
    for (const m of months) {
      await ctx.db.delete(m._id);
    }

    await ctx.db.delete(args.id);
    return { success: true };
  },
});

// Line Items

export const listLineItems = query({
  args: {
    userId: v.id("users"),
    budgetId: v.id("budgets"),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    const budget = await ctx.db.get(args.budgetId);
    if (!budget || budget.userId !== args.userId) {
      throw new Error("Budget not found or access denied");
    }
    return await ctx.db
      .query("budgetLineItems")
      .withIndex("by_budgetId", (q) => q.eq("budgetId", args.budgetId))
      .collect();
  },
});

export const createLineItem = mutation({
  args: {
    userId: v.id("users"),
    budgetId: v.id("budgets"),
    categoryId: v.id("categories"),
    subcategoryId: v.optional(v.id("subcategories")),
    amount: v.number(),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    const budget = await ctx.db.get(args.budgetId);
    if (!budget || budget.userId !== args.userId) {
      throw new Error("Budget not found or access denied");
    }
    const id = await ctx.db.insert("budgetLineItems", {
      budgetId: args.budgetId,
      categoryId: args.categoryId,
      subcategoryId: args.subcategoryId,
      amount: args.amount,
    });
    return await ctx.db.get(id);
  },
});

export const updateLineItem = mutation({
  args: {
    userId: v.id("users"),
    id: v.id("budgetLineItems"),
    amount: v.number(),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    const lineItem = await ctx.db.get(args.id);
    if (!lineItem) {
      throw new Error("Line item not found");
    }
    const budget = await ctx.db.get(lineItem.budgetId);
    if (!budget || budget.userId !== args.userId) {
      throw new Error("Access denied");
    }
    await ctx.db.patch(args.id, { amount: args.amount });
    return await ctx.db.get(args.id);
  },
});

export const deleteLineItem = mutation({
  args: {
    userId: v.id("users"),
    id: v.id("budgetLineItems"),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    const lineItem = await ctx.db.get(args.id);
    if (!lineItem) {
      throw new Error("Line item not found");
    }
    const budget = await ctx.db.get(lineItem.budgetId);
    if (!budget || budget.userId !== args.userId) {
      throw new Error("Access denied");
    }
    await ctx.db.delete(args.id);
    return { success: true };
  },
});

// Months

export const listMonths = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    return await ctx.db
      .query("budgetMonths")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();
  },
});

export const assignMonth = mutation({
  args: {
    userId: v.id("users"),
    budgetId: v.id("budgets"),
    month: v.string(),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    const budget = await ctx.db.get(args.budgetId);
    if (!budget || budget.userId !== args.userId) {
      throw new Error("Budget not found or access denied");
    }

    // Check if month is already assigned
    const existing = await ctx.db
      .query("budgetMonths")
      .withIndex("by_userId_month", (q) =>
        q.eq("userId", args.userId).eq("month", args.month)
      )
      .first();
    if (existing) {
      // Update existing assignment
      await ctx.db.patch(existing._id, { budgetId: args.budgetId });
      return await ctx.db.get(existing._id);
    }

    const id = await ctx.db.insert("budgetMonths", {
      budgetId: args.budgetId,
      userId: args.userId,
      month: args.month,
    });
    return await ctx.db.get(id);
  },
});

export const deleteMonth = mutation({
  args: {
    userId: v.id("users"),
    id: v.id("budgetMonths"),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    const month = await ctx.db.get(args.id);
    if (!month || month.userId !== args.userId) {
      throw new Error("Budget month not found or access denied");
    }
    await ctx.db.delete(args.id);
    return { success: true };
  },
});

// Accounts

export const listAccounts = query({
  args: {
    userId: v.id("users"),
    budgetId: v.id("budgets"),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    const budget = await ctx.db.get(args.budgetId);
    if (!budget || budget.userId !== args.userId) {
      throw new Error("Budget not found or access denied");
    }

    const items = await Promise.all(
      budget.accountIds.map(async (accountId) => {
        const account = await ctx.db.get(accountId);
        return {
          budgetId: budget._id,
          accountId,
          accountName: account?.name ?? "Unknown",
          balance: account?.balance ?? 0,
          createdAt: "",
        };
      })
    );

    return items;
  },
});

export const addAccount = mutation({
  args: {
    userId: v.id("users"),
    budgetId: v.id("budgets"),
    accountId: v.id("simplefinAccounts"),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    const budget = await ctx.db.get(args.budgetId);
    if (!budget || budget.userId !== args.userId) {
      throw new Error("Budget not found or access denied");
    }
    const account = await ctx.db.get(args.accountId);
    if (!account || account.userId !== args.userId) {
      throw new Error("Account not found or access denied");
    }

    if (!budget.accountIds.includes(args.accountId)) {
      await ctx.db.patch(args.budgetId, {
        accountIds: [...budget.accountIds, args.accountId],
      });
    }

    return {
      budgetId: args.budgetId,
      accountId: args.accountId,
      accountName: account.name,
      balance: account.balance ?? 0,
      createdAt: "",
    };
  },
});

export const removeAccount = mutation({
  args: {
    userId: v.id("users"),
    budgetId: v.id("budgets"),
    accountId: v.id("simplefinAccounts"),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    const budget = await ctx.db.get(args.budgetId);
    if (!budget || budget.userId !== args.userId) {
      throw new Error("Budget not found or access denied");
    }
    await ctx.db.patch(args.budgetId, {
      accountIds: budget.accountIds.filter((id) => id !== args.accountId),
    });
    return { success: true };
  },
});

// Summary

export const summary = query({
  args: {
    userId: v.id("users"),
    month: v.string(),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    const { startMs, endMs } = getMonthDateRange(args.month);

    // 1. Resolve active budget: check budgetMonths override → fallback to isDefault
    let budgetId: string | null = null;
    const monthOverride = await ctx.db
      .query("budgetMonths")
      .withIndex("by_userId_month", (q) =>
        q.eq("userId", args.userId).eq("month", args.month)
      )
      .first();

    if (monthOverride) {
      budgetId = monthOverride.budgetId;
    } else {
      const defaultBudget = await ctx.db
        .query("budgets")
        .withIndex("by_userId_isDefault", (q) =>
          q.eq("userId", args.userId).eq("isDefault", true)
        )
        .first();
      if (defaultBudget) {
        budgetId = defaultBudget._id;
      }
    }

    if (!budgetId) {
      return {
        budgetId: null,
        budgetName: null,
        month: args.month,
        totalBudgeted: 0,
        totalSpent: 0,
        lineItems: [],
        unbudgetedCategories: [],
        subcategorySpending: {},
        uncategorizedSpending: 0,
        accountIds: [],
      };
    }

    const budget = await ctx.db.get(budgetId as any);
    if (!budget) {
      throw new Error("Budget not found");
    }

    // 2. Get line items
    const lineItems = await ctx.db
      .query("budgetLineItems")
      .withIndex("by_budgetId", (q) => q.eq("budgetId", budget._id))
      .collect();

    // 3. Fetch transactions for month range
    const transactions = await ctx.db
      .query("simplefinTransactions")
      .withIndex("by_userId_date", (q) =>
        q
          .eq("userId", args.userId)
          .gte("date", startMs)
          .lt("date", endMs)
      )
      .collect();

    // Filter by budget's accountIds if specified
    const budgetAccountIds = new Set(
      budget.accountIds.map((id) => id.toString())
    );
    const filteredTxns =
      budget.accountIds.length > 0
        ? transactions.filter((tx) =>
            budgetAccountIds.has(tx.accountId.toString())
          )
        : transactions;

    // 4. Aggregate spending by categoryId/subcategoryId (expenses only)
    const spendingByCategory = new Map<string, number>();
    const spendingBySubcategory = new Map<string, number>();
    let uncategorizedSpending = 0;

    for (const tx of filteredTxns) {
      if (tx.amount >= 0) continue; // Only expenses (negative amounts)
      const absAmount = Math.abs(tx.amount);

      if (tx.categoryId) {
        const key = tx.categoryId.toString();
        spendingByCategory.set(
          key,
          (spendingByCategory.get(key) ?? 0) + absAmount
        );
        if (tx.subcategoryId) {
          const subKey = tx.subcategoryId.toString();
          spendingBySubcategory.set(
            subKey,
            (spendingBySubcategory.get(subKey) ?? 0) + absAmount
          );
        }
      } else {
        uncategorizedSpending += absAmount;
      }
    }

    // 5. Compute per-line-item spent/remaining
    const budgetedCategoryIds = new Set<string>();
    const summaryLineItems = lineItems.map((li) => {
      const catKey = li.categoryId.toString();
      budgetedCategoryIds.add(catKey);
      const spent = li.subcategoryId
        ? spendingBySubcategory.get(li.subcategoryId.toString()) ?? 0
        : spendingByCategory.get(catKey) ?? 0;
      return {
        id: li._id,
        budgetId: li.budgetId,
        categoryId: li.categoryId,
        subcategoryId: li.subcategoryId ?? null,
        amount: li.amount,
        spent: Math.round(spent * 100) / 100,
        remaining: Math.round((li.amount - spent) * 100) / 100,
      };
    });

    // 6. Find unbudgeted categories
    const unbudgetedCategories: { categoryId: string; spent: number }[] = [];
    for (const [catId, spent] of spendingByCategory) {
      if (!budgetedCategoryIds.has(catId)) {
        unbudgetedCategories.push({
          categoryId: catId,
          spent: Math.round(spent * 100) / 100,
        });
      }
    }

    // 7. Build subcategory spending map
    const subcategorySpending: Record<string, number> = {};
    for (const [subId, spent] of spendingBySubcategory) {
      subcategorySpending[subId] = Math.round(spent * 100) / 100;
    }

    const totalBudgeted = lineItems.reduce((sum, li) => sum + li.amount, 0);
    const totalSpent = filteredTxns
      .filter((tx) => tx.amount < 0)
      .reduce((sum, tx) => sum + Math.abs(tx.amount), 0);

    // Check whether adjacent months have transactions (account-scoped)
    const nowMs = Date.now();

    const prevTxCandidates = await ctx.db
      .query("simplefinTransactions")
      .withIndex("by_userId_date", (q) =>
        q.eq("userId", args.userId).lt("date", startMs)
      )
      .order("desc")
      .filter((q) =>
        budget.accountIds.length === 0
          ? q.eq(q.field("userId"), args.userId) // no-op, always true
          : q.or(
              ...budget.accountIds.map((id) =>
                q.eq(q.field("accountId"), id)
              )
            )
      )
      .first();
    const hasPreviousMonth = prevTxCandidates !== null;

    const nextTxCandidates = await ctx.db
      .query("simplefinTransactions")
      .withIndex("by_userId_date", (q) =>
        q.eq("userId", args.userId).gte("date", endMs).lt("date", nowMs)
      )
      .order("asc")
      .filter((q) =>
        budget.accountIds.length === 0
          ? q.eq(q.field("userId"), args.userId) // no-op, always true
          : q.or(
              ...budget.accountIds.map((id) =>
                q.eq(q.field("accountId"), id)
              )
            )
      )
      .first();
    const hasNextMonth = nextTxCandidates !== null;

    return {
      budgetId: budget._id,
      budgetName: budget.name,
      month: args.month,
      totalBudgeted: Math.round(totalBudgeted * 100) / 100,
      totalSpent: Math.round(totalSpent * 100) / 100,
      lineItems: summaryLineItems,
      unbudgetedCategories,
      subcategorySpending,
      uncategorizedSpending: Math.round(uncategorizedSpending * 100) / 100,
      accountIds: budget.accountIds,
      hasPreviousMonth,
      hasNextMonth,
    };
  },
});
