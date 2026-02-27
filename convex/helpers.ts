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
