-- ================================================================
-- 🚀 SYNC PUSH RPC (BYPASS RLS) - VERSION CORRIGÉE
-- ================================================================
-- Date: 24 Décembre 2025
-- Objectif: Contourner les RLS pour l'écriture via une fonction RPC sécurisée
--           + Support des dates ISO et Timestamp
-- ================================================================

BEGIN;

-- Fonction générique pour pousser des données (INSERT/UPDATE)
CREATE OR REPLACE FUNCTION sync_push_table(
    p_table_name TEXT,
    p_data JSONB,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER -- Exécute avec les droits admin (contourne RLS)
AS $$
DECLARE
    v_shop_id UUID;
    v_record_id UUID;
    v_result JSONB;
    v_created_at TIMESTAMPTZ;
BEGIN
    -- 1. Vérifier que l'utilisateur a accès au shop concerné
    IF p_data ? 'shop_id' THEN
        v_shop_id := (p_data->>'shop_id')::UUID;
        
        -- Vérifier si l'utilisateur est owner ou membre
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
        -- Si pas de shop_id, on prend celui de l'utilisateur
        SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    END IF;

    -- 2. Normaliser la date created_at
    IF p_data->>'created_at' ~ '^\d+$' THEN
        -- Timestamp numérique (ms)
        v_created_at := to_timestamp((p_data->>'created_at')::bigint / 1000);
    ELSE
        -- String ISO
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
            INSERT INTO debts (
                id, velmo_id, shop_id, user_id, debtor_id, customer_name,
                customer_phone, total_amount, paid_amount, remaining_amount,
                status, type, due_date, notes, created_at, updated_at
            ) VALUES (
                (p_data->>'id')::UUID,
                p_data->>'velmo_id',
                (p_data->>'shop_id')::UUID,
                (p_data->>'user_id')::UUID,
                (p_data->>'debtor_id')::UUID,
                p_data->>'customer_name',
                p_data->>'customer_phone',
                (p_data->>'total_amount')::DECIMAL,
                (p_data->>'paid_amount')::DECIMAL,
                (p_data->>'remaining_amount')::DECIMAL,
                (p_data->>'status')::debt_status,
                p_data->>'type',
                (to_timestamp((p_data->>'due_date')::bigint / 1000)),
                p_data->>'notes',
                v_created_at,
                NOW()
            )
            ON CONFLICT (id) DO UPDATE SET
                total_amount = EXCLUDED.total_amount,
                paid_amount = EXCLUDED.paid_amount,
                remaining_amount = EXCLUDED.remaining_amount,
                status = EXCLUDED.status,
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
ALTER FUNCTION sync_push_table OWNER TO postgres;

COMMIT;

-- ================================================================
-- ✅ RPC SYNC PUSH CRÉÉE (VERSION CORRIGÉE)
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ sync_push_table (v2) créée avec succès !';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🚀 Support des dates ISO et Timestamp ajouté';
    RAISE NOTICE '========================================';
END $$;
