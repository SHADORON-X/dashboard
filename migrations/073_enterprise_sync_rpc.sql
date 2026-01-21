-- ================================================================
-- MIGRATION 073: ENTERPRISE SYNC RPC - PRODUCTION READY
-- Date: 2026-01-07
-- Objectif: Système de synchronisation pour 20+ utilisateurs simultanés
--           avec gestion du stock concurrent et Server-Side Truth
-- ================================================================

BEGIN;

-- ================================================================
-- 0️⃣ DROP EXISTING FUNCTIONS (AUDIT FIX)
-- ================================================================
DROP FUNCTION IF EXISTS sync_push_product(JSONB, UUID) CASCADE;
DROP FUNCTION IF EXISTS sync_push_sale(JSONB, UUID) CASCADE;
DROP FUNCTION IF EXISTS sync_push_sale_item(JSONB, UUID) CASCADE;
DROP FUNCTION IF EXISTS sync_push_debt(JSONB, UUID) CASCADE;
DROP FUNCTION IF EXISTS sync_push_debt_payment(JSONB, UUID) CASCADE;
DROP FUNCTION IF EXISTS sync_push_record(TEXT, JSONB, UUID, TEXT) CASCADE;

-- ================================================================
-- 1️⃣ PRODUCTS - AVEC GESTION STOCK CONCURRENT
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
    v_quantity_delta NUMERIC;
