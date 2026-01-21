-- ================================================================
-- 🔧 CORRECTION SYNC PULL (MULTI-SHOPS)
-- ================================================================
-- Date: 24 Décembre 2025
-- Objectif: Améliorer sync_pull_table pour récupérer les données de TOUS les shops accessibles
--           (pas seulement le shop_id principal de l'utilisateur)
-- ================================================================

BEGIN;

-- Fonction: sync_pull_table (Version améliorée)
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
BEGIN
    -- On ne filtre plus par un seul v_shop_id, mais par la liste des shops accessibles
    -- On utilise la fonction get_accessible_shop_ids() qu'on a créée plus tôt (dans 06_fix_rls_recursion.sql)
    -- Si elle n'existe pas, on refait la logique ici.
    
    -- Construire la requête selon la table
    CASE p_table_name
        WHEN 'shops' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM shops
                WHERE (owner_id = p_user_id OR id IN (SELECT shop_id FROM shop_members WHERE user_id = p_user_id))
                AND updated_at > p_last_sync_time
                ORDER BY updated_at DESC
            ) t;
            
        WHEN 'products' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM products
                WHERE shop_id IN (
                    SELECT id FROM shops WHERE owner_id = p_user_id
                    UNION
                    SELECT shop_id FROM shop_members WHERE user_id = p_user_id
                )
                AND updated_at > p_last_sync_time
                ORDER BY updated_at DESC
            ) t;
            
        WHEN 'sales' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM sales
                WHERE shop_id IN (
                    SELECT id FROM shops WHERE owner_id = p_user_id
                    UNION
                    SELECT shop_id FROM shop_members WHERE user_id = p_user_id
                )
                AND updated_at > p_last_sync_time
                ORDER BY created_at DESC
            ) t;
            
        WHEN 'sale_items' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT si.* FROM sale_items si
                INNER JOIN sales s ON si.sale_id = s.id
                WHERE s.shop_id IN (
                    SELECT id FROM shops WHERE owner_id = p_user_id
                    UNION
                    SELECT shop_id FROM shop_members WHERE user_id = p_user_id
                )
                ORDER BY s.created_at DESC
            ) t;
            
        WHEN 'debts' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT 
                    id, velmo_id, shop_id, user_id, debtor_id,
                    customer_name, customer_phone, customer_address,
                    total_amount, paid_amount, remaining_amount,
                    status, type, category, due_date,
                    reliability_score, trust_level,
                    payment_count, on_time_payment_count,
                    notes, products_json,
                    sync_status, synced_at,
                    created_at, updated_at
                FROM debts
                WHERE shop_id IN (
                    SELECT id FROM shops WHERE owner_id = p_user_id
                    UNION
                    SELECT shop_id FROM shop_members WHERE user_id = p_user_id
                )
                AND updated_at > p_last_sync_time
                ORDER BY updated_at DESC
            ) t;
            
        WHEN 'debt_payments' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT 
                    dp.id, dp.debt_id, dp.amount, dp.payment_method,
                    dp.notes, dp.received_by,
                    dp.created_at, dp.updated_at
                FROM debt_payments dp
                INNER JOIN debts d ON dp.debt_id = d.id
                WHERE d.shop_id IN (
                    SELECT id FROM shops WHERE owner_id = p_user_id
                    UNION
                    SELECT shop_id FROM shop_members WHERE user_id = p_user_id
                )
                AND dp.updated_at > p_last_sync_time
                ORDER BY dp.created_at DESC
            ) t;
            
        WHEN 'cart_items' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM cart_items
                WHERE (user_id = p_user_id OR shop_id IN (
                    SELECT id FROM shops WHERE owner_id = p_user_id
                    UNION
                    SELECT shop_id FROM shop_members WHERE user_id = p_user_id
                ))
                AND updated_at > p_last_sync_time
                ORDER BY created_at DESC
            ) t;
            
        WHEN 'orders' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM orders
                WHERE shop_id IN (
                    SELECT id FROM shops WHERE owner_id = p_user_id
                    UNION
                    SELECT shop_id FROM shop_members WHERE user_id = p_user_id
                )
                AND updated_at > p_last_sync_time
                ORDER BY created_at DESC
            ) t;
            
        WHEN 'order_items' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT oi.* FROM order_items oi
                INNER JOIN orders o ON oi.order_id = o.id
                WHERE o.shop_id IN (
                    SELECT id FROM shops WHERE owner_id = p_user_id
                    UNION
                    SELECT shop_id FROM shop_members WHERE user_id = p_user_id
                )
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

COMMIT;

-- ================================================================
-- ✅ SYNC PULL AMÉLIORÉ
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ sync_pull_table mise à jour pour le multi-shop !';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔄 Les produits devraient maintenant apparaître';
    RAISE NOTICE '========================================';
END $$;
