-- ================================================================
-- MIGRATION 061: FIX SALES SYNC - FINAL CORRECTION
-- Date: 2026-01-04
-- Status: CRITICAL - Fix sales synchronization to Supabase
-- ================================================================
-- Problème: Les ventes ne se synchronisent pas vers Supabase
-- Solution: 
--   1. Ajouter colonnes manquantes (user_id, items_count, status, updated_at)
--   2. Corriger les fonctions RPC sync_push_sale
--   3. Ajouter fonction sync_pull_table pour sales
-- ================================================================

BEGIN;

-- ================================================================
-- 1️⃣ AJOUTER COLONNES MANQUANTES À LA TABLE SALES
-- ================================================================

-- Ajouter user_id si manquant
ALTER TABLE sales ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id);

-- Ajouter items_count si manquant
ALTER TABLE sales ADD COLUMN IF NOT EXISTS items_count INTEGER DEFAULT 0;

-- Ajouter status si manquant
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'sales' AND column_name = 'status') THEN
        ALTER TABLE sales ADD COLUMN status TEXT DEFAULT 'paid' 
        CHECK (status IN ('paid', 'debt', 'cancelled'));
    END IF;
END $$;

-- Ajouter updated_at si manquant
ALTER TABLE sales ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Créer index sur user_id
CREATE INDEX IF NOT EXISTS idx_sales_user_id ON sales(user_id);

-- Créer index sur status
CREATE INDEX IF NOT EXISTS idx_sales_status ON sales(status);

-- ================================================================
-- 2️⃣ AJOUTER COLONNES MANQUANTES À LA TABLE SALE_ITEMS
-- ================================================================

-- Ajouter user_id si manquant
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id);

-- Ajouter updated_at si manquant
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Créer index sur user_id
CREATE INDEX IF NOT EXISTS idx_sale_items_user_id ON sale_items(user_id);

-- ================================================================
-- 3️⃣ CRÉER/REMPLACER TRIGGER POUR updated_at
-- ================================================================

-- Créer trigger pour sales
DROP TRIGGER IF EXISTS update_sales_updated_at ON sales;
CREATE TRIGGER update_sales_updated_at 
    BEFORE UPDATE ON sales
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Créer trigger pour sale_items
DROP TRIGGER IF NOT EXISTS update_sale_items_updated_at ON sale_items;
CREATE TRIGGER update_sale_items_updated_at 
    BEFORE UPDATE ON sale_items
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- ================================================================
-- 4️⃣ CORRIGER LA FONCTION sync_push_sale
-- ================================================================

