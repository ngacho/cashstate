import { userQuery, userMutation } from "./functions";
import { v } from "convex/values";

function computeProgress(
  goalType: string,
  targetAmount: number,
  accounts: {
    accountId: string;
    allocationPercentage: number;
    startingBalance?: number | null;
    currentBalance: number;
  }[]
): { currentAmount: number; progressPercent: number } {
  let currentAmount = 0;

  if (goalType === "savings") {
    // Savings: sum(balance * allocationPercentage / 100)
    currentAmount = accounts.reduce(
      (sum, a) => sum + (a.currentBalance * a.allocationPercentage) / 100,
      0
    );
  } else {
    // Debt payment: sum(abs(startingBalance) - abs(currentBalance))
    currentAmount = accounts.reduce((sum, a) => {
      const starting = Math.abs(a.startingBalance ?? 0);
      const current = Math.abs(a.currentBalance);
      return sum + (starting - current);
    }, 0);
  }

  const progressPercent =
    targetAmount > 0
      ? Math.min(Math.round((currentAmount / targetAmount) * 10000) / 100, 100)
      : 0;

  return {
    currentAmount: Math.round(currentAmount * 100) / 100,
    progressPercent,
  };
}

export const list = userQuery({
  args: {},
  handler: async (ctx) => {
    const goals = await ctx.db
      .query("goals")
      .withIndex("by_userId", (q) => q.eq("userId", ctx.user._id))
      .collect();

    return await Promise.all(
      goals.map(async (goal) => {
        const enrichedAccounts = await Promise.all(
          goal.accounts.map(async (a) => {
            const account = await ctx.db.get(a.accountId);
            return {
              accountId: a.accountId.toString(),
              id: a.accountId,
              simplefinAccountId: a.accountId,
              accountName: account?.name ?? "Unknown",
              allocationPercentage: a.allocationPercentage,
              currentBalance: account?.balance ?? 0,
              startingBalance: a.startingBalance ?? null,
            };
          })
        );

        const { currentAmount, progressPercent } = computeProgress(
          goal.goalType,
          goal.targetAmount,
          enrichedAccounts
        );

        return {
          _id: goal._id,
          name: goal.name,
          description: goal.description ?? null,
          goalType: goal.goalType,
          targetAmount: goal.targetAmount,
          targetDate: goal.targetDate ?? null,
          isCompleted: goal.isCompleted,
          currentAmount,
          progressPercent,
          accounts: enrichedAccounts,
          createdAt: goal.createdAt,
          updatedAt: goal.updatedAt,
        };
      })
    );
  },
});

export const create = userMutation({
  args: {
    name: v.string(),
    description: v.optional(v.string()),
    goalType: v.string(),
    targetAmount: v.number(),
    targetDate: v.optional(v.string()),
    accounts: v.array(
      v.object({
        accountId: v.id("simplefinAccounts"),
        allocationPercentage: v.number(),
      })
    ),
  },
  handler: async (ctx, args) => {
    const now = new Date().toISOString();

    // Validate accounts belong to user, capture starting balances for debt goals
    const accountsWithBalance = await Promise.all(
      args.accounts.map(async (a) => {
        const account = await ctx.db.get(a.accountId);
        if (!account || account.userId !== ctx.user._id) {
          throw new Error(`Account ${a.accountId} not found or access denied`);
        }
        return {
          accountId: a.accountId,
          allocationPercentage: a.allocationPercentage,
          startingBalance:
            args.goalType === "debt_payment"
              ? account.balance ?? 0
              : undefined,
        };
      })
    );

    const goalId = await ctx.db.insert("goals", {
      userId: ctx.user._id,
      name: args.name,
      description: args.description,
      goalType: args.goalType,
      targetAmount: args.targetAmount,
      targetDate: args.targetDate,
      isCompleted: false,
      accounts: accountsWithBalance,
      createdAt: now,
      updatedAt: now,
    });

    // Return enriched goal
    const goal = await ctx.db.get(goalId);
    if (!goal) throw new Error("Failed to create goal");

    const enrichedAccounts = await Promise.all(
      goal.accounts.map(async (a) => {
        const account = await ctx.db.get(a.accountId);
        return {
          accountId: a.accountId.toString(),
          id: a.accountId,
          simplefinAccountId: a.accountId,
          accountName: account?.name ?? "Unknown",
          allocationPercentage: a.allocationPercentage,
          currentBalance: account?.balance ?? 0,
          startingBalance: a.startingBalance ?? null,
        };
      })
    );

    const { currentAmount, progressPercent } = computeProgress(
      goal.goalType,
      goal.targetAmount,
      enrichedAccounts
    );

    return {
      _id: goal._id,
      name: goal.name,
      description: goal.description ?? null,
      goalType: goal.goalType,
      targetAmount: goal.targetAmount,
      targetDate: goal.targetDate ?? null,
      isCompleted: goal.isCompleted,
      currentAmount,
      progressPercent,
      accounts: enrichedAccounts,
      createdAt: goal.createdAt,
      updatedAt: goal.updatedAt,
    };
  },
});

