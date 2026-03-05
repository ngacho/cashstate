import { mutation, query } from "./_generated/server";
import {
  customQuery,
  customMutation,
} from "convex-helpers/server/customFunctions";
import { v } from "convex/values";

export const userQuery = customQuery(query, {
  args: { clerkId: v.string() },
  input: async (ctx, { clerkId }) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerkId", (q) => q.eq("clerkId", clerkId))
      .unique();
    if (!user) throw new Error("User not found in DB");
    return { ctx: { ...ctx, user }, args: {} };
  },
});

export const userMutation = customMutation(mutation, {
  args: { clerkId: v.string() },
  input: async (ctx, { clerkId }) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerkId", (q) => q.eq("clerkId", clerkId))
      .unique();
    if (!user) throw new Error("User not found in DB");
    return { ctx: { ...ctx, user }, args: {} };
  },
});
