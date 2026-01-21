-- ================================================================
-- PATCH 069: FIX PHOTO COLUMN IN sync_push_product
-- Date: 2026-01-07
-- Objectif: Corriger le nom de colonne photo → photo_url
-- ================================================================

BEGIN;

-- ================================================================
-- RECRÉER sync_push_product AVEC LA CORRECTION
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
        photo_url, barcode, unit, is_active, is_incomplete,
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
        p_data->>'photo_url',  -- ✅ CORRIGÉ: était 'photo'
        p_data->>'barcode',
        p_data->>'unit',
        COALESCE((p_data->>'is_active')::BOOLEAN, true),
        COALESCE((p_data->>'is_incomplete')::BOOLEAN, false),
        COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW()),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        price_sale = EXCLUDED.price_sale,
        price_buy = EXCLUDED.price_buy,
        quantity = EXCLUDED.quantity,
        category = EXCLUDED.category,
        stock_alert = EXCLUDED.stock_alert,
        barcode = EXCLUDED.barcode,
        unit = EXCLUDED.unit,
        is_active = EXCLUDED.is_active,
        is_incomplete = EXCLUDED.is_incomplete,
        photo_url = EXCLUDED.photo_url,  -- ✅ AJOUTÉ: manquait dans ON CONFLICT
        updated_at = NOW()
    RETURNING to_jsonb(products.*) INTO v_result;
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- ================================================================
-- VERIFICATION
-- ================================================================
DO $$
BEGIN
    RAISE NOTICE '✅ Patch 069 appliqué avec succès!';
    RAISE NOTICE '🔧 Correction: photo → photo_url';
    RAISE NOTICE '📸 Les photos de produits seront maintenant synchronisées correctement';
END $$;

COMMIT;
