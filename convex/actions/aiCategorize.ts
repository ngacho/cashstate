"use node";

import { action, internalAction } from "../_generated/server";
import { internal } from "../_generated/api";
import { v } from "convex/values";

export const categorize = action({
  args: {
    userId: v.id("users"),
    transactionIds: v.optional(v.array(v.id("simplefinTransactions"))),
    force: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const openRouterKey = process.env.OPENROUTER_API_KEY;
    if (!openRouterKey) throw new Error("OPENROUTER_API_KEY not configured");

    // 1. Get rules and uncategorized transactions
    const [rules, transactions, categories] = await Promise.all([
      ctx.runQuery(internal.aiCategorizeHelpers._getRules, {
        userId: args.userId,
      }),
      ctx.runQuery(
        internal.aiCategorizeHelpers._getUncategorizedTransactions,
        {
          userId: args.userId,
          transactionIds: args.transactionIds,
          force: args.force,
        }
      ),
      ctx.runQuery(internal.aiCategorizeHelpers._getCategories, {
        userId: args.userId,
      }),
    ]);

    if (transactions.length === 0) {
      return { categorizedCount: 0, failedCount: 0, results: [] };
    }

    // 2. Apply rules first (case-insensitive substring match)
    const ruleMatches: {
      txId: any;
      categoryId: any;
      subcategoryId: any;
    }[] = [];
    const remaining: typeof transactions = [];

    for (const tx of transactions) {
      if (!tx) continue;
      let matched = false;
      for (const rule of rules) {
        const fieldValue =
          rule.matchField === "payee"
            ? tx.payee
            : rule.matchField === "description"
              ? tx.description
              : null;
        if (
          fieldValue &&
          fieldValue.toLowerCase().includes(rule.matchValue.toLowerCase())
        ) {
          ruleMatches.push({
            txId: tx._id,
            categoryId: rule.categoryId,
            subcategoryId: rule.subcategoryId,
          });
          matched = true;
          break;
        }
      }
      if (!matched) {
        remaining.push(tx);
      }
    }

    // 3. Update rule-matched transactions
    if (ruleMatches.length > 0) {
      await ctx.runMutation(
        internal.aiCategorizeHelpers._batchUpdateCategories,
        {
          updates: ruleMatches.map((m) => ({
            txId: m.txId,
            categoryId: m.categoryId,
            subcategoryId: m.subcategoryId,
            source: "rule",
          })),
        }
      );
    }

    const results: {
      transactionId: string;
      categoryId: string | null;
      subcategoryId: string | null;
      confidence: number;
      reasoning: string | null;
    }[] = ruleMatches.map((m) => ({
      transactionId: m.txId,
      categoryId: m.categoryId,
      subcategoryId: m.subcategoryId ?? null,
      confidence: 1.0,
      reasoning: "Matched by rule",
    }));

    // 4. Call AI for remaining uncategorized transactions
    if (remaining.length > 0) {
      const categoryContext = categories
        .filter((c) => c.name !== "Uncategorized")
        .map((c) => {
          const subs = c.subcategories
            .map((s) => `  - ${s.name} (id: ${s._id})`)
            .join("\n");
          return `${c.name} (id: ${c._id})\n${subs}`;
        })
        .join("\n\n");

      const txList = remaining
        .map(
          (tx) =>
            `- id: ${tx!._id}, payee: "${tx!.payee ?? ""}", description: "${tx!.description ?? ""}", amount: ${tx!.amount}`
        )
        .join("\n");

      const prompt = `You are a financial transaction categorizer. Given the following categories and transactions, assign each transaction to the most appropriate category and optionally a subcategory.

CATEGORIES:
${categoryContext}

TRANSACTIONS:
${txList}

Respond with a JSON array. Each element must have:
- "transactionId": the transaction id
- "categoryId": the category id (required)
- "subcategoryId": the subcategory id or null
- "confidence": a number 0-1
- "reasoning": brief explanation

Respond ONLY with the JSON array, no markdown or explanation.`;

      try {
        const response = await fetch(
          "https://openrouter.ai/api/v1/chat/completions",
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${openRouterKey}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              model: "anthropic/claude-sonnet-4",
              messages: [{ role: "user", content: prompt }],
              temperature: 0.1,
            }),
          }
        );

        if (!response.ok) {
          throw new Error(`OpenRouter API error: ${response.status}`);
        }

        const data = await response.json();
        const content = data.choices?.[0]?.message?.content ?? "[]";

        let parsed: any[];
        try {
          const jsonStr = content
            .replace(/```json\n?/g, "")
            .replace(/```\n?/g, "")
            .trim();
          parsed = JSON.parse(jsonStr);
        } catch {
          parsed = [];
        }

        const validCategoryIds = new Set(categories.map((c) => c._id));
        const validSubcategoryIds = new Set(
          categories.flatMap((c) => c.subcategories.map((s) => s._id))
        );

        const aiUpdates: {
          txId: any;
          categoryId: any;
          subcategoryId: any;
          source: string;
        }[] = [];

        for (const item of parsed) {
          if (!item.transactionId || !item.categoryId) continue;
          if (!validCategoryIds.has(item.categoryId)) continue;

          const subcategoryId =
            item.subcategoryId && validSubcategoryIds.has(item.subcategoryId)
              ? item.subcategoryId
              : undefined;

          aiUpdates.push({
            txId: item.transactionId,
            categoryId: item.categoryId,
            subcategoryId,
            source: "ai",
          });

          results.push({
            transactionId: item.transactionId,
            categoryId: item.categoryId,
            subcategoryId: subcategoryId ?? null,
            confidence: item.confidence ?? 0.5,
            reasoning: item.reasoning ?? null,
          });
        }

        if (aiUpdates.length > 0) {
          await ctx.runMutation(
            internal.aiCategorizeHelpers._batchUpdateCategories,
            {
              updates: aiUpdates as any,
            }
          );
        }
      } catch (e: any) {
        console.error("AI categorization failed:", e.message);
      }
    }

    const categorizedCount = results.length;
    const failedCount =
      transactions.filter((t) => t !== null).length - categorizedCount;

    return { categorizedCount, failedCount, results };
  },
});

