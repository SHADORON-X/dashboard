-- ================================================================
-- MIGRATION 062: STRICT SYNC DEBUG
-- But: Rendre les erreurs de sync EXPLICITES (plus de silence)
-- À EXÉCUTER DANS SUPABASE SQL EDITOR
-- ================================================================

-- 1️⃣ FONCTION SALES STRICTE
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

    -- Insert or update
    INSERT INTO sales (
        id, velmo_id, shop_id, user_id,
        total_amount, total_profit, payment_type,
        customer_name, customer_phone, notes,
        items_count, status,
        created_at, updated_at
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
        COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW()),
        COALESCE((p_data->>'updated_at')::TIMESTAMPTZ, NOW())
    )
    ON CONFLICT (id) DO UPDATE SET
        total_amount = EXCLUDED.total_amount,
        status = EXCLUDED.status,
        updated_at = NOW()
    RETURNING to_jsonb(sales.*) INTO v_result;
    
    RETURN v_result;
END; -- PAS DE GESTION D'ERREUR ICI -> ÇA DOIT PLANTER SI PROBLÈME
$$;

-- 2️⃣ FONCTION SALE_ITEMS STRICTE
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
    v_result JSONB;
    v_product_id_str TEXT;
    v_product_id UUID;
BEGIN
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    -- Validate IDs
    v_product_id_str := TRIM(p_data->>'product_id');
    
    -- 🛑 STOP SI ID INVALIDE
    IF v_product_id_str IS NULL OR LENGTH(v_product_id_str) < 30 THEN
        RAISE EXCEPTION 'CRITICAL ERROR: Invalid Product UUID "%" for item %. You must fix your local data.', v_product_id_str, p_data->>'id';
    END IF;
    
    BEGIN
        v_product_id := v_product_id_str::UUID;
    EXCEPTION WHEN OTHERS THEN
         RAISE EXCEPTION 'CRITICAL ERROR: Could not cast product_id "%" to UUID.', v_product_id_str;
    END;

    INSERT INTO sale_items (
        id, sale_id, product_id, user_id,
        product_name, quantity, unit_price,
        purchase_price, subtotal, profit,
        created_at, updated_at
    )
    VALUES (
        (p_data->>'id')::UUID,
        (p_data->>'sale_id')::UUID,
        v_product_id,
        p_user_id,
        p_data->>'product_name',
        COALESCE((p_data->>'quantity')::NUMERIC, 1),
        COALESCE((p_data->>'unit_price')::NUMERIC, 0),
        COALESCE((p_data->>'purchase_price')::NUMERIC, 0),
        COALESCE((p_data->>'subtotal')::NUMERIC, 0),
        COALESCE((p_data->>'profit')::NUMERIC, 0),
        COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW()),
        COALESCE((p_data->>'updated_at')::TIMESTAMPTZ, NOW())
    )
    ON CONFLICT (id) DO UPDATE SET
        quantity = EXCLUDED.quantity,
        updated_at = NOW()
    RETURNING to_jsonb(sale_items.*) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- 3️⃣ Permissions
GRANT EXECUTE ON FUNCTION sync_push_sale(JSONB, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_push_sale_item(JSONB, UUID) TO authenticated, service_role;
