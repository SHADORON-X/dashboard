-- Migration: Fix sync_pull_table orphan items issue
-- Date: 31 December 2025
-- Issue: sale_items and order_items are synced without their parent records
-- causing "undefined" IDs and missing data in UI

-- ============================================================
-- PROBLEM ANALYSIS
-- ============================================================
-- Current behavior:
-- 1. sales: Filtered by updated_at > p_last_sync_time ✅
-- 2. sale_items: NO updated_at filter ❌
-- Result: After first sync, old sales are filtered out but ALL their items
-- are still returned, creating orphans (items without parent sales)

-- ============================================================
-- SOLUTION: Add updated_at filters + ensure parent-child consistency
-- ============================================================

DROP FUNCTION IF EXISTS public.sync_pull_table(text, uuid, timestamptz) CASCADE;

CREATE OR REPLACE FUNCTION public.sync_pull_table(
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
            -- ✅ FIX: Add updated_at filter AND ensure parent sales are included
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT si.* FROM sale_items si
                INNER JOIN sales s ON si.sale_id = s.id
                WHERE s.shop_id IN (
                    SELECT id FROM shops WHERE owner_id = p_user_id
                    UNION
                    SELECT shop_id FROM shop_members WHERE user_id = p_user_id
                )
                AND (
                    -- Include items that were updated recently
                    si.updated_at > p_last_sync_time
                    OR
                    -- OR items whose parent sale was updated recently (to avoid orphans)
                    s.updated_at > p_last_sync_time
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
            -- ✅ FIX: Ensure consistency with parent debts
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
                AND (
                    dp.updated_at > p_last_sync_time
                    OR
                    d.updated_at > p_last_sync_time
                )
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
            -- ✅ FIX: Add updated_at filter AND ensure parent orders are included
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT oi.* FROM order_items oi
                INNER JOIN orders o ON oi.order_id = o.id
                WHERE o.shop_id IN (
                    SELECT id FROM shops WHERE owner_id = p_user_id
                    UNION
                    SELECT shop_id FROM shop_members WHERE user_id = p_user_id
                )
                AND (
                    oi.updated_at > p_last_sync_time
                    OR
                    o.updated_at > p_last_sync_time
                )
                ORDER BY o.created_at DESC
            ) t;

        WHEN 'stock_movements' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM stock_movements
                WHERE product_id IN (
                    SELECT id FROM products
                    WHERE shop_id IN (
                        SELECT id FROM shops WHERE owner_id = p_user_id
                        UNION
                        SELECT shop_id FROM shop_members WHERE user_id = p_user_id
                    )
                )
                AND updated_at > p_last_sync_time
                ORDER BY created_at DESC
            ) t;

        WHEN 'expenses' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM expenses
                WHERE shop_id IN (
                    SELECT id FROM shops WHERE owner_id = p_user_id
                    UNION
                    SELECT shop_id FROM shop_members WHERE user_id = p_user_id
                )
                AND updated_at > p_last_sync_time
                ORDER BY created_at DESC
            ) t;
            
        ELSE
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Unknown table: ' || p_table_name
            );
    END CASE;
    
    -- Retourner le résultat (ou tableau vide si NULL)
    RETURN COALESCE(v_result, '[]'::jsonb);
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.sync_pull_table(text, uuid, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sync_pull_table(text, uuid, timestamptz) TO anon;

-- Verification
DO $$
BEGIN
    RAISE NOTICE '✅ Migration 35: sync_pull_table orphan items fix applied!';
    RAISE NOTICE '   - Added updated_at filters to sale_items, order_items, debt_payments';
    RAISE NOTICE '   - Ensured parent-child consistency (items sync when parent updates)';
END $$;
