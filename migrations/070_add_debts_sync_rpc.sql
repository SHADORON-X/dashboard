-- ================================================================
-- MIGRATION 070: ADD DEBTS & DEBT_PAYMENTS SYNC RPC
-- Date: 2026-01-07
-- Objectif: Ajouter les fonctions RPC manquantes pour synchroniser
--           les dettes et paiements de dettes
-- ================================================================

BEGIN;

-- ================================================================
-- 1️⃣ DEBTS
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
BEGIN
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'User not found or no shop assigned';
    END IF;
    
    IF (p_data->>'shop_id')::UUID != v_shop_id THEN
        RAISE EXCEPTION 'Permission denied: shop_id mismatch';
    END IF;
    
    INSERT INTO debts (
        id, velmo_id, shop_id, user_id, debtor_id,
        customer_name, customer_phone, customer_address,
        total_amount, paid_amount, remaining_amount,
        status, type, category, due_date,
        reliability_score, trust_level,
        payment_count, on_time_payment_count,
        products_json, notes,
        created_at, updated_at
    )
    VALUES (
        (p_data->>'id')::UUID,
        p_data->>'velmo_id',
        v_shop_id,
        p_user_id,
        NULLIF((p_data->>'debtor_id'), '')::UUID,
        p_data->>'customer_name',
        p_data->>'customer_phone',
        p_data->>'customer_address',
        COALESCE((p_data->>'total_amount')::NUMERIC, 0),
        COALESCE((p_data->>'paid_amount')::NUMERIC, 0),
        COALESCE((p_data->>'remaining_amount')::NUMERIC, 0),
        COALESCE((p_data->>'status')::debt_status, 'pending'),
        COALESCE(p_data->>'type', 'credit'),
        p_data->>'category',
        NULLIF(p_data->>'due_date', '')::TIMESTAMPTZ,
        COALESCE((p_data->>'reliability_score')::NUMERIC, 0),
        COALESCE(p_data->>'trust_level', 'new'),
        COALESCE((p_data->>'payment_count')::INTEGER, 0),
        COALESCE((p_data->>'on_time_payment_count')::INTEGER, 0),
        COALESCE(p_data->'products_json', '[]'::JSONB),
        p_data->>'notes',
        COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW()),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        customer_name = EXCLUDED.customer_name,
        customer_phone = EXCLUDED.customer_phone,
        customer_address = EXCLUDED.customer_address,
        total_amount = EXCLUDED.total_amount,
        paid_amount = EXCLUDED.paid_amount,
        remaining_amount = EXCLUDED.remaining_amount,
        status = EXCLUDED.status,
        type = EXCLUDED.type,
        due_date = EXCLUDED.due_date,
        reliability_score = EXCLUDED.reliability_score,
        trust_level = EXCLUDED.trust_level,
        payment_count = EXCLUDED.payment_count,
        on_time_payment_count = EXCLUDED.on_time_payment_count,
        products_json = EXCLUDED.products_json,
        notes = EXCLUDED.notes,
        updated_at = NOW()
    RETURNING to_jsonb(debts.*) INTO v_result;
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- ================================================================
-- 2️⃣ DEBT_PAYMENTS
-- ================================================================
CREATE OR REPLACE FUNCTION sync_push_debt_payment(
    p_data JSONB,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_shop_id UUID;
    v_debt_shop_id UUID;
    v_result JSONB;
BEGIN
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'User not found or no shop assigned';
    END IF;
    
    -- Vérifier que la dette appartient à la boutique
    SELECT shop_id INTO v_debt_shop_id FROM debts WHERE id = (p_data->>'debt_id')::UUID;
    
    IF v_debt_shop_id != v_shop_id THEN
        RAISE EXCEPTION 'Permission denied: debt does not belong to your shop';
    END IF;
    
    INSERT INTO debt_payments (
        id, debt_id, user_id,
        amount, payment_method,
        notes, reference_code,
        created_at, updated_at
    )
    VALUES (
        (p_data->>'id')::UUID,
        (p_data->>'debt_id')::UUID,
        p_user_id,
        COALESCE((p_data->>'amount')::NUMERIC, 0),
        COALESCE((p_data->>'payment_method')::payment_type, 'cash'),
        p_data->>'notes',
        p_data->>'reference_code',
        COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW()),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        amount = EXCLUDED.amount,
        payment_method = EXCLUDED.payment_method,
        notes = EXCLUDED.notes,
        updated_at = NOW()
    RETURNING to_jsonb(debt_payments.*) INTO v_result;
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- ================================================================
-- 3️⃣ UPDATE WRAPPER FUNCTION
-- ================================================================
DROP FUNCTION IF EXISTS sync_push_record(TEXT, JSONB, UUID, TEXT) CASCADE;

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
        
    ELSE
        RAISE EXCEPTION 'Table % not supported by sync_push_record', p_table_name;
    END IF;
    
    RETURN v_result;
END;
$$;

-- ================================================================
-- 4️⃣ GRANT PERMISSIONS
-- ================================================================
GRANT EXECUTE ON FUNCTION sync_push_record(TEXT, JSONB, UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_push_debt(JSONB, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_push_debt_payment(JSONB, UUID) TO authenticated, service_role;

-- ================================================================
-- 5️⃣ VERIFICATION
-- ================================================================
DO $$
BEGIN
    RAISE NOTICE '✅ Migration 070 terminée avec succès!';
    RAISE NOTICE '📦 Fonctions créées:';
    RAISE NOTICE '   - sync_push_debt(JSONB, UUID)';
    RAISE NOTICE '   - sync_push_debt_payment(JSONB, UUID)';
    RAISE NOTICE '   - sync_push_record(TEXT, JSONB, UUID, TEXT) [UPDATED]';
    RAISE NOTICE '🔐 Permissions accordées à: authenticated, service_role';
END $$;

COMMIT;
