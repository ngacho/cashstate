import { QueryCtx, MutationCtx } from "./_generated/server";
import { Id } from "./_generated/dataModel";

/**
 * Validate that a user exists by their _id. Throws if not found.
 */
export async function validateUser(
  ctx: QueryCtx | MutationCtx,
  userId: Id<"users">
) {
  const user = await ctx.db.get(userId);
  if (!user) {
    throw new Error("User not found");
  }
  return user;
}

/**
 * Parse "YYYY-MM" month string into start/end timestamps (ms).
 * Start = first ms of the month, End = first ms of next month.
 */
export function getMonthDateRange(month: string): {
  startMs: number;
  endMs: number;
} {
  const [year, mon] = month.split("-").map(Number);
  const start = new Date(Date.UTC(year, mon - 1, 1));
  const end = new Date(Date.UTC(year, mon, 1));
  return { startMs: start.getTime(), endMs: end.getTime() };
}

/**
 * Hash a password using SHA-256 via Web Crypto API.
 * Returns hex string.
 */
export async function hashPassword(password: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(password);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}
