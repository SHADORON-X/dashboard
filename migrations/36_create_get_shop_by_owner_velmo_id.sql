-- ================================================================
-- 🔐 RPC FUNCTION: get_shop_by_owner_velmo_id
-- ================================================================
-- Cette fonction contourne les RLS policies
-- Elle s'exécute avec les permissions du propriétaire (SECURITY DEFINER)
-- 
-- Créé le: 2025-12-30
-- Objectif: Permettre à n'importe quel utilisateur de trouver une boutique
--           en cherchant par le velmo_id du propriétaire
-- ================================================================

DROP FUNCTION IF EXISTS public.get_shop_by_owner_velmo_id(TEXT) CASCADE;

CREATE OR REPLACE FUNCTION public.get_shop_by_owner_velmo_id(
  p_owner_velmo_id TEXT
)
RETURNS TABLE (
  shop_id UUID,
  shop_code TEXT,
  shop_name TEXT,
  shop_category TEXT,
  owner_id UUID,
  owner_velmo_id TEXT,
  owner_first_name TEXT,
  owner_last_name TEXT,
  is_active BOOLEAN
) 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- ÉTAPE 1: Chercher l'utilisateur propriétaire par velmo_id
  SELECT users.id INTO v_user_id
  FROM public.users
  WHERE public.users.velmo_id = UPPER(p_owner_velmo_id)
    AND public.users.role = 'owner'
  LIMIT 1;
  
  IF v_user_id IS NULL THEN
    RAISE NOTICE 'User not found with velmo_id: %', UPPER(p_owner_velmo_id);
    RETURN;
  END IF;
  
  -- ÉTAPE 2: Charger la boutique avec tous les détails
  RETURN QUERY
  SELECT 
    shops.id,
    shops.shop_code,
    shops.name,
    shops.category,
    shops.owner_id,
    users.velmo_id,
    users.first_name,
    users.last_name,
    shops.is_active
  FROM public.shops
  INNER JOIN public.users ON public.shops.owner_id = public.users.id
  WHERE public.shops.owner_id = v_user_id
  LIMIT 1;
  
END;
$$;


-- ================================================================
-- GRANT permissions
-- ================================================================
GRANT EXECUTE ON FUNCTION public.get_shop_by_owner_velmo_id(TEXT) TO authenticated, anon, service_role;

-- ================================================================
-- TEST
-- ================================================================
-- SELECT * FROM get_shop_by_owner_velmo_id('VLM-DM-506');
