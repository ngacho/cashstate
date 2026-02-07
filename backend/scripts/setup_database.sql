-- Airport Quest Database Schema
-- Run this in the Supabase SQL Editor

-- Enable PostGIS extension for geospatial features
CREATE EXTENSION IF NOT EXISTS postgis;

-- =====================================================
-- TABLES
-- =====================================================

-- Users table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    home_airport TEXT,
    total_xp INTEGER DEFAULT 0,
    level INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Airports table
CREATE TABLE IF NOT EXISTS public.airports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL, -- IATA code (e.g., 'LAX')
    name TEXT NOT NULL,
    city TEXT NOT NULL,
    country TEXT NOT NULL,
    timezone TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    geofence_radius INTEGER DEFAULT 5000, -- meters
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create spatial index on airports
CREATE INDEX IF NOT EXISTS airports_location_idx ON public.airports
    USING GIST (ST_SetSRID(ST_MakePoint(longitude, latitude), 4326));

-- Security checkpoints table
CREATE TABLE IF NOT EXISTS public.checkpoints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    airport_code TEXT NOT NULL REFERENCES public.airports(code) ON DELETE CASCADE,
    name TEXT NOT NULL, -- e.g., 'TSA PreCheck - Terminal 1'
    terminal TEXT,
    checkpoint_type TEXT DEFAULT 'standard', -- 'standard', 'precheck', 'clear', 'global_entry'
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    geofence_radius INTEGER DEFAULT 100, -- meters
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS checkpoints_airport_idx ON public.checkpoints(airport_code);

-- Gates table
CREATE TABLE IF NOT EXISTS public.gates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    airport_code TEXT NOT NULL REFERENCES public.airports(code) ON DELETE CASCADE,
    terminal TEXT NOT NULL,
    gate_number TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    geofence_radius INTEGER DEFAULT 50, -- meters
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(airport_code, terminal, gate_number)
);

CREATE INDEX IF NOT EXISTS gates_airport_idx ON public.gates(airport_code);

-- User flights table
CREATE TABLE IF NOT EXISTS public.flights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    flight_number TEXT NOT NULL,
    airline TEXT NOT NULL,
    departure_airport TEXT NOT NULL REFERENCES public.airports(code),
    arrival_airport TEXT NOT NULL REFERENCES public.airports(code),
    departure_time TIMESTAMPTZ NOT NULL,
    arrival_time TIMESTAMPTZ,
    gate_id UUID REFERENCES public.gates(id),
    status TEXT DEFAULT 'scheduled', -- 'scheduled', 'active', 'completed', 'cancelled'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS flights_user_idx ON public.flights(user_id);
CREATE INDEX IF NOT EXISTS flights_departure_idx ON public.flights(departure_time);

-- Airport visits (geofence entry/exit tracking)
CREATE TABLE IF NOT EXISTS public.airport_visits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    airport_code TEXT NOT NULL REFERENCES public.airports(code),
    flight_id UUID REFERENCES public.flights(id),
    entered_at TIMESTAMPTZ DEFAULT NOW(),
    exited_at TIMESTAMPTZ,
    entry_latitude DOUBLE PRECISION,
    entry_longitude DOUBLE PRECISION
);

CREATE INDEX IF NOT EXISTS visits_user_idx ON public.airport_visits(user_id);
CREATE INDEX IF NOT EXISTS visits_airport_idx ON public.airport_visits(airport_code);

-- Security sessions (queue time tracking)
CREATE TABLE IF NOT EXISTS public.security_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    checkpoint_id UUID NOT NULL REFERENCES public.checkpoints(id),
    flight_id UUID REFERENCES public.flights(id),
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER, -- calculated on end
    estimated_wait_minutes INTEGER, -- user's estimate at start
    actual_wait_minutes INTEGER, -- calculated on end
    xp_earned INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS sessions_user_idx ON public.security_sessions(user_id);
CREATE INDEX IF NOT EXISTS sessions_checkpoint_idx ON public.security_sessions(checkpoint_id);
CREATE INDEX IF NOT EXISTS sessions_started_idx ON public.security_sessions(started_at);

-- Gate journeys (checkpoint to gate tracking)
CREATE TABLE IF NOT EXISTS public.gate_journeys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    flight_id UUID REFERENCES public.flights(id),
    security_session_id UUID REFERENCES public.security_sessions(id),
    origin_checkpoint_id UUID REFERENCES public.checkpoints(id),
    destination_gate_id UUID REFERENCES public.gates(id),
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    total_distance_meters DOUBLE PRECISION,
    total_duration_seconds INTEGER,
    walking_duration_seconds INTEGER, -- excluding dwells
    xp_earned INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS journeys_user_idx ON public.gate_journeys(user_id);
CREATE INDEX IF NOT EXISTS journeys_flight_idx ON public.gate_journeys(flight_id);