CREATE OR REPLACE FUNCTION sync_push_sale(
    p_data JSONB,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_shop_id UUID;
    v_result JSONB;
    v_created_at TIMESTAMPTZ;
    v_updated_at TIMESTAMPTZ;
BEGIN
    -- Get user's shop_id
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'User not found or no shop assigned';
    END IF;
    
    -- Verify shop_id matches
    IF (p_data->>'shop_id')::UUID != v_shop_id THEN
        RAISE EXCEPTION 'Permission denied: shop_id mismatch';
    END IF;
    
    -- Parse timestamps safely
    v_created_at := COALESCE(
        (p_data->>'created_at')::TIMESTAMPTZ,
        NOW()
    );
    
    v_updated_at := COALESCE(
        (p_data->>'updated_at')::TIMESTAMPTZ,
        NOW()
    );
    
    -- Insert or update sale with ALL columns
    INSERT INTO sales (
        id,
        velmo_id,
        shop_id,
        user_id,
        total_amount,
        total_profit,
        payment_type,
        customer_name,
        customer_phone,
        notes,
        items_count,
        status,
        created_at,
        updated_at
    )
    VALUES (
        (p_data->>'id')::UUID,
        p_data->>'velmo_id',
        v_shop_id,
        p_user_id,
        COALESCE((p_data->>'total_amount')::NUMERIC, 0),
        COALESCE((p_data->>'total_profit')::NUMERIC, 0),
        COALESCE((p_data->>'payment_type')::payment_type, 'cash'),
        p_data->>'customer_name',
        p_data->>'customer_phone',
        p_data->>'notes',
        COALESCE((p_data->>'items_count')::INTEGER, 0),
        COALESCE(p_data->>'status', 'paid'),
        v_created_at,
        v_updated_at
    )
    ON CONFLICT (id) DO UPDATE SET
        total_amount = EXCLUDED.total_amount,
        total_profit = EXCLUDED.total_profit,
        payment_type = EXCLUDED.payment_type,
        customer_name = EXCLUDED.customer_name,
        customer_phone = EXCLUDED.customer_phone,
        notes = EXCLUDED.notes,
        items_count = EXCLUDED.items_count,
        status = EXCLUDED.status,
        updated_at = NOW()
    RETURNING to_jsonb(sales.*) INTO v_result;
    
    RETURN v_result;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error in sync_push_sale: %, Code: %', SQLERRM, SQLSTATE;
    RETURN jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- ================================================================
-- 5️⃣ CORRIGER LA FONCTION sync_push_sale_item
-- ================================================================

CREATE OR REPLACE FUNCTION sync_push_sale_item(
    p_data JSONB,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_shop_id UUID;
    v_sale_shop_id UUID;
    v_result JSONB;
    v_product_id_str TEXT;
    v_product_id UUID;
    v_sale_id UUID;
    v_created_at TIMESTAMPTZ;
    v_updated_at TIMESTAMPTZ;
BEGIN
    -- Get user's shop_id
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'User not found or no shop assigned';
    END IF;
    
    -- Parse sale_id safely
    v_sale_id := (p_data->>'sale_id')::UUID;
    
    -- Verify the sale belongs to the user's shop
    SELECT shop_id INTO v_sale_shop_id FROM sales WHERE id = v_sale_id;
    
    IF v_sale_shop_id IS NULL THEN
        RAISE NOTICE 'Sale not found: %. Creating sale_item anyway.', v_sale_id;
        -- Continue - the sale might be in the queue and will be created soon
    ELSIF v_sale_shop_id != v_shop_id THEN
        RAISE EXCEPTION 'Permission denied: sale does not belong to your shop';
    END IF;
    
    -- Parse product_id - validate it's a proper UUID
    v_product_id_str := TRIM(p_data->>'product_id');
    
    -- Guard against invalid UUIDs (e.g., WatermelonDB short IDs)
    IF v_product_id_str IS NULL OR v_product_id_str = '' OR LENGTH(v_product_id_str) < 30 THEN
        RAISE NOTICE 'Warning: Invalid UUID format for product_id: %. Skipping sale_item insertion.', v_product_id_str;
        RETURN jsonb_build_object(
            'status', 'skipped',
            'reason', 'invalid_product_uuid',
            'id', p_data->>'id'
        );
    END IF;
    
    BEGIN
        v_product_id := v_product_id_str::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error casting product_id to UUID: %. Skipping insert.', SQLERRM;
        RETURN jsonb_build_object(
            'status', 'skipped',
            'reason', 'uuid_cast_error',
            'id', p_data->>'id'
        );
    END;
    
    -- Parse timestamps safely
    v_created_at := COALESCE(
        (p_data->>'created_at')::TIMESTAMPTZ,
        NOW()
    );
    
    v_updated_at := COALESCE(
        (p_data->>'updated_at')::TIMESTAMPTZ,
        NOW()
    );
    
    -- Insert or update sale_item with ALL columns
    INSERT INTO sale_items (
        id,
        sale_id,
        product_id,
        user_id,
        product_name,
        quantity,
        unit_price,
        purchase_price,
        subtotal,
        profit,
        created_at,
        updated_at
    )
    VALUES (
        (p_data->>'id')::UUID,
        v_sale_id,
        v_product_id,
        p_user_id,
        p_data->>'product_name',
        COALESCE((p_data->>'quantity')::NUMERIC, 1),
        COALESCE((p_data->>'unit_price')::NUMERIC, 0),
        COALESCE((p_data->>'purchase_price')::NUMERIC, 0),
        COALESCE((p_data->>'subtotal')::NUMERIC, 0),
        COALESCE((p_data->>'profit')::NUMERIC, 0),
        v_created_at,
        v_updated_at
    )
    ON CONFLICT (id) DO UPDATE SET
        quantity = EXCLUDED.quantity,
        unit_price = EXCLUDED.unit_price,
        purchase_price = EXCLUDED.purchase_price,
        subtotal = EXCLUDED.subtotal,
        profit = EXCLUDED.profit,
        updated_at = NOW()
    RETURNING to_jsonb(sale_items.*) INTO v_result;
    
    RETURN v_result;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error in sync_push_sale_item: %, Code: %', SQLERRM, SQLSTATE;
    RETURN jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- ================================================================
-- 6️⃣ GRANT PERMISSIONS
-- ================================================================

GRANT EXECUTE ON FUNCTION sync_push_sale(JSONB, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_push_sale_item(JSONB, UUID) TO authenticated, service_role;

-- ================================================================
-- 7️⃣ VÉRIFIER LES RLS POLICIES
-- ================================================================

-- Activer RLS sur sales si pas déjà fait
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;

-- Créer policy pour permettre la lecture des ventes de sa boutique
DROP POLICY IF EXISTS "Users can view sales from their shop" ON sales;
CREATE POLICY "Users can view sales from their shop" ON sales
    FOR SELECT
    USING (
        shop_id IN (SELECT shop_id FROM users WHERE id = auth.uid())
    );

-- Créer policy pour permettre l'insertion via RPC (SECURITY DEFINER bypass RLS)
DROP POLICY IF EXISTS "Allow RPC to insert sales" ON sales;
CREATE POLICY "Allow RPC to insert sales" ON sales
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Créer policy pour sale_items
DROP POLICY IF EXISTS "Users can view sale_items from their shop" ON sale_items;
CREATE POLICY "Users can view sale_items from their shop" ON sale_items
    FOR SELECT
    USING (
        sale_id IN (
            SELECT id FROM sales 
            WHERE shop_id IN (SELECT shop_id FROM users WHERE id = auth.uid())
        )
    );

DROP POLICY IF EXISTS "Allow RPC to insert sale_items" ON sale_items;
CREATE POLICY "Allow RPC to insert sale_items" ON sale_items
    FOR ALL
    USING (true)
    WITH CHECK (true);

COMMIT;

-- ================================================================
-- ✅ VÉRIFICATION
-- ================================================================
-- Vérifier les colonnes de la table sales:
-- SELECT column_name, data_type FROM information_schema.columns 
-- WHERE table_name = 'sales' ORDER BY ordinal_position;

-- Vérifier les colonnes de la table sale_items:
-- SELECT column_name, data_type FROM information_schema.columns 
-- WHERE table_name = 'sale_items' ORDER BY ordinal_position;

-- Tester la fonction sync_push_sale:
-- SELECT sync_push_sale(
--   '{"id":"550e8400-e29b-41d4-a716-446655440000","velmo_id":"SAL-TEST","shop_id":"YOUR_SHOP_ID","total_amount":"100.50","payment_type":"cash","customer_name":"Test","items_count":2,"status":"paid","created_at":"2026-01-04T10:00:00Z"}'::JSONB,
--   'YOUR_USER_ID'::UUID
-- );
-- ================================================================
