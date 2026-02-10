# CashState Security Architecture

## 🔒 Security Model: User JWT + RLS

CashState uses **Supabase Row-Level Security (RLS)** with user JWTs for database access control. This provides defense-in-depth security where authorization is enforced at the database level, not just in application code.

### Why This Approach?

1. **No Service Role Key** - We don't use or need the `service_role` superuser key at all
2. **Principle of Least Privilege** - Users can ONLY access their own data
3. **Database-Level Enforcement** - Even if app code has bugs, RLS prevents unauthorized access
4. **Performance Optimized** - JWT verification is local (asymmetric RS256/ES256 via JWKS)
5. **Encrypted Sensitive Data** - Plaid access tokens are encrypted with Fernet before storage

## 🏗️ Architecture Flow

```
User Request
    ↓
FastAPI Endpoint
    ↓
[JWT Verification] ← Verify signature locally via JWKS (fast!)
    ↓
get_current_user_with_token() → Returns (user_dict, token)
    ↓
get_database() → Creates PostgREST client with user's JWT
    ↓
Database Operation (INSERT/SELECT/UPDATE/DELETE)
    ↓
PostgreSQL RLS Policies ← Checks (select auth.uid()) = user_id
    ↓
✅ Access Granted (if user owns the data)
❌ Access Denied (if user doesn't own the data)
```

## 📁 Key Components

### Authentication (`app/dependencies.py`)

```python
async def get_current_user_with_token(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    settings: Settings = Depends(get_settings),
) -> tuple[dict, str]:
    """
    1. Verify JWT signature locally via JWKS (asymmetric RS256/ES256)
    2. Extract user_id from JWT payload (sub claim)
    3. Create authenticated PostgREST client with user's JWT
    4. Fetch/create user record (RLS allows user to read their own profile)
    5. Return (user_dict, token) for downstream dependencies
    """
```

### Database Client (`app/database.py`)

```python
def get_authenticated_postgrest_client(access_token: str) -> SyncPostgrestClient:
    """
    Create PostgREST client with:
    - apikey: publishable/anon key (identifies project)
    - Authorization: Bearer {user_jwt} (for auth.uid())

    PostgREST extracts auth.uid() from JWT → RLS policies enforce access
    """
    return SyncPostgrestClient(
        base_url=f"{settings.supabase_url}/rest/v1",
        headers={
            "apikey": settings.supabase_publishable_key,
            "Authorization": f"Bearer {access_token}",
        },
    )
```

### RLS Policies (Optimized)

```sql
-- Performance optimized: (select auth.uid()) prevents re-evaluation per row
create policy "Users can insert own plaid items"
    on public.plaid_items for insert
    with check ((select auth.uid()) = user_id);
```

### Table Permissions

```sql
-- Grant table-level permissions to authenticated users
grant select, insert, update, delete on public.plaid_items to authenticated;
grant select, insert, update, delete on public.transactions to authenticated;
-- etc...
```

## 🛡️ Security Layers

### Layer 1: Network (HTTPS)
- All API requests over HTTPS
- JWT transmitted in Authorization header

### Layer 2: JWT Verification (FastAPI)
- Signature verified via JWKS
- Expiration checked
- Issuer/audience validated
- Invalid JWT → 401 Unauthorized

### Layer 3: RLS Policies (PostgreSQL)
- Every database operation checked
- Users can ONLY see/modify their own data
- Enforced at database level (can't be bypassed)

### Layer 4: Encryption at Rest
- Plaid access tokens encrypted with Fernet
- Database encrypted by Supabase (default)

## 📊 Performance

- **JWT Verification**: ~2-5ms (local JWKS verification, no network call)
- **RLS Policy Evaluation**: ~1-3ms (optimized with `(select auth.uid())`)
- **Total Auth Overhead**: ~5-10ms per request

Compare to symmetric JWT verification with network call: ~300-1200ms

## 🔐 Sensitive Data Protection

### Plaid Access Tokens
```python
# Encrypted before storage
from app.utils.encryption import encrypt_token, decrypt_token

encrypted = encrypt_token(plaid_access_token)
db.create_plaid_item({"access_token": encrypted, ...})

# Decrypted when needed
decrypted = decrypt_token(item["access_token"])
```

### Environment Variables
```bash
ENCRYPTION_KEY=<fernet_key>  # Rotatable encryption key
SUPABASE_SECRET_KEY=<secret>  # For GoTrue auth operations only
SUPABASE_PUBLISHABLE_KEY=<public>  # Anon key for client requests
```

## 🚀 Deployment Checklist

- [ ] All environment variables set (including `ENCRYPTION_KEY`)
- [ ] RLS policies enabled on all tables
- [ ] Table permissions granted to `authenticated` role
- [ ] HTTPS enabled (production)
- [ ] JWT signing keys configured in Supabase (asymmetric ES256/RS256)
- [ ] Only required keys: `SUPABASE_SECRET_KEY` (auth), `SUPABASE_PUBLISHABLE_KEY` (client)

## 📝 Migration Files

### For New Projects
```sql
-- Run this to set up everything from scratch
supabase/migrations/001_initial_schema.sql
```

### For Existing Projects
```sql
-- Run this to fix/optimize existing database
supabase/migrations/00X_complete_rls_fix.sql
```

## ✅ Testing

All security measures validated by E2E tests:

```bash
uv run pytest tests/test_complete_run.py -v
```

Tests verify:
- JWT authentication works
- RLS policies allow user to access own data
- RLS policies block access to other users' data
- Encrypted Plaid tokens are stored/retrieved correctly
- All CRUD operations work with user JWT

## 🎯 Summary

**CashState Security (User JWT + RLS):**
- ✅ **No service_role key** - Not needed or used
- ✅ **Defense-in-depth** - App + database layers
- ✅ **Users can ONLY access their own data**
- ✅ **Fast local JWT verification** (~2-5ms)
- ✅ **Performance optimized RLS policies**
- ✅ **Encrypted sensitive data** (Plaid tokens)

**Environment:**
- `SUPABASE_SECRET_KEY` - For GoTrue auth operations (sign_up, sign_in, refresh)
- `SUPABASE_PUBLISHABLE_KEY` - For PostgREST client requests with user JWTs
- `ENCRYPTION_KEY` - For encrypting Plaid access tokens
