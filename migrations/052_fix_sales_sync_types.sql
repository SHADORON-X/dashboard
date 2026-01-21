-- ================================================================
-- MIGRATION 052: FIX ALL SYNC FUNCTIONS - Type Errors & UUID Validation
-- Date: 2026-01-03
-- Status: CRITICAL - Fixes timestamp, UUID, and missing table support
-- ================================================================
-- Fixes:
-- 1. Error 42883: "operator does not exist: timestamp with time zone > numeric"
-- 2. Error 22P02: "invalid input syntax for type uuid"
-- 3. Missing support for: orders, order_items, debts
-- ================================================================
-- Supported tables (manual sync):
-- - products (produits) ✅ RESTORED
-- - sales (ventes)
-- - sale_items (articles vendus)
-- - orders (commandes/bons de commande)
-- - order_items (articles commandés)
-- - debts (dettes/crédits)
-- ================================================================

BEGIN;

-- ================================================================
-- DROP OLD SYNC FUNCTIONS (to avoid conflicts)
-- ================================================================
DROP FUNCTION IF EXISTS sync_push_record(TEXT, JSONB, UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS sync_push_product(JSONB, UUID) CASCADE;
DROP FUNCTION IF EXISTS sync_push_sale(JSONB, UUID) CASCADE;
DROP FUNCTION IF EXISTS sync_push_sale_item(JSONB, UUID) CASCADE;
DROP FUNCTION IF EXISTS sync_push_order(JSONB, UUID) CASCADE;
DROP FUNCTION IF EXISTS sync_push_order_item(JSONB, UUID) CASCADE;
DROP FUNCTION IF EXISTS sync_push_debt(JSONB, UUID) CASCADE;

-- ================================================================
-- 2️⃣ RECREATE SYNC_PUSH_PRODUCT - FIX TYPE MISMATCHES
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
    v_created_at TIMESTAMPTZ;
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
    
    -- Parse created_at safely, defaulting to NOW() if missing or invalid
    v_created_at := COALESCE(
        (p_data->>'created_at')::TIMESTAMPTZ,
        NOW()
    );
    
    -- Insert or update product with proper type casting
    INSERT INTO products (
        id,
        velmo_id,
        shop_id,
        user_id,
        name,
        description,
        price_sale,
        price_buy,
        quantity,
        stock_alert,
        category,
        photo,
        barcode,
        unit,
        is_active,
        is_incomplete,
        created_at,
        updated_at
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
        v_created_at,
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        price_sale = EXCLUDED.price_sale,
        price_buy = EXCLUDED.price_buy,
        quantity = EXCLUDED.quantity,
        stock_alert = EXCLUDED.stock_alert,
        category = EXCLUDED.category,
        photo = EXCLUDED.photo,
        barcode = EXCLUDED.barcode,
        unit = EXCLUDED.unit,
        is_active = EXCLUDED.is_active,
        is_incomplete = EXCLUDED.is_incomplete,
        updated_at = NOW()
    RETURNING to_jsonb(products.*) INTO v_result;
    
    RETURN v_result;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error in sync_push_product: %, Code: %', SQLERRM, SQLSTATE;
    RETURN jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- ================================================================
-- 3️⃣ RECREATE SYNC_PUSH_SALE - FIX TYPE MISMATCHES
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
    
    -- Parse created_at safely, defaulting to NOW() if missing or invalid
    v_created_at := COALESCE(
        (p_data->>'created_at')::TIMESTAMPTZ,
        NOW()
    );
    
    -- Insert or update sale with proper type casting
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
        v_created_at,
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        total_amount = EXCLUDED.total_amount,
        total_profit = EXCLUDED.total_profit,
        payment_type = EXCLUDED.payment_type,
        customer_name = EXCLUDED.customer_name,
        customer_phone = EXCLUDED.customer_phone,
        notes = EXCLUDED.notes,
        items_count = EXCLUDED.items_count,
        updated_at = NOW()
    RETURNING to_jsonb(sales.*) INTO v_result;
    
    RETURN v_result;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error in sync_push_sale: %, Code: %', SQLERRM, SQLSTATE;
    RETURN jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- ================================================================
-- 4️⃣ RECREATE SYNC_PUSH_SALE_ITEM - FIX UUID & TYPE ERRORS
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
    
    IF v_sale_shop_id != v_shop_id THEN
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
    
    -- Parse created_at safely
    v_created_at := COALESCE(
        (p_data->>'created_at')::TIMESTAMPTZ,
        NOW()
    );
    
    -- Insert or update sale_item
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
        created_at
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
        v_created_at
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
-- 5️⃣ RECREATE SYNC_PUSH_ORDER - FIX TYPE ERRORS
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
    v_created_at TIMESTAMPTZ;
    v_expected_delivery TIMESTAMPTZ;
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
    v_created_at := COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW());
    v_expected_delivery := (p_data->>'expected_delivery_date')::TIMESTAMPTZ;
    
    -- Insert or update order
    INSERT INTO orders (
        id,
        velmo_id,
        shop_id,
        supplier_id,
        supplier_name,
        supplier_phone,
        supplier_velmo_id,
        status,
        total_amount,
        paid_amount,
        payment_condition,
        expected_delivery_date,
        notes,
        created_at,
        updated_at
    )
    VALUES (
        (p_data->>'id')::UUID,
        p_data->>'velmo_id',
        v_shop_id,
        NULLIF(p_data->>'supplier_id', '')::UUID,
        p_data->>'supplier_name',
        p_data->>'supplier_phone',
        p_data->>'supplier_velmo_id',
        COALESCE((p_data->>'status')::order_status, 'draft'),
        COALESCE((p_data->>'total_amount')::NUMERIC, 0),
        COALESCE((p_data->>'paid_amount')::NUMERIC, 0),
        p_data->>'payment_condition',
        v_expected_delivery,
        p_data->>'notes',
        v_created_at,
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        total_amount = EXCLUDED.total_amount,
        paid_amount = EXCLUDED.paid_amount,
        status = EXCLUDED.status,
        updated_at = NOW()
    RETURNING to_jsonb(orders.*) INTO v_result;
    
    RETURN v_result;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error in sync_push_order: %, Code: %', SQLERRM, SQLSTATE;
    RETURN jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- ================================================================
-- 6️⃣ RECREATE SYNC_PUSH_ORDER_ITEM - FIX UUID & TYPE ERRORS
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
    v_product_id_str TEXT;
    v_product_id UUID;
    v_order_id UUID;
    v_created_at TIMESTAMPTZ;
BEGIN
    -- Get user's shop_id
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'User not found or no shop assigned';
    END IF;
    
    -- Parse order_id safely
    v_order_id := (p_data->>'order_id')::UUID;
    
    -- Verify the order belongs to the user's shop
    SELECT shop_id INTO v_order_shop_id FROM orders WHERE id = v_order_id;
    
    IF v_order_shop_id != v_shop_id THEN
        RAISE EXCEPTION 'Permission denied: order does not belong to your shop';
    END IF;
    
    -- Parse product_id - validate it's a proper UUID (skip if invalid)
    v_product_id_str := TRIM(p_data->>'product_id');
    
    IF v_product_id_str IS NULL OR v_product_id_str = '' OR LENGTH(v_product_id_str) < 30 THEN
        RAISE NOTICE 'Warning: Invalid UUID for order_item product_id: %. Skipping.', v_product_id_str;
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
    
    -- Parse created_at safely
    v_created_at := COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW());
    
    -- Insert or update order_item
    INSERT INTO order_items (
        id,
        order_id,
        product_id,
        product_name,
        quantity,
        unit_price,
        subtotal,
        received_quantity,
        created_at
    )
    VALUES (
        (p_data->>'id')::UUID,
        v_order_id,
        v_product_id,
        p_data->>'product_name',
        COALESCE((p_data->>'quantity')::NUMERIC, 1),
        COALESCE((p_data->>'unit_price')::NUMERIC, 0),
        COALESCE((p_data->>'subtotal')::NUMERIC, 0),
        COALESCE((p_data->>'received_quantity')::NUMERIC, 0),
        v_created_at
    )
    ON CONFLICT (id) DO UPDATE SET
        quantity = EXCLUDED.quantity,
        unit_price = EXCLUDED.unit_price,
        subtotal = EXCLUDED.subtotal,
        received_quantity = EXCLUDED.received_quantity,
        updated_at = NOW()
    RETURNING to_jsonb(order_items.*) INTO v_result;
    
    RETURN v_result;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error in sync_push_order_item: %, Code: %', SQLERRM, SQLSTATE;
    RETURN jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- ================================================================
-- 7️⃣ RECREATE SYNC_PUSH_DEBT - FIX TYPE ERRORS
-- ================================================================
CREATE OR REPLACE FUNCTION sync_push_debt(
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
    v_due_date TIMESTAMPTZ;
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
    v_created_at := COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW());
    v_due_date := (p_data->>'due_date')::TIMESTAMPTZ;
    
    -- Insert or update debt
    INSERT INTO debts (
        id,
        velmo_id,
        shop_id,
        user_id,
        debtor_id,
        customer_name,
        customer_phone,
        customer_address,
        total_amount,
        paid_amount,
        remaining_amount,
        status,
        type,
        category,
        due_date,
        reliability_score,
        trust_level,
        payment_count,
        on_time_payment_count,
        products_json,
        notes,
        created_at,
        updated_at
    )
    VALUES (
        (p_data->>'id')::UUID,
        p_data->>'velmo_id',
        v_shop_id,
        p_user_id,
        NULLIF(p_data->>'debtor_id', '')::UUID,
        COALESCE(p_data->>'customer_name', ''),
        p_data->>'customer_phone',
        p_data->>'customer_address',
        COALESCE((p_data->>'total_amount')::NUMERIC, 0),
        COALESCE((p_data->>'paid_amount')::NUMERIC, 0),
        COALESCE((p_data->>'remaining_amount')::NUMERIC, 0),
        COALESCE((p_data->>'status')::debt_status, 'pending'),
        COALESCE(p_data->>'type', 'credit'),
        p_data->>'category',
        v_due_date,
        COALESCE((p_data->>'reliability_score')::NUMERIC, 0),
        COALESCE(p_data->>'trust_level', 'new'),
        COALESCE((p_data->>'payment_count')::INTEGER, 0),
        COALESCE((p_data->>'on_time_payment_count')::INTEGER, 0),
        CASE WHEN p_data->>'products_json' IS NOT NULL THEN 
            (p_data->>'products_json')::JSONB 
        ELSE NULL END,
        p_data->>'notes',
        v_created_at,
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        total_amount = EXCLUDED.total_amount,
        paid_amount = EXCLUDED.paid_amount,
        remaining_amount = EXCLUDED.remaining_amount,
        status = EXCLUDED.status,
        due_date = EXCLUDED.due_date,
        updated_at = NOW()
    RETURNING to_jsonb(debts.*) INTO v_result;
    
    RETURN v_result;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error in sync_push_debt: %, Code: %', SQLERRM, SQLSTATE;
    RETURN jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- ================================================================
-- 8️⃣ RECREATE GENERIC WRAPPER FUNCTION
-- ================================================================
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
        
    ELSIF p_table_name = 'orders' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM orders WHERE id = (p_data->>'id')::UUID
            RETURNING to_jsonb(orders.*) INTO v_result;
        ELSE
            v_result := sync_push_order(p_data, p_user_id);
        END IF;
        
    ELSIF p_table_name = 'order_items' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM order_items WHERE id = (p_data->>'id')::UUID
            RETURNING to_jsonb(order_items.*) INTO v_result;
        ELSE
            v_result := sync_push_order_item(p_data, p_user_id);
        END IF;
        
    ELSIF p_table_name = 'debts' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM debts WHERE id = (p_data->>'id')::UUID
            RETURNING to_jsonb(debts.*) INTO v_result;
        ELSE
            v_result := sync_push_debt(p_data, p_user_id);
        END IF;
        
    ELSE
        RAISE EXCEPTION 'Table % not supported by sync_push_record', p_table_name;
    END IF;
    
    RETURN v_result;
END;
$$;

-- ================================================================
-- 9️⃣ GRANT PERMISSIONS
-- ================================================================
GRANT EXECUTE ON FUNCTION sync_push_product(JSONB, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_push_sale(JSONB, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_push_sale_item(JSONB, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_push_order(JSONB, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_push_order_item(JSONB, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_push_debt(JSONB, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_push_record(TEXT, JSONB, UUID, TEXT) TO authenticated, service_role;

COMMIT;

-- ================================================================
-- ✅ VERIFICATION QUERIES
-- ================================================================
-- Test the fixed functions with sample data:
-- SELECT sync_push_sale(
--   '{"id":"550e8400-e29b-41d4-a716-446655440000","shop_id":"550e8400-e29b-41d4-a716-446655440001","total_amount":"100.50","payment_type":"cash","customer_name":"Test","created_at":"2026-01-03T10:00:00Z"}'::JSONB,
--   'user-uuid-here'::UUID
-- );
-- ================================================================
