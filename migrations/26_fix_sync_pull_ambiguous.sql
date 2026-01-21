-- ================================================================
-- 🔥 MIGRATION 26: CORRECTION RPC sync_pull_table
-- ================================================================
-- Date: 26 Décembre 2025
-- Objectif: Corriger l'erreur "column reference 'id' is ambiguous"
-- 
-- PROBLÈME:
-- Les SELECT dans sync_pull_table utilisent des alias ambigus
-- qui causent des erreurs lors du JOIN
-- 
-- SOLUTION:
-- Préfixer TOUTES les colonnes avec l'alias de table
-- ================================================================

BEGIN;

-- Supprimer l'ancienne version
DROP FUNCTION IF EXISTS sync_pull_table(TEXT, TIMESTAMPTZ, UUID) CASCADE;

-- Créer la nouvelle version CORRIGÉE
CREATE OR REPLACE FUNCTION sync_pull_table(
    p_table_name TEXT,
    p_last_sync_time TIMESTAMPTZ,
    p_user_id UUID
)
RETURNS TABLE(
    id UUID,
    data JSONB,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_shop_id UUID;
BEGIN
    -- Récupérer le shop_id de l'utilisateur
    SELECT u.shop_id INTO v_shop_id FROM users u WHERE u.id = p_user_id;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'User not found or not associated with a shop';
    END IF;
    
    -- Router vers la bonne table
    IF p_table_name = 'products' THEN
        RETURN QUERY
        SELECT 
            p.id::UUID,                    -- ✅ Préfixé avec p.
            to_jsonb(p.*) as data,
            p.updated_at::TIMESTAMPTZ      -- ✅ Préfixé avec p.
        FROM products p
        WHERE p.shop_id = v_shop_id
        AND p.updated_at > p_last_sync_time
        ORDER BY p.updated_at ASC;
        
    ELSIF p_table_name = 'sales' THEN
        RETURN QUERY
        SELECT 
            s.id::UUID,                    -- ✅ Préfixé avec s.
            to_jsonb(s.*) as data,
            s.updated_at::TIMESTAMPTZ      -- ✅ Préfixé avec s.
        FROM sales s
        WHERE s.shop_id = v_shop_id
        AND s.updated_at > p_last_sync_time
        ORDER BY s.updated_at ASC;
        
    ELSIF p_table_name = 'sale_items' THEN
        RETURN QUERY
        SELECT 
            si.id::UUID,                   -- ✅ Préfixé avec si.
            to_jsonb(si.*) as data,
            si.created_at::TIMESTAMPTZ as updated_at  -- ✅ Préfixé avec si.
        FROM sale_items si
        JOIN sales s ON s.id = si.sale_id  -- ✅ Préfixé avec s. et si.
        WHERE s.shop_id = v_shop_id
        AND si.created_at > p_last_sync_time
        ORDER BY si.created_at ASC;
        
    ELSIF p_table_name = 'shops' THEN
        RETURN QUERY
        SELECT 
            sh.id::UUID,                   -- ✅ Préfixé avec sh.
            to_jsonb(sh.*) as data,
            sh.updated_at::TIMESTAMPTZ     -- ✅ Préfixé avec sh.
        FROM shops sh
        WHERE sh.id = v_shop_id
        AND sh.updated_at > p_last_sync_time
        ORDER BY sh.updated_at ASC;
        
    ELSIF p_table_name = 'debts' THEN
        RETURN QUERY
        SELECT 
            d.id::UUID,                    -- ✅ Préfixé avec d.
            to_jsonb(d.*) as data,
            d.updated_at::TIMESTAMPTZ      -- ✅ Préfixé avec d.
        FROM debts d
        WHERE d.shop_id = v_shop_id
        AND d.updated_at > p_last_sync_time
        ORDER BY d.updated_at ASC;
        
    ELSIF p_table_name = 'debt_payments' THEN
        RETURN QUERY
        SELECT 
            dp.id::UUID,                   -- ✅ Préfixé avec dp.
            to_jsonb(dp.*) as data,
            dp.created_at::TIMESTAMPTZ as updated_at  -- ✅ Préfixé avec dp.
        FROM debt_payments dp
        JOIN debts d ON d.id = dp.debt_id  -- ✅ Préfixé avec d. et dp.
        WHERE d.shop_id = v_shop_id
        AND dp.created_at > p_last_sync_time
        ORDER BY dp.created_at ASC;
        
    ELSIF p_table_name = 'cart_items' THEN
        RETURN QUERY
        SELECT 
            ci.id::UUID,                   -- ✅ Préfixé avec ci.
            to_jsonb(ci.*) as data,
            ci.created_at::TIMESTAMPTZ as updated_at  -- ✅ Préfixé avec ci.
        FROM cart_items ci
        WHERE ci.shop_id = v_shop_id
        AND ci.created_at > p_last_sync_time
        ORDER BY ci.created_at ASC;
        
    ELSIF p_table_name = 'merchant_relations' THEN
        RETURN QUERY
        SELECT 
            mr.id::UUID,                   -- ✅ Préfixé avec mr.
            to_jsonb(mr.*) as data,
            mr.updated_at::TIMESTAMPTZ     -- ✅ Préfixé avec mr.
        FROM merchant_relations mr
        WHERE (mr.shop_a_id = v_shop_id OR mr.shop_b_id = v_shop_id)
        AND mr.updated_at > p_last_sync_time
        ORDER BY mr.updated_at ASC;
        
    ELSIF p_table_name = 'orders' THEN
        RETURN QUERY
        SELECT 
            o.id::UUID,                    -- ✅ Préfixé avec o.
            to_jsonb(o.*) as data,
            o.updated_at::TIMESTAMPTZ      -- ✅ Préfixé avec o.
        FROM orders o
        WHERE o.shop_id = v_shop_id
        AND o.updated_at > p_last_sync_time
        ORDER BY o.updated_at ASC;
        
    ELSIF p_table_name = 'order_items' THEN
        RETURN QUERY
        SELECT 
            oi.id::UUID,                   -- ✅ Préfixé avec oi.
            to_jsonb(oi.*) as data,
            oi.created_at::TIMESTAMPTZ as updated_at  -- ✅ Préfixé avec oi.
        FROM order_items oi
        JOIN orders o ON o.id = oi.order_id  -- ✅ Préfixé avec o. et oi.
        WHERE o.shop_id = v_shop_id
        AND oi.created_at > p_last_sync_time
        ORDER BY oi.created_at ASC;
        
    ELSE
        RAISE EXCEPTION 'Table % not supported for sync_pull_table', p_table_name;
    END IF;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION sync_pull_table TO authenticated;
GRANT EXECUTE ON FUNCTION sync_pull_table TO anon;
GRANT EXECUTE ON FUNCTION sync_pull_table TO service_role;

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ RPC sync_pull_table CORRIGÉE !';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Tous les alias de colonnes préfixés';
    RAISE NOTICE '✅ Plus d''erreur "column reference ambiguous"';
    RAISE NOTICE '✅ Permissions accordées';
    RAISE NOTICE '========================================';
END $$;

COMMIT;
