-- ================================================================
-- 🔥 MIGRATION 27: AJOUTER SUPPORT DEBTS DANS sync_push_record
-- ================================================================
-- Date: 26 Décembre 2025
-- Objectif: Ajouter le support des debts et debt_payments dans sync_push
-- 
-- PROBLÈME:
-- sync_push_record ne supporte que products, sales, sale_items
-- Les debts causent l'erreur "Table debts not supported"
-- 
-- SOLUTION:
-- Ajouter les RPC pour debts et debt_payments
-- ================================================================

BEGIN;

-- ================================================================
-- ÉTAPE 1: CRÉER RPC sync_push_debt
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
    -- Vérifier que l'utilisateur appartient à la boutique
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    IF (p_data->>'shop_id')::UUID != v_shop_id THEN
        RAISE EXCEPTION 'Permission denied: shop_id mismatch';
    END IF;
    
    -- Upsert
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
        (p_data->>'shop_id')::UUID,
        p_user_id,
        NULLIF((p_data->>'debtor_id'), '')::UUID,
        p_data->>'customer_name',
        p_data->>'customer_phone',
        p_data->>'customer_address',
        (p_data->>'total_amount')::NUMERIC,
        COALESCE((p_data->>'paid_amount')::NUMERIC, 0),
        (p_data->>'remaining_amount')::NUMERIC,
        COALESCE(p_data->>'status', 'pending')::debt_status,
        COALESCE(p_data->>'type', 'credit'),
        p_data->>'category',
        NULLIF(p_data->>'due_date', '')::TIMESTAMPTZ,
        COALESCE((p_data->>'reliability_score')::NUMERIC, 0),
        COALESCE(p_data->>'trust_level', 'new'),
        COALESCE((p_data->>'payment_count')::INTEGER, 0),
        COALESCE((p_data->>'on_time_payment_count')::INTEGER, 0),
        (p_data->>'products_json')::JSONB,
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
        category = EXCLUDED.category,
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
END;
$$;

-- ================================================================
-- ÉTAPE 2: CRÉER RPC sync_push_debt_payment
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
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Vérifier que la dette appartient à la boutique
    SELECT shop_id INTO v_debt_shop_id FROM debts WHERE id = (p_data->>'debt_id')::UUID;
    
    IF v_debt_shop_id != v_shop_id THEN
        RAISE EXCEPTION 'Permission denied: debt does not belong to your shop';
    END IF;
    
    INSERT INTO debt_payments (
        id, debt_id, user_id, amount, payment_method, notes,
        created_at
    )
    VALUES (
        (p_data->>'id')::UUID,
        (p_data->>'debt_id')::UUID,
        p_user_id,
        (p_data->>'amount')::NUMERIC,
        COALESCE(p_data->>'payment_method', 'cash')::payment_type,
        p_data->>'notes',
        COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW())
    )
    ON CONFLICT (id) DO UPDATE SET
        amount = EXCLUDED.amount,
        payment_method = EXCLUDED.payment_method,
        notes = EXCLUDED.notes
    RETURNING to_jsonb(debt_payments.*) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- ================================================================
-- ÉTAPE 3: METTRE À JOUR sync_push_record POUR SUPPORTER DEBTS
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
    
    -- ✅ NOUVEAU: Support debts
    ELSIF p_table_name = 'debts' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM debts WHERE id = (p_data->>'id')::UUID
            RETURNING to_jsonb(debts.*) INTO v_result;
        ELSE
            v_result := sync_push_debt(p_data, p_user_id);
        END IF;
    
    -- ✅ NOUVEAU: Support debt_payments
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
-- ÉTAPE 4: PERMISSIONS
-- ================================================================

GRANT EXECUTE ON FUNCTION sync_push_debt TO authenticated;
GRANT EXECUTE ON FUNCTION sync_push_debt TO anon;
GRANT EXECUTE ON FUNCTION sync_push_debt TO service_role;

GRANT EXECUTE ON FUNCTION sync_push_debt_payment TO authenticated;
GRANT EXECUTE ON FUNCTION sync_push_debt_payment TO anon;
GRANT EXECUTE ON FUNCTION sync_push_debt_payment TO service_role;

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ SUPPORT DEBTS AJOUTÉ !';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ sync_push_debt créée';
    RAISE NOTICE '✅ sync_push_debt_payment créée';
    RAISE NOTICE '✅ sync_push_record mise à jour';
    RAISE NOTICE '✅ Permissions accordées';
    RAISE NOTICE '========================================';
END $$;

COMMIT;
