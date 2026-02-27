import { userQuery, userMutation } from "./functions";
import { v } from "convex/values";

export const list = userQuery({
  args: {},
  handler: async (ctx) => {
    return await ctx.db
      .query("categories")
      .withIndex("by_userId", (q) => q.eq("userId", ctx.user._id))
      .collect();
  },
});

export const tree = userQuery({
  args: {},
  handler: async (ctx) => {
    const categories = await ctx.db
      .query("categories")
      .withIndex("by_userId", (q) => q.eq("userId", ctx.user._id))
      .collect();

    const result = await Promise.all(
      categories.map(async (cat) => {
        const subcategories = await ctx.db
          .query("subcategories")
          .withIndex("by_categoryId", (q) => q.eq("categoryId", cat._id))
          .collect();
        return {
          _id: cat._id,
          name: cat.name,
          icon: cat.icon,
          color: cat.color,
          type: null as string | null,
          subcategories,
        };
      })
    );

    return result;
  },
});

export const create = userMutation({
  args: {
    name: v.string(),
    icon: v.string(),
    color: v.string(),
  },
  handler: async (ctx, args) => {
    // Get max display order
    const existing = await ctx.db
      .query("categories")
      .withIndex("by_userId", (q) => q.eq("userId", ctx.user._id))
      .collect();
    const maxOrder = existing.reduce(
      (max, c) => Math.max(max, c.displayOrder),
      0
    );

    const id = await ctx.db.insert("categories", {
      userId: ctx.user._id,
      name: args.name,
      icon: args.icon,
      color: args.color,
      isDefault: false,
      displayOrder: maxOrder + 1,
    });
    return await ctx.db.get(id);
  },
});

export const update = userMutation({
  args: {
    id: v.id("categories"),
    name: v.optional(v.string()),
    icon: v.optional(v.string()),
    color: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const cat = await ctx.db.get(args.id);
    if (!cat || cat.userId !== ctx.user._id) {
      throw new Error("Category not found or access denied");
    }
    const patch: Record<string, string> = {};
    if (args.name !== undefined) patch.name = args.name;
    if (args.icon !== undefined) patch.icon = args.icon;
    if (args.color !== undefined) patch.color = args.color;
    await ctx.db.patch(args.id, patch);
    return await ctx.db.get(args.id);
  },
});

export const deleteCategory = userMutation({
  args: {
    id: v.id("categories"),
  },
  handler: async (ctx, args) => {
    const cat = await ctx.db.get(args.id);
    if (!cat || cat.userId !== ctx.user._id) {
      throw new Error("Category not found or access denied");
    }

    // Find Uncategorized category for this user
    const uncategorized = await ctx.db
      .query("categories")
      .withIndex("by_userId", (q) => q.eq("userId", ctx.user._id))
      .filter((q) => q.eq(q.field("name"), "Uncategorized"))
      .first();

    // Reassign transactions to Uncategorized
    const transactions = await ctx.db
      .query("simplefinTransactions")
      .withIndex("by_userId", (q) => q.eq("userId", ctx.user._id))
      .filter((q) => q.eq(q.field("categoryId"), args.id))
      .collect();

    for (const tx of transactions) {
      await ctx.db.patch(tx._id, {
        categoryId: uncategorized?._id,
        subcategoryId: undefined,
      });
    }

    // Delete subcategories
    const subcategories = await ctx.db
      .query("subcategories")
      .withIndex("by_categoryId", (q) => q.eq("categoryId", args.id))
      .collect();
    for (const sub of subcategories) {
      await ctx.db.delete(sub._id);
    }

    // Delete budget line items referencing this category
    const lineItems = await ctx.db
      .query("budgetLineItems")
      .filter((q) => q.eq(q.field("categoryId"), args.id))
      .collect();
    for (const li of lineItems) {
      await ctx.db.delete(li._id);
    }

    // Delete categorization rules referencing this category
    const rules = await ctx.db
      .query("categorizationRules")
      .withIndex("by_userId", (q) => q.eq("userId", ctx.user._id))
      .filter((q) => q.eq(q.field("categoryId"), args.id))
      .collect();
    for (const rule of rules) {
      await ctx.db.delete(rule._id);
    }

    await ctx.db.delete(args.id);
    return { success: true };
  },
});

