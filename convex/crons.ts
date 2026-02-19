import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

// Daily SimpleFin sync at 2:00 AM UTC
crons.daily(
  "daily simplefin sync",
  { hourUTC: 2, minuteUTC: 0 },
  internal.cronHandlers.dailySync
);

// Daily balance snapshot at 11:55 PM UTC
crons.daily(
  "daily balance snapshot",
  { hourUTC: 23, minuteUTC: 55 },
  internal.cronHandlers.dailySnapshot
);

export default crons;
