"use node";

import { internalAction } from "./_generated/server";
import { api, internal } from "./_generated/api";

export const dailySync = internalAction({
  args: {},
  handler: async (ctx) => {
    const items = await ctx.runQuery(internal.cronHelpers._getActiveItems, {});

    for (const item of items) {
      try {
        // Fetch transactions from the last 30 days
        const thirtyDaysAgo = Math.floor((Date.now() - 30 * 24 * 60 * 60 * 1000) / 1000);
        await ctx.runAction(api.actions.simplefinSync.sync, {
          userId: item.userId,
          itemId: item._id,
          forceSync: true,
          startDate: thirtyDaysAgo,
        });
      } catch (e: any) {
        console.error(`Cron sync failed for item ${item._id}: ${e.message}`);
      }
    }
  },
});

export const dailySnapshot = internalAction({
  args: {},
  handler: async (ctx) => {
    const users = await ctx.runQuery(
      internal.cronHelpers._getUsersWithAccounts,
      {}
    );

    for (const userId of users) {
      try {
        await ctx.runMutation(internal.cronHelpers._calculateSnapshot, {
          userId,
        });
      } catch (e: any) {
        console.error(
          `Cron snapshot failed for user ${userId}: ${e.message}`
        );
      }
    }
  },
});
