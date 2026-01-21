-- ==============================================================================
-- NEW RPC: upsert_product_simple - Direct product sync without RLS restrictions
-- Purpose: Fallback when sync_push_product fails or permissions are denied
-- ==============================================================================

BEGIN;

-- Drop if exists
DROP FUNCTION IF EXISTS upsert_product_simple(UUID, JSONB) CASCADE;

-- Create simplified upsert function
CREATE OR REPLACE FUNCTION upsert_product_simple(
    p_product_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- Simple upsert without complex validations
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
        p_product_id,
        p_data->>'velmo_id',
        (p_data->>'shop_id')::UUID,
        (p_data->>'user_id')::UUID,
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
        velmo_id = COALESCE(EXCLUDED.velmo_id, products.velmo_id),
        name = COALESCE(EXCLUDED.name, products.name),
        description = COALESCE(EXCLUDED.description, products.description),
        price_sale = COALESCE(EXCLUDED.price_sale, products.price_sale),
        price_buy = COALESCE(EXCLUDED.price_buy, products.price_buy),
        quantity = COALESCE(EXCLUDED.quantity, products.quantity),
        stock_alert = COALESCE(EXCLUDED.stock_alert, products.stock_alert),
        category = COALESCE(EXCLUDED.category, products.category),
        photo = COALESCE(EXCLUDED.photo, products.photo),
        barcode = COALESCE(EXCLUDED.barcode, products.barcode),
        unit = COALESCE(EXCLUDED.unit, products.unit),
        is_active = COALESCE(EXCLUDED.is_active, products.is_active),
        is_incomplete = COALESCE(EXCLUDED.is_incomplete, products.is_incomplete),
        updated_at = NOW()
    RETURNING to_jsonb(products.*) INTO v_result;
    
    RETURN v_result;
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'error', SQLERRM,
        'code', SQLSTATE,
        'product_id', p_product_id::text
    );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION upsert_product_simple(UUID, JSONB) TO authenticated, service_role;

COMMIT;
