-- ================================================================
-- MIGRATION 071: FIX FUNCTION OVERLOAD - CORRECT PARAMETER ORDER
-- ================================================================
-- PROBLEM: PGRST203 - Multiple sync_pull_table signatures confusing Supabase
-- SOLUTION: Drop ALL versions, recreate ONE with correct param order
--
-- Correct order (matches TypeScript call):
-- sync_pull_table(p_table_name, p_last_sync_time, p_user_id)
-- ================================================================

BEGIN;

-- 🔥 DROP ALL OVERLOADED VERSIONS
DROP FUNCTION IF EXISTS public.sync_pull_table(text, uuid, timestamptz) CASCADE;
DROP FUNCTION IF EXISTS public.sync_pull_table(text, timestamptz, uuid) CASCADE;
DROP FUNCTION IF EXISTS sync_pull_table(text, uuid, timestamptz) CASCADE;
DROP FUNCTION IF EXISTS sync_pull_table(text, timestamptz, uuid) CASCADE;
DROP FUNCTION IF EXISTS sync_pull_table(text, text, text) CASCADE;
DROP FUNCTION IF EXISTS sync_pull_table(text, text, timestamp) CASCADE;

-- 🔥 CREATE SINGLE CORRECT VERSION
-- Parameter order MUST match TypeScript RPC call:
-- rpc('sync_pull_table', { p_table_name, p_last_sync_time, p_user_id })
CREATE OR REPLACE FUNCTION public.sync_pull_table(
    p_table_name TEXT,
    p_last_sync_time TIMESTAMPTZ DEFAULT '1970-01-01'::TIMESTAMPTZ,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
    v_cutoff_time TIMESTAMPTZ;
BEGIN
    -- 🔥 SAFETY: Ensure p_last_sync_time is valid (epoch = first sync)
    v_cutoff_time := GREATEST(p_last_sync_time, '1970-01-01'::TIMESTAMPTZ);
    
    -- DEBUG: Log parameters
    RAISE NOTICE '[sync_pull_table] table=%, cutoff=%, user=%', 
        p_table_name, v_cutoff_time, p_user_id;
    
    -- Build query per table
    CASE p_table_name
        WHEN 'shops' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM shops
                WHERE (owner_id = p_user_id OR id IN (SELECT shop_id FROM shop_members WHERE user_id = p_user_id))
                AND updated_at > v_cutoff_time
                ORDER BY updated_at DESC
            ) t;
            
        WHEN 'users' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM users
                WHERE id = p_user_id
                AND updated_at > v_cutoff_time
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
                AND updated_at > v_cutoff_time
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
                AND updated_at > v_cutoff_time
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
                AND (si.updated_at > v_cutoff_time OR s.updated_at > v_cutoff_time)
                ORDER BY s.created_at DESC
            ) t;
            
        WHEN 'customers' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM customers
                WHERE shop_id IN (
                    SELECT id FROM shops WHERE owner_id = p_user_id
                    UNION
                    SELECT shop_id FROM shop_members WHERE user_id = p_user_id
                )
                AND updated_at > v_cutoff_time
                ORDER BY updated_at DESC
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
                    notes, created_at, updated_at, synced_at
                FROM debts
                WHERE shop_id IN (
                    SELECT id FROM shops WHERE owner_id = p_user_id
                    UNION
                    SELECT shop_id FROM shop_members WHERE user_id = p_user_id
                )
                AND updated_at > v_cutoff_time
                ORDER BY created_at DESC
            ) t;
            
        WHEN 'debt_payments' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT dp.* FROM debt_payments dp
                INNER JOIN debts d ON dp.debt_id = d.id
                WHERE d.shop_id IN (
                    SELECT id FROM shops WHERE owner_id = p_user_id
                    UNION
                    SELECT shop_id FROM shop_members WHERE user_id = p_user_id
                )
                AND (dp.updated_at > v_cutoff_time OR d.updated_at > v_cutoff_time)
                ORDER BY d.created_at DESC
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
                AND updated_at > v_cutoff_time
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
                AND (oi.updated_at > v_cutoff_time OR o.updated_at > v_cutoff_time)
                ORDER BY o.created_at DESC
            ) t;
            
        WHEN 'stock_movements' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM stock_movements
                WHERE shop_id IN (
                    SELECT id FROM shops WHERE owner_id = p_user_id
                    UNION
                    SELECT shop_id FROM shop_members WHERE user_id = p_user_id
                )
                AND updated_at > v_cutoff_time
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
                AND updated_at > v_cutoff_time
                ORDER BY created_at DESC
            ) t;
            
        ELSE
            v_result := '[]'::jsonb;
    END CASE;
    
    RETURN COALESCE(v_result, '[]'::jsonb);
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '[sync_pull_table] ERROR: table=%, error=%', p_table_name, SQLERRM;
    RETURN jsonb_build_object('error', SQLERRM);
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.sync_pull_table(text, timestamptz, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sync_pull_table(text, timestamptz, uuid) TO anon;

-- Verify only one version exists
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'sync_pull_table';
    
    IF v_count = 1 THEN
        RAISE NOTICE '✅ Migration 071: sync_pull_table fixed - SINGLE version with correct parameter order!';
    ELSE
        RAISE NOTICE '❌ WARNING: Found % versions of sync_pull_table (expected 1)', v_count;
    END IF;
END $$;

COMMIT;
