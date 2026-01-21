-- ================================================================
-- MIGRATION: Fix JoinShop RLS Permission Error
-- Date: 2026-01-03
-- Description: Créer RPC get_shop_by_id pour permettre la lecture
--              de shops sans authentification (pour joinShop)
-- ================================================================

-- ================================================================
-- 1️⃣ CREATE RPC get_shop_by_id (SECURITY DEFINER)
-- ================================================================
DROP FUNCTION IF EXISTS public.get_shop_by_id(uuid) CASCADE;

CREATE OR REPLACE FUNCTION public.get_shop_by_id(p_shop_id uuid)
RETURNS TABLE (
  id uuid,
  shop_code text,
  name text,
  category text,
  owner_id uuid,
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
    s.owner_id,
    COALESCE(u.first_name || ' ' || u.last_name, 'Propriétaire') as owner_name,
    s.is_active
  FROM shops s
  LEFT JOIN users u ON s.owner_id = u.id
  WHERE s.id = p_shop_id
  AND s.is_active = true;
$$;

-- ================================================================
-- 2️⃣ GRANT PERMISSIONS (accessible sans auth)
-- ================================================================
GRANT EXECUTE ON FUNCTION public.get_shop_by_id(uuid) TO authenticated, anon;

-- ================================================================
-- 3️⃣ TEST
-- ================================================================
-- SELECT * FROM get_shop_by_id('667fad42-e96a-48a7-990d-59a15d4d3a93');

-- ================================================================
-- ✅ DONE - Fix JoinShop RLS Error
-- ================================================================