export const _categorizeBackground = internalAction({
  args: {
    userId: v.id("users"),
    jobId: v.id("categorizationJobs"),
    transactionIds: v.optional(v.array(v.id("simplefinTransactions"))),
    force: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const openRouterKey = process.env.OPENROUTER_API_KEY;
    if (!openRouterKey) {
      await ctx.runMutation(
        internal.aiCategorizeHelpers._updateCategorizationJob,
        {
          id: args.jobId,
          status: "failed",
          errorMessage: "OPENROUTER_API_KEY not configured",
          completedAt: Date.now(),
        }
      );
      return;
    }

    try {
      const [rules, transactions, categories] = await Promise.all([
        ctx.runQuery(internal.aiCategorizeHelpers._getRules, {
          userId: args.userId,
        }),
        ctx.runQuery(
          internal.aiCategorizeHelpers._getUncategorizedTransactions,
          {
            userId: args.userId,
            transactionIds: args.transactionIds,
            force: args.force,
          }
        ),
        ctx.runQuery(internal.aiCategorizeHelpers._getCategories, {
          userId: args.userId,
        }),
      ]);

      if (transactions.length === 0) {
        await ctx.runMutation(
          internal.aiCategorizeHelpers._updateCategorizationJob,
          {
            id: args.jobId,
            status: "completed",
            categorizedCount: 0,
            failedCount: 0,
            completedAt: Date.now(),
          }
        );
        return;
      }

      // Apply rules first
      const ruleMatches: {
        txId: any;
        categoryId: any;
        subcategoryId: any;
      }[] = [];
      const remaining: typeof transactions = [];

      for (const tx of transactions) {
        if (!tx) continue;
        let matched = false;
        for (const rule of rules) {
          const fieldValue =
            rule.matchField === "payee"
              ? tx.payee
              : rule.matchField === "description"
                ? tx.description
                : null;
          if (
            fieldValue &&
            fieldValue.toLowerCase().includes(rule.matchValue.toLowerCase())
          ) {
            ruleMatches.push({
              txId: tx._id,
              categoryId: rule.categoryId,
              subcategoryId: rule.subcategoryId,
            });
            matched = true;
            break;
          }
        }
        if (!matched) {
          remaining.push(tx);
        }
      }

      // Update rule-matched transactions
      if (ruleMatches.length > 0) {
        await ctx.runMutation(
          internal.aiCategorizeHelpers._batchUpdateCategories,
          {
            updates: ruleMatches.map((m) => ({
              txId: m.txId,
              categoryId: m.categoryId,
              subcategoryId: m.subcategoryId,
              source: "rule",
            })),
          }
        );
      }

      let categorizedCount = ruleMatches.length;
      let failedCount = 0;

      // Update progress after rule matching
      await ctx.runMutation(
        internal.aiCategorizeHelpers._updateCategorizationJob,
        {
          id: args.jobId,
          categorizedCount,
        }
      );

      // Call AI for remaining
      if (remaining.length > 0) {
        const categoryContext = categories
          .filter((c) => c.name !== "Uncategorized")
          .map((c) => {
            const subs = c.subcategories
              .map((s) => `  - ${s.name} (id: ${s._id})`)
              .join("\n");
            return `${c.name} (id: ${c._id})\n${subs}`;
          })
          .join("\n\n");

        const txList = remaining
          .map(
            (tx) =>
              `- id: ${tx!._id}, payee: "${tx!.payee ?? ""}", description: "${tx!.description ?? ""}", amount: ${tx!.amount}`
          )
          .join("\n");

        const prompt = `You are a financial transaction categorizer. Given the following categories and transactions, assign each transaction to the most appropriate category and optionally a subcategory.

CATEGORIES:
${categoryContext}

TRANSACTIONS:
${txList}

Respond with a JSON array. Each element must have:
- "transactionId": the transaction id
- "categoryId": the category id (required)
- "subcategoryId": the subcategory id or null
- "confidence": a number 0-1
- "reasoning": brief explanation

Respond ONLY with the JSON array, no markdown or explanation.`;

        const response = await fetch(
          "https://openrouter.ai/api/v1/chat/completions",
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${openRouterKey}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              model: "anthropic/claude-sonnet-4",
              messages: [{ role: "user", content: prompt }],
              temperature: 0.1,
            }),
          }
        );

        if (!response.ok) {
          throw new Error(`OpenRouter API error: ${response.status}`);
        }

        const data = await response.json();
        const content = data.choices?.[0]?.message?.content ?? "[]";

        let parsed: any[];
        try {
          const jsonStr = content
            .replace(/```json\n?/g, "")
            .replace(/```\n?/g, "")
            .trim();
          parsed = JSON.parse(jsonStr);
        } catch {
          parsed = [];
        }

        const validCategoryIds = new Set(categories.map((c) => c._id));
        const validSubcategoryIds = new Set(
          categories.flatMap((c) => c.subcategories.map((s) => s._id))
        );

        const aiUpdates: {
          txId: any;
          categoryId: any;
          subcategoryId: any;
          source: string;
        }[] = [];

        for (const item of parsed) {
          if (!item.transactionId || !item.categoryId) continue;
          if (!validCategoryIds.has(item.categoryId)) continue;

          const subcategoryId =
            item.subcategoryId && validSubcategoryIds.has(item.subcategoryId)
              ? item.subcategoryId
              : undefined;

          aiUpdates.push({
            txId: item.transactionId,
            categoryId: item.categoryId,
            subcategoryId,
            source: "ai",
          });
        }

        if (aiUpdates.length > 0) {
          await ctx.runMutation(
            internal.aiCategorizeHelpers._batchUpdateCategories,
            {
              updates: aiUpdates as any,
            }
          );
        }

        categorizedCount += aiUpdates.length;
        failedCount = remaining.length - aiUpdates.length;
      }

      await ctx.runMutation(
        internal.aiCategorizeHelpers._updateCategorizationJob,
        {
          id: args.jobId,
          status: "completed",
          categorizedCount,
          failedCount,
          completedAt: Date.now(),
        }
      );
    } catch (e: any) {
      console.error("Background AI categorization failed:", e.message);
      await ctx.runMutation(
        internal.aiCategorizeHelpers._updateCategorizationJob,
        {
          id: args.jobId,
          status: "failed",
          errorMessage: e.message ?? "Unknown error",
          completedAt: Date.now(),
        }
      );
    }
  },
});
