# Scheduled Cron Jobs

CashState uses `fastapi-utilities` to run scheduled background tasks (cron jobs) for automatic data syncing and maintenance.

## Available Jobs

### 1. SimpleFin Transaction Sync
**Schedule**: Every 24 hours
**Function**: `sync_simplefin_transactions()`

**What it does:**
- Automatically syncs transactions for all active SimpleFin items
- Fetches transactions from the last 30 days
- Respects SimpleFin's 24-hour rate limit per item
- Updates account balances and organization info
- Creates sync jobs for tracking

**Behavior:**
- Runs on startup (initial sync)
- Then runs every 24 hours
- Skips items synced in the last 24 hours (rate limit)
- Logs all activity with `[CRON]` prefix

**Rate Limiting:**
SimpleFin allows 24 API requests per day. The cron job checks `last_synced_at` and skips items synced within the last 24 hours to avoid hitting the rate limit.

### 2. Daily Snapshots Update
**Schedule**: Every 24 hours
**Function**: `update_daily_snapshots()`

**What it does:**
- Calculates daily financial snapshots for all users
- Updates snapshots for yesterday and today
- Ensures net worth tracking data is current
- Powers the HomeView charts in the iOS app

**Behavior:**
- Runs on startup (initial calculation)
- Then runs every 24 hours
- Only processes users with active SimpleFin items
- Logs success/failure for each user

## Configuration

### Enable/Disable Cron Jobs

Set in `.env`:
```bash
ENABLE_CRON_JOBS=true   # Enable (default)
ENABLE_CRON_JOBS=false  # Disable
```

### Customizing Schedule

Edit `app/cron.py` and change the `@repeat_every()` decorator:

```python
@repeat_every(seconds=60 * 60 * 24)  # 24 hours
async def sync_simplefin_transactions():
    ...
```

**Common intervals:**
- Every hour: `seconds=60 * 60`
- Every 12 hours: `seconds=60 * 60 * 12`
- Every 6 hours: `seconds=60 * 60 * 6`
- Every day: `seconds=60 * 60 * 24`

## Monitoring

### Check Logs

Cron jobs log to stdout with the `[CRON]` prefix:

```
[CRON] Starting SimpleFin transaction sync...
[CRON] Found 3 active SimpleFin item(s)
[CRON] Synced item abc-123: 2 accounts, 45 transactions
[CRON] SimpleFin sync complete: 3 synced, 0 skipped, 0 errors
```

### Production Monitoring

In production, pipe logs to a service like:
- **Papertrail**: `uvicorn app.main:app --log-config logging.yaml`
- **CloudWatch**: Use AWS CloudWatch Logs
- **Sentry**: Add Sentry SDK for error tracking

## How It Works

1. **Startup**: FastAPI's lifespan context manager starts the cron jobs
2. **Immediate Run**: Both jobs run once immediately on startup
3. **Scheduled Runs**: `fastapi-utilities` uses APScheduler to repeat every 24 hours
4. **Database Access**: Uses service role client (admin access) via `get_supabase_client()`
5. **Error Handling**: Each item/user is processed independently; one failure doesn't stop the entire job

## Database Access

Cron jobs use the **service role** Supabase client for admin-level access:

```python
client = get_supabase_client()  # Uses SUPABASE_SECRET_KEY
db = Database(client)
```

This bypasses RLS policies since cron jobs operate on behalf of all users, not a specific authenticated user.

## Testing Cron Jobs

### Manual Trigger (Development)

You can manually trigger cron jobs by calling them directly:

```python
# In Python REPL or test script
from app.cron import sync_simplefin_transactions, update_daily_snapshots
import asyncio

# Run sync
asyncio.run(sync_simplefin_transactions())

# Run snapshots update
asyncio.run(update_daily_snapshots())
```

### Disable in Tests

Set `ENABLE_CRON_JOBS=false` in your test environment to prevent cron jobs from running during tests.

## Troubleshooting

### Cron Jobs Not Running

1. Check if enabled: `ENABLE_CRON_JOBS=true` in `.env`
2. Check logs for startup message: `[CRON] Starting scheduled tasks...`
3. Ensure FastAPI server is running (cron jobs only run while server is up)

### SimpleFin Rate Limit Errors

If you see rate limit errors (429):
- Check `last_synced_at` timestamps in `simplefin_items` table
- Ensure cron job respects 24-hour cooldown
- SimpleFin allows 24 requests per day; manual syncs also count

### Snapshot Calculation Errors

If snapshots fail to calculate:
- Check that transactions exist for the user
- Verify SimpleFin accounts are properly linked
- Check for database permission issues (RLS policies)

## Performance Considerations

### Memory Usage

Each cron job processes items/users sequentially to avoid overwhelming the database. For large user bases (1000+ users), consider:
- Batching users in chunks
- Adding delays between batches
- Running cron jobs on a dedicated worker instance

### Database Load

Current implementation:
- Syncs all active items (could be 100+ API calls)
- Calculates snapshots for all users (could be 1000+ users)

For production with many users:
- Consider using Celery or RQ for distributed task queues
- Implement rate limiting and backoff
- Add job status tracking in database

## Security

### Service Role Access

Cron jobs use the service role key (SUPABASE_SECRET_KEY) which has **admin access**. Ensure:
- Service role key is never exposed to clients
- Cron job code is thoroughly tested
- Error handling prevents data corruption

### Data Validation

All data from SimpleFin is validated before insertion:
- Account data parsed through `parse_simplefin_accounts()`
- Transaction data parsed through `parse_simplefin_transactions()`
- Upsert operations use unique constraints to prevent duplicates

## Future Improvements

- [ ] Add job status tracking in database (job_runs table)
- [ ] Implement dead letter queue for failed items
- [ ] Add metrics/monitoring (Prometheus, Grafana)
- [ ] Support manual retry for failed jobs
- [ ] Add email notifications for sync failures
- [ ] Implement exponential backoff for transient errors