-- Journey waypoints (location tracking during journey)
CREATE TABLE IF NOT EXISTS public.journey_waypoints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    journey_id UUID NOT NULL REFERENCES public.gate_journeys(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy DOUBLE PRECISION,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS waypoints_journey_idx ON public.journey_waypoints(journey_id);

-- Dwell events (stops during journey - shops, restaurants, etc.)
CREATE TABLE IF NOT EXISTS public.dwell_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    journey_id UUID NOT NULL REFERENCES public.gate_journeys(id) ON DELETE CASCADE,
    location_type TEXT, -- 'shop', 'restaurant', 'lounge', 'restroom', 'other'
    location_name TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER
);

CREATE INDEX IF NOT EXISTS dwells_journey_idx ON public.dwell_events(journey_id);

-- XP transactions
CREATE TABLE IF NOT EXISTS public.xp_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL,
    reason TEXT NOT NULL, -- 'security_session', 'journey_complete', 'feedback', 'bonus'
    reference_id UUID, -- ID of related session/journey/etc
    reference_type TEXT, -- 'security_session', 'gate_journey', 'feedback'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS xp_user_idx ON public.xp_transactions(user_id);
CREATE INDEX IF NOT EXISTS xp_created_idx ON public.xp_transactions(created_at);

-- Feedback table
CREATE TABLE IF NOT EXISTS public.feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    flight_id UUID REFERENCES public.flights(id),
    security_session_id UUID REFERENCES public.security_sessions(id),
    checkpoint_id UUID REFERENCES public.checkpoints(id),
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    wait_accuracy TEXT, -- 'accurate', 'longer', 'shorter'
    comments TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS feedback_checkpoint_idx ON public.feedback(checkpoint_id);
CREATE INDEX IF NOT EXISTS feedback_session_idx ON public.feedback(security_session_id);

-- Checkpoint status cache (aggregated wait times)
CREATE TABLE IF NOT EXISTS public.checkpoint_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    checkpoint_id UUID NOT NULL REFERENCES public.checkpoints(id) ON DELETE CASCADE,
    current_wait_minutes INTEGER,
    trend TEXT, -- 'increasing', 'decreasing', 'stable'
    confidence DOUBLE PRECISION, -- 0-1 based on sample size
    sample_count INTEGER DEFAULT 0,
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(checkpoint_id)
);

CREATE INDEX IF NOT EXISTS status_checkpoint_idx ON public.checkpoint_status(checkpoint_id);

-- Daily leaderboards
CREATE TABLE IF NOT EXISTS public.leaderboards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    leaderboard_date DATE NOT NULL,
    airport_code TEXT REFERENCES public.airports(code),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    xp_earned INTEGER DEFAULT 0,
    sessions_completed INTEGER DEFAULT 0,
    rank INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(leaderboard_date, airport_code, user_id)
);

CREATE INDEX IF NOT EXISTS leaderboard_date_idx ON public.leaderboards(leaderboard_date);
CREATE INDEX IF NOT EXISTS leaderboard_airport_idx ON public.leaderboards(airport_code);

