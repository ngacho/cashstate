import { userQuery, userMutation } from "./functions";
import { v } from "convex/values";

export const list = userQuery({
  args: {
    startDate: v.optional(v.string()),
    endDate: v.optional(v.string()),
    granularity: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const granularity = args.granularity ?? "day";

    // Get all balance history for user
    const history = await ctx.db
      .query("accountBalanceHistory")
      .withIndex("by_userId_date", (q) =>
        args.startDate
          ? q.eq("userId", ctx.user._id).gte("snapshotDate", args.startDate)
          : q.eq("userId", ctx.user._id)
      )
      .collect();

    // Filter by endDate
    const filtered = args.endDate
      ? history.filter((h) => h.snapshotDate <= args.endDate!)
      : history;

    // Group by date, sum balances across all accounts (net worth)
    const dateMap = new Map<string, number>();
    for (const h of filtered) {
      dateMap.set(
        h.snapshotDate,
        (dateMap.get(h.snapshotDate) ?? 0) + h.balance
      );
    }

    let data = Array.from(dateMap.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([date, balance]) => ({
        date,
        balance: Math.round(balance * 100) / 100,
      }));

    // Apply granularity
    if (granularity !== "day" && data.length > 0) {
      const grouped = new Map<string, { date: string; balance: number }>();
      for (const point of data) {
        let key: string;
        if (granularity === "week") {
          const d = new Date(point.date);
          const dayOfWeek = d.getUTCDay();
          const monday = new Date(d);
          monday.setUTCDate(d.getUTCDate() - ((dayOfWeek + 6) % 7));
          key = monday.toISOString().split("T")[0];
        } else if (granularity === "month") {
          key = point.date.substring(0, 7) + "-01";
        } else {
          key = point.date.substring(0, 4) + "-01-01";
        }
        grouped.set(key, { date: key, balance: point.balance });
      }
      data = Array.from(grouped.values()).sort((a, b) =>
        a.date.localeCompare(b.date)
      );
    }

    const startDate =
      data.length > 0 ? data[0].date : args.startDate ?? "";
    const endDate =
      data.length > 0 ? data[data.length - 1].date : args.endDate ?? "";

    return {
      startDate,
      endDate,
      granularity,
      data,
    };
  },
});

export const listForAccount = userQuery({
  args: {
    accountId: v.id("simplefinAccounts"),
    startDate: v.optional(v.string()),
    endDate: v.optional(v.string()),
    granularity: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const granularity = args.granularity ?? "day";

    // Verify ownership
    const account = await ctx.db.get(args.accountId);
    if (!account || account.userId !== ctx.user._id) {
      throw new Error("Account not found or access denied");
    }

    const history = await ctx.db
      .query("accountBalanceHistory")
      .withIndex("by_account_date", (q) =>
        args.startDate
          ? q.eq("simplefinAccountId", args.accountId).gte("snapshotDate", args.startDate)
          : q.eq("simplefinAccountId", args.accountId)
      )
      .collect();

    const filtered = args.endDate
      ? history.filter((h) => h.snapshotDate <= args.endDate!)
      : history;

    let data = filtered
      .sort((a, b) => a.snapshotDate.localeCompare(b.snapshotDate))
      .map((h) => ({
        date: h.snapshotDate,
        balance: Math.round(h.balance * 100) / 100,
      }));

    // Apply granularity
    if (granularity !== "day" && data.length > 0) {
      const grouped = new Map<string, { date: string; balance: number }>();
      for (const point of data) {
        let key: string;
        if (granularity === "week") {
          const d = new Date(point.date);
          const dayOfWeek = d.getUTCDay();
          const monday = new Date(d);
          monday.setUTCDate(d.getUTCDate() - ((dayOfWeek + 6) % 7));
          key = monday.toISOString().split("T")[0];
        } else if (granularity === "month") {
          key = point.date.substring(0, 7) + "-01";
        } else {
          key = point.date.substring(0, 4) + "-01-01";
        }
        grouped.set(key, { date: key, balance: point.balance });
      }
      data = Array.from(grouped.values()).sort((a, b) =>
        a.date.localeCompare(b.date)
      );
    }

    const startDate =
      data.length > 0 ? data[0].date : args.startDate ?? "";
    const endDate =
      data.length > 0 ? data[data.length - 1].date : args.endDate ?? "";

    return {
      startDate,
      endDate,
      granularity,
      data,
    };
  },
});

export const calculate = userMutation({
  args: {
    startDate: v.optional(v.string()),
    endDate: v.optional(v.string()),
  },
  handler: async (ctx) => {
    const today = new Date().toISOString().split("T")[0];

    // Get all accounts for user
    const accounts = await ctx.db
      .query("simplefinAccounts")
      .withIndex("by_userId", (q) => q.eq("userId", ctx.user._id))
      .collect();

    // Upsert balance history for today
    for (const account of accounts) {
      if (account.balance === undefined) continue;

      const existing = await ctx.db
        .query("accountBalanceHistory")
        .withIndex("by_userId_account_date", (q) =>
          q
            .eq("userId", ctx.user._id)
            .eq("simplefinAccountId", account._id)
            .eq("snapshotDate", today)
        )
        .first();

      if (existing) {
        await ctx.db.patch(existing._id, { balance: account.balance });
      } else {
        await ctx.db.insert("accountBalanceHistory", {
          userId: ctx.user._id,
          simplefinAccountId: account._id,
          snapshotDate: today,
          balance: account.balance,
        });
      }
    }

    return { success: true };
  },
});
