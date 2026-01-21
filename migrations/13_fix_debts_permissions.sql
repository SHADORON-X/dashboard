-- Migration: Fix debts permissions and create propose_debt RPC
-- Description: Add proper permissions for debts table and create RPC function
-- Date: 2025-12-25

-- ================================================================
-- 1. GRANT PERMISSIONS ON DEBTS TABLE
-- ================================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.debts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.debts TO anon;

-- ================================================================
-- 2. CREATE PROPOSE_DEBT RPC FUNCTION
-- ================================================================

-- Drop existing function if it exists (to avoid "already exists" error)
DROP FUNCTION IF EXISTS public.propose_debt(
    NUMERIC,
    UUID,
    TEXT,
    TIMESTAMPTZ,
    TEXT,
    UUID
) CASCADE;

CREATE OR REPLACE FUNCTION public.propose_debt(
    p_amount NUMERIC,
    p_user_id UUID,                          -- Changed from p_creditor_id
    p_debtor_identifier TEXT,
    p_due_date TIMESTAMPTZ,
    p_notes TEXT DEFAULT NULL,
    p_shop_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    velmo_id TEXT,
    shop_id UUID,
    user_id UUID,
    debtor_id UUID,
    customer_name TEXT,
    customer_phone TEXT,
    customer_address TEXT,
    total_amount NUMERIC,
    paid_amount NUMERIC,
    remaining_amount NUMERIC,
    status TEXT,
    type TEXT,
    category TEXT,
    due_date TIMESTAMPTZ,
    reliability_score NUMERIC,
    trust_level TEXT,
    payment_count INTEGER,
    on_time_payment_count INTEGER,
    notes TEXT,
    products_json JSONB,
    sync_status TEXT,
    synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_debt_id UUID;
    v_velmo_id TEXT;
    v_debtor_id UUID;
    v_debtor_name TEXT;
    v_debtor_phone TEXT;
    v_is_velmo_id BOOLEAN;
BEGIN
    -- Generate unique debt ID and Velmo ID
    v_debt_id := gen_random_uuid();
    v_velmo_id := 'DBT-' || substr(v_debt_id::TEXT, 1, 8);
    
    -- Check if debtor_identifier is a Velmo ID (starts with VLM-)
    v_is_velmo_id := p_debtor_identifier LIKE 'VLM-%';
    
    IF v_is_velmo_id THEN
        -- It's a Velmo ID - try to find the user
        SELECT u.id, concat(u.first_name, ' ', u.last_name), u.phone
        INTO v_debtor_id, v_debtor_name, v_debtor_phone
        FROM public.users u
        WHERE u.velmo_id = p_debtor_identifier;
        
        -- ✅ FIX: Si l'utilisateur n'existe pas, créer la dette en mode OFFLINE
        -- (pas de debtor_id lié, juste le Velmo ID en reference)
        IF v_debtor_id IS NULL THEN
            -- L'utilisateur avec ce Velmo ID n'existe pas
            -- On crée quand même la dette, juste pas liée
            v_debtor_id := NULL;
            v_debtor_name := p_debtor_identifier; -- Garder le Velmo ID comme nom
            v_debtor_phone := NULL;
            RAISE NOTICE 'Velmo ID % not found yet, creating offline debt', p_debtor_identifier;
        END IF;
    ELSE
        -- It's a name/phone - create an offline debt (no debtor_id)
        v_debtor_id := NULL;
        v_debtor_name := p_debtor_identifier;
        v_debtor_phone := NULL;
    END IF;
    
    -- Insert the debt
    INSERT INTO public.debts (
        id,
        velmo_id,
        shop_id,
        user_id,
        debtor_id,
        customer_name,
        customer_phone,
        customer_address,
        total_amount,
        paid_amount,
        remaining_amount,
        status,
        type,
        category,
        due_date,
        reliability_score,
        trust_level,
        payment_count,
        on_time_payment_count,
        notes,
        products_json,
        sync_status,
        created_at,
        updated_at
    ) VALUES (
        v_debt_id,
        v_velmo_id,
        p_shop_id,
        p_user_id,
        v_debtor_id,
        v_debtor_name,
        v_debtor_phone,
        NULL,                    -- customer_address
        p_amount,
        0,                       -- paid_amount
        p_amount,                -- remaining_amount
        CASE 
            WHEN v_is_velmo_id THEN 'proposed'::debt_status
            ELSE 'pending'::debt_status
        END,
        'credit',                -- type (on me doit)
        'general',               -- category
        p_due_date,
        50,                      -- reliability_score (neutral)
        'new',                   -- trust_level
        0,                       -- payment_count
        0,                       -- on_time_payment_count
        p_notes,
        NULL,                    -- products_json
        'pending'::sync_status,
        NOW(),
        NOW()
    );
    
    -- Return the created debt
    RETURN QUERY
    SELECT 
        d.id,
        d.velmo_id,
        d.shop_id,
        d.user_id,
        d.debtor_id,
        d.customer_name,
        d.customer_phone,
        d.customer_address,
        d.total_amount,
        d.paid_amount,
        d.remaining_amount,
        d.status::TEXT,
        d.type,
        d.category,
        d.due_date,
        d.reliability_score,
        d.trust_level,
        d.payment_count,
        d.on_time_payment_count,
        d.notes,
        d.products_json,
        d.sync_status::TEXT,
        d.synced_at,
        d.created_at,
        d.updated_at
    FROM public.debts d
    WHERE d.id = v_debt_id;
END;
$$;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION public.propose_debt TO authenticated;
GRANT EXECUTE ON FUNCTION public.propose_debt TO anon;

-- ================================================================
-- 3. CREATE INDEXES FOR BETTER PERFORMANCE
-- ================================================================

-- Check if indexes already exist before creating
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_debts_user_id') THEN
        CREATE INDEX idx_debts_user_id ON public.debts(user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_debts_debtor_id') THEN
        CREATE INDEX idx_debts_debtor_id ON public.debts(debtor_id) WHERE debtor_id IS NOT NULL;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_debts_shop_id') THEN
        CREATE INDEX idx_debts_shop_id ON public.debts(shop_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_debts_status') THEN
        CREATE INDEX idx_debts_status ON public.debts(status);
    END IF;
END $$;

-- ================================================================
-- 4. VERIFICATION QUERIES (Comment out after verification)
-- ================================================================

-- Uncomment to verify permissions:
-- SELECT grantee, privilege_type 
-- FROM information_schema.role_table_grants 
-- WHERE table_name = 'debts';

-- Uncomment to verify function:
-- SELECT routine_name, routine_type 
-- FROM information_schema.routines 
-- WHERE routine_name = 'propose_debt';

-- Uncomment to test function (replace with real values):
-- SELECT * FROM propose_debt(
--     20000,
--     'your-user-uuid-here'::UUID,
--     'Saidou',
--     NOW() + INTERVAL '30 days',
--     'Test dette',
--     'your-shop-uuid-here'::UUID
-- );
