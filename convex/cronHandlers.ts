"use node";

import { internalAction } from "./_generated/server";
import { internal } from "./_generated/api";

export const dailySync = internalAction({
  args: {},
  handler: async (ctx) => {
    const items = await ctx.runQuery(internal.cronHelpers._getActiveItems, {});
    console.log(`[dailySync] Starting sync for ${items.length} active items`);

    for (const item of items) {
      try {
        // Always sync from last day of last month
        const now = new Date();
        const lastDayOfLastMonth = new Date(now.getFullYear(), now.getMonth(), 0);
        lastDayOfLastMonth.setHours(0, 0, 0, 0);
        const startDate = Math.floor(lastDayOfLastMonth.getTime() / 1000);
        console.log(
          `[dailySync] Syncing item=${item._id}, userId=${item.userId}, ` +
          `lastSyncedAt=${item.lastSyncedAt ? new Date(item.lastSyncedAt).toISOString() : "never"}, ` +
          `startDate=${lastDayOfLastMonth.toISOString()} (epoch=${startDate})`
        );
        await ctx.runAction(internal.actions.simplefinSync._syncInternal, {
          userId: item.userId,
          itemId: item._id,
          forceSync: true,
          startDate,
        });
        console.log(`[dailySync] Sync completed for item=${item._id}`);
      } catch (e: any) {
        console.error(`[dailySync] Sync FAILED for item ${item._id}: ${e.message}`);
      }
    }
    console.log(`[dailySync] Finished all items`);
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
