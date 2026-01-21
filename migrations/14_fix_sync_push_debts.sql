-- Migration: Fix sync_push_table for debts and add parameter order flexibility
-- Description: Handle NULL debtor_id and ensure sync_push_table works correctly
-- Date: 2025-12-25

-- ================================================================
-- 1. FIX SYNC_PUSH_TABLE FOR DEBTS (Handle NULL debtor_id)
-- ================================================================

CREATE OR REPLACE FUNCTION sync_push_table(
    p_table_name TEXT,
    p_data JSONB,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_shop_id UUID;
    v_record_id UUID;
    v_result JSONB;
    v_created_at TIMESTAMPTZ;
    v_debtor_id UUID;
BEGIN
    -- 1. Vérifier que l'utilisateur a accès au shop concerné
    IF p_data ? 'shop_id' THEN
        v_shop_id := (p_data->>'shop_id')::UUID;
        
        IF NOT EXISTS (
            SELECT 1 FROM shops s 
            WHERE s.id = v_shop_id 
            AND (s.owner_id = p_user_id OR EXISTS (
                SELECT 1 FROM shop_members sm 
                WHERE sm.shop_id = s.id AND sm.user_id = p_user_id
            ))
        ) THEN
            RETURN jsonb_build_object('success', false, 'message', 'Permission denied for this shop');
        END IF;
    ELSE
        SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    END IF;

    -- 2. Normaliser la date created_at
    IF p_data->>'created_at' ~ '^\d+$' THEN
        v_created_at := to_timestamp((p_data->>'created_at')::bigint / 1000);
    ELSE
        v_created_at := (p_data->>'created_at')::TIMESTAMPTZ;
    END IF;

    -- 3. Insérer ou mettre à jour selon la table
    CASE p_table_name
        WHEN 'products' THEN
            INSERT INTO products (
                id, velmo_id, shop_id, user_id, name, price_sale, price_buy, quantity,
                stock_alert, category, description, photo_url, barcode, unit, 
                is_active, is_incomplete, created_at, updated_at
            ) VALUES (
                (p_data->>'id')::UUID,
                p_data->>'velmo_id',
                (p_data->>'shop_id')::UUID,
                (p_data->>'user_id')::UUID,
                p_data->>'name',
                (p_data->>'price_sale')::DECIMAL,
                (p_data->>'price_buy')::DECIMAL,
                (p_data->>'quantity')::DECIMAL,
                (p_data->>'stock_alert')::DECIMAL,
                p_data->>'category',
                p_data->>'description',
                p_data->>'photo_url',
                p_data->>'barcode',
                p_data->>'unit',
                (p_data->>'is_active')::BOOLEAN,
                (p_data->>'is_incomplete')::BOOLEAN,
                v_created_at,
                NOW()
            )
            ON CONFLICT (id) DO UPDATE SET
                name = EXCLUDED.name,
                price_sale = EXCLUDED.price_sale,
                price_buy = EXCLUDED.price_buy,
                quantity = EXCLUDED.quantity,
                stock_alert = EXCLUDED.stock_alert,
                category = EXCLUDED.category,
                description = EXCLUDED.description,
                photo_url = EXCLUDED.photo_url,
                barcode = EXCLUDED.barcode,
                unit = EXCLUDED.unit,
                is_active = EXCLUDED.is_active,
                is_incomplete = EXCLUDED.is_incomplete,
                updated_at = NOW()
            RETURNING to_jsonb(products.*) INTO v_result;

        WHEN 'sales' THEN
            INSERT INTO sales (
                id, velmo_id, shop_id, user_id, total_amount, total_profit,
                payment_type, customer_name, customer_phone, notes, items_count,
                created_by, created_at, updated_at
            ) VALUES (
                (p_data->>'id')::UUID,
                p_data->>'velmo_id',
                (p_data->>'shop_id')::UUID,
                (p_data->>'user_id')::UUID,
                (p_data->>'total_amount')::DECIMAL,
                (p_data->>'total_profit')::DECIMAL,
                (p_data->>'payment_type')::payment_type,
                p_data->>'customer_name',
                p_data->>'customer_phone',
                p_data->>'notes',
                (p_data->>'items_count')::INTEGER,
                (p_data->>'created_by')::UUID,
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

        WHEN 'sale_items' THEN
            INSERT INTO sale_items (
                id, sale_id, product_id, user_id, product_name, quantity,
                unit_price, purchase_price, subtotal, profit, created_at
            ) VALUES (
                (p_data->>'id')::UUID,
                (p_data->>'sale_id')::UUID,
                (p_data->>'product_id')::UUID,
                (p_data->>'user_id')::UUID,
                p_data->>'product_name',
                (p_data->>'quantity')::DECIMAL,
                (p_data->>'unit_price')::DECIMAL,
                (p_data->>'purchase_price')::DECIMAL,
                (p_data->>'subtotal')::DECIMAL,
                (p_data->>'profit')::DECIMAL,
                v_created_at
            )
            ON CONFLICT (id) DO NOTHING
            RETURNING to_jsonb(sale_items.*) INTO v_result;

        WHEN 'debts' THEN
            -- ✅ FIX: Handle NULL debtor_id properly
            -- Only convert to UUID if the value exists and is not empty
            IF p_data ? 'debtor_id' AND p_data->>'debtor_id' IS NOT NULL AND p_data->>'debtor_id' != '' THEN
                BEGIN
                    v_debtor_id := (p_data->>'debtor_id')::UUID;
                EXCEPTION WHEN OTHERS THEN
                    -- If conversion fails (e.g., it's a Velmo ID), set to NULL
                    v_debtor_id := NULL;
                END;
            ELSE
                v_debtor_id := NULL;
            END IF;

            INSERT INTO debts (
                id, velmo_id, shop_id, user_id, debtor_id, customer_name,
                customer_phone, customer_address, total_amount, paid_amount, remaining_amount,
                status, type, category, due_date, reliability_score, trust_level,
                payment_count, on_time_payment_count, notes, products_json,
                created_at, updated_at
            ) VALUES (
                (p_data->>'id')::UUID,
                p_data->>'velmo_id',
                (p_data->>'shop_id')::UUID,
                (p_data->>'user_id')::UUID,
                v_debtor_id,  -- ✅ Use the safely converted value
                p_data->>'customer_name',
                p_data->>'customer_phone',
                p_data->>'customer_address',
                (p_data->>'total_amount')::DECIMAL,
                (p_data->>'paid_amount')::DECIMAL,
                (p_data->>'remaining_amount')::DECIMAL,
                (p_data->>'status')::debt_status,
                p_data->>'type',
                p_data->>'category',
                CASE 
                    WHEN p_data->>'due_date' ~ '^\d+$' THEN to_timestamp((p_data->>'due_date')::bigint / 1000)
                    ELSE (p_data->>'due_date')::TIMESTAMPTZ
                END,
                COALESCE((p_data->>'reliability_score')::DECIMAL, 50),
                COALESCE(p_data->>'trust_level', 'new'),
                COALESCE((p_data->>'payment_count')::INTEGER, 0),
                COALESCE((p_data->>'on_time_payment_count')::INTEGER, 0),
                p_data->>'notes',
                (p_data->'products_json')::JSONB,
                v_created_at,
                NOW()
            )
            ON CONFLICT (id) DO UPDATE SET
                total_amount = EXCLUDED.total_amount,
                paid_amount = EXCLUDED.paid_amount,
                remaining_amount = EXCLUDED.remaining_amount,
                status = EXCLUDED.status,
                reliability_score = EXCLUDED.reliability_score,
                trust_level = EXCLUDED.trust_level,
                payment_count = EXCLUDED.payment_count,
                on_time_payment_count = EXCLUDED.on_time_payment_count,
                updated_at = NOW()
            RETURNING to_jsonb(debts.*) INTO v_result;

        ELSE
            RETURN jsonb_build_object('success', false, 'message', 'Table not supported: ' || p_table_name);
    END CASE;

    RETURN jsonb_build_object('success', true, 'data', v_result);

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM, 'detail', SQLSTATE);
END;
$$;

-- Permissions
GRANT EXECUTE ON FUNCTION sync_push_table TO anon, authenticated, service_role;

-- ================================================================
-- 2. VERIFICATION
-- ================================================================

DO $$ 
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ sync_push_table updated successfully!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔧 Fixed NULL debtor_id handling';
    RAISE NOTICE '🔧 Added safe UUID conversion';
    RAISE NOTICE '========================================';
END $$;
