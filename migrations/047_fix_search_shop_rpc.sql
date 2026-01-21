-- ================================================================
-- FIX: search_shop_for_join RPC - correct shop_code column
-- Date: 2025-01-02
-- ================================================================

BEGIN;

-- Drop old problematic function
DROP FUNCTION IF EXISTS search_shop_for_join(text) CASCADE;

-- Recreate with correct column names
CREATE OR REPLACE FUNCTION search_shop_for_join(shop_code text)
RETURNS TABLE (
    id uuid,
    shop_id text,
    name text,
    category text,
    city text,
    owner_name text
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id, 
        s.shop_code,
        s.name, 
        s.category,
        COALESCE(s.address, '') as city, 
        COALESCE(u.first_name || ' ' || u.last_name, 'Propriétaire') as owner_name
    FROM shops s
    LEFT JOIN users u ON s.owner_id = u.id
    WHERE s.shop_code = $1
    AND s.is_active = true
    LIMIT 1;
END;
$$;

COMMIT;

-- ================================================================
-- Now execute in Supabase: SELECT search_shop_for_join('SHP-BE2CC4');
-- ================================================================
