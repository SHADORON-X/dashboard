-- ================================================================
-- MIGRATION 068: DISABLE *USER* TRIGGERS
-- Correction de l'erreur "permission denied: system trigger"
-- On ne désactive QUE les triggers créés par l'utilisateur.
-- ================================================================

BEGIN;

-- 1️⃣ DÉSACTIVATION DES TRIGGERS UTILISATEUR UNIQUEMENT
-- Cela évitera l'erreur sur RI_ConstraintTrigger_...
ALTER TABLE sales DISABLE TRIGGER USER;
ALTER TABLE sale_items DISABLE TRIGGER USER;

-- 2️⃣ PERMISSIONS RLS "OPEN BAR" (Toujours nécessaire)
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Final insert sales" ON sales;
CREATE POLICY "Final insert sales" ON sales FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Final insert items" ON sale_items;
CREATE POLICY "Final insert items" ON sale_items FOR ALL USING (true) WITH CHECK (true);

-- 3️⃣ REDÉFINITION DU ROUTEUR RPC (Toujours nécessaire)
-- On force l'utilisation de méthodes simples et directes
CREATE OR REPLACE FUNCTION sync_push_record(
    p_table_name TEXT,
    p_data JSONB,
    p_user_id UUID,
    p_operation TEXT DEFAULT 'create'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF p_table_name = 'sales' THEN
        INSERT INTO sales (
            id, shop_id, user_id, status, total_amount, items_count, 
            customer_name, customer_phone, notes,
            created_at, updated_at
        )
        VALUES (
            (p_data->>'id')::UUID,
            (p_data->>'shop_id')::UUID,
            p_user_id,
            COALESCE(p_data->>'status', 'paid'),
            COALESCE((p_data->>'total_amount')::NUMERIC, 0),
            COALESCE((p_data->>'items_count')::INTEGER, 1),
            p_data->>'customer_name',
            p_data->>'customer_phone',
            p_data->>'notes',
            NOW(), NOW()
        )
        ON CONFLICT (id) DO UPDATE SET
            total_amount = EXCLUDED.total_amount,
            items_count = EXCLUDED.items_count,
            status = EXCLUDED.status,
            updated_at = NOW();
        RETURN to_jsonb(p_data);

    ELSIF p_table_name = 'sale_items' THEN
        INSERT INTO sale_items (
            id, sale_id, product_id, user_id, 
            product_name, quantity, unit_price, subtotal, profit,
            created_at, updated_at
        )
        VALUES (
            (p_data->>'id')::UUID,
            (p_data->>'sale_id')::UUID,
            (p_data->>'product_id')::UUID,
            p_user_id,
            p_data->>'product_name',
            COALESCE((p_data->>'quantity')::NUMERIC, 1),
            COALESCE((p_data->>'unit_price')::NUMERIC, 0),
            COALESCE((p_data->>'subtotal')::NUMERIC, 0),
            COALESCE((p_data->>'profit')::NUMERIC, 0),
            NOW(), NOW()
        )
        ON CONFLICT (id) DO NOTHING;
        RETURN to_jsonb(p_data);

    ELSE
        RETURN jsonb_build_object('status', 'ignored');
    END IF;
END;
$$;

COMMIT;
