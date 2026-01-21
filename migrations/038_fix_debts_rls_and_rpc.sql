-- ==============================================================================
-- MIGRATION: 038_fix_debts_rls_and_rpc.sql (NUCLEAR FIX)
-- PURPOSE: Fix RLS to allow debtors to view their debts and add missing RPCs.
--          Uses dynamic SQL to DROP ALL existing function overloads to prevent errors.
-- ==============================================================================

-- 1. FIX RLS
DROP POLICY IF EXISTS "Debtors can view their debts" ON debts;
CREATE POLICY "Debtors can view their debts" ON debts
FOR SELECT USING (
    debtor_id = auth.uid()
);

-- 2. NUCLEAR CLEANUP: Drop all existing versions of the functions
DO $$ 
DECLARE 
    r RECORD;
BEGIN 
    -- Drop all overloads of propose_debt
    FOR r IN (SELECT oid::regprocedure as name FROM pg_proc WHERE proname = 'propose_debt') LOOP 
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.name || ' CASCADE'; 
    END LOOP;

    -- Drop all overloads of confirm_debt
    FOR r IN (SELECT oid::regprocedure as name FROM pg_proc WHERE proname = 'confirm_debt') LOOP 
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.name || ' CASCADE'; 
    END LOOP;

    -- Drop all overloads of reject_debt
    FOR r IN (SELECT oid::regprocedure as name FROM pg_proc WHERE proname = 'reject_debt') LOOP 
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.name || ' CASCADE'; 
    END LOOP;
END $$;

-- 3. CREATE RPC: PROPOSE DEBT
CREATE OR REPLACE FUNCTION propose_debt(
    p_shop_id UUID,
    p_user_id UUID,          -- The creator (shop owner/staff)
    p_debtor_identifier TEXT, -- Name or VelmoID (VLM-XXX)
    p_amount DECIMAL,
    p_due_date TIMESTAMPTZ DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_debt_id UUID;
    v_velmo_id TEXT;
    v_debtor_id UUID;
    v_status debt_status;
BEGIN
    -- 1. Generate IDs
    v_debt_id := gen_random_uuid();
    v_velmo_id := 'DBT-' || substr(md5(random()::text), 1, 8); -- Simple ID gen

    -- 2. Resolve Debtor (Link if VLM-*)
    IF p_debtor_identifier LIKE 'VLM-%' THEN
        SELECT id INTO v_debtor_id FROM users WHERE velmo_id = p_debtor_identifier;
        IF v_debtor_id IS NOT NULL THEN
            v_status := 'proposed'; -- Needs confirmation
        ELSE
            -- VLM ID not found, treat as unlinked name
            v_status := 'pending'; -- Just a local debt
        END IF;
    ELSE
        v_debtor_id := NULL;
        v_status := 'pending'; -- Offline/Unlinked debt
    END IF;

    -- 3. Insert Debt
    INSERT INTO debts (
        id,
        velmo_id,
        shop_id,
        user_id,
        debtor_id,
        customer_name,
        total_amount, 
        remaining_amount,
        status, 
        type,
        due_date,
        notes,
        created_at,
        updated_at,
        sync_status
    ) VALUES (
        v_debt_id,
        v_velmo_id,
        p_shop_id,
        p_user_id,
        v_debtor_id,
        p_debtor_identifier, -- Use identifier as name
        p_amount,
        p_amount, -- Full amount remaining initially
        v_status,
        'credit',
        p_due_date,
        p_notes,
        NOW(),
        NOW(),
        'synced'  -- Created via RPC, so it is synced
    );

    -- 4. Return result
    RETURN json_build_object(
        'id', v_debt_id,
        'status', v_status,
        'debtor_id', v_debtor_id
    );
END;
$$;

-- 4. CREATE RPC: CONFIRM DEBT
CREATE OR REPLACE FUNCTION confirm_debt(
    p_debt_id UUID,
    p_user_id UUID -- The debtor confirming
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_debt RECORD;
BEGIN
    -- Verify debt exists and belongs to user
    SELECT * INTO v_debt FROM debts WHERE id = p_debt_id;
    
    IF v_debt.id IS NULL THEN
        RAISE EXCEPTION 'Debt not found';
    END IF;

    IF v_debt.debtor_id != p_user_id THEN
        RAISE EXCEPTION 'Not authorized to confirm this debt';
    END IF;

    -- Update status
    UPDATE debts 
    SET 
        status = 'pending', -- Active state
        trust_level = 'new', -- Initialize trust
        updated_at = NOW(),
        sync_status = 'synced'
    WHERE id = p_debt_id;

    RETURN json_build_object('success', true);
END;
$$;

-- 5. CREATE RPC: REJECT DEBT
CREATE OR REPLACE FUNCTION reject_debt(
    p_debt_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_debt RECORD;
BEGIN
    -- Verify debt exists
    SELECT * INTO v_debt FROM debts WHERE id = p_debt_id;

    IF v_debt.id IS NULL THEN
         RAISE EXCEPTION 'Debt not found';
    END IF;

    IF v_debt.debtor_id != p_user_id THEN
        RAISE EXCEPTION 'Not authorized to reject this debt';
    END IF;

    -- Create rejection record or just update status
    UPDATE debts 
    SET 
        status = 'rejected',
        updated_at = NOW(),
        sync_status = 'synced'
    WHERE id = p_debt_id;

    RETURN json_build_object('success', true);
END;
$$;

-- 6. Grant permissions
GRANT EXECUTE ON FUNCTION propose_debt TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION confirm_debt TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION reject_debt TO authenticated, anon, service_role;
