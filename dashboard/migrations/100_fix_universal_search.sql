-- ==============================================================================
-- MIGRATION 100: FIX UNIVERSAL SEARCH ENGINE (God Eye)
-- ==============================================================================

-- Crée une fonction RPC performante pour chercher partout avec les bons noms de colonnes
CREATE OR REPLACE FUNCTION search_all(search_query TEXT)
RETURNS TABLE (
    type TEXT,
    id TEXT, -- UUID casté en TEXT
    title TEXT,
    subtitle TEXT,
    url TEXT,
    meta JSONB
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    -- 1. RECHERCHE PRODUITS (Nom ou ID Velmo)
    RETURN QUERY
    SELECT 
        'product'::TEXT as type,
        p.id::TEXT as id,
        p.name as title,
        'Stock: ' || p.quantity || ' | ' || COALESCE((SELECT name FROM shops WHERE id = p.shop_id), 'Boutique Inconnue') as subtitle,
        '/products'::TEXT as url,
        jsonb_build_object('price', p.price_sale, 'category', p.category, 'velmo_id', p.velmo_id) as meta
    FROM products p
    WHERE 
        p.name ILIKE '%' || search_query || '%' OR 
        p.velmo_id ILIKE '%' || search_query || '%' OR
        p.barcode ILIKE '%' || search_query || '%'
    LIMIT 10;

    -- 2. RECHERCHE UTILISATEURS / VENDEURS
    RETURN QUERY
    SELECT 
        'user'::TEXT as type,
        u.id::TEXT as id,
        COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '') as title,
        COALESCE(u.role, 'Utilisateur') || ' | ' || u.email as subtitle,
        '/users'::TEXT as url,
        jsonb_build_object('phone', u.phone) as meta
    FROM users u
    WHERE 
        u.first_name ILIKE '%' || search_query || '%' OR 
        u.last_name ILIKE '%' || search_query || '%' OR
        u.email ILIKE '%' || search_query || '%' OR
        u.phone ILIKE '%' || search_query || '%'
    LIMIT 10;

    -- 3. RECHERCHE BOUTIQUES
    RETURN QUERY
    SELECT 
        'shop'::TEXT as type,
        s.id::TEXT as id,
        s.name as title,
        COALESCE(s.address, s.location, 'Sans adresse') as subtitle,
        '/shops'::TEXT as url,
        jsonb_build_object('status', s.status, 'velmo_id', s.velmo_id) as meta
    FROM shops s
    WHERE 
        s.name ILIKE '%' || search_query || '%' OR 
        s.velmo_id ILIKE '%' || search_query || '%'
    LIMIT 10;

    -- 4. RECHERCHE VENTES
    RETURN QUERY
    SELECT 
        'sale'::TEXT as type,
        sl.id::TEXT as id,
        'Vente #' || COALESCE(sl.velmo_id, SUBSTRING(sl.id::TEXT, 1, 8)) as title,
        to_char(sl.created_at, 'DD/MM/YYYY HH24:MI') || ' | ' || sl.total_amount || ' GNF' as subtitle,
        '/sales'::TEXT as url,
        jsonb_build_object('status', sl.status) as meta
    FROM sales sl
    WHERE 
        sl.id::TEXT ILIKE '%' || search_query || '%' OR
        sl.velmo_id ILIKE '%' || search_query || '%' OR
        sl.customer_name ILIKE '%' || search_query || '%'
    LIMIT 10;

    -- 5. RECHERCHE DETTES
    RETURN QUERY
    SELECT 
        'debt'::TEXT as type,
        d.id::TEXT as id,
        'Dette: ' || COALESCE(d.customer_name, 'Client Anonyme') as title,
        'Reste: ' || d.remaining_amount || ' GNF | Échéance: ' || COALESCE(to_char(d.due_date, 'DD/MM/YYYY'), 'Non fixée') as subtitle,
        '/debts'::TEXT as url,
        jsonb_build_object('total', d.total_amount) as meta
    FROM debts d
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
