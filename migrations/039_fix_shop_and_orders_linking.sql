-- ==============================================================================
-- MIGRATION: 039_fix_shop_and_orders_linking.sql (NUCLEAR FIX)
-- PURPOSE: Fix RLS for Orders (Suppliers) and implement Join Shop flow.
--          Uses dynamic SQL to DROP ALL existing function overloads to prevent errors.
-- ==============================================================================

-- ==============================================================================
-- 1. ORDERS: Allow Suppliers to View Orders
-- ==============================================================================

-- Policy: Suppliers can view orders where they are the designated supplier
DROP POLICY IF EXISTS "Suppliers can view orders" ON orders;
CREATE POLICY "Suppliers can view orders" ON orders
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM shops s
        WHERE s.id = orders.supplier_id
        AND (s.owner_id = auth.uid() OR EXISTS (
             SELECT 1 FROM shop_members sm
             WHERE sm.shop_id = s.id AND sm.user_id = auth.uid()
        ))
    )
);

-- ==============================================================================
-- 2. SHOP REQUESTS: Implement "Join Shop" Flow
-- ==============================================================================

-- Create table for requests (Safe check)
CREATE TABLE IF NOT EXISTS shop_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT unique_user_shop_request UNIQUE(shop_id, user_id)
);

-- RLS for shop_requests
ALTER TABLE shop_requests ENABLE ROW LEVEL SECURITY;

-- Users can see/manage their own requests
DROP POLICY IF EXISTS "Users manage their own requests" ON shop_requests;
CREATE POLICY "Users manage their own requests" ON shop_requests
FOR ALL USING (user_id = auth.uid());

-- Shop owners can view requests for their shop
DROP POLICY IF EXISTS "Shop owners view requests" ON shop_requests;
CREATE POLICY "Shop owners view requests" ON shop_requests
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM shops s
        WHERE s.id = shop_requests.shop_id
        AND s.owner_id = auth.uid()
    )
);

-- Shop owners can update requests (approve/reject)
DROP POLICY IF EXISTS "Shop owners manage requests" ON shop_requests;
CREATE POLICY "Shop owners manage requests" ON shop_requests
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM shops s
        WHERE s.id = shop_requests.shop_id
        AND s.owner_id = auth.uid()
    )
);

-- ==============================================================================
-- 3. NUCLEAR CLEANUP: Drop all existing versions of the functions
-- ==============================================================================
DO $$ 
DECLARE 
    r RECORD;
BEGIN 
    -- Drop all overloads of request_join_shop
    FOR r IN (SELECT oid::regprocedure as name FROM pg_proc WHERE proname = 'request_join_shop') LOOP 
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.name || ' CASCADE'; 
    END LOOP;

    -- Drop all overloads of approve_shop_request
    FOR r IN (SELECT oid::regprocedure as name FROM pg_proc WHERE proname = 'approve_shop_request') LOOP 
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.name || ' CASCADE'; 
    END LOOP;

    -- Drop all overloads of reject_shop_request
    FOR r IN (SELECT oid::regprocedure as name FROM pg_proc WHERE proname = 'reject_shop_request') LOOP 
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.name || ' CASCADE'; 
    END LOOP;
END $$;

-- ==============================================================================
-- 4. CREATE RPCs: SHOP JOIN FLOW
-- ==============================================================================

-- RPC: Request to join a shop
CREATE OR REPLACE FUNCTION request_join_shop(
    p_shop_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request_id UUID;
    v_existing_member UUID;
BEGIN
    -- Check if already a member
    SELECT id INTO v_existing_member FROM shop_members 
    WHERE shop_id = p_shop_id AND user_id = auth.uid();
    
    IF v_existing_member IS NOT NULL THEN
        RAISE EXCEPTION 'User is already a member of this shop';
    END IF;

    -- Insert request (upsert to handle re-requests)
    INSERT INTO shop_requests (shop_id, user_id, status)
    VALUES (p_shop_id, auth.uid(), 'pending')
    ON CONFLICT (shop_id, user_id) 
    DO UPDATE SET status = 'pending', updated_at = NOW()
    RETURNING id INTO v_request_id;

    RETURN json_build_object('request_id', v_request_id, 'status', 'pending');
END;
$$;

-- RPC: Approve shop request
CREATE OR REPLACE FUNCTION approve_shop_request(
    p_request_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req RECORD;
BEGIN
    -- Get request
    SELECT * INTO v_req FROM shop_requests WHERE id = p_request_id;
    
    IF v_req.id IS NULL THEN
        RAISE EXCEPTION 'Request not found';
    END IF;

    -- Verify caller is shop owner
    IF NOT EXISTS (SELECT 1 FROM shops WHERE id = v_req.shop_id AND owner_id = auth.uid()) THEN
        RAISE EXCEPTION 'Not authorized to approve requests for this shop';
    END IF;

    -- Add to shop_members
    INSERT INTO shop_members (shop_id, user_id, role, is_active)
    VALUES (v_req.shop_id, v_req.user_id, 'seller', TRUE) -- Default role seller
    ON CONFLICT (shop_id, user_id) DO NOTHING; -- Should not happen due to check, but safe

    -- Update request status
    UPDATE shop_requests SET status = 'approved', updated_at = NOW() WHERE id = p_request_id;

    RETURN json_build_object('success', true);
END;
$$;

-- RPC: Reject shop request
CREATE OR REPLACE FUNCTION reject_shop_request(
    p_request_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req RECORD;
BEGIN
    -- Get request
    SELECT * INTO v_req FROM shop_requests WHERE id = p_request_id;
    
    IF v_req.id IS NULL THEN
        RAISE EXCEPTION 'Request not found';
    END IF;

    -- Verify caller is shop owner
    IF NOT EXISTS (SELECT 1 FROM shops WHERE id = v_req.shop_id AND owner_id = auth.uid()) THEN
        RAISE EXCEPTION 'Not authorized to reject requests for this shop';
    END IF;

    -- Update request status
    UPDATE shop_requests SET status = 'rejected', updated_at = NOW() WHERE id = p_request_id;

    RETURN json_build_object('success', true);
END;
$$;

-- Grant permissions
GRANT ALL ON shop_requests TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION request_join_shop TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION approve_shop_request TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION reject_shop_request TO authenticated, anon, service_role;
