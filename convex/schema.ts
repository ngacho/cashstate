import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  users: defineTable({
    clerkId: v.string(),
    email: v.string(),
    firstName: v.optional(v.string()),
    lastName: v.optional(v.string()),
    createdAt: v.number(),
  }).index("by_clerkId", ["clerkId"]),

  simplefinItems: defineTable({
    userId: v.id("users"),
    accessUrl: v.string(), // encrypted AES-256-GCM
    institutionName: v.optional(v.string()),
    status: v.string(), // "active" | "error" | "disconnected"
    lastSyncedAt: v.optional(v.number()),
  }).index("by_userId", ["userId"]),

  simplefinAccounts: defineTable({
    userId: v.id("users"),
    simplefinItemId: v.id("simplefinItems"),
    simplefinAccountId: v.string(), // external SimpleFin ID
    name: v.string(),
    currency: v.string(),
    balance: v.optional(v.number()),
    availableBalance: v.optional(v.number()),
    balanceDate: v.optional(v.number()),
    orgName: v.optional(v.string()),
  })
    .index("by_userId", ["userId"])
    .index("by_itemId", ["simplefinItemId"])
    .index("by_externalId", [
      "userId",
      "simplefinItemId",
      "simplefinAccountId",
    ]),

  simplefinTransactions: defineTable({
    userId: v.id("users"),
    accountId: v.id("simplefinAccounts"),
    accountName: v.string(), // denormalized
    simplefinTxId: v.string(), // external SimpleFin transaction ID
    amount: v.number(),
    currency: v.string(),
    date: v.number(), // Unix ms (posted date)
    transactedAt: v.optional(v.number()), // Unix ms (transaction date)
    description: v.optional(v.string()),
    payee: v.optional(v.string()),
    pending: v.boolean(),
    categoryId: v.optional(v.id("categories")),
    subcategoryId: v.optional(v.id("subcategories")),
    categorizationSource: v.optional(v.string()), // "manual" | "rule" | "ai"
  })
    .index("by_userId", ["userId"])
    .index("by_userId_date", ["userId", "date"])
    .index("by_txId", ["userId", "simplefinTxId"])
    .index("by_accountId", ["accountId"]),

  categories: defineTable({
    userId: v.id("users"),
    name: v.string(),
    icon: v.string(),
    color: v.string(),
    isDefault: v.boolean(),
    displayOrder: v.number(),
  }).index("by_userId", ["userId"]),

  subcategories: defineTable({
    categoryId: v.id("categories"),
    userId: v.id("users"),
    name: v.string(),
    icon: v.string(),
    isDefault: v.boolean(),
    displayOrder: v.number(),
  })
    .index("by_categoryId", ["categoryId"])
    .index("by_userId", ["userId"]),

  categorizationRules: defineTable({
    userId: v.id("users"),
    matchField: v.string(), // "payee" | "description" | "memo"
    matchValue: v.string(),
    categoryId: v.id("categories"),
    subcategoryId: v.optional(v.id("subcategories")),
  }).index("by_userId", ["userId"]),

  budgets: defineTable({
    userId: v.id("users"),
    name: v.string(),
    isDefault: v.boolean(),
    emoji: v.optional(v.string()),
    color: v.optional(v.string()),
    accountIds: v.array(v.id("simplefinAccounts")),
  })
    .index("by_userId", ["userId"])
    .index("by_userId_isDefault", ["userId", "isDefault"]),

  budgetLineItems: defineTable({
    budgetId: v.id("budgets"),
    categoryId: v.id("categories"),
    subcategoryId: v.optional(v.id("subcategories")),
    amount: v.number(),
  }).index("by_budgetId", ["budgetId"]),

  budgetMonths: defineTable({
    budgetId: v.id("budgets"),
    userId: v.id("users"),
    month: v.string(), // "YYYY-MM"
  })
    .index("by_userId", ["userId"])
    .index("by_userId_month", ["userId", "month"]),

  goals: defineTable({
    userId: v.id("users"),
    name: v.string(),
    description: v.optional(v.string()),
    goalType: v.string(), // "savings" | "debt_payment"
    targetAmount: v.number(),
    targetDate: v.optional(v.string()), // "YYYY-MM-DD"
    isCompleted: v.boolean(),
    accounts: v.array(
      v.object({
        accountId: v.id("simplefinAccounts"),
        allocationPercentage: v.number(),
        startingBalance: v.optional(v.number()),
      })
    ),
    createdAt: v.string(), // ISO date string
    updatedAt: v.string(),
  }).index("by_userId", ["userId"]),

  accountBalanceHistory: defineTable({
    userId: v.id("users"),
    simplefinAccountId: v.id("simplefinAccounts"),
    snapshotDate: v.string(), // "YYYY-MM-DD"
    balance: v.number(),
  })
    .index("by_userId_date", ["userId", "snapshotDate"])
    .index("by_account_date", ["simplefinAccountId", "snapshotDate"])
    .index("by_userId_account_date", [
      "userId",
      "simplefinAccountId",
      "snapshotDate",
    ]),

  syncJobs: defineTable({
    userId: v.id("users"),
    simplefinItemId: v.id("simplefinItems"),
    status: v.string(), // "running" | "completed" | "failed"
    accountsSynced: v.number(),
    transactionsAdded: v.number(),
    transactionsUpdated: v.number(),
    errorMessage: v.optional(v.string()),
    completedAt: v.optional(v.number()),
  }).index("by_userId", ["userId"]),

  categorizationJobs: defineTable({
    userId: v.id("users"),
    status: v.string(), // "running" | "completed" | "failed"
    totalTransactions: v.number(),
    categorizedCount: v.number(),
    failedCount: v.number(),
    errorMessage: v.optional(v.string()),
    completedAt: v.optional(v.number()),
  }).index("by_userId", ["userId"]),
});
