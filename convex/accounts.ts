import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { validateUser } from "./helpers";

export const listItems = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    return await ctx.db
      .query("simplefinItems")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();
  },
});

export const listAccounts = query({
  args: {
    userId: v.id("users"),
    itemId: v.id("simplefinItems"),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    // Verify ownership of the item
    const item = await ctx.db.get(args.itemId);
    if (!item || item.userId !== args.userId) {
      throw new Error("Item not found or access denied");
    }
    return await ctx.db
      .query("simplefinAccounts")
      .withIndex("by_itemId", (q) => q.eq("simplefinItemId", args.itemId))
      .collect();
  },
});

export const listAllAccounts = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    return await ctx.db
      .query("simplefinAccounts")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();
  },
});

export const disconnect = mutation({
  args: {
    userId: v.id("users"),
    itemId: v.id("simplefinItems"),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    const item = await ctx.db.get(args.itemId);
    if (!item || item.userId !== args.userId) {
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

export const createItem = mutation({
  args: {
    userId: v.id("users"),
    accessUrl: v.string(),
    institutionName: v.optional(v.string()),
    status: v.string(),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    const itemId = await ctx.db.insert("simplefinItems", {
      userId: args.userId,
      accessUrl: args.accessUrl,
      institutionName: args.institutionName,
      status: args.status,
    });
    return await ctx.db.get(itemId);
  },
});
