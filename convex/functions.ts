import { mutation, query, QueryCtx } from "./_generated/server";
import {
  customQuery,
  customCtx,
  customMutation,
} from "convex-helpers/server/customFunctions";

async function authCheck(ctx: QueryCtx) {
  const identity = await ctx.auth.getUserIdentity();
  if (identity === null) {
    throw new Error("Not authenticated");
  }

  // Look up user by Clerk subject ID
  const user = await ctx.db
    .query("users")
    .withIndex("by_clerkId", (q) => q.eq("clerkId", identity.subject))
    .unique();
  if (!user) {
    throw new Error("User not found in DB");
  }

  return { identity, user };
}

export const userQuery = customQuery(
  query,
  customCtx(async (ctx) => {
    return await authCheck(ctx);
  })
);

export const userMutation = customMutation(
  mutation,
  customCtx(async (ctx) => {
    return await authCheck(ctx);
  })
);
