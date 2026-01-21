-- ================================================================
-- 🔥 MIGRATION 28: AJOUTER SUPPORT ORDERS DANS sync_push_record
-- ================================================================
-- Date: 26 Décembre 2025
-- Objectif: Ajouter les tables orders et order_items et leur support sync
-- 
-- ================================================================

BEGIN;

-- ================================================================
-- ÉTAPE 1: CRÉER LES TABLES SI ELLES N'EXISTENT PAS
-- ================================================================

CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    supplier_id UUID REFERENCES shops(id) ON DELETE SET NULL,
    supplier_name TEXT NOT NULL,
    supplier_phone TEXT,
    supplier_velmo_id TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    paid_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    payment_condition TEXT NOT NULL, -- 'delivery', 'advance', 'credit'
    expected_delivery_date TIMESTAMPTZ,
    notes TEXT,
    
    -- Synchronisation
    sync_status sync_status DEFAULT 'pending',
    synced_at TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_shop_id ON orders(shop_id);
CREATE INDEX IF NOT EXISTS idx_orders_supplier_id ON orders(supplier_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);

CREATE TABLE IF NOT EXISTS order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_name TEXT NOT NULL,
    quantity DECIMAL(10, 3) NOT NULL,
    unit_price DECIMAL(12, 2) NOT NULL,
    total_price DECIMAL(12, 2) NOT NULL,
    photo_uri TEXT,
    is_confirmed BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);

-- Trigger updated_at pour orders
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ================================================================
-- ÉTAPE 2: CRÉER RPC sync_push_order
-- ================================================================