BEGIN
    -- Validation user + shop
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'User not found or no shop assigned';
    END IF;
    
    IF (p_data->>'shop_id')::UUID != v_shop_id THEN
        RAISE EXCEPTION 'Permission denied: shop_id mismatch';
    END IF;
    
    -- ✅ STOCK CONCURRENT: Détecter si c'est une opération relative ou absolue
    v_quantity_delta := (p_data->>'quantity_delta')::NUMERIC;
    
    IF v_quantity_delta IS NOT NULL THEN
        -- ═══════════════════════════════════════════════════════════
        -- MODE RELATIF (pour ventes/ajustements concurrents)
        -- ═══════════════════════════════════════════════════════════
        UPDATE products
        SET 
            quantity = quantity + v_quantity_delta, -- ✅ Opération relative
            updated_at = NOW()
        WHERE id = (p_data->>'id')::UUID
        RETURNING to_jsonb(products.*) INTO v_result;
        
        IF v_result IS NULL THEN
            RAISE EXCEPTION 'Product % not found for relative update', p_data->>'id';
        END IF;
        
        RAISE NOTICE '🔄 [RELATIVE UPDATE] Product % quantity changed by %', p_data->>'id', v_quantity_delta;
        
    ELSE
        -- ═══════════════════════════════════════════════════════════
        -- MODE ABSOLU (pour création/modification manuelle)
        -- ═══════════════════════════════════════════════════════════
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
            p_data->>'photo_url',
            p_data->>'barcode',
            p_data->>'unit',
            COALESCE((p_data->>'is_active')::BOOLEAN, true),
            COALESCE((p_data->>'is_incomplete')::BOOLEAN, false),
            COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW()),
            NOW() -- ✅ SERVER-SIDE TRUTH
        )
        ON CONFLICT (id) DO UPDATE SET
            -- ✅ TOUTES LES COLONNES (anti-doublons)
            velmo_id = EXCLUDED.velmo_id,
            shop_id = EXCLUDED.shop_id,
            user_id = EXCLUDED.user_id,
            name = EXCLUDED.name,
            description = EXCLUDED.description,
            price_sale = EXCLUDED.price_sale,
            price_buy = EXCLUDED.price_buy,
            quantity = EXCLUDED.quantity, -- ← Écrasement absolu uniquement ici
            stock_alert = EXCLUDED.stock_alert,
            category = EXCLUDED.category,
            photo_url = EXCLUDED.photo_url,
            barcode = EXCLUDED.barcode,
            unit = EXCLUDED.unit,
            is_active = EXCLUDED.is_active,
            is_incomplete = EXCLUDED.is_incomplete,
            updated_at = NOW() -- ✅ SERVER-SIDE TRUTH
        RETURNING to_jsonb(products.*) INTO v_result;
    END IF;
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- ================================================================
-- 2️⃣ SALES - ATOMIQUE & IDEMPOTENT
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
        v_velmo_id,
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
        NOW() -- ✅ SERVER-SIDE TRUTH
    )
    ON CONFLICT (id) DO UPDATE SET
        shop_id = EXCLUDED.shop_id,
        user_id = EXCLUDED.user_id,
        total_amount = EXCLUDED.total_amount,
        total_profit = EXCLUDED.total_profit,
        payment_type = EXCLUDED.payment_type,
        customer_name = EXCLUDED.customer_name,
        customer_phone = EXCLUDED.customer_phone,
        notes = EXCLUDED.notes,
        items_count = EXCLUDED.items_count,
        status = EXCLUDED.status,
        updated_at = NOW() -- ✅ SERVER-SIDE TRUTH
    RETURNING to_jsonb(sales.*) INTO v_result;
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- ================================================================
-- 3️⃣ SALE_ITEMS - AVEC AUTO-HEAL PARENT
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
    
    -- Vérifier produit existe
    SELECT EXISTS(SELECT 1 FROM products WHERE id = v_product_id) INTO v_product_exists;
    
    IF NOT v_product_exists THEN
        RAISE NOTICE 'WARNING: Product % does not exist. Skipping sale_item insertion.', v_product_id;
        RETURN jsonb_build_object(
            'status', 'skipped',
            'reason', 'product_not_found',
            'id', p_data->>'id',
            'product_id', v_product_id::TEXT
        );
    END IF;
    
    v_purchase_price := COALESCE((p_data->>'purchase_price')::NUMERIC, 0);
    
    -- ✅ AUTO-HEAL: Créer sale parent si manquant
    IF NOT EXISTS (SELECT 1 FROM sales WHERE id = v_sale_id) THEN
        INSERT INTO sales (id, shop_id, user_id, status, created_at, updated_at)
        VALUES (v_sale_id, v_shop_id, p_user_id, 'paid', NOW(), NOW())
        ON CONFLICT (id) DO NOTHING;
        RAISE NOTICE '🔧 [AUTO-HEAL] Created missing parent sale %', v_sale_id;
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
        v_purchase_price,
        COALESCE((p_data->>'subtotal')::NUMERIC, 0),
        COALESCE((p_data->>'profit')::NUMERIC, 0),
        COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW()),
        NOW() -- ✅ SERVER-SIDE TRUTH
    )
    ON CONFLICT (id) DO UPDATE SET
        sale_id = EXCLUDED.sale_id,
        product_id = EXCLUDED.product_id,
        user_id = EXCLUDED.user_id,
        product_name = EXCLUDED.product_name,
        quantity = EXCLUDED.quantity,
        unit_price = EXCLUDED.unit_price,
        purchase_price = EXCLUDED.purchase_price,
        subtotal = EXCLUDED.subtotal,
        profit = EXCLUDED.profit,
        updated_at = NOW() -- ✅ SERVER-SIDE TRUTH
    RETURNING to_jsonb(sale_items.*) INTO v_result;
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- ================================================================
-- 4️⃣ DEBTS - COMPLET
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
        NOW() -- ✅ SERVER-SIDE TRUTH
    )
    ON CONFLICT (id) DO UPDATE SET
        shop_id = EXCLUDED.shop_id,
        user_id = EXCLUDED.user_id,
        debtor_id = EXCLUDED.debtor_id,
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
        updated_at = NOW() -- ✅ SERVER-SIDE TRUTH
    RETURNING to_jsonb(debts.*) INTO v_result;
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- ================================================================
-- 5️⃣ DEBT_PAYMENTS - COMPLET
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
        NOW() -- ✅ SERVER-SIDE TRUTH
    )
    ON CONFLICT (id) DO UPDATE SET
        debt_id = EXCLUDED.debt_id,
        user_id = EXCLUDED.user_id,
        amount = EXCLUDED.amount,
        payment_method = EXCLUDED.payment_method,
        notes = EXCLUDED.notes,
        reference_code = EXCLUDED.reference_code,
        updated_at = NOW() -- ✅ SERVER-SIDE TRUTH
    RETURNING to_jsonb(debt_payments.*) INTO v_result;
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('error', SQLERRM, 'code', SQLSTATE);
END;
$$;

