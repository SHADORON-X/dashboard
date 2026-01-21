-- ================================================================
-- 🔄 AJOUT FONCTION SYNC_PULL_TABLE
-- ================================================================
-- Date: 24 Décembre 2025
-- Objectif: Ajouter la fonction de synchronisation manquante
-- ================================================================

BEGIN;

-- Fonction: sync_pull_table (Pull générique pour toutes les tables)
CREATE OR REPLACE FUNCTION sync_pull_table(
    p_table_name TEXT,
    p_user_id UUID,
    p_last_sync_time TIMESTAMPTZ DEFAULT '1970-01-01'::TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
    v_query TEXT;
    v_shop_id UUID;
BEGIN
    -- Récupérer le shop_id de l'utilisateur
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    -- Construire la requête selon la table
    CASE p_table_name
        WHEN 'shops' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM shops
                WHERE owner_id = p_user_id
                AND updated_at > p_last_sync_time
                ORDER BY updated_at DESC
            ) t;
            
        WHEN 'products' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM products
                WHERE shop_id = v_shop_id
                AND updated_at > p_last_sync_time
                ORDER BY updated_at DESC
            ) t;
            
        WHEN 'sales' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM sales
                WHERE shop_id = v_shop_id
                AND updated_at > p_last_sync_time
                ORDER BY created_at DESC
            ) t;
            
        WHEN 'sale_items' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT si.* FROM sale_items si
                INNER JOIN sales s ON si.sale_id = s.id
                WHERE s.shop_id = v_shop_id
                ORDER BY s.created_at DESC
            ) t;
            
        WHEN 'debts' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM debts
                WHERE shop_id = v_shop_id
                AND updated_at > p_last_sync_time
                ORDER BY updated_at DESC
            ) t;
            
        WHEN 'debt_payments' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT dp.* FROM debt_payments dp
                INNER JOIN debts d ON dp.debt_id = d.id
                WHERE d.shop_id = v_shop_id
                AND dp.updated_at > p_last_sync_time
                ORDER BY dp.created_at DESC
            ) t;
            
        WHEN 'cart_items' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM cart_items
                WHERE shop_id = v_shop_id
                AND updated_at > p_last_sync_time
                ORDER BY created_at DESC
            ) t;
            
        WHEN 'merchant_relations' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM merchant_relations
                WHERE (shop_a_id = v_shop_id OR shop_b_id = v_shop_id)
                AND updated_at > p_last_sync_time
                ORDER BY updated_at DESC
            ) t;
            
        WHEN 'orders' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM orders
                WHERE shop_id = v_shop_id
                AND updated_at > p_last_sync_time
                ORDER BY created_at DESC
            ) t;
            
        WHEN 'order_items' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT oi.* FROM order_items oi
                INNER JOIN orders o ON oi.order_id = o.id
                WHERE o.shop_id = v_shop_id
                ORDER BY o.created_at DESC
            ) t;
            
        ELSE
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Unknown table: ' || p_table_name
            );
    END CASE;
    
    -- Retourner le résultat
    RETURN COALESCE(v_result, '[]'::jsonb);
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', SQLERRM,
        'detail', SQLSTATE
    );
END;
$$;

-- Permissions
GRANT EXECUTE ON FUNCTION sync_pull_table TO anon, authenticated, service_role;
ALTER FUNCTION sync_pull_table OWNER TO postgres;

COMMIT;

-- ================================================================
-- ✅ FONCTION SYNC_PULL_TABLE AJOUTÉE
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ sync_pull_table AJOUTÉE !';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔄 La synchronisation devrait maintenant fonctionner';
    RAISE NOTICE '========================================';
END $$;
