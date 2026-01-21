-- ================================================================
-- MIGRATION 071: FIX SYNC_PULL_TABLE - INITIAL SYNC EPOCH HANDLING
-- Date: 2026-01-07
-- Objectif: Corriger le pull pour gérer correctement le premier sync (epoch)
-- ================================================================

BEGIN;

-- ================================================================
-- RECRÉER sync_pull_table AVEC GESTION EPOCH
-- ================================================================
DROP FUNCTION IF EXISTS sync_pull_table(text, timestamptz, uuid) CASCADE;

CREATE OR REPLACE FUNCTION sync_pull_table(
    p_table_name TEXT,
    p_last_sync_time TIMESTAMPTZ,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result JSONB;
    v_user_shops UUID[];
    v_is_first_sync BOOLEAN;
BEGIN
    -- Validate table name
    IF p_table_name NOT IN (
        'users', 'shops', 'products', 'sales', 'sale_items',
        'debts', 'debt_payments', 'cart_items', 'orders', 'order_items',
        'shop_members', 'merchant_relations'
    ) THEN
        RAISE EXCEPTION 'Invalid table name: %', p_table_name;
    END IF;
    
    -- Get user's shops
    SELECT ARRAY_AGG(id) INTO v_user_shops
    FROM shops
    WHERE owner_id = p_user_id;
    
    -- ✅ FIX: Detect first sync (epoch or very old timestamp)
    -- If last_sync_time is epoch (1970-01-01) or NULL, it's a first sync
    v_is_first_sync := (p_last_sync_time IS NULL OR p_last_sync_time <= '1970-01-02'::TIMESTAMPTZ);
    
    IF v_is_first_sync THEN
        RAISE NOTICE '🌍 [FIRST SYNC] Pulling ALL data for table %', p_table_name;
    ELSE
        RAISE NOTICE '🔄 [INCREMENTAL SYNC] Pulling changes since % for table %', p_last_sync_time, p_table_name;
    END IF;
    
    -- Build query based on table
    CASE p_table_name
        WHEN 'users' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM users t
            WHERE (v_is_first_sync OR updated_at >= p_last_sync_time)
            AND id = p_user_id;
            
        WHEN 'shops' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM shops t
            WHERE (v_is_first_sync OR updated_at >= p_last_sync_time)
            AND (owner_id = p_user_id OR id = ANY(v_user_shops));
            
        WHEN 'products' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM products t
            WHERE (v_is_first_sync OR updated_at >= p_last_sync_time)
            AND shop_id = ANY(v_user_shops);
            
        WHEN 'sales' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM sales t
            WHERE (v_is_first_sync OR updated_at >= p_last_sync_time)
            AND shop_id = ANY(v_user_shops);
            
        WHEN 'sale_items' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM sale_items t
            WHERE (v_is_first_sync OR updated_at >= p_last_sync_time)
            AND EXISTS (
                SELECT 1 FROM sales s
                WHERE s.id = t.sale_id
                AND s.shop_id = ANY(v_user_shops)
            );
            
        WHEN 'debts' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM debts t
            WHERE (v_is_first_sync OR updated_at >= p_last_sync_time)
            AND shop_id = ANY(v_user_shops);
            
        WHEN 'debt_payments' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM debt_payments t
            WHERE (v_is_first_sync OR updated_at >= p_last_sync_time)
            AND EXISTS (
                SELECT 1 FROM debts d
                WHERE d.id = t.debt_id
                AND d.shop_id = ANY(v_user_shops)
            );
            
        WHEN 'cart_items' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM cart_items t
            WHERE (v_is_first_sync OR updated_at >= p_last_sync_time)
            AND user_id = p_user_id;
            
        WHEN 'orders' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM orders t
            WHERE (v_is_first_sync OR updated_at >= p_last_sync_time)
            AND shop_id = ANY(v_user_shops);
            
        WHEN 'order_items' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM order_items t
            WHERE (v_is_first_sync OR updated_at >= p_last_sync_time)
            AND EXISTS (
                SELECT 1 FROM orders o
                WHERE o.id = t.order_id
                AND o.shop_id = ANY(v_user_shops)
            );
            
        WHEN 'shop_members' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM shop_members t
            WHERE (v_is_first_sync OR updated_at >= p_last_sync_time)
            AND shop_id = ANY(v_user_shops);
            
        WHEN 'merchant_relations' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM merchant_relations t
            WHERE (v_is_first_sync OR updated_at >= p_last_sync_time)
            AND (shop_a_id = ANY(v_user_shops) OR shop_b_id = ANY(v_user_shops));
    END CASE;
    
    RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$;

-- ================================================================
-- GRANT PERMISSIONS
-- ================================================================
GRANT EXECUTE ON FUNCTION sync_pull_table(TEXT, TIMESTAMPTZ, UUID) TO authenticated, service_role;

-- ================================================================
-- VERIFICATION
-- ================================================================
DO $$
BEGIN
    RAISE NOTICE '✅ Migration 071 terminée avec succès!';
    RAISE NOTICE '🔧 Correction: sync_pull_table gère maintenant correctement le premier sync (epoch)';
    RAISE NOTICE '🌍 Si p_last_sync_time <= 1970-01-02, TOUTES les données sont renvoyées';
END $$;

COMMIT;
