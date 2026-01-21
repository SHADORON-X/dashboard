-- ================================================================
-- MIGRATION 072: NUCLEAR OPTION - FORCE DROP ALL sync_pull_table
-- ================================================================
-- PROBLEM: PGRST203 still shows 2 overloaded versions
-- SOLUTION: Force drop all versions, kill any procedures referencing it,
--           then create SINGLE clean version
-- ================================================================

BEGIN;

-- 🔥 EXTREME NUCLEAR: Drop with explicit parameter signatures
-- Try every possible combination
DROP FUNCTION IF EXISTS public.sync_pull_table(text, uuid, timestamptz) CASCADE;
DROP FUNCTION IF EXISTS public.sync_pull_table(text, timestamptz, uuid) CASCADE;
DROP FUNCTION IF EXISTS sync_pull_table(text, uuid, timestamptz) CASCADE;
DROP FUNCTION IF EXISTS sync_pull_table(text, timestamptz, uuid) CASCADE;
DROP FUNCTION IF EXISTS sync_pull_table(text, text, text) CASCADE;
DROP FUNCTION IF EXISTS sync_pull_table(text, text, timestamp) CASCADE;
DROP FUNCTION IF EXISTS public.sync_pull_table(text, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.sync_pull_table(text, text, timestamptz) CASCADE;

-- Wait for Supabase cache to clear
-- (Implicit - Supabase handles this between BEGIN/COMMIT)

-- 🔥 CREATE SINGLE DEFINITIVE VERSION
-- CRITICAL: Parameter order MUST be exactly as called from TypeScript
-- TypeScript calls: rpc('sync_pull_table', { p_table_name, p_last_sync_time, p_user_id })
CREATE OR REPLACE FUNCTION public.sync_pull_table(
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
    v_cutoff_time TIMESTAMPTZ;
BEGIN
    v_cutoff_time := GREATEST(COALESCE(p_last_sync_time, '1970-01-01'::TIMESTAMPTZ), '1970-01-01'::TIMESTAMPTZ);
    
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
                SELECT id, velmo_id, shop_id, user_id, debtor_id,
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
    RAISE NOTICE '[sync_pull_table] ERROR: %', SQLERRM;
    RETURN '[]'::jsonb;
END;
$$;

-- ✅ GRANT EXPLICIT PERMISSIONS
GRANT EXECUTE ON FUNCTION public.sync_pull_table(text, TIMESTAMPTZ, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sync_pull_table(text, TIMESTAMPTZ, uuid) TO anon;

-- ✅ VERIFY - Check that ONLY ONE VERSION EXISTS
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'sync_pull_table';
    
    IF v_count = 1 THEN
        RAISE NOTICE '✅ Migration 072 SUCCESS: sync_pull_table exists as SINGLE version';
    ELSIF v_count > 1 THEN
        RAISE EXCEPTION 'sync_pull_table function overload not resolved! Found % versions', v_count;
    ELSE
        RAISE EXCEPTION 'sync_pull_table function missing!';
    END IF;
END $$;

COMMIT;
