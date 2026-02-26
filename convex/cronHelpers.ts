import { internalQuery, internalMutation } from "./_generated/server";
import { v } from "convex/values";

export const _getActiveItems = internalQuery({
  args: {},
  handler: async (ctx) => {
    return await ctx.db
      .query("simplefinItems")
      .filter((q) => q.eq(q.field("status"), "active"))
      .collect();
  },
});

export const _getUsersWithAccounts = internalQuery({
  args: {},
  handler: async (ctx) => {
    const accounts = await ctx.db.query("simplefinAccounts").collect();
    const userIds = new Set(accounts.map((a) => a.userId));
    return Array.from(userIds);
  },
});

export const _calculateSnapshot = internalMutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const today = new Date().toISOString().split("T")[0];
    const accounts = await ctx.db
      .query("simplefinAccounts")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();

    for (const account of accounts) {
      if (account.balance === undefined) continue;

      const existing = await ctx.db
        .query("accountBalanceHistory")
        .withIndex("by_userId_account_date", (q) =>
          q
            .eq("userId", args.userId)
            .eq("simplefinAccountId", account._id)
            .eq("snapshotDate", today)
        )
        .first();

      if (existing) {
        await ctx.db.patch(existing._id, { balance: account.balance });
      } else {
        await ctx.db.insert("accountBalanceHistory", {
          userId: args.userId,
          simplefinAccountId: account._id,
          snapshotDate: today,
          balance: account.balance,
        });
      }
    }
  },
});
