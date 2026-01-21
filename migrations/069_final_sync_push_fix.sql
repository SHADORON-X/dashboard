-- ================================================================
-- MIGRATION 069: FINAL SYNC PUSH RECORD FIX
-- Ensures velmo_id and purchase_price are NEVER lost during sync
-- ================================================================

BEGIN;

-- 🔥 NUCLEAR: DROP ALL OLD VERSIONS
DROP FUNCTION IF EXISTS sync_push_record(TEXT, JSONB, UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS sync_push_product(JSONB, UUID) CASCADE;
DROP FUNCTION IF EXISTS sync_push_sale(JSONB, UUID) CASCADE;
DROP FUNCTION IF EXISTS sync_push_sale_item(JSONB, UUID) CASCADE;
DROP FUNCTION IF EXISTS sync_push_order(JSONB, UUID) CASCADE;
DROP FUNCTION IF EXISTS sync_push_order_item(JSONB, UUID) CASCADE;
DROP FUNCTION IF EXISTS sync_push_debt(JSONB, UUID) CASCADE;

-- ================================================================
-- 1️⃣ PRODUCTS
-- ================================================================
CREATE OR REPLACE FUNCTION sync_push_product(
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
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'User not found or no shop assigned';
    END IF;
    
    IF (p_data->>'shop_id')::UUID != v_shop_id THEN
        RAISE EXCEPTION 'Permission denied: shop_id mismatch';
    END IF;
    
    INSERT INTO products (
        id, velmo_id, shop_id, user_id, name, description,
        price_sale, price_buy, quantity, stock_alert, category,
        photo, barcode, unit, is_active, is_incomplete,
        created_at, updated_at
    )
    VALUES (
        (p_data->>'id')::UUID,
        p_data->>'velmo_id',
        v_shop_id,
        p_user_id,
        p_data->>'name',
        p_data->>'description',
        COALESCE((p_data->>'price_sale')::NUMERIC, 0),
        COALESCE((p_data->>'price_buy')::NUMERIC, 0),
        COALESCE((p_data->>'quantity')::NUMERIC, 0),
        COALESCE((p_data->>'stock_alert')::INTEGER, 5),
        p_data->>'category',
        p_data->>'photo',
        p_data->>'barcode',
        p_data->>'unit',
        COALESCE((p_data->>'is_active')::BOOLEAN, true),
        COALESCE((p_data->>'is_incomplete')::BOOLEAN, false),
        COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW()),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        price_sale = EXCLUDED.price_sale,
        price_buy = EXCLUDED.price_buy,
        quantity = EXCLUDED.quantity,
        updated_at = NOW()
    RETURNING to_jsonb(products.*) INTO v_result;
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- ================================================================
-- 2️⃣ SALES — CRITICAL FIX: velmo_id IS REQUIRED
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
    v_velmo_id TEXT;
    v_result JSONB;
BEGIN
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'User not found or no shop assigned';
    END IF;
    
    IF (p_data->>'shop_id')::UUID != v_shop_id THEN
        RAISE EXCEPTION 'Permission denied: shop_id mismatch';
    END IF;
    
    -- 🔐 CRITICAL VALIDATION: velmo_id MUST exist
    v_velmo_id := TRIM(p_data->>'velmo_id');
    IF v_velmo_id IS NULL OR v_velmo_id = '' THEN
        RAISE EXCEPTION 'velmo_id is required for sales (cannot be null)';
    END IF;
    
    INSERT INTO sales (
        id, velmo_id, shop_id, user_id,
        total_amount, total_profit, payment_type,
        customer_name, customer_phone, notes,
        items_count, status,
        created_at, updated_at
    )
    VALUES (
        (p_data->>'id')::UUID,
        v_velmo_id,  -- ✅ GUARANTEED NOT NULL
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
        COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW()),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        total_amount = EXCLUDED.total_amount,
        items_count = EXCLUDED.items_count,
        status = EXCLUDED.status,
        updated_at = NOW()
    RETURNING to_jsonb(sales.*) INTO v_result;
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- ================================================================
-- 3️⃣ SALE_ITEMS — CRITICAL FIX: purchase_price MUST be populated
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
    v_purchase_price NUMERIC;
    v_result JSONB;
    v_product_id UUID;
    v_sale_id UUID;
    v_product_exists BOOLEAN;
BEGIN
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'User not found or no shop assigned';
    END IF;
    
    v_sale_id := (p_data->>'sale_id')::UUID;
    
    BEGIN
        v_product_id := (p_data->>'product_id')::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid Product UUID %', p_data->>'product_id';
    END;
    
    -- 🔐 CRITICAL FIX: Verify product exists (FK constraint)
    SELECT EXISTS(SELECT 1 FROM products WHERE id = v_product_id) INTO v_product_exists;
    
    IF NOT v_product_exists THEN
        -- ⚠️ Skip this item if product doesn't exist (avoid FK violation)
        RAISE NOTICE 'WARNING: Product % does not exist. Skipping sale_item insertion.', v_product_id;
        RETURN jsonb_build_object(
            'status', 'skipped',
            'reason', 'product_not_found',
            'id', p_data->>'id',
            'product_id', v_product_id::TEXT
        );
    END IF;
    
    -- 🔐 CRITICAL FIX: purchase_price MUST NEVER be null
    v_purchase_price := COALESCE((p_data->>'purchase_price')::NUMERIC, 0);
    
    -- Auto-heal missing parent sale
    IF NOT EXISTS (SELECT 1 FROM sales WHERE id = v_sale_id) THEN
        INSERT INTO sales (id, shop_id, user_id, status, created_at, updated_at)
        VALUES (v_sale_id, v_shop_id, p_user_id, 'paid', NOW(), NOW())
        ON CONFLICT (id) DO NOTHING;
    END IF;
    
    INSERT INTO sale_items (
        id, sale_id, product_id, user_id,
        product_name, quantity, unit_price,
        purchase_price, subtotal, profit,
        created_at, updated_at
    )
    VALUES (
        (p_data->>'id')::UUID,
        v_sale_id,
        v_product_id,
        p_user_id,
        p_data->>'product_name',
        COALESCE((p_data->>'quantity')::NUMERIC, 1),
        COALESCE((p_data->>'unit_price')::NUMERIC, 0),
        v_purchase_price,  -- ✅ GUARANTEED NOT NULL
        COALESCE((p_data->>'subtotal')::NUMERIC, 0),
        COALESCE((p_data->>'profit')::NUMERIC, 0),
        COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW()),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        quantity = EXCLUDED.quantity,
        purchase_price = EXCLUDED.purchase_price,
        updated_at = NOW()
    RETURNING to_jsonb(sale_items.*) INTO v_result;
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- ================================================================
-- 4️⃣ GENERIC WRAPPER FUNCTION
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
        
    ELSE
        RAISE EXCEPTION 'Table % not supported by sync_push_record', p_table_name;
    END IF;
    
    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION sync_push_record(TEXT, JSONB, UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_push_product(JSONB, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_push_sale(JSONB, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_push_sale_item(JSONB, UUID) TO authenticated, service_role;

COMMIT;
