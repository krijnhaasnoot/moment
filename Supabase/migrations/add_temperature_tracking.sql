-- ============================================
-- MIGRATION: Add Basal Body Temperature (BBT) Tracking
-- ============================================
-- This migration adds optional temperature tracking capabilities.
-- Temperature is stored but NOT used for fertility predictions in v1.
-- It may be used as a secondary signal in future versions.
-- ============================================

-- Add temperature tracking preference to profiles
-- OFF by default, user must explicitly enable
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS temperature_tracking_enabled BOOLEAN NOT NULL DEFAULT false;

-- Add flag to track if user has seen the one-time explanation
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS temperature_info_acknowledged BOOLEAN NOT NULL DEFAULT false;

-- Add temperature unit preference (celsius by default)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS temperature_unit TEXT NOT NULL DEFAULT 'celsius' 
CHECK (temperature_unit IN ('celsius', 'fahrenheit'));

-- Add temperature field to cycle_days
-- Stored in Celsius internally, converted for display based on user preference
-- Note: This field is currently stored only and displayed in history.
-- It is NOT used to drive ovulation prediction or fertile window logic.
-- Future versions may use temperature as a secondary confirmation signal.
ALTER TABLE public.cycle_days 
ADD COLUMN IF NOT EXISTS temperature DECIMAL(4,2);

-- Add timestamp for when temperature was logged
ALTER TABLE public.cycle_days 
ADD COLUMN IF NOT EXISTS temperature_logged_at TIMESTAMPTZ;

-- ============================================
-- COMMENTS (for documentation)
-- ============================================
COMMENT ON COLUMN public.profiles.temperature_tracking_enabled IS 
'User preference: whether to show temperature input. OFF by default.';

COMMENT ON COLUMN public.profiles.temperature_info_acknowledged IS 
'Has user seen and dismissed the one-time temperature info modal.';

COMMENT ON COLUMN public.profiles.temperature_unit IS 
'Display preference for temperature: celsius (default) or fahrenheit.';

COMMENT ON COLUMN public.cycle_days.temperature IS 
'Basal body temperature in Celsius. Optional field, null if not logged. Currently stored only - not used for predictions.';

COMMENT ON COLUMN public.cycle_days.temperature_logged_at IS 
'Timestamp when temperature was recorded for this day.';
