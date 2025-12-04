-- Create the 'daily_work_span' table to store the processed Avadhi data.
CREATE TABLE public.daily_work_span (
    -- Primary Key: Required for UPSERT operations (on_conflict=date)
    date DATE PRIMARY KEY,

    -- Timestamp: Stored in UTC, useful for indexing and sorting
    timestamp TIMESTAMPTZ NOT NULL,

    -- Login/Logout Times
    first_boot TIME WITHOUT TIME ZONE NOT NULL,
    last_shutdown TIME WITHOUT TIME ZONE NOT NULL,

    -- Calculated Span Data
    total_span_minutes BIGINT NOT NULL,
    total_span TEXT NOT NULL, -- The H.MM formatted string (e.g., '9.06')

    -- Optional: Record when the entry was last updated by the Rust service
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Apply indexes for faster querying
CREATE INDEX idx_daily_work_span_timestamp ON public.daily_work_span (timestamp);

COMMENT ON TABLE public.daily_work_span IS 'Stores the calculated earliest boot and latest shutdown duration for each day.';


-- 1. Enable RLS on the new table
ALTER TABLE public.daily_work_span ENABLE ROW LEVEL SECURITY;

-- 2. Policy for INSERT/UPSERT: Allow the Rust Service (using the Service Role Key) to insert/update.
-- The Service Role Key bypasses RLS, but for a typical authenticated user (which you might use
-- during initial testing), this is a common policy.
-- For production, you usually grant SELECT access to 'anon' for the dashboard.
CREATE POLICY "Enable all access for service role only"
ON public.daily_work_span
FOR ALL
USING (
  (SELECT auth.role()) = 'service_role'
)
WITH CHECK (
  (SELECT auth.role()) = 'service_role'
);

-- 3. Policy for READ (Frontend): Allow public read access (essential for the Lovable.dev dashboard).
CREATE POLICY "Enable read access for all users"
ON public.daily_work_span
FOR SELECT
TO public
USING (
  true
);