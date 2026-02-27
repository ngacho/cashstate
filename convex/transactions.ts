import { userQuery, userMutation } from "./functions";
import { v } from "convex/values";
import { paginationOptsValidator } from "convex/server";

export const list = userQuery({
  args: {
    paginationOpts: paginationOptsValidator,
    dateFrom: v.optional(v.number()),
    dateTo: v.optional(v.number()),
    accountIds: v.optional(v.array(v.id("simplefinAccounts"))),
  },
  handler: async (ctx, args) => {
    let q = ctx.db
      .query("simplefinTransactions")
      .withIndex("by_userId_date", (q) => {
        let idx = q.eq("userId", ctx.user._id);
        if (args.dateFrom !== undefined && args.dateTo !== undefined) {
          return idx.gte("date", args.dateFrom).lte("date", args.dateTo);
        } else if (args.dateFrom !== undefined) {
          return idx.gte("date", args.dateFrom);
        } else if (args.dateTo !== undefined) {
          return idx.lte("date", args.dateTo);
        }
        return idx;
      })
      .order("desc");

    // If accountIds filter provided, apply filter
    if (args.accountIds && args.accountIds.length > 0) {
      return await q
        .filter((qb) =>
          qb.or(
            ...args.accountIds!.map((accountId) =>
              qb.eq(qb.field("accountId"), accountId)
            )
          )
        )
        .paginate(args.paginationOpts);
    }

    return await q.paginate(args.paginationOpts);
  },
});

export const categorize = userMutation({
  args: {
    txId: v.id("simplefinTransactions"),
    categoryId: v.optional(v.id("categories")),
    subcategoryId: v.optional(v.id("subcategories")),
    createRule: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const tx = await ctx.db.get(args.txId);
    if (!tx || tx.userId !== ctx.user._id) {
      throw new Error("Transaction not found or access denied");
    }

    await ctx.db.patch(args.txId, {
      categoryId: args.categoryId,
      subcategoryId: args.subcategoryId,
      categorizationSource: "manual",
    });

    // Optionally create a categorization rule
    if (args.createRule && args.categoryId) {
      const matchValue = tx.payee || tx.description || "";
      if (matchValue) {
        await ctx.db.insert("categorizationRules", {
          userId: ctx.user._id,
          matchField: tx.payee ? "payee" : "description",
          matchValue,
          categoryId: args.categoryId,
          subcategoryId: args.subcategoryId,
        });
      }
    }

    return { success: true };
  },
});

export const batchCategorize = userMutation({
  args: {
    updates: v.array(
      v.object({
        txId: v.id("simplefinTransactions"),
        categoryId: v.optional(v.id("categories")),
        subcategoryId: v.optional(v.id("subcategories")),
      })
    ),
  },
  handler: async (ctx, args) => {
    let updatedCount = 0;
    let failedCount = 0;
    const failedIds: string[] = [];

    for (const update of args.updates) {
      try {
        const tx = await ctx.db.get(update.txId);
        if (!tx || tx.userId !== ctx.user._id) {
          failedCount++;
          failedIds.push(update.txId);
          continue;
        }
        await ctx.db.patch(update.txId, {
          categoryId: update.categoryId,
          subcategoryId: update.subcategoryId,
          categorizationSource: "manual",
        });
        updatedCount++;
      } catch {
        failedCount++;
        failedIds.push(update.txId);
      }
    }

    return { updatedCount, failedCount, failedIds };
  },
});
