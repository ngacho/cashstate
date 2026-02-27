"use node";

import { action, internalAction } from "../_generated/server";
import { internal } from "../_generated/api";
import { v } from "convex/values";

// AES-256-GCM encryption helpers
async function getKey(envKey: string): Promise<CryptoKey> {
  const keyBytes = Buffer.from(envKey, "base64");
  return await crypto.subtle.importKey("raw", keyBytes, "AES-GCM", false, [
    "encrypt",
    "decrypt",
  ]);
}

async function encrypt(plaintext: string, envKey: string): Promise<string> {
  const key = await getKey(envKey);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encoded = new TextEncoder().encode(plaintext);
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    encoded
  );
  const combined = new Uint8Array(
    iv.length + new Uint8Array(ciphertext).length
  );
  combined.set(iv);
  combined.set(new Uint8Array(ciphertext), iv.length);
  return Buffer.from(combined).toString("base64");
}

async function decrypt(encrypted: string, envKey: string): Promise<string> {
  const key = await getKey(envKey);
  const combined = Buffer.from(encrypted, "base64");
  const iv = combined.subarray(0, 12);
  const ciphertext = combined.subarray(12);
  const decrypted = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv },
    key,
    ciphertext
  );
  return new TextDecoder().decode(decrypted);
}

async function getUserFromAuth(ctx: any): Promise<{ userId: string }> {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) throw new Error("Not authenticated");
  // Look up user by clerkId via internal query
  const user = await ctx.runQuery(internal.usersHelpers._getByClerkId, {
    clerkId: identity.subject,
  });
  if (!user) throw new Error("User not found in DB");
  return { userId: user._id };
}

export const setup = action({
  args: {
    setupToken: v.string(),
    institutionName: v.optional(v.string()),
  },
  handler: async (ctx, args): Promise<{ itemId: string; institutionName: string | null }> => {
    const { userId } = await getUserFromAuth(ctx);
    const encryptionKey = process.env.ENCRYPTION_KEY;
    if (!encryptionKey) throw new Error("ENCRYPTION_KEY not configured");

    // Base64-decode setup token to get claim URL
    const claimUrl = Buffer.from(args.setupToken, "base64").toString("utf-8");

    // POST to claim URL to get access URL
    const response = await fetch(claimUrl, { method: "POST" });
    if (!response.ok) {
      throw new Error(
        `SimpleFin setup failed: ${response.status} ${response.statusText}`
      );
    }
    const accessUrl = await response.text();

    // Encrypt access URL
    const encryptedUrl = await encrypt(accessUrl.trim(), encryptionKey);

    // Store in DB via internal mutation
    const itemId = await ctx.runMutation(
      internal.simplefinSyncHelpers._storeItem,
      {
        userId: userId as any,
        accessUrl: encryptedUrl,
        institutionName: args.institutionName,
        status: "active",
      }
    );

    return {
      itemId: itemId.toString(),
      institutionName: args.institutionName ?? null,
    };
  },
});

export const sync = action({
  args: {
    itemId: v.id("simplefinItems"),
    startDate: v.optional(v.number()),
    forceSync: v.optional(v.boolean()),
  },
  handler: async (ctx, args): Promise<any> => {
    const { userId } = await getUserFromAuth(ctx);
    return await syncInternal(ctx, userId as any, args.itemId, args.startDate, args.forceSync);
  },
});

// Internal sync action for cron jobs (no JWT auth needed)
export const _syncInternal = internalAction({
  args: {
    userId: v.id("users"),
    itemId: v.id("simplefinItems"),
    startDate: v.optional(v.number()),
    forceSync: v.optional(v.boolean()),
  },
  handler: async (ctx, args): Promise<any> => {
    return await syncInternal(ctx, args.userId, args.itemId, args.startDate, args.forceSync);
  },
});

