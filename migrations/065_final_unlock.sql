-- ================================================================
-- MIGRATION 065: FINAL UNLOCK (RLS + TIMESTAMP FIX)
-- 1. Fix Permissions (RLS) bloquantes
-- 2. Fix Comparaison Timestamp pour le Pull
-- ================================================================

BEGIN;

-- 1️⃣ FIX RLS SUR SALES (Le bloqueur critique 42501)
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable insert for authenticated users with matching user_id" ON sales;
DROP POLICY IF EXISTS "Users can insert sales" ON sales;
DROP POLICY IF EXISTS "Users can update own sales" ON sales;

-- Policy SIMPLE et PERMISSIVE pour l'owner
CREATE POLICY "Users can insert sales" ON sales FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sales" ON sales FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can view own sales" ON sales FOR SELECT
USING (auth.uid() = user_id);

-- IDEM POUR SALE_ITEMS
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert sale_items" ON sale_items;
DROP POLICY IF EXISTS "Users can update own sale_items" ON sale_items;

CREATE POLICY "Users can insert sale_items" ON sale_items FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sale_items" ON sale_items FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can view own sale_items" ON sale_items FOR SELECT
USING (auth.uid() = user_id);


-- 2️⃣ FIX RPC PULL (Le bloqueur Timestamp Operator)
-- On force le type TIMESTAMPTZ pour éviter la confusion Numeric/Timestamp
CREATE OR REPLACE FUNCTION sync_pull_table(
    p_table_name TEXT,
    p_last_sync_time TIMESTAMPTZ,
    p_user_id UUID
)
RETURNS TABLE (
    id UUID,
    updated_at TIMESTAMPTZ,
    data JSONB,
    deleted BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Validation basique pour éviter injection SQL sur nom de table
    IF p_table_name NOT IN ('sales', 'sale_items', 'products', 'customers', 'debts', 'debt_payments', 'orders', 'order_items', 'expenses', 'stock_movements', 'shops', 'users') THEN
        RAISE EXCEPTION 'Invalid table name: %', p_table_name;
    END IF;

    -- Query dynamique avec comparaison TIMESTAMPTZ sûre
    RETURN QUERY EXECUTE format(
        'SELECT 
            id, 
            updated_at, 
            to_jsonb(t.*) as data, 
            false as deleted 
         FROM %I t
         WHERE t.user_id = $1 
         AND t.updated_at > $2',
        p_table_name
    ) USING p_user_id, p_last_sync_time;
END;
$$;

COMMIT;
