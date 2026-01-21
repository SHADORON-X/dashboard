-- ================================================================
-- FIX: RLS Policy + UPSERT for shop_users relation
-- Date: 2025-01-02
-- Status: CRITICAL - Execute in Supabase SQL Editor
-- ================================================================

BEGIN;

-- ================================================================
-- 1️⃣ DROP all problematic policies on shops
-- ================================================================
DROP POLICY IF EXISTS "Users see their own shops" ON shops;
DROP POLICY IF EXISTS "Users update their own shops" ON shops;
DROP POLICY IF EXISTS "Users delete their shops" ON shops;
DROP POLICY IF EXISTS "Users insert shops" ON shops;
DROP POLICY IF EXISTS "Users update their shops" ON shops;
DROP POLICY IF EXISTS "Users delete their shops" ON shops;
DROP POLICY IF EXISTS "Service role bypass" ON shops;
DROP POLICY IF EXISTS "Users see their own shops" ON shops;
DROP POLICY IF EXISTS "Service role bypass shops" ON shops;

-- ================================================================
-- 2️⃣ CREATE CLEAN RLS Policy on shops (NO RECURSION)
-- ================================================================

-- SELECT: User can read shops where they are owner OR member
CREATE POLICY "Users can read their shops"
ON shops
FOR SELECT
USING (
    owner_id = auth.uid()::uuid
    OR EXISTS (
        SELECT 1 FROM shop_members
        WHERE shop_members.shop_id = shops.id
        AND shop_members.user_id = auth.uid()::uuid
    )
);

-- INSERT: Only owner can create shop
CREATE POLICY "Users can create shops"
ON shops
FOR INSERT
WITH CHECK (
    owner_id = auth.uid()::uuid
);

-- UPDATE: Only owner can update shop
CREATE POLICY "Users can update their shops"
ON shops
FOR UPDATE
USING (
    owner_id = auth.uid()::uuid
);

-- DELETE: Only owner can delete shop
CREATE POLICY "Users can delete their shops"
ON shops
FOR DELETE
USING (
    owner_id = auth.uid()::uuid
);

-- Service role bypass (for RPC/backend)
CREATE POLICY "Service role bypass shops"
ON shops
FOR ALL
USING (current_setting('app.bypass_rls', true)::text = 'true');

-- ================================================================
-- 3️⃣ ENSURE RLS is ENABLED on shops
-- ================================================================
ALTER TABLE shops ENABLE ROW LEVEL SECURITY;

-- ================================================================
-- 4️⃣ FIX shop_users: Create UPSERT function
-- ================================================================

-- Drop old problematic function if exists
DROP FUNCTION IF EXISTS join_shop_safe(uuid, uuid) CASCADE;

-- Create safe UPSERT function (prevents "Relation already exists")
CREATE OR REPLACE FUNCTION join_shop_safe(
    p_shop_id UUID,
    p_user_id UUID
)
RETURNS json AS $$
DECLARE
    v_result json;
BEGIN
    -- UPSERT: Insert or do nothing if already exists
    INSERT INTO shop_members (shop_id, user_id, role, joined_at)
    VALUES (p_shop_id, p_user_id::uuid, 'member', NOW()::timestamptz)
    ON CONFLICT (shop_id, user_id) DO NOTHING;
    
    -- Return success
    v_result := json_build_object(
        'success', true,
        'message', 'User joined or already member of shop',
        'shop_id', p_shop_id,
        'user_id', p_user_id
    );
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    v_result := json_build_object(
        'success', false,
        'error', SQLERRM,
        'shop_id', p_shop_id,
        'user_id', p_user_id
    );
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- 5️⃣ Grant permissions
-- ================================================================
GRANT EXECUTE ON FUNCTION join_shop_safe(uuid, uuid) TO authenticated;

COMMIT;

-- ================================================================
-- ✅ DONE
-- ================================================================
-- Now call in your app/backend:
-- SELECT join_shop_safe(shop_id, auth.uid());
-- ================================================================
