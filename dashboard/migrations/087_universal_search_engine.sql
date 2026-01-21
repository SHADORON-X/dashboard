-- ==============================================================================
-- MIGRATION 087: UNIVERSAL SEARCH ENGINE (God Eye)
-- ==============================================================================

-- Crée une fonction RPC performante pour chercher partout
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
    -- 1. RECHERCHE PRODUITS
    RETURN QUERY
    SELECT 
        'product'::TEXT as type,
        p.id::TEXT as id,
        p.name as title,
        'Stock: ' || p.quantity || ' | ' || (SELECT name FROM shops WHERE id = p.shop_id) as subtitle,
        '/products'::TEXT as url, -- On pourrait pointer vers /products?id=...
        jsonb_build_object('price', p.price, 'category', p.category) as meta
    FROM products p
    WHERE p.name ILIKE '%' || search_query || '%'
    LIMIT 5;

    -- 2. RECHERCHE UTILISATEURS / VENDEURS
    RETURN QUERY
    SELECT 
        'user'::TEXT as type,
        u.id::TEXT as id,
        u.first_name || ' ' || u.last_name as title,
        u.role || ' | ' || u.email as subtitle,
        '/users'::TEXT as url,
        jsonb_build_object('phone', u.phone) as meta
    FROM users u
    WHERE 
        u.first_name ILIKE '%' || search_query || '%' OR 
        u.last_name ILIKE '%' || search_query || '%' OR
        u.email ILIKE '%' || search_query || '%'
    LIMIT 5;

    -- 3. RECHERCHE BOUTIQUES
    RETURN QUERY
    SELECT 
        'shop'::TEXT as type,
        s.id::TEXT as id,
        s.name as title,
        s.location as subtitle,
        '/shops'::TEXT as url,
        jsonb_build_object('status', s.status) as meta
    FROM shops s
    WHERE s.name ILIKE '%' || search_query || '%'
    LIMIT 3;

    -- 4. RECHERCHE VENTES (par ID ou Montant)
    RETURN QUERY
    SELECT 
        'sale'::TEXT as type,
        sl.id::TEXT as id,
        'Vente #' || SUBSTRING(sl.id::TEXT, 1, 8) as title,
        to_char(sl.created_at, 'DD/MM/YYYY HH:MM') || ' | ' || sl.total_amount || ' FCFA' as subtitle,
        '/sales'::TEXT as url,
        jsonb_build_object('status', sl.payment_status) as meta
    FROM sales sl
    WHERE sl.id::TEXT ILIKE '%' || search_query || '%'
    LIMIT 3;

END;
$$;

-- Accorder l'exécution aux utilisateurs connectés
GRANT EXECUTE ON FUNCTION search_all(TEXT) TO authenticated;

-- Confirmation
SELECT 'MIGRATION 087: UNIVERSAL SEARCH ENGINE DEPLOYED' as status;
