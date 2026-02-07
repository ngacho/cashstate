# Airport Quest Backend Implementation Spec

> **Purpose**: This document provides everything needed to build the Airport Quest backend API. Build this first, then verify with a complete airport run simulation before building the frontend.

---

## ⚠️ IMPORTANT: Data Dependencies

**Before building, you need seed data.** The backend requires manually-curated airport data that doesn't exist in any public API. See `airport-quest-risks-and-dependencies.md` for full details.

**Required seed data (blocks MVP):**
| Data | Effort | Source |
|------|--------|--------|
| Airport geofences (10 airports) | 2 hrs | Google Maps + manual |
| Checkpoint locations + metadata | 8-10 hrs | Airport PDFs + research |
| Gate locations | 5-8 hrs | Terminal maps + satellite |
| Travel time estimates | 2 hrs | Auto-generate from coordinates |

**Collect this data FIRST, then build.**

---

## Tech Stack

| Component | Technology | Why |
|-----------|------------|-----|
| API Framework | FastAPI | Async, auto OpenAPI docs, Pydantic validation |
| Database | **Supabase (PostgreSQL + PostGIS)** | Hosted, auth included, realtime, edge functions |
| Auth | **Supabase Auth** | Built-in, handles JWT, OAuth providers |
| Realtime | **Supabase Realtime** | Live checkpoint status updates |
| Cache | Redis (optional) | Only if Supabase latency insufficient |
| Migrations | **Supabase migrations** or Alembic | Schema versioning |
| Testing | pytest + httpx | Async test client |

### Supabase Setup

```bash
# Install Supabase CLI
npm install -g supabase

# Initialize project
supabase init

# Start local dev (optional)
supabase start

# Link to hosted project
supabase link --project-ref your-project-ref
```

### Environment Variables

```bash
# .env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-role-key  # For backend operations

# Optional if using Redis for caching
REDIS_URL=redis://localhost:6379/0
```

### Supabase Client Setup

```python
# app/database.py
from supabase import create_client, Client
from app.config import settings

supabase: Client = create_client(
    settings.SUPABASE_URL,
    settings.SUPABASE_SERVICE_KEY  # Service key for backend
)

# For auth-required operations, use the user's JWT
def get_client_with_auth(access_token: str) -> Client:
    return create_client(
        settings.SUPABASE_URL,
        settings.SUPABASE_ANON_KEY,
        options={"headers": {"Authorization": f"Bearer {access_token}"}}
    )
```

---

## Project Structure

```
airport-quest-api/
├── alembic/
│   └── versions/
├── app/
│   ├── __init__.py
│   ├── main.py                 # FastAPI app entry
│   ├── config.py               # Settings (pydantic-settings)
│   ├── database.py             # SQLAlchemy async engine
│   ├── dependencies.py         # Dependency injection
│   ├── models/                 # SQLAlchemy ORM models
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── flight.py
│   │   ├── airport.py
│   │   ├── checkpoint.py
│   │   ├── gate.py
│   │   ├── security_session.py
│   │   ├── gate_journey.py
│   │   ├── dwell_event.py
│   │   ├── feedback.py
│   │   └── leaderboard.py
│   ├── schemas/                # Pydantic request/response schemas
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── flight.py
│   │   ├── checkpoint.py
│   │   ├── session.py
│   │   ├── journey.py
│   │   └── feedback.py
│   ├── routers/                # API route handlers
│   │   ├── __init__.py
│   │   ├── auth.py
│   │   ├── users.py
│   │   ├── flights.py
│   │   ├── checkpoints.py
│   │   ├── gates.py
│   │   ├── sessions.py
│   │   ├── journeys.py
│   │   ├── location.py
│   │   ├── compete.py
│   │   ├── alerts.py
│   │   └── gamification.py
│   ├── services/               # Business logic
│   │   ├── __init__.py
│   │   ├── auth_service.py
│   │   ├── flight_service.py
│   │   ├── checkpoint_service.py
│   │   ├── session_service.py
│   │   ├── journey_service.py
│   │   ├── percentile_service.py
│   │   ├── leaderboard_service.py
│   │   └── xp_service.py
│   └── utils/
│       ├── __init__.py
│       ├── geo.py              # Geo calculations
│       └── time.py             # Time helpers
├── tests/
│   ├── conftest.py
│   ├── test_auth.py
│   ├── test_flights.py
│   ├── test_sessions.py
│   ├── test_journeys.py
│   └── test_complete_run.py    # Full airport run simulation
├── scripts/
│   ├── seed_airports.py        # Load airport/checkpoint/gate data
│   └── simulate_run.py         # CLI to simulate complete airport run
├── alembic.ini
├── requirements.txt
├── docker-compose.yml
├── Dockerfile
└── README.md
```

---

## Database Schema

### Supabase Setup

```sql
-- Enable PostGIS (run in Supabase SQL editor)
CREATE EXTENSION IF NOT EXISTS postgis;

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

### Tables

Note: Supabase Auth creates `auth.users` automatically. We extend it with a `profiles` table.

```sql
-- ============================================
-- PROFILES (extends Supabase auth.users)
-- ============================================
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name VARCHAR(100),
    trust_score FLOAT DEFAULT 0.5,
    total_xp INTEGER DEFAULT 0,
    current_level INTEGER DEFAULT 1,
    tracking_mode VARCHAR(20) DEFAULT 'inactive',
    current_airport VARCHAR(3),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, display_name)
    VALUES (NEW.id, NEW.raw_user_meta_data->>'display_name');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