-- =====================================================
-- FUNCTIONS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_flights_updated_at
    BEFORE UPDATE ON public.flights
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to calculate distance between two points (in meters)
CREATE OR REPLACE FUNCTION calculate_distance(
    lat1 DOUBLE PRECISION,
    lon1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION,
    lon2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION AS $$
BEGIN
    RETURN ST_DistanceSphere(
        ST_MakePoint(lon1, lat1),
        ST_MakePoint(lon2, lat2)
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to find nearby checkpoints
CREATE OR REPLACE FUNCTION find_nearby_checkpoints(
    user_lat DOUBLE PRECISION,
    user_lon DOUBLE PRECISION,
    radius_meters INTEGER DEFAULT 5000
)
RETURNS TABLE (
    checkpoint_id UUID,
    checkpoint_name TEXT,
    airport_code TEXT,
    checkpoint_type TEXT,
    distance_meters DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.name,
        c.airport_code,
        c.checkpoint_type,
        calculate_distance(user_lat, user_lon, c.latitude, c.longitude) as distance
    FROM public.checkpoints c
    WHERE c.is_active = TRUE
    AND calculate_distance(user_lat, user_lon, c.latitude, c.longitude) <= radius_meters
    ORDER BY distance;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate percentile for security wait time
CREATE OR REPLACE FUNCTION calculate_wait_percentile(
    p_checkpoint_id UUID,
    p_wait_minutes INTEGER,
    p_days_back INTEGER DEFAULT 30
)
RETURNS INTEGER AS $$
DECLARE
    percentile_rank INTEGER;
    total_count INTEGER;
    below_count INTEGER;
BEGIN
    SELECT COUNT(*), COUNT(*) FILTER (WHERE actual_wait_minutes < p_wait_minutes)
    INTO total_count, below_count
    FROM public.security_sessions
    WHERE checkpoint_id = p_checkpoint_id
    AND ended_at IS NOT NULL
    AND ended_at >= NOW() - (p_days_back || ' days')::INTERVAL;

    IF total_count = 0 THEN
        RETURN 50; -- Default to median if no data
    END IF;

    percentile_rank := (below_count * 100) / total_count;
    RETURN percentile_rank;
END;
$$ LANGUAGE plpgsql;

-- Function to update user XP and level
CREATE OR REPLACE FUNCTION update_user_xp(
    p_user_id UUID,
    p_amount INTEGER
)
RETURNS void AS $$
DECLARE
    new_total INTEGER;
    new_level INTEGER;
BEGIN
    UPDATE public.users
    SET total_xp = total_xp + p_amount
    WHERE id = p_user_id
    RETURNING total_xp INTO new_total;

    -- Simple level calculation: level = floor(total_xp / 100) + 1
    new_level := GREATEST(1, (new_total / 100) + 1);

    UPDATE public.users
    SET level = new_level
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.airport_visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gate_journeys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_waypoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dwell_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.xp_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboards ENABLE ROW LEVEL SECURITY;

-- Public read access for reference tables
ALTER TABLE public.airports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checkpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checkpoint_status ENABLE ROW LEVEL SECURITY;

-- Policies for users table
CREATE POLICY "Users can view own profile"
    ON public.users FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can create own profile"
    ON public.users FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Allow service role to manage users (for backend auto-creation)
CREATE POLICY "Service role can manage users"
    ON public.users FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role')
    WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Users can update own profile"
    ON public.users FOR UPDATE
    USING (auth.uid() = id);

-- Policies for flights
CREATE POLICY "Users can view own flights"
    ON public.flights FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create own flights"
    ON public.flights FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own flights"
    ON public.flights FOR UPDATE
    USING (auth.uid() = user_id);

-- Policies for security_sessions
CREATE POLICY "Users can view own sessions"
    ON public.security_sessions FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create own sessions"
    ON public.security_sessions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sessions"
    ON public.security_sessions FOR UPDATE
    USING (auth.uid() = user_id);

-- Policies for gate_journeys
CREATE POLICY "Users can view own journeys"
    ON public.gate_journeys FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create own journeys"
    ON public.gate_journeys FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own journeys"
    ON public.gate_journeys FOR UPDATE
    USING (auth.uid() = user_id);

-- Policies for journey_waypoints (through journey ownership)
CREATE POLICY "Users can view waypoints of own journeys"
    ON public.journey_waypoints FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM public.gate_journeys gj
        WHERE gj.id = journey_id AND gj.user_id = auth.uid()
    ));

CREATE POLICY "Users can create waypoints for own journeys"
    ON public.journey_waypoints FOR INSERT
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.gate_journeys gj
        WHERE gj.id = journey_id AND gj.user_id = auth.uid()
    ));

-- Policies for dwell_events
CREATE POLICY "Users can view dwells of own journeys"
    ON public.dwell_events FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM public.gate_journeys gj
        WHERE gj.id = journey_id AND gj.user_id = auth.uid()
    ));

CREATE POLICY "Users can create dwells for own journeys"
    ON public.dwell_events FOR INSERT
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.gate_journeys gj
        WHERE gj.id = journey_id AND gj.user_id = auth.uid()
    ));

CREATE POLICY "Users can update dwells of own journeys"
    ON public.dwell_events FOR UPDATE
    USING (EXISTS (
        SELECT 1 FROM public.gate_journeys gj
        WHERE gj.id = journey_id AND gj.user_id = auth.uid()
    ));

-- Policies for airport_visits
CREATE POLICY "Users can view own visits"
    ON public.airport_visits FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create own visits"
    ON public.airport_visits FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policies for xp_transactions
CREATE POLICY "Users can view own XP"
    ON public.xp_transactions FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Server can create XP transactions"
    ON public.xp_transactions FOR INSERT
    WITH CHECK (true);  -- Server-side only, protected by API

-- Policies for feedback
CREATE POLICY "Users can view own feedback"
    ON public.feedback FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create feedback"
    ON public.feedback FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policies for leaderboards (public read)
CREATE POLICY "Anyone can view leaderboards"
    ON public.leaderboards FOR SELECT
    USING (true);

-- Public read policies for reference tables
CREATE POLICY "Anyone can view airports"
    ON public.airports FOR SELECT
    USING (true);

CREATE POLICY "Anyone can view checkpoints"
    ON public.checkpoints FOR SELECT
    USING (true);

CREATE POLICY "Anyone can view gates"
    ON public.gates FOR SELECT
    USING (true);

CREATE POLICY "Anyone can view checkpoint status"
    ON public.checkpoint_status FOR SELECT
    USING (true);

-- Service role bypass (for backend operations)
-- The service key bypasses RLS by default in Supabase

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Compound indexes for common queries
CREATE INDEX IF NOT EXISTS sessions_checkpoint_time_idx
    ON public.security_sessions(checkpoint_id, started_at DESC);

CREATE INDEX IF NOT EXISTS journeys_user_time_idx
    ON public.gate_journeys(user_id, started_at DESC);

CREATE INDEX IF NOT EXISTS xp_user_time_idx
    ON public.xp_transactions(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS feedback_checkpoint_time_idx
    ON public.feedback(checkpoint_id, created_at DESC);
