-- ================================================================
-- MIGRATION 064: ROBUST SYNC (AUTO PARENT CREATION)
-- Solution pour l'erreur "Foreign key constraint violation" (23503)
-- Crée la vente parente automatiquement si elle manque lors de l'insert d'item.
-- ================================================================

BEGIN;

-- 1️⃣ FONCTION SALES : On la redéfinit pour être 100% sûr
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

    -- Insert or update sale
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
        items_count = EXCLUDED.items_count,
        status = EXCLUDED.status,
        updated_at = NOW()
    RETURNING to_jsonb(sales.*) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- 2️⃣ FONCTION SALE_ITEMS ROBUSTE
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
    v_product_id UUID;
    v_sale_id UUID;
BEGIN
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    -- Parse IDs
    v_sale_id := (p_data->>'sale_id')::UUID;
    
    BEGIN
        v_product_id := (p_data->>'product_id')::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid Product UUID %', p_data->>'product_id';
    END;

    -- 🔥 AUTO-HEALING: Si la vente parente n'existe pas, on la crée (Placeholder)
    -- Cela évite l'erreur Foreign Key 23503
    IF NOT EXISTS (SELECT 1 FROM sales WHERE id = v_sale_id) THEN
        RAISE NOTICE 'Parent sale % missing. Creating placeholder.', v_sale_id;
        
        INSERT INTO sales (id, shop_id, user_id, status, created_at, updated_at)
        VALUES (
            v_sale_id,
            v_shop_id,
            p_user_id,
            'paid', -- Default safe status
            NOW(),
            NOW()
        )
        ON CONFLICT (id) DO NOTHING;
    END IF;

    -- Insert item
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

COMMIT;