CREATE OR REPLACE FUNCTION sync_push_order(
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
BEGIN
    -- Vérifier que l'utilisateur appartient à la boutique
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    IF (p_data->>'shop_id')::UUID != v_shop_id THEN
        RAISE EXCEPTION 'Permission denied: shop_id mismatch';
    END IF;
    
    -- Upsert
    INSERT INTO orders (
        id, shop_id, supplier_id,
        supplier_name, supplier_phone, supplier_velmo_id,
        status, total_amount, paid_amount,
        payment_condition, expected_delivery_date, notes,
        created_at, updated_at
    )
    VALUES (
        (p_data->>'id')::UUID,
        (p_data->>'shop_id')::UUID,
        NULLIF(p_data->>'supplier_id', '')::UUID,
        p_data->>'supplier_name',
        p_data->>'supplier_phone',
        p_data->>'supplier_velmo_id',
        COALESCE(p_data->>'status', 'pending'),
        COALESCE((p_data->>'total_amount')::NUMERIC, 0),
        COALESCE((p_data->>'paid_amount')::NUMERIC, 0),
        p_data->>'payment_condition',
        NULLIF(p_data->>'expected_delivery_date', '')::TIMESTAMPTZ,
        p_data->>'notes',
        COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW()),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        supplier_id = EXCLUDED.supplier_id,
        supplier_name = EXCLUDED.supplier_name,
        supplier_phone = EXCLUDED.supplier_phone,
        supplier_velmo_id = EXCLUDED.supplier_velmo_id,
        status = EXCLUDED.status,
        total_amount = EXCLUDED.total_amount,
        paid_amount = EXCLUDED.paid_amount,
        payment_condition = EXCLUDED.payment_condition,
        expected_delivery_date = EXCLUDED.expected_delivery_date,
        notes = EXCLUDED.notes,
        updated_at = NOW()
    RETURNING to_jsonb(orders.*) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- ================================================================
-- ÉTAPE 3: CRÉER RPC sync_push_order_item
-- ================================================================

CREATE OR REPLACE FUNCTION sync_push_order_item(
    p_data JSONB,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_shop_id UUID;
    v_order_shop_id UUID;
    v_result JSONB;
BEGIN
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Vérifier que la commande appartient à la boutique
    SELECT shop_id INTO v_order_shop_id FROM orders WHERE id = (p_data->>'order_id')::UUID;
    
    IF v_order_shop_id != v_shop_id THEN
        RAISE EXCEPTION 'Permission denied: order does not belong to your shop';
    END IF;
    
    INSERT INTO order_items (
        id, order_id, product_name,
        quantity, unit_price, total_price,
        photo_uri, is_confirmed
    )
    VALUES (
        (p_data->>'id')::UUID,
        (p_data->>'order_id')::UUID,
        p_data->>'product_name',
        (p_data->>'quantity')::NUMERIC,
        (p_data->>'unit_price')::NUMERIC,
        (p_data->>'total_price')::NUMERIC,
        p_data->>'photo_uri',
        COALESCE((p_data->>'is_confirmed')::BOOLEAN, FALSE)
    )
    ON CONFLICT (id) DO UPDATE SET
        product_name = EXCLUDED.product_name,
        quantity = EXCLUDED.quantity,
        unit_price = EXCLUDED.unit_price,
        total_price = EXCLUDED.total_price,
        photo_uri = EXCLUDED.photo_uri,
        is_confirmed = EXCLUDED.is_confirmed
    RETURNING to_jsonb(order_items.*) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- ================================================================
-- ÉTAPE 4: METTRE À JOUR sync_push_record
-- ================================================================

CREATE OR REPLACE FUNCTION sync_push_record(
    p_table_name TEXT,
    p_data JSONB,
    p_user_id UUID,
    p_operation TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    IF p_table_name = 'products' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM products WHERE id = (p_data->>'id')::UUID
            RETURNING to_jsonb(products.*) INTO v_result;
        ELSE
            v_result := sync_push_product(p_data, p_user_id);
        END IF;
        
    ELSIF p_table_name = 'sales' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM sales WHERE id = (p_data->>'id')::UUID
            RETURNING to_jsonb(sales.*) INTO v_result;
        ELSE
            v_result := sync_push_sale(p_data, p_user_id);
        END IF;
        
    ELSIF p_table_name = 'sale_items' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM sale_items WHERE id = (p_data->>'id')::UUID
            RETURNING to_jsonb(sale_items.*) INTO v_result;
        ELSE
            v_result := sync_push_sale_item(p_data, p_user_id);
        END IF;
    
    ELSIF p_table_name = 'debts' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM debts WHERE id = (p_data->>'id')::UUID
            RETURNING to_jsonb(debts.*) INTO v_result;
        ELSE
            v_result := sync_push_debt(p_data, p_user_id);
        END IF;
    
    ELSIF p_table_name = 'debt_payments' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM debt_payments WHERE id = (p_data->>'id')::UUID
            RETURNING to_jsonb(debt_payments.*) INTO v_result;
        ELSE
            v_result := sync_push_debt_payment(p_data, p_user_id);
        END IF;

    -- ✅ NOUVEAU: Support orders
    ELSIF p_table_name = 'orders' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM orders WHERE id = (p_data->>'id')::UUID
            RETURNING to_jsonb(orders.*) INTO v_result;
        ELSE
            v_result := sync_push_order(p_data, p_user_id);
        END IF;

    -- ✅ NOUVEAU: Support order_items
    ELSIF p_table_name = 'order_items' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM order_items WHERE id = (p_data->>'id')::UUID
            RETURNING to_jsonb(order_items.*) INTO v_result;
        ELSE
            v_result := sync_push_order_item(p_data, p_user_id);
        END IF;
        
    ELSE
        RAISE EXCEPTION 'Table % not supported by sync_push_record', p_table_name;
    END IF;
    
    RETURN v_result;
END;
$$;

-- ================================================================
-- ÉTAPE 5: PERMISSIONS
-- ================================================================

GRANT EXECUTE ON FUNCTION sync_push_order TO authenticated;
GRANT EXECUTE ON FUNCTION sync_push_order TO anon;
GRANT EXECUTE ON FUNCTION sync_push_order TO service_role;

GRANT EXECUTE ON FUNCTION sync_push_order_item TO authenticated;
GRANT EXECUTE ON FUNCTION sync_push_order_item TO anon;
GRANT EXECUTE ON FUNCTION sync_push_order_item TO service_role;

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ SUPPORT ORDERS AJOUTÉ !';
    RAISE NOTICE '========================================';
END $$;

COMMIT;