export const get = userQuery({
  args: {
    id: v.id("goals"),
    startDate: v.optional(v.string()),
    endDate: v.optional(v.string()),
    granularity: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const goal = await ctx.db.get(args.id);
    if (!goal || goal.userId !== ctx.user._id) {
      throw new Error("Goal not found or access denied");
    }

    const enrichedAccounts = await Promise.all(
      goal.accounts.map(async (a) => {
        const account = await ctx.db.get(a.accountId);
        return {
          accountId: a.accountId.toString(),
          id: a.accountId,
          simplefinAccountId: a.accountId,
          accountName: account?.name ?? "Unknown",
          allocationPercentage: a.allocationPercentage,
          currentBalance: account?.balance ?? 0,
          startingBalance: a.startingBalance ?? null,
        };
      })
    );

    const { currentAmount, progressPercent } = computeProgress(
      goal.goalType,
      goal.targetAmount,
      enrichedAccounts
    );

    // Get progress data from accountBalanceHistory
    const accountIds = goal.accounts.map((a) => a.accountId);
    let progressData: { date: string; balance: number }[] = [];

    if (accountIds.length > 0) {
      // Collect all balance history for these accounts
      const allHistory = await Promise.all(
        accountIds.map(async (accountId) => {
          let q = ctx.db
            .query("accountBalanceHistory")
            .withIndex("by_account_date", (q) =>
              q.eq("simplefinAccountId", accountId)
            );
          return await q.collect();
        })
      );

      // Merge by date
      const dateMap = new Map<string, number>();
      for (const history of allHistory) {
        for (const h of history) {
          if (args.startDate && h.snapshotDate < args.startDate) continue;
          if (args.endDate && h.snapshotDate > args.endDate) continue;
          dateMap.set(
            h.snapshotDate,
            (dateMap.get(h.snapshotDate) ?? 0) + h.balance
          );
        }
      }

      progressData = Array.from(dateMap.entries())
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([date, balance]) => ({
          date,
          balance: Math.round(balance * 100) / 100,
        }));

      // Apply granularity filtering
      const granularity = args.granularity ?? "day";
      if (granularity !== "day") {
        const grouped = new Map<string, { date: string; balance: number }>();
        for (const point of progressData) {
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
          // Keep the latest entry per group
          grouped.set(key, { date: key, balance: point.balance });
        }
        progressData = Array.from(grouped.values()).sort((a, b) =>
          a.date.localeCompare(b.date)
        );
      }
    }

    return {
      _id: goal._id,
      name: goal.name,
      description: goal.description ?? null,
      goalType: goal.goalType,
      targetAmount: goal.targetAmount,
      targetDate: goal.targetDate ?? null,
      isCompleted: goal.isCompleted,
      currentAmount,
      progressPercent,
      accounts: enrichedAccounts,
      progressData,
      createdAt: goal.createdAt,
      updatedAt: goal.updatedAt,
    };
  },
});

export const update = userMutation({
  args: {
    id: v.id("goals"),
    name: v.optional(v.string()),
    description: v.optional(v.string()),
    targetAmount: v.optional(v.number()),
    targetDate: v.optional(v.string()),
    isCompleted: v.optional(v.boolean()),
    accounts: v.optional(
      v.array(
        v.object({
          accountId: v.id("simplefinAccounts"),
          allocationPercentage: v.number(),
        })
      )
    ),
  },
  handler: async (ctx, args) => {
    const goal = await ctx.db.get(args.id);
    if (!goal || goal.userId !== ctx.user._id) {
      throw new Error("Goal not found or access denied");
    }

    const now = new Date().toISOString();
    const patch: Record<string, unknown> = { updatedAt: now };
    if (args.name !== undefined) patch.name = args.name;
    if (args.description !== undefined) patch.description = args.description;
    if (args.targetAmount !== undefined) patch.targetAmount = args.targetAmount;
    if (args.targetDate !== undefined) patch.targetDate = args.targetDate;
    if (args.isCompleted !== undefined) patch.isCompleted = args.isCompleted;

    if (args.accounts !== undefined) {
      const accountsWithBalance = await Promise.all(
        args.accounts.map(async (a) => {
          const account = await ctx.db.get(a.accountId);
          if (!account || account.userId !== ctx.user._id) {
            throw new Error(
              `Account ${a.accountId} not found or access denied`
            );
          }
          return {
            accountId: a.accountId,
            allocationPercentage: a.allocationPercentage,
            startingBalance:
              goal.goalType === "debt_payment"
                ? account.balance ?? 0
                : undefined,
          };
        })
      );
      patch.accounts = accountsWithBalance;
    }

    await ctx.db.patch(args.id, patch);

    // Return enriched goal
    const updated = await ctx.db.get(args.id);
    if (!updated) throw new Error("Failed to update goal");

    const enrichedAccounts = await Promise.all(
      updated.accounts.map(async (a) => {
        const account = await ctx.db.get(a.accountId);
        return {
          accountId: a.accountId.toString(),
          id: a.accountId,
          simplefinAccountId: a.accountId,
          accountName: account?.name ?? "Unknown",
          allocationPercentage: a.allocationPercentage,
          currentBalance: account?.balance ?? 0,
          startingBalance: a.startingBalance ?? null,
        };
      })
    );

    const { currentAmount, progressPercent } = computeProgress(
      updated.goalType,
      updated.targetAmount,
      enrichedAccounts
    );

    return {
      _id: updated._id,
      name: updated.name,
      description: updated.description ?? null,
      goalType: updated.goalType,
      targetAmount: updated.targetAmount,
      targetDate: updated.targetDate ?? null,
      isCompleted: updated.isCompleted,
      currentAmount,
      progressPercent,
      accounts: enrichedAccounts,
      createdAt: updated.createdAt,
      updatedAt: updated.updatedAt,
    };
  },
});

export const deleteGoal = userMutation({
  args: {
    id: v.id("goals"),
  },
  handler: async (ctx, args) => {
    const goal = await ctx.db.get(args.id);
    if (!goal || goal.userId !== ctx.user._id) {
      throw new Error("Goal not found or access denied");
    }
    await ctx.db.delete(args.id);
    return { success: true };
  },
});