export const updateSubcategory = userMutation({
  args: {
    id: v.id("subcategories"),
    name: v.optional(v.string()),
    icon: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const sub = await ctx.db.get(args.id);
    if (!sub || sub.userId !== ctx.user._id) {
      throw new Error("Subcategory not found or access denied");
    }
    const patch: Record<string, string> = {};
    if (args.name !== undefined) patch.name = args.name;
    if (args.icon !== undefined) patch.icon = args.icon;
    await ctx.db.patch(args.id, patch);
    return await ctx.db.get(args.id);
  },
});

export const createSubcategory = userMutation({
  args: {
    categoryId: v.id("categories"),
    name: v.string(),
    icon: v.string(),
  },
  handler: async (ctx, args) => {
    const cat = await ctx.db.get(args.categoryId);
    if (!cat || cat.userId !== ctx.user._id) {
      throw new Error("Category not found or access denied");
    }

    // Get max display order within this category
    const existing = await ctx.db
      .query("subcategories")
      .withIndex("by_categoryId", (q) => q.eq("categoryId", args.categoryId))
      .collect();
    const maxOrder = existing.reduce(
      (max, s) => Math.max(max, s.displayOrder),
      0
    );

    const id = await ctx.db.insert("subcategories", {
      categoryId: args.categoryId,
      userId: ctx.user._id,
      name: args.name,
      icon: args.icon,
      isDefault: false,
      displayOrder: maxOrder + 1,
    });
    return await ctx.db.get(id);
  },
});

// Categorization Rules

export const listRules = userQuery({
  args: {},
  handler: async (ctx) => {
    return await ctx.db
      .query("categorizationRules")
      .withIndex("by_userId", (q) => q.eq("userId", ctx.user._id))
      .collect();
  },
});

export const createRule = userMutation({
  args: {
    matchField: v.string(),
    matchValue: v.string(),
    categoryId: v.id("categories"),
    subcategoryId: v.optional(v.id("subcategories")),
  },
  handler: async (ctx, args) => {
    const id = await ctx.db.insert("categorizationRules", {
      userId: ctx.user._id,
      matchField: args.matchField,
      matchValue: args.matchValue,
      categoryId: args.categoryId,
      subcategoryId: args.subcategoryId,
    });
    return await ctx.db.get(id);
  },
});

export const deleteRule = userMutation({
  args: {
    id: v.id("categorizationRules"),
  },
  handler: async (ctx, args) => {
    const rule = await ctx.db.get(args.id);
    if (!rule || rule.userId !== ctx.user._id) {
      throw new Error("Rule not found or access denied");
    }
    await ctx.db.delete(args.id);
    return { success: true };
  },
});

// Seed Defaults