-- ============================================
-- AIRPORTS
-- ============================================
CREATE TABLE airports (
    airport_code VARCHAR(3) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(50),
    country VARCHAR(50) DEFAULT 'US',
    timezone VARCHAR(50) NOT NULL,
    geo_fence GEOGRAPHY(POLYGON, 4326),
    has_airtrain BOOLEAN DEFAULT FALSE,
    has_shuttle BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Data provenance
    data_source VARCHAR(50) DEFAULT 'manual',
    last_verified DATE,
    map_url TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- CHECKPOINTS
-- ============================================
CREATE TABLE checkpoints (
    checkpoint_id VARCHAR(50) PRIMARY KEY,
    airport_code VARCHAR(3) REFERENCES airports(airport_code),
    terminal VARCHAR(20) NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    secure_side_fence GEOGRAPHY(POLYGON, 4326),
    radius_meters INTEGER DEFAULT 300,
    has_precheck BOOLEAN DEFAULT FALSE,
    has_clear BOOLEAN DEFAULT FALSE,
    serves_gates TEXT[],
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Data provenance
    data_source VARCHAR(50) DEFAULT 'manual',  -- manual, user_reported, official
    confidence VARCHAR(20) DEFAULT 'high',     -- high, medium, low
    last_verified DATE,
    verified_by VARCHAR(100),
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- GATES
-- ============================================
CREATE TABLE gates (
    gate_id VARCHAR(50) PRIMARY KEY,
    airport_code VARCHAR(3) REFERENCES airports(airport_code),
    terminal VARCHAR(20) NOT NULL,
    gate_number VARCHAR(10) NOT NULL,
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    radius_meters INTEGER DEFAULT 75,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Data provenance
    data_source VARCHAR(50) DEFAULT 'manual',
    confidence VARCHAR(20) DEFAULT 'medium',
    last_verified DATE,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- FLIGHTS (user's tracked flights)
-- ============================================
CREATE TABLE flights (
    flight_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    flight_number VARCHAR(10) NOT NULL,
    airline_code VARCHAR(3),
    departure_airport VARCHAR(3) REFERENCES airports(airport_code),
    arrival_airport VARCHAR(3),
    terminal VARCHAR(20),
    gate VARCHAR(20),
    scheduled_departure TIMESTAMPTZ NOT NULL,
    boarding_time TIMESTAMPTZ,
    status VARCHAR(20) DEFAULT 'scheduled',
    source VARCHAR(20) DEFAULT 'manual',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_flights_user_departure ON flights(user_id, scheduled_departure);

-- RLS
ALTER TABLE flights ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can CRUD own flights"
    ON flights FOR ALL
    USING (auth.uid() = user_id);

-- ============================================
-- SECURITY_SESSIONS
-- ============================================
CREATE TABLE security_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    flight_id UUID REFERENCES flights(flight_id) ON DELETE SET NULL,
    checkpoint_id VARCHAR(50) REFERENCES checkpoints(checkpoint_id),
    security_type VARCHAR(20) DEFAULT 'standard',
    line_start_time TIMESTAMPTZ NOT NULL,
    line_start_location GEOGRAPHY(POINT, 4326),
    line_end_time TIMESTAMPTZ,
    line_end_location GEOGRAPHY(POINT, 4326),
    duration_seconds INTEGER,
    start_method VARCHAR(20) DEFAULT 'tap',
    end_method VARCHAR(20),
    status VARCHAR(20) DEFAULT 'in_progress',
    percentile_rank INTEGER,
    confidence_score FLOAT DEFAULT 1.0,
    gps_accuracy_start FLOAT,
    gps_accuracy_end FLOAT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sessions_user ON security_sessions(user_id);
CREATE INDEX idx_sessions_checkpoint ON security_sessions(checkpoint_id, line_end_time);

-- RLS
ALTER TABLE security_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can CRUD own sessions"
    ON security_sessions FOR ALL
    USING (auth.uid() = user_id);

-- Allow reading others' sessions for percentile calculation (anonymized in app layer)
CREATE POLICY "Anyone can read completed sessions"
    ON security_sessions FOR SELECT
    USING (status = 'completed');

-- ============================================
-- GATE_JOURNEYS
-- ============================================
CREATE TABLE gate_journeys (
    journey_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    flight_id UUID REFERENCES flights(flight_id) ON DELETE SET NULL,
    checkpoint_id VARCHAR(50) REFERENCES checkpoints(checkpoint_id),
    gate_id VARCHAR(50) REFERENCES gates(gate_id),
    security_session_id UUID REFERENCES security_sessions(session_id),
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    total_duration_sec INTEGER,
    walking_duration_sec INTEGER,
    dwell_duration_sec INTEGER DEFAULT 0,
    transport_modes TEXT[],
    status VARCHAR(20) DEFAULT 'in_progress',
    percentile_rank INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_journeys_user ON gate_journeys(user_id);
CREATE INDEX idx_journeys_route ON gate_journeys(checkpoint_id, gate_id);

-- RLS
ALTER TABLE gate_journeys ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can CRUD own journeys"
    ON gate_journeys FOR ALL
    USING (auth.uid() = user_id);

CREATE POLICY "Anyone can read completed journeys"
    ON gate_journeys FOR SELECT
    USING (status = 'completed');

-- ============================================
-- DWELL_EVENTS
-- ============================================
CREATE TABLE dwell_events (
    dwell_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    journey_id UUID REFERENCES gate_journeys(journey_id) ON DELETE CASCADE,
    location GEOGRAPHY(POINT, 4326),
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    duration_sec INTEGER,
    venue_type VARCHAR(50) DEFAULT 'unknown',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- XP_TRANSACTIONS
-- ============================================
CREATE TABLE xp_transactions (
    transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL,
    reason VARCHAR(50) NOT NULL,
    reference_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE xp_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own XP"
    ON xp_transactions FOR SELECT
    USING (auth.uid() = user_id);

-- ============================================
-- USER_PERCENTILES (per checkpoint stats)
-- ============================================
CREATE TABLE user_percentiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    checkpoint_id VARCHAR(50) REFERENCES checkpoints(checkpoint_id),
    security_type VARCHAR(20) DEFAULT 'standard',
    best_time_sec INTEGER,
    percentile_rank INTEGER,
    attempts_count INTEGER DEFAULT 0,
    last_attempt_at TIMESTAMPTZ,
    UNIQUE(user_id, checkpoint_id, security_type)
);

-- RLS
ALTER TABLE user_percentiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own percentiles"
    ON user_percentiles FOR SELECT
    USING (auth.uid() = user_id);

-- ============================================
-- ESTIMATE_FEEDBACK
-- ============================================
CREATE TABLE estimate_feedback (
    feedback_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    flight_id UUID REFERENCES flights(flight_id) ON DELETE CASCADE,
    estimated_security_min INTEGER,
    actual_security_min INTEGER,
    estimated_gate_travel_min INTEGER,
    actual_gate_travel_min INTEGER,
    recommended_arrival TIMESTAMPTZ,
    actual_arrival TIMESTAMPTZ,
    overall_helpful_rating INTEGER,
    estimate_accuracy_rating INTEGER,
    would_use_again BOOLEAN,
    stress_level_rating INTEGER,
    freeform_comment TEXT,
    submitted_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE estimate_feedback ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can CRUD own feedback"
    ON estimate_feedback FOR ALL
    USING (auth.uid() = user_id);

-- ============================================
-- CHECKPOINT_STATUS (real-time cache table)
-- ============================================
CREATE TABLE checkpoint_status (
    checkpoint_id VARCHAR(50) PRIMARY KEY REFERENCES checkpoints(checkpoint_id),
    current_wait_min INTEGER,
    confidence_score FLOAT,
    sample_count_30min INTEGER DEFAULT 0,
    trend VARCHAR(20) DEFAULT 'stable',
    last_updated TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Realtime for live checkpoint updates
ALTER PUBLICATION supabase_realtime ADD TABLE checkpoint_status;

-- ============================================
-- GATE_TRAVEL_MATRIX (aggregated)
-- ============================================
CREATE TABLE gate_travel_matrix (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    checkpoint_id VARCHAR(50) REFERENCES checkpoints(checkpoint_id),
    gate_id VARCHAR(50) REFERENCES gates(gate_id),
    median_walking_sec INTEGER,
    p10_walking_sec INTEGER,
    p90_walking_sec INTEGER,
    sample_count INTEGER DEFAULT 0,
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(checkpoint_id, gate_id)
);
```

---

## API Endpoints

### Base URL: `/app/v1`

All authenticated endpoints require: `Authorization: Bearer {jwt_token}`

---

### 1. Authentication (Supabase Auth)

Supabase handles auth — your API just validates the JWT and passes it through.

#### POST /auth/register
```python
# Request
{
  "email": "user@example.com",
  "password": "securepassword",
  "display_name": "Brandon"
}

# Backend calls Supabase
response = supabase.auth.sign_up({
    "email": email,
    "password": password,
    "options": {"data": {"display_name": display_name}}
})

# Response 201
{
  "user_id": "uuid",
  "email": "user@example.com",
  "access_token": "supabase_jwt",
  "refresh_token": "refresh_token"
}
```

#### POST /auth/login
```python
# Request
{
  "email": "user@example.com",
  "password": "securepassword"
}

# Backend calls Supabase
response = supabase.auth.sign_in_with_password({
    "email": email,
    "password": password
})

# Response 200
{
  "access_token": "supabase_jwt",
  "refresh_token": "refresh_token",
  "user": { ...user object... }
}
```

#### POST /auth/refresh
```python
# Request
{ "refresh_token": "refresh_token" }

# Backend calls Supabase
response = supabase.auth.refresh_session(refresh_token)

# Response 200
{ "access_token": "new_jwt" }
```

#### Auth Dependency (FastAPI)
```python
# app/dependencies.py
from fastapi import Depends, HTTPException, Header
from supabase import Client

async def get_current_user(authorization: str = Header(...)):
    """Validate Supabase JWT and get user."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(401, "Invalid authorization header")
    
    token = authorization.replace("Bearer ", "")
    
    try:
        # Verify JWT with Supabase
        user = supabase.auth.get_user(token)
        return user.user
    except Exception:
        raise HTTPException(401, "Invalid or expired token")

# Usage in routes
@router.get("/users/me")
async def get_me(user = Depends(get_current_user)):
    return user
```

---

### 2. Users

#### GET /users/me
```
Response 200:
{
  "user_id": "uuid",
  "email": "user@example.com",
  "display_name": "Brandon",
  "total_xp": 1250,
  "current_level": 12,
  "created_at": "2024-01-01T00:00:00Z"
}
```

#### GET /users/me/stats
```
Response 200:
{
  "total_sessions": 45,
  "total_journeys": 38,
  "airports_visited": 8,
  "checkpoints_used": 15,
  "avg_security_percentile": 67,
  "current_streak": 4
}
```

---

### 3. Flights

#### POST /flights
```
Request:
{
  "flight_number": "UA123",
  "date": "2024-01-15",
  "departure_airport": "SEA"
}

Response 201:
{
  "flight_id": "uuid",
  "flight_number": "UA123",
  "airline_code": "UA",
  "departure_airport": "SEA",
  "arrival_airport": "LAX",
  "terminal": "N",
  "gate": "N7",
  "scheduled_departure": "2024-01-15T15:00:00-08:00",
  "boarding_time": "2024-01-15T14:30:00-08:00",
  "status": "scheduled"
}
```

#### GET /flights
```
Query: ?status=upcoming

Response 200:
{
  "flights": [ ...flight objects... ]
}
```

#### GET /flights/{flight_id}
```
Response 200: { ...flight object... }
```

#### GET /flights/{flight_id}/journey-summary
```
Response 200:
{
  "flight": {
    "flight_number": "UA123",
    "route": "SEA → LAX"
  },
  "timing": {
    "security_wait_min": 11,
    "security_to_gate_min": 34,
    "dwell_min": 23,
    "walking_min": 11
  },
  "performance": {
    "security_percentile": 67,
    "walking_percentile": 58
  },
  "xp_summary": {
    "total_earned": 45
  }
}
```

#### GET /flights/{flight_id}/feedback-prompt
```
Response 200:
{
  "our_estimate": {
    "security_estimate_min": 12,
    "gate_travel_estimate_min": 8
  },
  "actual_observed": {
    "actual_security_min": 11,
    "actual_gate_travel_min": 11
  },
  "prompt_questions": [
    {
      "id": "overall_helpful",
      "question": "Was our arrival recommendation helpful?",
      "type": "rating",
      "options": ["Not at all", "Somewhat", "Helpful", "Very helpful"]
    },
    {
      "id": "estimate_accuracy",
      "question": "How accurate was our security estimate?",
      "type": "rating",
      "options": ["Way off", "A bit off", "Close", "Spot on"]
    },
    {
      "id": "would_use_again",
      "question": "Would you rely on Airport Quest next time?",
      "type": "boolean"
    },
    {
      "id": "stress_level",
      "question": "How stressed were you about making your flight?",
      "type": "rating",
      "options": ["Very stressed", "Somewhat", "Relaxed", "No stress"]
    }
  ]
}
```

#### POST /flights/{flight_id}/feedback
```
Request:
{
  "responses": {
    "overall_helpful": 3,
    "estimate_accuracy": 4,
    "would_use_again": true,
    "stress_level": 3
  }
}

Response 201:
{
  "feedback_id": "uuid",
  "xp_earned": 10,
  "new_total_xp": 1305
}
```

---

### 4. Location

#### POST /location/geofence/enter
```
Request:
{
  "geofence_id": "SEA-AIRPORT",
  "geofence_type": "airport",
  "latitude": 47.4502,
  "longitude": -122.3088,
  "timestamp": "2024-01-15T13:15:00-08:00",
  "accuracy_meters": 15
}

Response 200:
{
  "status": "tracking_activated",
  "active_flight": {
    "flight_id": "uuid",
    "flight_number": "UA123",
    "gate": "N7",
    "boarding_in_minutes": 75
  }
}
```

#### POST /location/update
```
Request:
{
  "latitude": 47.4495,
  "longitude": -122.3082,
  "timestamp": "2024-01-15T13:38:00-08:00",
  "accuracy_meters": 10
}

Response 200:
{
  "status": "received",
  "context": {
    "airport": "SEA",
    "near_checkpoint": "SEA-C3",
    "in_secure_area": true
  }
}
```

---

### 5. Checkpoints

#### GET /checkpoints/nearby
```
Query: ?lat=47.4489&lng=-122.3094

Response 200:
{
  "checkpoints": [
    {
      "checkpoint_id": "SEA-C3",
      "name": "Checkpoint 3",
      "distance_meters": 45,
      "current_wait_min": 11,
      "confidence": 0.87,
      "trend": "stable",
      "your_best_time_sec": 342,
      "your_percentile": 73
    }
  ],
  "recommendation": "SEA-C3"
}
```

#### GET /checkpoints/{checkpoint_id}/status
```
Response 200:
{
  "checkpoint_id": "SEA-C3",
  "current_wait_min": 11,
  "confidence": 0.87,
  "trend": "stable",
  "sample_count_30min": 14
}
```

#### GET /airports/{code}/checkpoints
```
Response 200:
{
  "checkpoints": [ ...checkpoint objects with status... ]
}
```

#### GET /airports/{code}/comparison
```
Response 200:
{
  "checkpoints": [
    {
      "checkpoint_id": "SEA-C3",
      "name": "Checkpoint 3",
      "median_wait_sec": 420,
      "rank": 1,
      "insider_score": 94,
      "notes": "Locals' favorite"
    }
  ],
  "recommendation": {
    "fastest_now": "SEA-C3",
    "avoid": "SEA-C2"
  }
}
```

---

### 6. Security Sessions

#### POST /sessions/security/start
```
Request:
{
  "checkpoint_id": "SEA-C3",
  "flight_id": "uuid",
  "security_type": "standard",
  "latitude": 47.4491,
  "longitude": -122.3095,
  "timestamp": "2024-01-15T13:27:00-08:00"
}

Response 201:
{
  "session_id": "uuid",
  "checkpoint_id": "SEA-C3",
  "checkpoint_name": "Checkpoint 3",
  "started_at": "2024-01-15T13:27:00-08:00",
  "status": "in_progress",
  "current_checkpoint_median_sec": 660,
  "your_best_here_sec": 342
}
```

#### POST /sessions/security/{session_id}/end
```
Request:
{
  "latitude": 47.4495,
  "longitude": -122.3082,
  "timestamp": "2024-01-15T13:38:00-08:00",
  "end_method": "tap"
}

Response 200:
{
  "session_id": "uuid",
  "duration_seconds": 660,
  "duration_display": "11:00",
  "percentile": 67,
  "percentile_description": "Faster than 67% of travelers",
  "is_personal_best": false,
  "your_best_here_sec": 342,
  "xp_earned": {
    "base": 25,
    "total": 25
  },
  "new_total_xp": 1275,
  "leaderboard_position": {
    "daily_rank": 23,
    "daily_total": 89
  }
}
```

#### GET /sessions/security/active
```
Response 200 (if active):
{
  "session_id": "uuid",
  "checkpoint_id": "SEA-C3",
  "started_at": "2024-01-15T13:27:00-08:00",
  "elapsed_seconds": 342
}

Response 200 (if none):
{ "session": null }
```

---

### 7. Gate Journeys

#### POST /journeys/start
```
Request:
{
  "flight_id": "uuid",
  "checkpoint_id": "SEA-C3",
  "gate_id": "SEA-N7",
  "security_session_id": "uuid",
  "latitude": 47.4495,
  "longitude": -122.3082,
  "timestamp": "2024-01-15T13:38:00-08:00"
}

Response 201:
{
  "journey_id": "uuid",
  "from_checkpoint": "Checkpoint 3",
  "to_gate": "N7",
  "estimated_walking_min": 8,
  "status": "in_progress"
}
```

#### POST /journeys/{journey_id}/waypoint
```
Request:
{
  "latitude": 47.4498,
  "longitude": -122.3078,
  "timestamp": "2024-01-15T13:42:00-08:00"
}

Response 200:
{ "status": "recorded" }
```

#### POST /journeys/{journey_id}/dwell/start
```
Request:
{
  "latitude": 47.4498,
  "longitude": -122.3078,
  "timestamp": "2024-01-15T13:42:00-08:00"
}

Response 200:
{
  "dwell_id": "uuid",
  "status": "dwell_started"
}
```

#### POST /journeys/{journey_id}/dwell/end
```
Request:
{
  "timestamp": "2024-01-15T14:05:00-08:00"
}

Response 200:
{
  "dwell_id": "uuid",
  "duration_sec": 1380,
  "status": "dwell_ended"
}
```

#### POST /journeys/{journey_id}/end
```
Request:
{
  "latitude": 47.4512,
  "longitude": -122.3045,
  "timestamp": "2024-01-15T14:12:00-08:00"
}

Response 200:
{
  "journey_id": "uuid",
  "total_duration_sec": 2040,
  "walking_duration_sec": 660,
  "dwell_duration_sec": 1380,
  "dwell_events": [
    { "duration_sec": 1380, "venue_type": "restaurant" }
  ],
  "percentile": 58,
  "xp_earned": {
    "base": 20,
    "total": 20
  },
  "new_total_xp": 1295
}
```

---

### 8. Competition

#### GET /compete/checkpoint/{checkpoint_id}/rank
```
Response 200:
{
  "checkpoint_id": "SEA-C3",
  "your_best_time_sec": 342,
  "your_percentile": 73,
  "daily_rank": 23,
  "daily_total": 89,
  "weekly_rank": 145,
  "alltime_rank": 892
}
```

#### GET /compete/leaderboards/daily
```
Query: ?checkpoint_id=SEA-C3

Response 200:
{
  "checkpoint_id": "SEA-C3",
  "period": "daily",
  "date": "2024-01-15",
  "entries": [
    { "rank": 1, "display_name": "SpeedyTraveler", "time_sec": 198 },
    { "rank": 2, "display_name": "GateRunner", "time_sec": 215 }
  ],
  "your_position": { "rank": 23, "time_sec": 660 }
}
```

---

### 9. Alerts

#### GET /alerts/upcoming
```
Response 200:
{
  "alerts": [
    {
      "flight_id": "uuid",
      "flight_number": "UA123",
      "boarding_time": "2024-01-15T14:30:00-08:00",
      "urgency": "normal",
      "recommended_arrival": "2024-01-15T13:55:00-08:00",
      "current_security_wait_min": 12,
      "gate_travel_min": 8,
      "recommended_checkpoint": "SEA-C3"
    }
  ]
}
```

---

### 10. Travel Time

#### GET /travel-time
```
Query: ?checkpoint_id=SEA-C3&gate_id=SEA-N7

Response 200:
{
  "checkpoint_id": "SEA-C3",
  "gate_id": "SEA-N7",
  "median_walking_sec": 480,
  "fast_estimate_sec": 300,
  "slow_estimate_sec": 720,
  "sample_count": 234
}
```

---

## Business Logic

### Percentile Calculation

```python
def calculate_percentile(checkpoint_id: str, security_type: str, time_sec: int) -> int:
    """
    Calculate percentile using last 30 days of data.
    Returns: percentile (0-100) or None if insufficient data.
    """
    sessions = get_sessions_last_30_days(checkpoint_id, security_type)
    
    if len(sessions) < 20:
        return estimate_percentile(time_sec)  # Fallback
    
    times = [s.duration_seconds for s in sessions]
    slower_count = sum(1 for t in times if t > time_sec)
    
    return int((slower_count / len(times)) * 100)


def estimate_percentile(time_sec: int) -> int:
    """Estimate when insufficient data."""
    if time_sec < 300:    return 90   # < 5 min
    if time_sec < 600:    return 70   # 5-10 min
    if time_sec < 900:    return 50   # 10-15 min
    if time_sec < 1200:   return 30   # 15-20 min
    return 10
```

### XP Calculation

```python
XP_RULES = {
    "security_session_complete": 25,
    "gate_journey_complete": 20,
    "personal_best": 15,
    "top_10_percent": 10,
    "top_1_percent": 25,
    "feedback_submitted": 10,
    "new_airport": 30,
}

def calculate_session_xp(percentile: int, is_personal_best: bool) -> dict:
    xp = {"base": 25, "bonus": 0}
    
    if is_personal_best:
        xp["bonus"] += 15
    
    if percentile >= 99:
        xp["bonus"] += 25
    elif percentile >= 90:
        xp["bonus"] += 10
    
    xp["total"] = xp["base"] + xp["bonus"]
    return xp
```

### Checkpoint Status Aggregation

```python
from app.database import supabase
from datetime import datetime, timedelta

async def update_checkpoint_status(checkpoint_id: str):
    """Recalculate from last 30 min of sessions. Updates trigger Supabase Realtime."""
    now = datetime.utcnow()
    thirty_min_ago = now - timedelta(minutes=30)
    
    # Get recent sessions using Supabase client
    response = supabase.table("security_sessions") \
        .select("duration_seconds, line_end_time") \
        .eq("checkpoint_id", checkpoint_id) \
        .eq("status", "completed") \
        .gte("line_end_time", thirty_min_ago.isoformat()) \
        .execute()
    
    sessions = response.data
    
    if not sessions:
        return
    
    # Time-weighted average (recent = higher weight)
    weighted_sum = 0
    total_weight = 0
    
    for s in sessions:
        end_time = datetime.fromisoformat(s["line_end_time"].replace("Z", "+00:00"))
        age_min = (now - end_time).total_seconds() / 60
        weight = max(0.1, 1 - (age_min / 30))
        weighted_sum += s["duration_seconds"] * weight
        total_weight += weight
    
    avg_sec = weighted_sum / total_weight
    current_wait_min = int(avg_sec / 60)
    confidence = min(1.0, len(sessions) / 10)
    
    # Trend detection
    sixty_min_ago = now - timedelta(minutes=60)
    prev_response = supabase.table("security_sessions") \
        .select("duration_seconds") \
        .eq("checkpoint_id", checkpoint_id) \
        .eq("status", "completed") \
        .gte("line_end_time", sixty_min_ago.isoformat()) \
        .lt("line_end_time", thirty_min_ago.isoformat()) \
        .execute()
    
    prev_sessions = prev_response.data
    if prev_sessions:
        prev_avg = sum(s["duration_seconds"] for s in prev_sessions) / len(prev_sessions)
        if avg_sec > prev_avg * 1.15:
            trend = "increasing"
        elif avg_sec < prev_avg * 0.85:
            trend = "decreasing"
        else:
            trend = "stable"
    else:
        trend = "stable"
    
    # Upsert to checkpoint_status (triggers Realtime broadcast)
    supabase.table("checkpoint_status").upsert({
        "checkpoint_id": checkpoint_id,
        "current_wait_min": current_wait_min,
        "confidence_score": confidence,
        "trend": trend,
        "sample_count_30min": len(sessions),
        "last_updated": now.isoformat()
    }).execute()
```

### Supabase Realtime (Client-Side)

Mobile app can subscribe to checkpoint status changes:

```typescript
// React Native / TypeScript
import { supabase } from './supabase'

// Subscribe to checkpoint status updates
const subscription = supabase
  .channel('checkpoint-status')
  .on(
    'postgres_changes',
    {
      event: 'UPDATE',
      schema: 'public',
      table: 'checkpoint_status',
      filter: `checkpoint_id=eq.SEA-C3`
    },
    (payload) => {
      console.log('Checkpoint status updated:', payload.new)
      // Update UI with new wait time
    }
  )
  .subscribe()
```

---

## Seed Data

### Data Collection Structure

Use a spreadsheet with these sheets:

**Sheet 1: Airports**
| airport_code | name | city | state | timezone | geofence_coords | has_airtrain | map_url | last_verified |

**Sheet 2: Checkpoints**
| checkpoint_id | airport_code | terminal | display_name | lat | lng | has_precheck | has_clear | serves_gates | notes | data_source | last_verified |

**Sheet 3: Gates**
| gate_id | airport_code | terminal | gate_number | lat | lng | notes | last_verified |

**Sheet 4: Initial Checkpoint Status**
| checkpoint_id | default_wait_min | confidence | notes |

### scripts/seed_airports.py

```python
"""
Seed data loader. Reads from JSON files and inserts into database.
Run this AFTER migrations, BEFORE testing.
"""

# Structure for each airport
SEED_DATA = {
    "SEA": {
        "name": "Seattle-Tacoma International",
        "city": "Seattle",
        "state": "WA",
        "timezone": "America/Los_Angeles",
        "geo_fence": "POLYGON((-122.32 47.43, -122.32 47.46, -122.29 47.46, -122.29 47.43, -122.32 47.43))",
        "map_url": "https://www.flysea.org/traveler-information/terminal-maps",
        "last_verified": "2024-01-15",
        "checkpoints": [
            {
                "checkpoint_id": "SEA-C2",
                "terminal": "Main",
                "display_name": "Checkpoint 2",
                "lat": 47.4493,
                "lng": -122.3055,
                "has_precheck": True,
                "has_clear": True,
                "serves_gates": ["A", "B", "C", "D"],
                "notes": "Main checkpoint, usually busiest",
                "data_source": "manual_research",
                "confidence": "high"
            },
            {
                "checkpoint_id": "SEA-C3",
                "terminal": "Main",
                "display_name": "Checkpoint 3",
                "lat": 47.4491,
                "lng": -122.3095,
                "has_precheck": True,
                "has_clear": False,
                "serves_gates": ["C", "D", "N"],
                "notes": "Locals' favorite - consistently faster",
                "data_source": "manual_research",
                "confidence": "high"
            },
            {
                "checkpoint_id": "SEA-C5",
                "terminal": "South",
                "display_name": "Checkpoint 5",
                "lat": 47.4445,
                "lng": -122.3020,
                "has_precheck": False,
                "has_clear": False,
                "serves_gates": ["S"],
                "notes": "South satellite access",
                "data_source": "manual_research",
                "confidence": "medium"
            }
        ],
        "gates": [
            {"gate_id": "SEA-N7", "terminal": "N", "gate_number": "N7", "lat": 47.4512, "lng": -122.3045},
            {"gate_id": "SEA-N15", "terminal": "N", "gate_number": "N15", "lat": 47.4520, "lng": -122.3030},
            {"gate_id": "SEA-S5", "terminal": "S", "gate_number": "S5", "lat": 47.4435, "lng": -122.3010},
            {"gate_id": "SEA-A10", "terminal": "A", "gate_number": "A10", "lat": 47.4488, "lng": -122.3040},
            # Add more gates...
        ],
        "checkpoint_status": [
            {"checkpoint_id": "SEA-C2", "default_wait_min": 15, "confidence": 0.3},
            {"checkpoint_id": "SEA-C3", "default_wait_min": 10, "confidence": 0.3},
            {"checkpoint_id": "SEA-C5", "default_wait_min": 12, "confidence": 0.3},
        ],
        "gate_travel_matrix": [
            # Auto-generated from coordinates, but can override
            {"checkpoint_id": "SEA-C3", "gate_id": "SEA-N7", "median_walking_sec": 480},
        ]
    },
    # Add LAX, SFO, JFK, ORD, ATL, DEN, DFW, BOS, MIA...
}

# Helper to generate travel time estimates from coordinates
def estimate_walking_time(lat1, lng1, lat2, lng2):
    """Estimate walking time based on distance. Assumes 1.2 m/s indoor walking."""
    from math import radians, sin, cos, sqrt, atan2
    
    R = 6371000  # Earth radius in meters
    lat1, lng1, lat2, lng2 = map(radians, [lat1, lng1, lat2, lng2])
    dlat = lat2 - lat1
    dlng = lng2 - lng1
    
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlng/2)**2
    c = 2 * atan2(sqrt(a), sqrt(1-a))
    distance = R * c
    
    # 1.2 m/s = slow indoor walk with luggage
    walking_sec = int(distance / 1.2)
    return walking_sec, int(distance)
```

### How to Research an Airport

1. **Find terminal map**
   - Google: "[airport code] terminal map pdf"
   - Check airport official website
   - Look for "Traveler Information" or "Maps" section

2. **Identify checkpoints**
   - Look for "Security" or "TSA" labels on map
   - Note terminal and nearby gates
   - Cross-reference with TSA MyTSA app for PreCheck/CLEAR

3. **Get coordinates**
   - Open Google Maps satellite view
   - Zoom into airport terminal
   - Find checkpoint location (usually between check-in and gates)
   - Right-click → "What's here?" → copy coordinates

4. **Draw geofence**
   - Use https://geojson.io/ to draw polygon
   - Cover entire airport property generously
   - Export as coordinates

5. **Get gate locations**
   - Same process as checkpoints
   - For large airports, focus on major gates first
   - Can estimate others from terminal map

6. **Verify**
   - Plot all points on a map
   - Check distances make sense
   - Note confidence level

---

## Complete Airport Run Test

### tests/test_complete_run.py

```python
"""
End-to-end test of complete airport journey.
Simulates: Brandon flying UA123 SEA→LAX
"""
import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_complete_airport_run(client: AsyncClient, auth_headers: dict):
    
    # STEP 1: Add flight
    r = await client.post("/app/v1/flights", headers=auth_headers, json={
        "flight_number": "UA123",
        "date": "2024-01-15",
        "departure_airport": "SEA"
    })
    assert r.status_code == 201
    flight = r.json()
    flight_id = flight["flight_id"]
    print(f"✓ Step 1: Added flight {flight['flight_number']}")
    
    # STEP 2: Get alerts
    r = await client.get("/app/v1/alerts/upcoming", headers=auth_headers)
    assert r.status_code == 200
    assert len(r.json()["alerts"]) == 1
    print("✓ Step 2: Got pre-arrival alert")
    
    # STEP 3: Enter airport
    r = await client.post("/app/v1/location/geofence/enter", headers=auth_headers, json={
        "geofence_id": "SEA-AIRPORT",
        "geofence_type": "airport",
        "latitude": 47.4502,
        "longitude": -122.3088,
        "timestamp": "2024-01-15T13:15:00-08:00",
        "accuracy_meters": 15
    })
    assert r.status_code == 200
    assert r.json()["status"] == "tracking_activated"
    print("✓ Step 3: Entered airport, tracking activated")
    
    # STEP 4: Get nearby checkpoints
    r = await client.get("/app/v1/checkpoints/nearby", headers=auth_headers,
                         params={"lat": 47.4489, "lng": -122.3094})
    assert r.status_code == 200
    checkpoints = r.json()["checkpoints"]
    assert len(checkpoints) > 0
    print(f"✓ Step 4: Found {len(checkpoints)} checkpoints")
    
    # STEP 5: Start security session
    r = await client.post("/app/v1/sessions/security/start", headers=auth_headers, json={
        "checkpoint_id": "SEA-C3",
        "flight_id": flight_id,
        "security_type": "standard",
        "latitude": 47.4491,
        "longitude": -122.3095,
        "timestamp": "2024-01-15T13:27:00-08:00"
    })
    assert r.status_code == 201
    session_id = r.json()["session_id"]
    print("✓ Step 5: Started security session")
    
    # STEP 6: End security session
    r = await client.post(f"/app/v1/sessions/security/{session_id}/end", headers=auth_headers, json={
        "latitude": 47.4495,
        "longitude": -122.3082,
        "timestamp": "2024-01-15T13:38:00-08:00",
        "end_method": "tap"
    })
    assert r.status_code == 200
    result = r.json()
    assert result["duration_seconds"] == 660
    assert result["xp_earned"]["total"] >= 25
    print(f"✓ Step 6: Completed security - {result['duration_display']}, {result['percentile']}th percentile")
    
    # STEP 7: Start gate journey
    r = await client.post("/app/v1/journeys/start", headers=auth_headers, json={
        "flight_id": flight_id,
        "checkpoint_id": "SEA-C3",
        "gate_id": "SEA-N7",
        "security_session_id": session_id,
        "latitude": 47.4495,
        "longitude": -122.3082,
        "timestamp": "2024-01-15T13:38:00-08:00"
    })
    assert r.status_code == 201
    journey_id = r.json()["journey_id"]
    print("✓ Step 7: Started gate journey")
    
    # STEP 8: Dwell event (bar stop)
    await client.post(f"/app/v1/journeys/{journey_id}/dwell/start", headers=auth_headers, json={
        "latitude": 47.4498,
        "longitude": -122.3078,
        "timestamp": "2024-01-15T13:42:00-08:00"
    })
    await client.post(f"/app/v1/journeys/{journey_id}/dwell/end", headers=auth_headers, json={
        "timestamp": "2024-01-15T14:05:00-08:00"
    })
    print("✓ Step 8: Recorded dwell event (23 min)")
    
    # STEP 9: End gate journey
    r = await client.post(f"/app/v1/journeys/{journey_id}/end", headers=auth_headers, json={
        "latitude": 47.4512,
        "longitude": -122.3045,
        "timestamp": "2024-01-15T14:12:00-08:00"
    })
    assert r.status_code == 200
    journey = r.json()
    assert journey["total_duration_sec"] == 2040
    assert journey["dwell_duration_sec"] == 1380
    print(f"✓ Step 9: Completed journey - {journey['walking_duration_sec']}s walking, {journey['dwell_duration_sec']}s dwell")
    
    # STEP 10: Get summary
    r = await client.get(f"/app/v1/flights/{flight_id}/journey-summary", headers=auth_headers)
    assert r.status_code == 200
    summary = r.json()
    assert summary["timing"]["security_wait_min"] == 11
    print("✓ Step 10: Got journey summary")
    
    # STEP 11: Submit feedback
    r = await client.get(f"/app/v1/flights/{flight_id}/feedback-prompt", headers=auth_headers)
    assert r.status_code == 200
    
    r = await client.post(f"/app/v1/flights/{flight_id}/feedback", headers=auth_headers, json={
        "responses": {
            "overall_helpful": 3,
            "estimate_accuracy": 4,
            "would_use_again": True,
            "stress_level": 3
        }
    })
    assert r.status_code == 201
    assert r.json()["xp_earned"] == 10
    print("✓ Step 11: Submitted feedback")
    
    print("\n🎉 COMPLETE AIRPORT RUN PASSED!")
```

---

## Docker Setup (Local Development)

For local development, you can either:
1. Use Supabase Cloud (recommended) — just set env vars
2. Run Supabase locally with Docker

### Option 1: Supabase Cloud (Recommended)

```bash
# Just need your FastAPI app
docker build -t airport-quest-api .
docker run -p 8000:8000 \
  -e SUPABASE_URL=https://your-project.supabase.co \
  -e SUPABASE_SERVICE_KEY=your-service-key \
  airport-quest-api
```

### Option 2: Local Supabase

```yaml
# docker-compose.yml
version: '3.8'

services:
  api:
    build: .
    ports:
      - "8000:8000"
    environment:
      - SUPABASE_URL=http://localhost:54321
      - SUPABASE_ANON_KEY=your-local-anon-key
      - SUPABASE_SERVICE_KEY=your-local-service-key
    depends_on:
      - supabase

  # Supabase runs via CLI, not docker-compose
  # Run: supabase start
```

### Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### requirements.txt

```
fastapi>=0.104.0
uvicorn>=0.24.0
supabase>=2.0.0
python-dotenv>=1.0.0
pydantic>=2.0.0
pydantic-settings>=2.0.0
httpx>=0.25.0
python-jose>=3.3.0
passlib>=1.7.4
```

---

## Implementation Order

### Phase 0: Data Collection (Before Coding)
- [ ] Create data collection spreadsheet
- [ ] Research SEA (checkpoints, gates, geofence)
- [ ] Research 9 more airports (LAX, SFO, JFK, ORD, ATL, DEN, DFW, BOS, MIA)
- [ ] Generate seed SQL from collected data
- [ ] Verify data accuracy (spot-check coordinates on map)

### Phase 1: Foundation (Days 1-2)
- [ ] Project setup, FastAPI app
- [ ] Database models + Alembic migrations
- [ ] Auth endpoints (register, login, refresh)
- [ ] User endpoints
- [ ] Seed data script

### Phase 2 
#### Part I: Core Tracking (Days 3-4)
- [ ] Flight endpoints
- [ ] Location endpoints
- [ ] Checkpoint endpoints
- [ ] Security session endpoints (start, end)

#### Part II: Journeys (Days 5-6)
- [ ] Gate journey endpoints
- [ ] Dwell event handling
- [ ] Travel time endpoint
- [ ] Journey summary endpoint

#### Part III: Intelligence (Days 7-8)
- [ ] Percentile calculation service
- [ ] XP calculation + awarding
- [ ] Checkpoint status aggregation
- [ ] Leaderboard endpoints

#### Part IV: Polish (Days 9-10)
- [ ] Alerts endpoint
- [ ] Feedback endpoints
- [ ] Competition endpoints
- [ ] Complete run test
- [ ] Bug fixes

---

## Success Criteria

Before building frontend, verify:

1. ✅ `pytest tests/test_complete_run.py -v` passes
2. ✅ All 11 steps execute without errors
3. ✅ XP accumulates correctly
4. ✅ Percentiles calculate (even with seed data)
5. ✅ Dwell time segments correctly
6. ✅ Feedback records to database
7. ✅ API docs work at `/docs`

---

## Notes

- All timestamps are UTC internally, convert for display
- Distances use PostGIS ST_Distance with geography type (meters)
- Redis keys: `checkpoint:{id}:status`, `leaderboard:{checkpoint}:daily:{date}`
- JWT expiry: 60 min access, 7 day refresh
- For MVP, flight lookup can return mock data (no external API needed)

---

**Ready to build. Start with Phase 1.**