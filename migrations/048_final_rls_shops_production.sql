-- ================================================================
-- FINAL FIX: RLS Shops - Production Safe (NO RECURSION)
-- Date: 2025-01-02
-- Status: CRITICAL - Execute in Supabase SQL Editor
-- ================================================================

BEGIN;

-- ================================================================
-- 1️⃣ DROP OLD POLICIES (clean slate)
-- ================================================================
DROP POLICY IF EXISTS "Users see their own shops" ON shops;
DROP POLICY IF EXISTS "Users update their own shops" ON shops;
DROP POLICY IF EXISTS "Users delete their shops" ON shops;
DROP POLICY IF EXISTS "Users insert shops" ON shops;
DROP POLICY IF EXISTS "Users update their shops" ON shops;
DROP POLICY IF EXISTS "Users delete their shops" ON shops;
DROP POLICY IF EXISTS "Service role bypass" ON shops;
DROP POLICY IF EXISTS "Service role bypass shops" ON shops;
DROP POLICY IF EXISTS "Users can read their shops" ON shops;
DROP POLICY IF EXISTS "Users can create shops" ON shops;
DROP POLICY IF EXISTS "Users can update their shops" ON shops;
DROP POLICY IF EXISTS "Users can delete their shops" ON shops;
DROP POLICY IF EXISTS "Users can read shops" ON shops;
DROP POLICY IF EXISTS "Public can read shop by code" ON shops;

-- ================================================================
-- 2️⃣ CREATE SECURITY DEFINER FUNCTION (NO RECURSION)
-- ================================================================
CREATE OR REPLACE FUNCTION public.user_can_access_shop(p_shop_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT
    EXISTS (
      SELECT 1
      FROM shops s
      WHERE s.id = p_shop_id
        AND s.owner_id = auth.uid()::uuid
    )
    OR
    EXISTS (
      SELECT 1
      FROM shop_members sm
      WHERE sm.shop_id = p_shop_id
        AND sm.user_id = auth.uid()::uuid
    );
$$;

-- ================================================================
-- 3️⃣ CREATE CLEAN RLS POLICIES ON SHOPS
-- ================================================================

-- READ: User can see shops where they're owner or member
CREATE POLICY "Users can read shops"
ON shops
FOR SELECT
USING (
  public.user_can_access_shop(id)
);

-- INSERT: Only owner can create
CREATE POLICY "Users can create shops"
ON shops
FOR INSERT
WITH CHECK (
  owner_id = auth.uid()::uuid
);

-- UPDATE: Only owner can update
CREATE POLICY "Users can update shops"
ON shops
FOR UPDATE
USING (
  owner_id = auth.uid()::uuid
);

-- DELETE: Only owner can delete
CREATE POLICY "Users can delete shops"
ON shops
FOR DELETE
USING (
  owner_id = auth.uid()::uuid
);

-- Service role bypass (for backend RPC)
CREATE POLICY "Service role bypass"
ON shops
FOR ALL
USING (current_setting('app.bypass_rls', true)::text = 'true');

-- ================================================================
-- 4️⃣ RPC FOR JOIN SHOP BY CODE (public access)
-- ================================================================
DROP FUNCTION IF EXISTS public.get_shop_by_code(text) CASCADE;

CREATE OR REPLACE FUNCTION public.get_shop_by_code(p_code text)
RETURNS TABLE (
  id uuid,
  shop_code text,
  name text,
  category text,
  owner_name text,
  is_active boolean
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    s.id,
    s.shop_code,
    s.name,
    s.category,
    COALESCE(u.first_name || ' ' || u.last_name, 'Propriétaire') as owner_name,
    s.is_active
  FROM shops s
  LEFT JOIN users u ON s.owner_id = u.id
  WHERE s.shop_code = p_code
  AND s.is_active = true
  LIMIT 1;
$$;

-- ================================================================
-- 5️⃣ GRANT PERMISSIONS
-- ================================================================
GRANT EXECUTE ON FUNCTION public.user_can_access_shop(uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_shop_by_code(text) TO authenticated, anon;

-- ================================================================
-- 6️⃣ ENSURE RLS ENABLED
-- ================================================================
ALTER TABLE shops ENABLE ROW LEVEL SECURITY;

COMMIT;

-- ================================================================
-- ✅ DONE - PRODUCTION SAFE
-- ================================================================
-- Test dans Supabase:
-- SELECT * FROM get_shop_by_code('SHP-BE2CC4');
-- ================================================================
