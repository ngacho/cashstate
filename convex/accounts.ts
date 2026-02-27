import { userQuery, userMutation } from "./functions";
import { v } from "convex/values";

export const listItems = userQuery({
  args: {},
  handler: async (ctx) => {
    return await ctx.db
      .query("simplefinItems")
      .withIndex("by_userId", (q) => q.eq("userId", ctx.user._id))
      .collect();
  },
});

export const listAccounts = userQuery({
  args: {
    itemId: v.id("simplefinItems"),
  },
  handler: async (ctx, args) => {
    // Verify ownership of the item
    const item = await ctx.db.get(args.itemId);
    if (!item || item.userId !== ctx.user._id) {
      throw new Error("Item not found or access denied");
    }
    return await ctx.db
      .query("simplefinAccounts")
      .withIndex("by_itemId", (q) => q.eq("simplefinItemId", args.itemId))
      .collect();
  },
});

export const listAllAccounts = userQuery({
  args: {},
  handler: async (ctx) => {
    return await ctx.db
      .query("simplefinAccounts")
      .withIndex("by_userId", (q) => q.eq("userId", ctx.user._id))
      .collect();
  },
});

export const disconnect = userMutation({
  args: {
    itemId: v.id("simplefinItems"),
  },
  handler: async (ctx, args) => {
    const item = await ctx.db.get(args.itemId);
    if (!item || item.userId !== ctx.user._id) {
      throw new Error("Item not found or access denied");
    }

    // Get all accounts for this item
    const accounts = await ctx.db
      .query("simplefinAccounts")
      .withIndex("by_itemId", (q) => q.eq("simplefinItemId", args.itemId))
      .collect();

    // Delete transactions for each account
    for (const account of accounts) {
      const transactions = await ctx.db
        .query("simplefinTransactions")
        .withIndex("by_accountId", (q) => q.eq("accountId", account._id))
        .collect();
      for (const tx of transactions) {
        await ctx.db.delete(tx._id);
      }
      await ctx.db.delete(account._id);
    }

    // Delete the item itself
    await ctx.db.delete(args.itemId);
    return { success: true };
  },
});

export const createItem = userMutation({
  args: {
    accessUrl: v.string(),
    institutionName: v.optional(v.string()),
    status: v.string(),
  },
  handler: async (ctx, args) => {
    const itemId = await ctx.db.insert("simplefinItems", {
      userId: ctx.user._id,
      accessUrl: args.accessUrl,
      institutionName: args.institutionName,
      status: args.status,
    });
    return await ctx.db.get(itemId);
  },
});
