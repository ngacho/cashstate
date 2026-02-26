import { internalMutation, internalQuery } from "./_generated/server";
import { v } from "convex/values";

export const _storeItem = internalMutation({
  args: {
    userId: v.id("users"),
    accessUrl: v.string(),
    institutionName: v.optional(v.string()),
    status: v.string(),
  },
  handler: async (ctx, args) => {
    const id = await ctx.db.insert("simplefinItems", {
      userId: args.userId,
      accessUrl: args.accessUrl,
      institutionName: args.institutionName,
      status: args.status,
    });
    return id;
  },
});

export const _getItem = internalQuery({
  args: { itemId: v.id("simplefinItems") },
  handler: async (ctx, args) => {
    return await ctx.db.get(args.itemId);
  },
});

export const _upsertAccounts = internalMutation({
  args: {
    userId: v.id("users"),
    itemId: v.id("simplefinItems"),
    accounts: v.array(
      v.object({
        simplefinAccountId: v.string(),
        name: v.string(),
        currency: v.string(),
        balance: v.optional(v.number()),
        availableBalance: v.optional(v.number()),
        balanceDate: v.optional(v.number()),
        orgName: v.optional(v.string()),
      })
    ),
  },
  handler: async (ctx, args) => {
    console.log(`[UPSERT_ACCOUNTS] Processing ${args.accounts.length} accounts for userId=${args.userId}, itemId=${args.itemId}`);
    const results: string[] = [];
    for (const acc of args.accounts) {
      const existing = await ctx.db
        .query("simplefinAccounts")
        .withIndex("by_externalId", (q) =>
          q
            .eq("userId", args.userId)
            .eq("simplefinItemId", args.itemId)
            .eq("simplefinAccountId", acc.simplefinAccountId)
        )
        .first();

      if (existing) {
        console.log(`[UPSERT_ACCOUNTS] Updating existing account "${acc.name}" (${existing._id}): balance ${existing.balance} -> ${acc.balance}`);
        await ctx.db.patch(existing._id, {
          name: acc.name,
          currency: acc.currency,
          balance: acc.balance,
          availableBalance: acc.availableBalance,
          balanceDate: acc.balanceDate,
          orgName: acc.orgName,
        });
        results.push(existing._id);
      } else {
        console.log(`[UPSERT_ACCOUNTS] Inserting new account "${acc.name}" (externalId=${acc.simplefinAccountId}), balance=${acc.balance}`);
        const id = await ctx.db.insert("simplefinAccounts", {
          userId: args.userId,
          simplefinItemId: args.itemId,
          simplefinAccountId: acc.simplefinAccountId,
          name: acc.name,
          currency: acc.currency,
          balance: acc.balance,
          availableBalance: acc.availableBalance,
          balanceDate: acc.balanceDate,
          orgName: acc.orgName,
        });
        results.push(id);
      }
    }
    return results;
  },
});

export const _upsertTransactions = internalMutation({
  args: {
    userId: v.id("users"),
    accountId: v.id("simplefinAccounts"),
    accountName: v.string(),
    transactions: v.array(
      v.object({
        simplefinTxId: v.string(),
        amount: v.number(),
        currency: v.string(),
        date: v.number(),
        transactedAt: v.optional(v.number()),
        description: v.optional(v.string()),
        payee: v.optional(v.string()),
        pending: v.boolean(),
      })
    ),
  },
  handler: async (ctx, args) => {
    console.log(`[UPSERT_TX] Processing ${args.transactions.length} transactions for account "${args.accountName}" (${args.accountId})`);
    let added = 0;
    let updated = 0;

    for (const tx of args.transactions) {
      const existing = await ctx.db
        .query("simplefinTransactions")
        .withIndex("by_txId", (q) =>
          q.eq("userId", args.userId).eq("simplefinTxId", tx.simplefinTxId)
        )
        .first();

      if (existing) {
        const changes: string[] = [];
        if (existing.amount !== tx.amount) changes.push(`amount: ${existing.amount} -> ${tx.amount}`);
        if (existing.pending !== tx.pending) changes.push(`pending: ${existing.pending} -> ${tx.pending}`);
        if (existing.description !== tx.description) changes.push(`desc: "${existing.description}" -> "${tx.description}"`);
        if (existing.date !== tx.date) changes.push(`date: ${existing.date} -> ${tx.date}`);
        if (changes.length > 0) {
          console.log(`[UPSERT_TX] Updating tx "${tx.simplefinTxId}": ${changes.join(', ')}`);
        }
        await ctx.db.patch(existing._id, {
          amount: tx.amount,
          currency: tx.currency,
          date: tx.date,
          transactedAt: tx.transactedAt,
          description: tx.description,
          payee: tx.payee,
          pending: tx.pending,
        });
        updated++;
      } else {
        console.log(`[UPSERT_TX] Inserting new tx: id="${tx.simplefinTxId}", amount=${tx.amount}, date=${new Date(tx.date).toISOString()}, desc="${tx.description}", pending=${tx.pending}`);
        await ctx.db.insert("simplefinTransactions", {
          userId: args.userId,
          accountId: args.accountId,
          accountName: args.accountName,
          simplefinTxId: tx.simplefinTxId,
          amount: tx.amount,
          currency: tx.currency,
          date: tx.date,
          transactedAt: tx.transactedAt,
          description: tx.description,
          payee: tx.payee,
          pending: tx.pending,
        });
        added++;
      }
    }

    console.log(`[UPSERT_TX] Done for "${args.accountName}": added=${added}, updated=${updated}`);
    return { added, updated };
  },
});

export const _createSyncJob = internalMutation({
  args: {
    userId: v.id("users"),
    simplefinItemId: v.id("simplefinItems"),
    status: v.string(),
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("syncJobs", {
      userId: args.userId,
      simplefinItemId: args.simplefinItemId,
      status: args.status,
      accountsSynced: 0,
      transactionsAdded: 0,
      transactionsUpdated: 0,
    });
  },
});

export const _updateSyncJob = internalMutation({
  args: {
    id: v.id("syncJobs"),
    status: v.string(),
    accountsSynced: v.optional(v.number()),
    transactionsAdded: v.optional(v.number()),
    transactionsUpdated: v.optional(v.number()),
    errorMessage: v.optional(v.string()),
    completedAt: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { id, ...patch } = args;
    const cleanPatch: Record<string, unknown> = {};
    for (const [k, val] of Object.entries(patch)) {
      if (val !== undefined) cleanPatch[k] = val;
    }
    await ctx.db.patch(id, cleanPatch);
  },
});

export const _updateItemLastSynced = internalMutation({
  args: {
    itemId: v.id("simplefinItems"),
    lastSyncedAt: v.number(),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.itemId, { lastSyncedAt: args.lastSyncedAt });
  },
});