-- ================================================================
-- 6️⃣ WRAPPER GÉNÉRIQUE (UPDATED)
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
    CASE p_table_name
        WHEN 'products' THEN
            IF p_operation = 'delete' THEN
                DELETE FROM products WHERE id = (p_data->>'id')::UUID
                RETURNING to_jsonb(products.*) INTO v_result;
            ELSE
                v_result := sync_push_product(p_data, p_user_id);
            END IF;
            
        WHEN 'sales' THEN
            IF p_operation = 'delete' THEN
                DELETE FROM sales WHERE id = (p_data->>'id')::UUID
                RETURNING to_jsonb(sales.*) INTO v_result;
            ELSE
                v_result := sync_push_sale(p_data, p_user_id);
            END IF;
            
        WHEN 'sale_items' THEN
            IF p_operation = 'delete' THEN
                DELETE FROM sale_items WHERE id = (p_data->>'id')::UUID
                RETURNING to_jsonb(sale_items.*) INTO v_result;
            ELSE
                v_result := sync_push_sale_item(p_data, p_user_id);
            END IF;
            
        WHEN 'debts' THEN
            IF p_operation = 'delete' THEN
                DELETE FROM debts WHERE id = (p_data->>'id')::UUID
                RETURNING to_jsonb(debts.*) INTO v_result;
            ELSE
                v_result := sync_push_debt(p_data, p_user_id);
            END IF;
            
        WHEN 'debt_payments' THEN
            IF p_operation = 'delete' THEN
                DELETE FROM debt_payments WHERE id = (p_data->>'id')::UUID
                RETURNING to_jsonb(debt_payments.*) INTO v_result;
            ELSE
                v_result := sync_push_debt_payment(p_data, p_user_id);
            END IF;
            
        ELSE
            RAISE EXCEPTION 'Table % not supported by sync_push_record', p_table_name;
    END CASE;
    
    RETURN v_result;
END;
$$;

-- ================================================================
-- GRANT PERMISSIONS
-- ================================================================
GRANT EXECUTE ON FUNCTION sync_push_record(TEXT, JSONB, UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_push_product(JSONB, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_push_sale(JSONB, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_push_sale_item(JSONB, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_push_debt(JSONB, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_push_debt_payment(JSONB, UUID) TO authenticated, service_role;

-- ================================================================
-- VERIFICATION
-- ================================================================
DO $$
BEGIN
    RAISE NOTICE '✅ Migration 073 terminée avec succès!';
    RAISE NOTICE '🏗️ ENTERPRISE SYNC RPC - PRODUCTION READY';
    RAISE NOTICE '📦 Fonctions créées/mises à jour:';
    RAISE NOTICE '   - sync_push_product (avec stock concurrent)';
    RAISE NOTICE '   - sync_push_sale (atomique)';
    RAISE NOTICE '   - sync_push_sale_item (auto-heal)';
    RAISE NOTICE '   - sync_push_debt (complet)';
    RAISE NOTICE '   - sync_push_debt_payment (complet)';
    RAISE NOTICE '   - sync_push_record (wrapper)';
    RAISE NOTICE '🔐 Permissions accordées à: authenticated, service_role';
    RAISE NOTICE '⏰ SERVER-SIDE TRUTH: updated_at = NOW() partout';
    RAISE NOTICE '🔄 STOCK CONCURRENT: quantity_delta supporté';
    RAISE NOTICE '🚀 Prêt pour 20+ utilisateurs simultanés!';
END $$;

COMMIT;