const DEFAULT_CATEGORIES = [
  {
    name: "Housing",
    icon: "\u{1F3E0}",
    color: "#7A5230",
    displayOrder: 10,
    subcategories: [
      { name: "Rent", icon: "\u{1F3D8}\u{FE0F}", displayOrder: 1 },
      { name: "Mortgage", icon: "\u{1F3E2}", displayOrder: 2 },
      { name: "Property Tax", icon: "\u{1F4DD}", displayOrder: 3 },
      { name: "Home Insurance", icon: "\u{1F6E1}\u{FE0F}", displayOrder: 4 },
      { name: "HOA Fees", icon: "\u{1F465}", displayOrder: 5 },
      {
        name: "Maintenance & Repairs",
        icon: "\u{1F527}",
        displayOrder: 6,
      },
      { name: "Furniture & Decor", icon: "\u{1F6CB}\u{FE0F}", displayOrder: 7 },
    ],
  },
  {
    name: "Transportation",
    icon: "\u{1F697}",
    color: "#E8943A",
    displayOrder: 11,
    subcategories: [
      { name: "Gas & Fuel", icon: "\u{26FD}", displayOrder: 1 },
      { name: "Car Payment", icon: "\u{1F699}", displayOrder: 2 },
      { name: "Car Insurance", icon: "\u{1F6E1}\u{FE0F}", displayOrder: 3 },
      {
        name: "Maintenance & Repairs",
        icon: "\u{1F527}",
        displayOrder: 4,
      },
      { name: "Public Transit", icon: "\u{1F68C}", displayOrder: 5 },
      { name: "Ride Share", icon: "\u{1F695}", displayOrder: 6 },
      { name: "Parking", icon: "\u{1F17F}\u{FE0F}", displayOrder: 7 },
    ],
  },
  {
    name: "Food & Dining",
    icon: "\u{1F37D}\u{FE0F}",
    color: "#E05474",
    displayOrder: 12,
    subcategories: [
      { name: "Groceries", icon: "\u{1F6D2}", displayOrder: 1 },
      { name: "Restaurants", icon: "\u{1F374}", displayOrder: 2 },
      { name: "Coffee Shops", icon: "\u{2615}", displayOrder: 3 },
      { name: "Fast Food", icon: "\u{1F354}", displayOrder: 4 },
      { name: "Delivery", icon: "\u{1F4E6}", displayOrder: 5 },
    ],
  },
  {
    name: "Utilities",
    icon: "\u{26A1}",
    color: "#0072B2",
    displayOrder: 13,
    subcategories: [
      { name: "Electricity", icon: "\u{1F4A1}", displayOrder: 1 },
      { name: "Water", icon: "\u{1F4A7}", displayOrder: 2 },
      { name: "Gas", icon: "\u{1F525}", displayOrder: 3 },
      { name: "Internet", icon: "\u{1F4E1}", displayOrder: 4 },
      { name: "Phone", icon: "\u{1F4F1}", displayOrder: 5 },
      { name: "Trash & Recycling", icon: "\u{1F5D1}\u{FE0F}", displayOrder: 6 },
    ],
  },
  {
    name: "Healthcare",
    icon: "\u{1F3E5}",
    color: "#B5338A",
    displayOrder: 14,
    subcategories: [
      { name: "Doctor Visits", icon: "\u{2695}\u{FE0F}", displayOrder: 1 },
      { name: "Prescriptions", icon: "\u{1F48A}", displayOrder: 2 },
      { name: "Dental", icon: "\u{1F9B7}", displayOrder: 3 },
      { name: "Vision", icon: "\u{1F441}\u{FE0F}", displayOrder: 4 },
      { name: "Mental Health", icon: "\u{1F9E0}", displayOrder: 5 },
      { name: "Medical Devices", icon: "\u{1FA79}", displayOrder: 6 },
    ],
  },
  {
    name: "Insurance",
    icon: "\u{1F6E1}\u{FE0F}",
    color: "#4F46E5",
    displayOrder: 15,
    subcategories: [
      { name: "Health Insurance", icon: "\u{1F3E5}", displayOrder: 1 },
      { name: "Life Insurance", icon: "\u{2764}\u{FE0F}", displayOrder: 2 },
      { name: "Disability Insurance", icon: "\u{1F6B6}", displayOrder: 3 },
    ],
  },
  {
    name: "Shopping",
    icon: "\u{1F6CD}\u{FE0F}",
    color: "#00A6A6",
    displayOrder: 20,
    subcategories: [
      { name: "Clothing", icon: "\u{1F455}", displayOrder: 1 },
      { name: "Shoes", icon: "\u{1F45F}", displayOrder: 2 },
      { name: "Electronics", icon: "\u{1F4BB}", displayOrder: 3 },
      { name: "Home Goods", icon: "\u{1F3E0}", displayOrder: 4 },
      { name: "Books", icon: "\u{1F4D6}", displayOrder: 5 },
      { name: "Hobbies", icon: "\u{1F3A8}", displayOrder: 6 },
      { name: "General Shopping", icon: "\u{1F6D2}", displayOrder: 7 },
    ],
  },
  {
    name: "Entertainment",
    icon: "\u{1F3AE}",
    color: "#7B2CBF",
    displayOrder: 21,
    subcategories: [
      { name: "Movies & Shows", icon: "\u{1F3AC}", displayOrder: 1 },
      { name: "Music & Concerts", icon: "\u{1F3B5}", displayOrder: 2 },
      { name: "Sports & Fitness", icon: "\u{1F3C3}", displayOrder: 3 },
      { name: "Gaming", icon: "\u{1F3AE}", displayOrder: 4 },
      { name: "Events & Activities", icon: "\u{1F3AB}", displayOrder: 5 },
      { name: "Hobbies", icon: "\u{1F4F7}", displayOrder: 6 },
    ],
  },
  {
    name: "Personal Care",
    icon: "\u{2728}",
    color: "#9381CC",
    displayOrder: 22,
    subcategories: [
      { name: "Hair Care", icon: "\u{1F487}", displayOrder: 1 },
      { name: "Skincare", icon: "\u{1F9F4}", displayOrder: 2 },
      { name: "Spa & Massage", icon: "\u{1F486}", displayOrder: 3 },
      { name: "Gym Membership", icon: "\u{1F3CB}\u{FE0F}", displayOrder: 4 },
      { name: "Personal Items", icon: "\u{1F9FC}", displayOrder: 5 },
    ],
  },
  {
    name: "Education",
    icon: "\u{1F4DA}",
    color: "#009E73",
    displayOrder: 23,
    subcategories: [
      { name: "Tuition", icon: "\u{1F393}", displayOrder: 1 },
      { name: "Books & Supplies", icon: "\u{1F4DA}", displayOrder: 2 },
      { name: "Online Courses", icon: "\u{1F4BB}", displayOrder: 3 },
      { name: "Student Loans", icon: "\u{1F4C4}", displayOrder: 4 },
    ],
  },
  {
    name: "Subscriptions",
    icon: "\u{1F501}",
    color: "#5B86B8",
    displayOrder: 24,
    subcategories: [
      { name: "Streaming Services", icon: "\u{1F4FA}", displayOrder: 1 },
      { name: "Music Streaming", icon: "\u{1F3B5}", displayOrder: 2 },
      { name: "Cloud Storage", icon: "\u{2601}\u{FE0F}", displayOrder: 3 },
      { name: "Software", icon: "\u{1F4F1}", displayOrder: 4 },
      { name: "News & Magazines", icon: "\u{1F4F0}", displayOrder: 5 },
      { name: "Other Subscriptions", icon: "\u{1F501}", displayOrder: 6 },
    ],
  },
  {
    name: "Savings & Investments",
    icon: "\u{1F4C8}",
    color: "#B87040",
    displayOrder: 30,
    subcategories: [
      { name: "Emergency Fund", icon: "\u{1F198}", displayOrder: 1 },
      { name: "Retirement", icon: "\u{1F474}", displayOrder: 2 },
      { name: "Investments", icon: "\u{1F4C8}", displayOrder: 3 },
      { name: "Savings Goals", icon: "\u{1F3AF}", displayOrder: 4 },
    ],
  },
  {
    name: "Debt Payments",
    icon: "\u{1F4B3}",
    color: "#C1121F",
    displayOrder: 31,
    subcategories: [
      { name: "Credit Card", icon: "\u{1F4B3}", displayOrder: 1 },
      { name: "Personal Loan", icon: "\u{1F4B5}", displayOrder: 2 },
      { name: "Student Loan", icon: "\u{1F393}", displayOrder: 3 },
      { name: "Other Debt", icon: "\u{1F4C4}", displayOrder: 4 },
    ],
  },
  {
    name: "Taxes",
    icon: "\u{1F4C4}",
    color: "#C9A227",
    displayOrder: 32,
    subcategories: [
      { name: "Federal Tax", icon: "\u{1F3DB}\u{FE0F}", displayOrder: 1 },
      { name: "State Tax", icon: "\u{1F4CD}", displayOrder: 2 },
      { name: "Property Tax", icon: "\u{1F3E0}", displayOrder: 3 },
    ],
  },
  {
    name: "Fees & Charges",
    icon: "\u{26A0}\u{FE0F}",
    color: "#803848",
    displayOrder: 33,
    subcategories: [
      { name: "Bank Fees", icon: "\u{1F3E6}", displayOrder: 1 },
      { name: "ATM Fees", icon: "\u{1F4B5}", displayOrder: 2 },
      { name: "Late Fees", icon: "\u{23F0}", displayOrder: 3 },
      { name: "Service Charges", icon: "\u{1F527}", displayOrder: 4 },
    ],
  },
  {
    name: "Gifts & Donations",
    icon: "\u{1F381}",
    color: "#D86C9E",
    displayOrder: 40,
    subcategories: [
      { name: "Gifts", icon: "\u{1F381}", displayOrder: 1 },
      { name: "Charity", icon: "\u{2764}\u{FE0F}", displayOrder: 2 },
      { name: "Religious Donations", icon: "\u{1F64F}", displayOrder: 3 },
    ],
  },
  {
    name: "Travel",
    icon: "\u{2708}\u{FE0F}",
    color: "#7CB342",
    displayOrder: 41,
    subcategories: [
      { name: "Flights", icon: "\u{2708}\u{FE0F}", displayOrder: 1 },
      { name: "Hotels", icon: "\u{1F3E8}", displayOrder: 2 },
      { name: "Car Rental", icon: "\u{1F697}", displayOrder: 3 },
      { name: "Vacation Activities", icon: "\u{1F3AB}", displayOrder: 4 },
    ],
  },
  {
    name: "Business Expenses",
    icon: "\u{1F4BC}",
    color: "#00B4D8",
    displayOrder: 42,
    subcategories: [
      { name: "Office Supplies", icon: "\u{1F4CE}", displayOrder: 1 },
      { name: "Business Travel", icon: "\u{2708}\u{FE0F}", displayOrder: 2 },
      { name: "Client Meetings", icon: "\u{1F465}", displayOrder: 3 },
      {
        name: "Professional Services",
        icon: "\u{1F4BC}",
        displayOrder: 4,
      },
    ],
  },
  {
    name: "Uncategorized",
    icon: "\u{2753}",
    color: "#7A9148",
    displayOrder: 99,
    subcategories: [],
  },
];