async function syncInternal(
  ctx: any,
  userId: any,
  itemId: any,
  startDate?: number,
  forceSync?: boolean,
): Promise<any> {
  const encryptionKey = process.env.ENCRYPTION_KEY;
  if (!encryptionKey) throw new Error("ENCRYPTION_KEY not configured");

  // Get item
  const item = await ctx.runQuery(
    internal.simplefinSyncHelpers._getItem,
    { itemId }
  );
  if (!item || item.userId !== userId) {
    throw new Error("Item not found or access denied");
  }

  // Rate limit: 24h unless forceSync
  if (!forceSync && item.lastSyncedAt) {
    const hoursSinceSync =
      (Date.now() - item.lastSyncedAt) / (1000 * 60 * 60);
    if (hoursSinceSync < 24) {
      throw new Error(
        `Rate limited: last synced ${Math.round(hoursSinceSync)}h ago. Use forceSync to override.`
      );
    }
  }

  // Create sync job
  const syncJobId = await ctx.runMutation(
    internal.simplefinSyncHelpers._createSyncJob,
    {
      userId,
      simplefinItemId: itemId,
      status: "running",
    }
  );

  try {
    // Decrypt access URL
    const accessUrl = await decrypt(item.accessUrl, encryptionKey);

    // Parse access URL to get base URL and credentials
    const urlObj = new URL(accessUrl);
    const baseUrl = `${urlObj.protocol}//${urlObj.host}${urlObj.pathname}`;
    const authHeader =
      "Basic " +
      Buffer.from(`${urlObj.username}:${urlObj.password}`).toString("base64");

    // Build SimpleFin API URL
    let apiUrl = `${baseUrl}/accounts`;
    const params = new URLSearchParams();
    if (startDate) {
      params.set("start-date", String(startDate));
    }
    const qs = params.toString();
    if (qs) apiUrl += `?${qs}`;

    // Fetch from SimpleFin
    const response = await fetch(apiUrl, {
      headers: { Authorization: authHeader },
    });
    if (!response.ok) {
      throw new Error(
        `SimpleFin API error: ${response.status} ${response.statusText}`
      );
    }
    const data = await response.json();

    let totalAccountsSynced = 0;
    let totalTxAdded = 0;
    let totalTxUpdated = 0;
    const errors: string[] = [];

    // Process accounts
    const sfAccounts = data.accounts || [];
    const accountData = sfAccounts.map((acc: any) => ({
      simplefinAccountId: acc.id,
      name: acc.name || "Unknown Account",
      currency: acc.currency || "USD",
      balance: acc.balance ? parseFloat(acc.balance) : undefined,
      availableBalance: acc["available-balance"]
        ? parseFloat(acc["available-balance"])
        : undefined,
      balanceDate: acc["balance-date"]
        ? acc["balance-date"] * 1000
        : undefined,
      orgName: acc.org?.name,
    }));

    const accountIds = await ctx.runMutation(
      internal.simplefinSyncHelpers._upsertAccounts,
      {
        userId,
        itemId,
        accounts: accountData,
      }
    );
    totalAccountsSynced = accountIds.length;

    // Process transactions per account
    for (let i = 0; i < sfAccounts.length; i++) {
      const sfAccount = sfAccounts[i];
      const accountId = accountIds[i];
      const accountName = sfAccount.name || "Unknown Account";
      const sfTransactions = sfAccount.transactions || [];

      if (sfTransactions.length === 0) continue;

      const txData = sfTransactions.map((tx: any) => ({
        simplefinTxId: tx.id,
        amount: parseFloat(tx.amount),
        currency: sfAccount.currency || "USD",
        date: tx.posted * 1000,
        transactedAt: tx.transacted_at
          ? tx.transacted_at * 1000
          : undefined,
        description: tx.description,
        payee: tx.payee,
        pending: tx.pending === true,
      }));

      try {
        const result = await ctx.runMutation(
          internal.simplefinSyncHelpers._upsertTransactions,
          {
            userId,
            accountId: accountId as any,
            accountName,
            transactions: txData,
          }
        );
        totalTxAdded += result.added;
        totalTxUpdated += result.updated;
      } catch (e: any) {
        errors.push(`Account ${accountName}: ${e.message}`);
      }
    }

    // Update sync job
    await ctx.runMutation(internal.simplefinSyncHelpers._updateSyncJob, {
      id: syncJobId,
      status: "completed",
      accountsSynced: totalAccountsSynced,
      transactionsAdded: totalTxAdded,
      transactionsUpdated: totalTxUpdated,
      completedAt: Date.now(),
    });

    // Update item last synced
    await ctx.runMutation(
      internal.simplefinSyncHelpers._updateItemLastSynced,
      {
        itemId,
        lastSyncedAt: Date.now(),
      }
    );

    return {
      success: true,
      syncJobId: syncJobId.toString(),
      accountsSynced: totalAccountsSynced,
      transactionsAdded: totalTxAdded,
      transactionsUpdated: totalTxUpdated,
      errors,
    };
  } catch (e: any) {
    await ctx.runMutation(internal.simplefinSyncHelpers._updateSyncJob, {
      id: syncJobId,
      status: "failed",
      errorMessage: e.message,
      completedAt: Date.now(),
    });
    throw e;
  }
}
