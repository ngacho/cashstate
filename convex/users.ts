import { internalMutation, mutation, query } from "./_generated/server";
import { v } from "convex/values";

// Diagnostic: no-auth lookup by clerkId — used by iOS isolation test to confirm
// whether the user row exists independently of JWT auth.
export const getByClerkId = query({
  args: { clerkId: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerkId", (q) => q.eq("clerkId", args.clerkId))
      .unique();
    return user ? { found: true, email: user.email } : { found: false, email: null };
  },
});

// Called by Clerk webhook on user.created / user.updated
export const upsertFromWebhook = internalMutation({
  args: {
    clerkId: v.string(),
    email: v.string(),
    firstName: v.optional(v.string()),
    lastName: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("users")
      .withIndex("by_clerkId", (q) => q.eq("clerkId", args.clerkId))
      .unique();

    if (existing) {
      await ctx.db.patch(existing._id, {
        email: args.email,
        firstName: args.firstName,
        lastName: args.lastName,
      });
      return existing._id;
    }

    return await ctx.db.insert("users", {
      clerkId: args.clerkId,
      email: args.email,
      firstName: args.firstName,
      lastName: args.lastName,
      createdAt: Date.now(),
    });
  },
});

// Called by Clerk webhook on user.deleted — cascades all user data
export const deleteFromWebhook = internalMutation({
  args: { clerkId: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerkId", (q) => q.eq("clerkId", args.clerkId))
      .unique();
    if (!user) return;

    const userId = user._id;

    // Delete budgetLineItems via budgets (indexed by budgetId, not userId)
    const budgets = await ctx.db
      .query("budgets")
      .withIndex("by_userId", (q) => q.eq("userId", userId))
      .collect();
    for (const budget of budgets) {
      const lineItems = await ctx.db
        .query("budgetLineItems")
        .withIndex("by_budgetId", (q) => q.eq("budgetId", budget._id))
        .collect();
      for (const item of lineItems) {
        await ctx.db.delete(item._id);
      }
    }

    // Helper to delete all rows in a table by userId index
    async function deleteByUserId<T extends "categorizationJobs" | "syncJobs" | "accountBalanceHistory" | "budgetMonths" | "goals" | "categorizationRules" | "subcategories" | "categories" | "simplefinTransactions" | "simplefinAccounts" | "simplefinItems" | "budgets">(table: T) {
      const rows = await ctx.db
        .query(table)
        .withIndex("by_userId", (q: any) => q.eq("userId", userId))
        .collect();
      for (const row of rows) {
        await ctx.db.delete(row._id);
      }
    }

    // Delete all userId-indexed tables (children before parents)
    await deleteByUserId("categorizationJobs");
    await deleteByUserId("syncJobs");
    await deleteByUserId("accountBalanceHistory");
    await deleteByUserId("budgetMonths");
    await deleteByUserId("goals");
    await deleteByUserId("categorizationRules");
    await deleteByUserId("subcategories");
    await deleteByUserId("categories");
    await deleteByUserId("simplefinTransactions");
    await deleteByUserId("simplefinAccounts");
    await deleteByUserId("simplefinItems");
    await deleteByUserId("budgets");

    // Finally delete the user record
    await ctx.db.delete(userId);
  },
});
