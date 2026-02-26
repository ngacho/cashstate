"use node";

import { internalAction } from "./_generated/server";
import { api, internal } from "./_generated/api";

export const dailySync = internalAction({
  args: {},
  handler: async (ctx) => {
    console.log(`[CRON_SYNC] Daily sync starting at ${new Date().toISOString()}`);
    const items = await ctx.runQuery(internal.cronHelpers._getActiveItems, {});
    console.log(`[CRON_SYNC] Found ${items.length} active items to sync`);

    for (const item of items) {
      console.log(`[CRON_SYNC] Syncing item ${item._id} for userId=${item.userId}, institution="${item.institutionName}", lastSynced=${item.lastSyncedAt ? new Date(item.lastSyncedAt).toISOString() : 'never'}`);
      try {
        // Fetch transactions from the last 30 days
        const thirtyDaysAgo = Math.floor((Date.now() - 30 * 24 * 60 * 60 * 1000) / 1000);
        await ctx.runAction(api.actions.simplefinSync.sync, {
          userId: item.userId,
          itemId: item._id,
          forceSync: true,
          startDate: thirtyDaysAgo,
        });
        console.log(`[CRON_SYNC] Successfully synced item ${item._id}`);
      } catch (e: any) {
        console.error(`[CRON_SYNC] FAILED for item ${item._id}: ${e.message}`);
      }
    }
    console.log(`[CRON_SYNC] Daily sync finished at ${new Date().toISOString()}`);
  },
});

export const dailySnapshot = internalAction({
  args: {},
  handler: async (ctx) => {
    console.log(`[CRON_SNAPSHOT] Daily snapshot starting at ${new Date().toISOString()}`);
    const users = await ctx.runQuery(
      internal.cronHelpers._getUsersWithAccounts,
      {}
    );
    console.log(`[CRON_SNAPSHOT] Found ${users.length} users with accounts`);

    for (const userId of users) {
      console.log(`[CRON_SNAPSHOT] Calculating snapshot for userId=${userId}`);
      try {
        await ctx.runMutation(internal.cronHelpers._calculateSnapshot, {
          userId,
        });
        console.log(`[CRON_SNAPSHOT] Successfully snapshotted userId=${userId}`);
      } catch (e: any) {
        console.error(
          `[CRON_SNAPSHOT] FAILED for user ${userId}: ${e.message}`
        );
      }
    }
    console.log(`[CRON_SNAPSHOT] Daily snapshot finished at ${new Date().toISOString()}`);
  },
});
