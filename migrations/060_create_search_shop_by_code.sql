-- ================================================================
-- MIGRATION: Create search_shop_by_code RPC
-- Date: 2026-01-04
-- Description: Permet aux employés de rechercher une boutique par son code (SHP-XX-XXX)
-- ================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.search_shop_by_code(p_shop_code TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_shop jsonb;
BEGIN
    -- Recherche boutique par shop_code (case insensitive)
    SELECT jsonb_build_object(
        'id', s.id,
        'name', s.name,
        'category', s.category,
        'velmo_id', s.velmo_id,
        'shop_code', s.shop_code,
        'owner_id', s.owner_id
    ) INTO v_shop
    FROM shops s
    WHERE UPPER(s.shop_code) = UPPER(p_shop_code)
    AND s.is_active = true;
    
    -- Retourner shop ou objet vide si introuvable
    RETURN COALESCE(v_shop, '{}'::jsonb);
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.search_shop_by_code(TEXT) TO authenticated, anon;

-- Commentaire
COMMENT ON FUNCTION public.search_shop_by_code IS 'Recherche une boutique par son code (SHP-XX-XXX) pour le flow join shop';

COMMIT;
