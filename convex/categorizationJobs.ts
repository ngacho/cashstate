import { mutation, query } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import { validateUser } from "./helpers";

export const start = mutation({
  args: {
    userId: v.id("users"),
    transactionIds: v.optional(v.array(v.id("simplefinTransactions"))),
    force: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);

    // Count uncategorized transactions to determine job size
    let totalTransactions = 0;
    if (args.transactionIds && args.transactionIds.length > 0) {
      totalTransactions = args.transactionIds.length;
    } else {
      const txns = await ctx.db
        .query("simplefinTransactions")
        .withIndex("by_userId", (q) => q.eq("userId", args.userId))
        .collect();
      totalTransactions = txns.filter(
        (tx) => args.force || !tx.categoryId
      ).length;
    }

    // Create the job record
    const jobId = await ctx.db.insert("categorizationJobs", {
      userId: args.userId,
      status: "running",
      totalTransactions,
      categorizedCount: 0,
      failedCount: 0,
    });

    // Schedule the background action
    await ctx.scheduler.runAfter(
      0,
      internal.actions.aiCategorize._categorizeBackground,
      {
        userId: args.userId,
        jobId,
        transactionIds: args.transactionIds,
        force: args.force,
      }
    );

    return { jobId };
  },
});

export const getStatus = query({
  args: {
    userId: v.id("users"),
    jobId: v.id("categorizationJobs"),
  },
  handler: async (ctx, args) => {
    await validateUser(ctx, args.userId);
    const job = await ctx.db.get(args.jobId);
    if (!job || job.userId !== args.userId) {
      throw new Error("Job not found or access denied");
    }
    return job;
  },
});
