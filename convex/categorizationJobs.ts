import { internal } from "./_generated/api";
import { v } from "convex/values";
import { userQuery, userMutation } from "./functions";

export const start = userMutation({
  args: {
    transactionIds: v.optional(v.array(v.id("simplefinTransactions"))),
    force: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    // Count uncategorized transactions to determine job size
    let totalTransactions = 0;
    if (args.transactionIds && args.transactionIds.length > 0) {
      totalTransactions = args.transactionIds.length;
    } else {
      const txns = await ctx.db
        .query("simplefinTransactions")
        .withIndex("by_userId", (q) => q.eq("userId", ctx.user._id))
        .collect();
      totalTransactions = txns.filter(
        (tx) => args.force || !tx.categoryId
      ).length;
    }

    // Create the job record
    const jobId = await ctx.db.insert("categorizationJobs", {
      userId: ctx.user._id,
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
        userId: ctx.user._id,
        jobId,
        transactionIds: args.transactionIds,
        force: args.force,
      }
    );

    return { jobId };
  },
});

export const getStatus = userQuery({
  args: {
    jobId: v.id("categorizationJobs"),
  },
  handler: async (ctx, args) => {
    const job = await ctx.db.get(args.jobId);
    if (!job || job.userId !== ctx.user._id) {
      throw new Error("Job not found or access denied");
    }
    return job;
  },
});
