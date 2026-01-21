-- ==============================================================================
-- MIGRATION 102: FIX SEARCH AMBIGUITY (God Eye)
-- ==============================================================================

-- On supprime l'ancienne version pour changer les noms de colonnes de retour
DROP FUNCTION IF EXISTS search_all(TEXT);

-- Crée une fonction RPC performante avec des noms de colonnes préfixés pour éviter toute ambiguïté
CREATE OR REPLACE FUNCTION search_all(search_query TEXT)
RETURNS TABLE (
    type TEXT,
    id TEXT,
    title TEXT,
    subtitle TEXT,
    url TEXT,
    meta JSONB
) LANGUAGE plpgsql SECURITY DEFINER AS $$
-- On force la résolution des conflits en faveur des colonnes de table
#variable_conflict use_column
BEGIN
    -- 1. RECHERCHE PRODUITS (Nom ou ID Velmo)
    RETURN QUERY
    SELECT 
        'product'::TEXT,
        p.id::TEXT,
        p.name,
        'Stock: ' || p.quantity || ' | ' || COALESCE((SELECT s.name FROM public.shops s WHERE s.id = p.shop_id), 'Boutique Inconnue'),
        '/products'::TEXT,
        jsonb_build_object('price', p.price_sale, 'category', p.category, 'velmo_id', p.velmo_id)
    FROM public.products p
    WHERE 
        p.name ILIKE '%' || search_query || '%' OR 
        p.velmo_id ILIKE '%' || search_query || '%' OR
        p.barcode ILIKE '%' || search_query || '%'
    LIMIT 10;

    -- 2. RECHERCHE UTILISATEURS / VENDEURS
    RETURN QUERY
    SELECT 
        'user'::TEXT,
        u.id::TEXT,
        COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, ''),
        COALESCE(u.role, 'Utilisateur') || ' | ' || u.email,
        '/users'::TEXT,
        jsonb_build_object('phone', u.phone)
    FROM public.users u
    WHERE 
        u.first_name ILIKE '%' || search_query || '%' OR 
        u.last_name ILIKE '%' || search_query || '%' OR
        u.email ILIKE '%' || search_query || '%' OR
        u.phone ILIKE '%' || search_query || '%'
    LIMIT 10;

    -- 3. RECHERCHE BOUTIQUES
    RETURN QUERY
    SELECT 
        'shop'::TEXT,
        s.id::TEXT,
        s.name,
        COALESCE(s.address, s.location, 'Sans adresse'),
        '/shops'::TEXT,
        jsonb_build_object('status', s.status, 'velmo_id', s.velmo_id)
    FROM public.shops s
    WHERE 
        s.name ILIKE '%' || search_query || '%' OR 
        s.velmo_id ILIKE '%' || search_query || '%'
    LIMIT 10;

    -- 4. RECHERCHE VENTES
    RETURN QUERY
    SELECT 
        'sale'::TEXT,
        sl.id::TEXT,
        'Vente #' || COALESCE(sl.velmo_id, SUBSTRING(sl.id::TEXT, 1, 8)),
        to_char(sl.created_at, 'DD/MM/YYYY HH24:MI') || ' | ' || sl.total_amount || ' GNF',
        '/sales'::TEXT,
        jsonb_build_object('status', sl.status)
    FROM public.sales sl
    WHERE 
        sl.id::TEXT ILIKE '%' || search_query || '%' OR
        sl.velmo_id ILIKE '%' || search_query || '%' OR
        sl.customer_name ILIKE '%' || search_query || '%'
    LIMIT 10;

    -- 5. RECHERCHE DETTES
    RETURN QUERY
    SELECT 
        'debt'::TEXT,
        d.id::TEXT,
        'Dette: ' || COALESCE(d.customer_name, 'Client Anonyme'),
        'Reste: ' || d.remaining_amount || ' GNF | Échéance: ' || COALESCE(to_char(d.due_date, 'DD/MM/YYYY'), 'Non fixée'),
        '/debts'::TEXT,
        jsonb_build_object('total', d.total_amount)
    FROM public.debts d
    WHERE 
        d.customer_name ILIKE '%' || search_query || '%' OR
        d.customer_phone ILIKE '%' || search_query || '%'
    LIMIT 10;

END;
$$;

-- Accorder l'exécution
GRANT EXECUTE ON FUNCTION search_all(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION search_all(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION search_all(TEXT) TO service_role;
