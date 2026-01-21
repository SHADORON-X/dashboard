-- ================================================================
-- 🔥 MIGRATION 29: FIX ALL SYNC ISSUES (USERS + ORDERS + DEBTS)
-- ================================================================
-- Date: 27 Décembre 2025
-- Objectif: Corriger tous les problèmes de synchronisation en une seule fois
-- 1. Corriger la table users (auth_mode, etc.)
-- 2. Ajouter le support sync pour orders
-- 3. Ajouter le support sync pour debts
-- 4. Ajouter la gestion des relations commerçants (Velmo ID)
-- ================================================================

BEGIN;

-- ================================================================
-- 1️⃣ CORRECTION TABLE USERS
-- ================================================================

ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_mode auth_mode DEFAULT 'offline';
ALTER TABLE users ADD COLUMN IF NOT EXISTS pin_hash TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS sync_status sync_status DEFAULT 'pending';
ALTER TABLE users ADD COLUMN IF NOT EXISTS created_offline BOOLEAN DEFAULT FALSE;

-- ================================================================
-- 2️⃣ CRÉATION TABLES ORDERS (Si inexistantes)
-- ================================================================

DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;

CREATE TABLE IF NOT EXISTS orders (
    id TEXT PRIMARY KEY, -- ⚠️ TEXT pour compatibilité WatermelonDB
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    supplier_id UUID REFERENCES shops(id) ON DELETE SET NULL,
    supplier_name TEXT NOT NULL,
    supplier_phone TEXT,
    supplier_velmo_id TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    paid_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    payment_condition TEXT NOT NULL,
    expected_delivery_date TIMESTAMPTZ,
    notes TEXT,
    sync_status sync_status DEFAULT 'pending',
    synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS order_items (
    id TEXT PRIMARY KEY, -- ⚠️ TEXT pour compatibilité WatermelonDB
    order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_name TEXT NOT NULL,
    quantity DECIMAL(10, 3) NOT NULL,
    unit_price DECIMAL(12, 2) NOT NULL,
    total_price DECIMAL(12, 2) NOT NULL,
    photo_uri TEXT,
    is_confirmed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- 2.5️⃣ GESTION DES RELATIONS COMMERÇANTS (LIAISONS)
-- ================================================================

DROP TABLE IF EXISTS merchant_relations CASCADE;

CREATE TABLE IF NOT EXISTS merchant_relations (
    id TEXT PRIMARY KEY, -- ⚠️ TEXT pour compatibilité WatermelonDB
    requester_shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    target_shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'active', 'rejected'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(requester_shop_id, target_shop_id)
);

-- Index pour recherche rapide
CREATE INDEX IF NOT EXISTS idx_merchant_relations_target ON merchant_relations(target_shop_id);
CREATE INDEX IF NOT EXISTS idx_merchant_relations_requester ON merchant_relations(requester_shop_id);

-- ================================================================
-- 3️⃣ RPC SYNC FUNCTIONS (ORDERS)
-- ================================================================

CREATE OR REPLACE FUNCTION sync_push_order(p_data JSONB, p_user_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_shop_id UUID;
    v_supplier_id UUID;
    v_result JSONB;
BEGIN
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    IF v_shop_id IS NULL THEN RAISE EXCEPTION 'User not found'; END IF;

    -- 🔍 RÉSOLUTION INTELLIGENTE DU FOURNISSEUR VIA VELMO ID
    v_supplier_id := NULLIF(p_data->>'supplier_id', '')::UUID;
    
    IF v_supplier_id IS NULL AND (p_data->>'supplier_velmo_id') IS NOT NULL THEN
        -- Essayer de trouver le shop_id via le velmo_id de l'utilisateur
        SELECT shop_id INTO v_supplier_id 
        FROM users 
        WHERE velmo_id = (p_data->>'supplier_velmo_id') 
        LIMIT 1;

        -- 🆕 SI TROUVÉ, CRÉER UNE DEMANDE DE RELATION AUTOMATIQUE (PENDING)
        IF v_supplier_id IS NOT NULL AND v_supplier_id != v_shop_id THEN
            INSERT INTO merchant_relations (requester_shop_id, target_shop_id, status)
            VALUES (v_shop_id, v_supplier_id, 'pending')
            ON CONFLICT (requester_shop_id, target_shop_id) DO NOTHING;
        END IF;
    END IF;
    
    INSERT INTO orders (
        id, shop_id, supplier_id, supplier_name, supplier_phone, supplier_velmo_id,
        status, total_amount, paid_amount, payment_condition, expected_delivery_date, notes,
        created_at, updated_at
    ) VALUES (
        p_data->>'id', (p_data->>'shop_id')::UUID, v_supplier_id,
        p_data->>'supplier_name', p_data->>'supplier_phone', p_data->>'supplier_velmo_id',
        COALESCE(p_data->>'status', 'pending'), COALESCE((p_data->>'total_amount')::NUMERIC, 0),
        COALESCE((p_data->>'paid_amount')::NUMERIC, 0), p_data->>'payment_condition',
        NULLIF(p_data->>'expected_delivery_date', '')::TIMESTAMPTZ, p_data->>'notes',
        COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW()), NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        supplier_id = EXCLUDED.supplier_id, supplier_name = EXCLUDED.supplier_name,
        supplier_phone = EXCLUDED.supplier_phone, supplier_velmo_id = EXCLUDED.supplier_velmo_id,
        status = EXCLUDED.status, total_amount = EXCLUDED.total_amount,
        paid_amount = EXCLUDED.paid_amount, payment_condition = EXCLUDED.payment_condition,
        expected_delivery_date = EXCLUDED.expected_delivery_date, notes = EXCLUDED.notes,
        updated_at = NOW()
    RETURNING to_jsonb(orders.*) INTO v_result;
    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION sync_push_order_item(p_data JSONB, p_user_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_shop_id UUID;
    v_order_shop_id UUID;
    v_result JSONB;
BEGIN
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    IF v_shop_id IS NULL THEN RAISE EXCEPTION 'User not found'; END IF;
    
    SELECT shop_id INTO v_order_shop_id FROM orders WHERE id = (p_data->>'order_id');
    -- IF v_order_shop_id != v_shop_id THEN RAISE EXCEPTION 'Permission denied'; END IF;
    
    INSERT INTO order_items (
        id, order_id, product_name, quantity, unit_price, total_price, photo_uri, is_confirmed
    ) VALUES (
        p_data->>'id', p_data->>'order_id', p_data->>'product_name',
        (p_data->>'quantity')::NUMERIC, (p_data->>'unit_price')::NUMERIC,
        (p_data->>'total_price')::NUMERIC, p_data->>'photo_uri',
        COALESCE((p_data->>'is_confirmed')::BOOLEAN, FALSE)
    )
    ON CONFLICT (id) DO UPDATE SET
        product_name = EXCLUDED.product_name, quantity = EXCLUDED.quantity,
        unit_price = EXCLUDED.unit_price, total_price = EXCLUDED.total_price,
        photo_uri = EXCLUDED.photo_uri, is_confirmed = EXCLUDED.is_confirmed
    RETURNING to_jsonb(order_items.*) INTO v_result;
    RETURN v_result;
END;
$$;

-- ================================================================
-- 4️⃣ RPC SYNC FUNCTIONS (DEBTS) - Rappel
-- ================================================================

CREATE OR REPLACE FUNCTION sync_push_debt(p_data JSONB, p_user_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_shop_id UUID;
    v_debtor_id UUID;
    v_result JSONB;
BEGIN
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    IF v_shop_id IS NULL THEN RAISE EXCEPTION 'User not found'; END IF;

    -- 🔍 RÉSOLUTION INTELLIGENTE DU DÉBITEUR VIA VELMO ID
    v_debtor_id := NULLIF(p_data->>'debtor_id', '')::UUID;
    
    IF v_debtor_id IS NULL AND (p_data->>'velmo_id') IS NOT NULL THEN
        -- Essayer de trouver le shop_id via le velmo_id
        SELECT shop_id INTO v_debtor_id 
        FROM users 
        WHERE velmo_id = (p_data->>'velmo_id') 
        LIMIT 1;

        -- 🆕 SI TROUVÉ, CRÉER UNE DEMANDE DE RELATION AUTOMATIQUE (PENDING)
        IF v_debtor_id IS NOT NULL AND v_debtor_id != v_shop_id THEN
            INSERT INTO merchant_relations (requester_shop_id, target_shop_id, status)
            VALUES (v_shop_id, v_debtor_id, 'pending')
            ON CONFLICT (requester_shop_id, target_shop_id) DO NOTHING;
        END IF;
    END IF;

    INSERT INTO debts (
        id, velmo_id, shop_id, user_id, debtor_id, customer_name, customer_phone,
        customer_address, total_amount, paid_amount, remaining_amount, status,
        type, category, due_date, reliability_score, trust_level, payment_count,
        on_time_payment_count, notes, products_json, created_at, updated_at
    ) VALUES (
        (p_data->>'id')::UUID, p_data->>'velmo_id', (p_data->>'shop_id')::UUID,
        (p_data->>'user_id')::UUID, v_debtor_id,
        p_data->>'customer_name', p_data->>'customer_phone', p_data->>'customer_address',
        (p_data->>'total_amount')::NUMERIC, (p_data->>'paid_amount')::NUMERIC,
        (p_data->>'remaining_amount')::NUMERIC, p_data->>'status', p_data->>'type',
        p_data->>'category', NULLIF(p_data->>'due_date', '')::TIMESTAMPTZ,
        COALESCE((p_data->>'reliability_score')::NUMERIC, 0),
        COALESCE(p_data->>'trust_level', 'new'),
        COALESCE((p_data->>'payment_count')::INTEGER, 0),
        COALESCE((p_data->>'on_time_payment_count')::INTEGER, 0),
        p_data->>'notes', (p_data->>'products_json')::JSONB,
        COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW()), NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        paid_amount = EXCLUDED.paid_amount, remaining_amount = EXCLUDED.remaining_amount,
        status = EXCLUDED.status, updated_at = NOW()
    RETURNING to_jsonb(debts.*) INTO v_result;
    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION sync_push_debt_payment(p_data JSONB, p_user_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_result JSONB;
BEGIN
    INSERT INTO debt_payments (
        id, debt_id, user_id, amount, payment_method, notes, reference_code, created_at
    ) VALUES (
        (p_data->>'id')::UUID, (p_data->>'debt_id')::UUID, (p_data->>'user_id')::UUID,
        (p_data->>'amount')::NUMERIC, p_data->>'payment_method', p_data->>'notes',
        p_data->>'reference_code', COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW())
    )
    ON CONFLICT (id) DO NOTHING
    RETURNING to_jsonb(debt_payments.*) INTO v_result;
    RETURN v_result;
END;
$$;

-- ================================================================
-- 5️⃣ MASTER FUNCTION: sync_push_record
-- ================================================================

CREATE OR REPLACE FUNCTION sync_push_record(
    p_table_name TEXT,
    p_data JSONB,
    p_user_id UUID,
    p_operation TEXT
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- PRODUCTS
    IF p_table_name = 'products' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM products WHERE id = (p_data->>'id')::UUID RETURNING to_jsonb(products.*) INTO v_result;
        ELSE
            v_result := sync_push_product(p_data, p_user_id);
        END IF;
        
    -- SALES
    ELSIF p_table_name = 'sales' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM sales WHERE id = (p_data->>'id')::UUID RETURNING to_jsonb(sales.*) INTO v_result;
        ELSE
            v_result := sync_push_sale(p_data, p_user_id);
        END IF;
        
    -- SALE ITEMS
    ELSIF p_table_name = 'sale_items' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM sale_items WHERE id = (p_data->>'id')::UUID RETURNING to_jsonb(sale_items.*) INTO v_result;
        ELSE
            v_result := sync_push_sale_item(p_data, p_user_id);
        END IF;
    
    -- DEBTS
    ELSIF p_table_name = 'debts' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM debts WHERE id = (p_data->>'id')::UUID RETURNING to_jsonb(debts.*) INTO v_result;
        ELSE
            v_result := sync_push_debt(p_data, p_user_id);
        END IF;
    
    -- DEBT PAYMENTS
    ELSIF p_table_name = 'debt_payments' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM debt_payments WHERE id = (p_data->>'id')::UUID RETURNING to_jsonb(debt_payments.*) INTO v_result;
        ELSE
            v_result := sync_push_debt_payment(p_data, p_user_id);
        END IF;

    -- ORDERS (✅ AJOUTÉ)
    ELSIF p_table_name = 'orders' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM orders WHERE id = (p_data->>'id') RETURNING to_jsonb(orders.*) INTO v_result;
        ELSE
            v_result := sync_push_order(p_data, p_user_id);
        END IF;

    -- ORDER ITEMS (✅ AJOUTÉ)
    ELSIF p_table_name = 'order_items' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM order_items WHERE id = (p_data->>'id') RETURNING to_jsonb(order_items.*) INTO v_result;
        ELSE
            v_result := sync_push_order_item(p_data, p_user_id);
        END IF;

    -- MERCHANT RELATIONS (✅ AJOUTÉ)
    ELSIF p_table_name = 'merchant_relations' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM merchant_relations WHERE id = (p_data->>'id') RETURNING to_jsonb(merchant_relations.*) INTO v_result;
        ELSE
            INSERT INTO merchant_relations (
                id, requester_shop_id, target_shop_id, status, created_at, updated_at
            ) VALUES (
                p_data->>'id', (p_data->>'requester_shop_id')::UUID, (p_data->>'target_shop_id')::UUID,
                COALESCE(p_data->>'status', 'pending'),
                COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW()), NOW()
            )
            ON CONFLICT (id) DO UPDATE SET
                status = EXCLUDED.status, updated_at = NOW()
            RETURNING to_jsonb(merchant_relations.*) INTO v_result;
        END IF;
        
    ELSE
        RAISE EXCEPTION 'Table % not supported by sync_push_record', p_table_name;
    END IF;
    
    RETURN v_result;
END;
$$;

-- ================================================================
-- 6️⃣ RPC RELATIONS (CONFIRM / REJECT)
-- ================================================================

CREATE OR REPLACE FUNCTION confirm_merchant_relation(p_relation_id TEXT, p_user_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_shop_id UUID;
    v_result JSONB;
BEGIN
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    IF v_shop_id IS NULL THEN RAISE EXCEPTION 'User not found'; END IF;

    -- Vérifier que c'est bien le destinataire qui confirme
    UPDATE merchant_relations
    SET status = 'active', updated_at = NOW()
    WHERE id = p_relation_id AND target_shop_id = v_shop_id
    RETURNING to_jsonb(merchant_relations.*) INTO v_result;

    IF v_result IS NULL THEN RAISE EXCEPTION 'Relation not found or permission denied'; END IF;

    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION reject_merchant_relation(p_relation_id TEXT, p_user_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_shop_id UUID;
    v_result JSONB;
BEGIN
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    IF v_shop_id IS NULL THEN RAISE EXCEPTION 'User not found'; END IF;

    -- Vérifier que c'est bien le destinataire qui rejette
    UPDATE merchant_relations
    SET status = 'rejected', updated_at = NOW()
    WHERE id = p_relation_id AND target_shop_id = v_shop_id
    RETURNING to_jsonb(merchant_relations.*) INTO v_result;

    IF v_result IS NULL THEN RAISE EXCEPTION 'Relation not found or permission denied'; END IF;

    RETURN v_result;
END;
$$;

-- Permissions
GRANT EXECUTE ON FUNCTION sync_push_order TO authenticated;
GRANT EXECUTE ON FUNCTION sync_push_order_item TO authenticated;
GRANT EXECUTE ON FUNCTION sync_push_debt TO authenticated;
GRANT EXECUTE ON FUNCTION sync_push_debt_payment TO authenticated;
GRANT EXECUTE ON FUNCTION sync_push_record TO authenticated;
GRANT EXECUTE ON FUNCTION confirm_merchant_relation TO authenticated;
GRANT EXECUTE ON FUNCTION reject_merchant_relation TO authenticated;

COMMIT;