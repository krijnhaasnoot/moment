-- ============================================
-- MOMENT APP - SUPABASE DATABASE SCHEMA
-- ============================================
-- Run this in your Supabase SQL Editor
-- Dashboard: https://supabase.com/dashboard
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- TABLES
-- ============================================

-- Users table (extends Supabase auth.users)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('woman', 'partner')),
    couple_id UUID,
    notification_tone TEXT NOT NULL DEFAULT 'discreet' CHECK (notification_tone IN ('discreet', 'explicit')),
    notifications_enabled BOOLEAN NOT NULL DEFAULT true,
    push_token TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Couples table
CREATE TABLE public.couples (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    woman_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    partner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    invite_code TEXT NOT NULL UNIQUE,
    is_linked BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add foreign key from profiles to couples
ALTER TABLE public.profiles 
ADD CONSTRAINT fk_profiles_couple 
FOREIGN KEY (couple_id) REFERENCES public.couples(id) ON DELETE SET NULL;

-- Cycles table
CREATE TABLE public.cycles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    couple_id UUID REFERENCES public.couples(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE,
    cycle_length INTEGER NOT NULL DEFAULT 28,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Cycle days table
CREATE TABLE public.cycle_days (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cycle_id UUID NOT NULL REFERENCES public.cycles(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    fertility_level TEXT NOT NULL DEFAULT 'low' CHECK (fertility_level IN ('low', 'high', 'peak')),
    is_menstruation BOOLEAN NOT NULL DEFAULT false,
    lh_test_result TEXT CHECK (lh_test_result IN ('negative', 'positive')),
    lh_test_logged_at TIMESTAMPTZ,
    had_intimacy BOOLEAN DEFAULT false,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(cycle_id, date)
);

-- Migration: Add had_intimacy column if table exists
-- Run this if upgrading from previous schema:
-- ALTER TABLE public.cycle_days ADD COLUMN IF NOT EXISTS had_intimacy BOOLEAN DEFAULT false;

-- Notifications log (for tracking sent notifications)
CREATE TABLE public.notification_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('daily_fertility', 'lh_reminder', 'lh_positive', 'cycle_start')),
    content TEXT NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX idx_profiles_couple_id ON public.profiles(couple_id);
CREATE INDEX idx_couples_invite_code ON public.couples(invite_code);
CREATE INDEX idx_couples_woman_id ON public.couples(woman_id);
CREATE INDEX idx_cycles_user_id ON public.cycles(user_id);
CREATE INDEX idx_cycles_couple_id ON public.cycles(couple_id);
CREATE INDEX idx_cycles_active ON public.cycles(is_active) WHERE is_active = true;
CREATE INDEX idx_cycle_days_cycle_id ON public.cycle_days(cycle_id);
CREATE INDEX idx_cycle_days_date ON public.cycle_days(date);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.couples ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cycles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cycle_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_log ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can read/update their own profile
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Profiles: Users can view their partner's profile (limited fields via function)
CREATE POLICY "Users can view partner profile" ON public.profiles
    FOR SELECT USING (
        couple_id IN (
            SELECT couple_id FROM public.profiles WHERE id = auth.uid()
        )
    );

-- Couples: Woman can manage her couple
CREATE POLICY "Woman can manage couple" ON public.couples
    FOR ALL USING (woman_id = auth.uid());

-- Couples: Partner can view couple they're part of
CREATE POLICY "Partner can view couple" ON public.couples
    FOR SELECT USING (partner_id = auth.uid());

-- Couples: Partner can update couple to unlink themselves
CREATE POLICY "Partner can update couple" ON public.couples
    FOR UPDATE USING (partner_id = auth.uid());

-- Couples: Anyone can view couple by invite code (for joining)
CREATE POLICY "Anyone can view couple by invite code" ON public.couples
    FOR SELECT USING (true);

-- Cycles: Woman can manage her cycles
CREATE POLICY "Woman can manage cycles" ON public.cycles
    FOR ALL USING (user_id = auth.uid());

-- Cycles: Partner can view cycles (fertility data only, enforced in app)
CREATE POLICY "Partner can view couple cycles" ON public.cycles
    FOR SELECT USING (
        couple_id IN (
            SELECT couple_id FROM public.profiles WHERE id = auth.uid()
        )
    );

-- Cycle days: Woman can manage her cycle days
CREATE POLICY "Woman can manage cycle days" ON public.cycle_days
    FOR ALL USING (
        cycle_id IN (
            SELECT id FROM public.cycles WHERE user_id = auth.uid()
        )
    );

-- Cycle days: Partner can view cycle days (limited via app logic)
CREATE POLICY "Partner can view couple cycle days" ON public.cycle_days
    FOR SELECT USING (
        cycle_id IN (
            SELECT c.id FROM public.cycles c
            JOIN public.profiles p ON c.couple_id = p.couple_id
            WHERE p.id = auth.uid()
        )
    );

-- Cycle days: Partner can update intimacy on cycle days
CREATE POLICY "Partner can update couple cycle days" ON public.cycle_days
    FOR UPDATE USING (
        cycle_id IN (
            SELECT c.id FROM public.cycles c
            JOIN public.profiles p ON c.couple_id = p.couple_id
            WHERE p.id = auth.uid()
        )
    );

-- Notification log: Users can view their own notifications
CREATE POLICY "Users can view own notifications" ON public.notification_log
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can insert own notifications" ON public.notification_log
    FOR INSERT WITH CHECK (user_id = auth.uid());

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to generate unique invite code
CREATE OR REPLACE FUNCTION generate_invite_code()
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    result TEXT := '';
    i INTEGER;
BEGIN
    FOR i IN 1..6 LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to create a couple when woman signs up
CREATE OR REPLACE FUNCTION create_couple_for_woman()
RETURNS TRIGGER AS $$
DECLARE
    new_couple_id UUID;
    new_invite_code TEXT;
BEGIN
    IF NEW.role = 'woman' THEN
        -- Generate unique invite code
        LOOP
            new_invite_code := generate_invite_code();
            EXIT WHEN NOT EXISTS (SELECT 1 FROM public.couples WHERE invite_code = new_invite_code);
        END LOOP;
        
        -- Create couple
        INSERT INTO public.couples (woman_id, invite_code)
        VALUES (NEW.id, new_invite_code)
        RETURNING id INTO new_couple_id;
        
        -- Update profile with couple_id
        NEW.couple_id := new_couple_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-create couple for woman
CREATE TRIGGER on_woman_profile_created
    BEFORE INSERT ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION create_couple_for_woman();

-- Function to join couple with invite code
CREATE OR REPLACE FUNCTION join_couple(invite_code_input TEXT)
RETURNS JSON AS $$
DECLARE
    couple_record RECORD;
    result JSON;
BEGIN
    -- Find couple by invite code
    SELECT * INTO couple_record 
    FROM public.couples 
    WHERE invite_code = UPPER(invite_code_input);
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'Invalid invite code');
    END IF;
    
    IF couple_record.is_linked THEN
        RETURN json_build_object('success', false, 'error', 'This couple is already linked');
    END IF;
    
    -- Link partner to couple
    UPDATE public.couples 
    SET partner_id = auth.uid(), is_linked = true, updated_at = NOW()
    WHERE id = couple_record.id;
    
    -- Update partner's profile
    UPDATE public.profiles 
    SET couple_id = couple_record.id, updated_at = NOW()
    WHERE id = auth.uid();
    
    RETURN json_build_object('success', true, 'couple_id', couple_record.id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get partner-safe cycle data (no menstruation details)
CREATE OR REPLACE FUNCTION get_partner_cycle_view(cycle_id_input UUID)
RETURNS TABLE (
    date DATE,
    fertility_level TEXT,
    lh_test_result TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cd.date,
        cd.fertility_level,
        cd.lh_test_result
    FROM public.cycle_days cd
    WHERE cd.cycle_id = cycle_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_couples_updated_at
    BEFORE UPDATE ON public.couples
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_cycles_updated_at
    BEFORE UPDATE ON public.cycles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_cycle_days_updated_at
    BEFORE UPDATE ON public.cycle_days
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- TRIGGER: Auto-sync couple_id to cycles when partner joins
-- ============================================

-- When a couple becomes linked (partner joins), ensure all woman's cycles have couple_id
CREATE OR REPLACE FUNCTION sync_cycles_couple_id()
RETURNS TRIGGER AS $$
BEGIN
    -- Only run when couple becomes linked (is_linked changes to true)
    IF NEW.is_linked = true AND (OLD.is_linked = false OR OLD.is_linked IS NULL) THEN
        -- Update all cycles for this woman that don't have couple_id
        UPDATE public.cycles
        SET couple_id = NEW.id,
            updated_at = NOW()
        WHERE user_id = NEW.woman_id
          AND couple_id IS NULL;
        
        RAISE NOTICE 'Synced couple_id % to cycles for woman %', NEW.id, NEW.woman_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER sync_cycles_on_couple_link
    AFTER UPDATE ON public.couples
    FOR EACH ROW EXECUTE FUNCTION sync_cycles_couple_id();

-- ============================================
-- REALTIME SUBSCRIPTIONS
-- ============================================

-- Enable realtime for couples and cycle_days (for partner sync)
ALTER PUBLICATION supabase_realtime ADD TABLE public.couples;
ALTER PUBLICATION supabase_realtime ADD TABLE public.cycle_days;
ALTER PUBLICATION supabase_realtime ADD TABLE public.cycles;
