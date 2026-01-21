-- ================================================================
-- FIX: Infinite Recursion in shops RLS Policy
-- Error: "infinite recursion detected in policy for relation \"shops\""
-- ================================================================

BEGIN;

-- Drop existing problematic policies on shops
DROP POLICY IF EXISTS "Users see their own shops" ON shops;
DROP POLICY IF EXISTS "Users update their own shops" ON shops;
DROP POLICY IF EXISTS "Users delete their shops" ON shops;
DROP POLICY IF EXISTS "Users insert shops" ON shops;
DROP POLICY IF EXISTS "Users update their shops" ON shops;
DROP POLICY IF EXISTS "Users delete their shops" ON shops;
DROP POLICY IF EXISTS "Service role bypass" ON shops;

-- Recreate policies WITHOUT recursion (no SELECT shops FROM shops)
CREATE POLICY "Users see their own shops" ON shops
FOR SELECT USING (
    owner_id = auth.uid()::uuid
    OR EXISTS (
        SELECT 1 FROM shop_members sm
        WHERE sm.shop_id = shops.id AND sm.user_id = auth.uid()::uuid
    )
);

CREATE POLICY "Users insert shops" ON shops
FOR INSERT WITH CHECK (
    owner_id = auth.uid()::uuid
);

CREATE POLICY "Users update their shops" ON shops
FOR UPDATE USING (
    owner_id = auth.uid()::uuid
);

CREATE POLICY "Users delete their shops" ON shops
FOR DELETE USING (
    owner_id = auth.uid()::uuid
);

CREATE POLICY "Service role bypass shops" ON shops
FOR ALL USING (current_setting('app.bypass_rls', true)::text = 'true');

COMMIT;

-- ================================================================
-- ✅ Recursion fixed: No SELECT shops FROM shops in policies
-- ================================================================