export const seedDefaults = userMutation({
  args: {
    monthlyBudget: v.number(),
    accountIds: v.optional(v.array(v.id("simplefinAccounts"))),
  },
  handler: async (ctx, args) => {
    let categoriesCreated = 0;
    let subcategoriesCreated = 0;
    let budgetsCreated = 0;

    // Filter expense categories for budget allocation
    const expenseCategoryNames = new Set([
      "Income",
      "Transfers",
      "Uncategorized",
    ]);

    const createdCategories: {
      categoryId: any;
      isExpense: boolean;
    }[] = [];

    for (const catData of DEFAULT_CATEGORIES) {
      const categoryId = await ctx.db.insert("categories", {
        userId: ctx.user._id,
        name: catData.name,
        icon: catData.icon,
        color: catData.color,
        isDefault: true,
        displayOrder: catData.displayOrder,
      });
      categoriesCreated++;

      createdCategories.push({
        categoryId: categoryId as any,
        isExpense: !expenseCategoryNames.has(catData.name),
      });

      for (const subData of catData.subcategories) {
        await ctx.db.insert("subcategories", {
          categoryId,
          userId: ctx.user._id,
          name: subData.name,
          icon: subData.icon,
          isDefault: true,
          displayOrder: subData.displayOrder,
        });
        subcategoriesCreated++;
      }
    }

    // Create default budget with evenly distributed line items
    const expenseCategories = createdCategories.filter((c) => c.isExpense);
    const budgetPerCategory =
      expenseCategories.length > 0
        ? Math.round((args.monthlyBudget / expenseCategories.length) * 100) /
          100
        : 0;

    if (args.monthlyBudget > 0) {
      const budgetId = await ctx.db.insert("budgets", {
        userId: ctx.user._id,
        name: "My Budget",
        isDefault: true,
        emoji: "\u{1F4B0}",
        color: "#00A699",
        accountIds: args.accountIds ?? [],
      });

      for (const cat of expenseCategories) {
        await ctx.db.insert("budgetLineItems", {
          budgetId,
          categoryId: cat.categoryId as any,
          amount: budgetPerCategory,
        });
        budgetsCreated++;
      }
    }

    return {
      categoriesCreated,
      subcategoriesCreated,
      budgetsCreated,
      monthlyBudget: args.monthlyBudget,
      budgetPerCategory,
    };
  },
});
