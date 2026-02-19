import { internalQuery, internalMutation } from "./_generated/server";
import { v } from "convex/values";

export const _getRules = internalQuery({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("categorizationRules")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();
  },
});

export const _getUncategorizedTransactions = internalQuery({
  args: {
    userId: v.id("users"),
    transactionIds: v.optional(v.array(v.id("simplefinTransactions"))),
    force: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    if (args.transactionIds && args.transactionIds.length > 0) {
      const txns = await Promise.all(
        args.transactionIds.map((id) => ctx.db.get(id))
      );
      return txns.filter(
        (tx) =>
          tx &&
          tx.userId === args.userId &&
          (args.force || !tx.categoryId)
      );
    }

    const txns = await ctx.db
      .query("simplefinTransactions")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();

    return txns.filter((tx) => args.force || !tx.categoryId);
  },
});

export const _getCategories = internalQuery({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const categories = await ctx.db
      .query("categories")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();

    const result = await Promise.all(
      categories.map(async (cat) => {
        const subcategories = await ctx.db
          .query("subcategories")
          .withIndex("by_categoryId", (q) => q.eq("categoryId", cat._id))
          .collect();
        return { ...cat, subcategories };
      })
    );

    return result;
  },
});

export const _createCategorizationJob = internalMutation({
  args: {
    userId: v.id("users"),
    totalTransactions: v.number(),
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("categorizationJobs", {
      userId: args.userId,
      status: "running",
      totalTransactions: args.totalTransactions,
      categorizedCount: 0,
      failedCount: 0,
    });
  },
});

export const _updateCategorizationJob = internalMutation({
  args: {
    id: v.id("categorizationJobs"),
    status: v.optional(v.string()),
    categorizedCount: v.optional(v.number()),
    failedCount: v.optional(v.number()),
    errorMessage: v.optional(v.string()),
    completedAt: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const patch: Record<string, unknown> = {};
    if (args.status !== undefined) patch.status = args.status;
    if (args.categorizedCount !== undefined) patch.categorizedCount = args.categorizedCount;
    if (args.failedCount !== undefined) patch.failedCount = args.failedCount;
    if (args.errorMessage !== undefined) patch.errorMessage = args.errorMessage;
    if (args.completedAt !== undefined) patch.completedAt = args.completedAt;
    await ctx.db.patch(args.id, patch);
  },
});

export const _batchUpdateCategories = internalMutation({
  args: {
    updates: v.array(
      v.object({
        txId: v.id("simplefinTransactions"),
        categoryId: v.id("categories"),
        subcategoryId: v.optional(v.id("subcategories")),
        source: v.string(),
      })
    ),
  },
  handler: async (ctx, args) => {
    for (const update of args.updates) {
      await ctx.db.patch(update.txId, {
        categoryId: update.categoryId,
        subcategoryId: update.subcategoryId,
        categorizationSource: update.source,
      });
    }
  },
});
