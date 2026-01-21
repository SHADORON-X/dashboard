-- Migration: Team Management System
-- Description: Add shop_requests table, enhance shop_members, RPCs, and update sync_push_table
-- Date: 2025-12-25

-- ================================================================
-- 1. SHOP REQUESTS TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS public.shop_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    requested_role TEXT DEFAULT 'seller',
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    allowed_pages JSONB DEFAULT '[]'::JSONB,
    handled_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Un utilisateur ne peut avoir qu'une demande en attente par shop
    CONSTRAINT unique_pending_request UNIQUE(user_id, shop_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_shop_requests_shop_id ON public.shop_requests(shop_id);
CREATE INDEX IF NOT EXISTS idx_shop_requests_user_id ON public.shop_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_shop_requests_status ON public.shop_requests(status);

-- Permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.shop_requests TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.shop_requests TO anon;

-- ================================================================
-- 2. ENHANCE SHOP_MEMBERS
-- ================================================================

-- Add permissions column if not exists
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'shop_members' AND column_name = 'permissions') THEN
        ALTER TABLE public.shop_members ADD COLUMN permissions JSONB DEFAULT '[]'::JSONB;
    END IF;
END $$;

-- ================================================================
-- 3. RPC: REQUEST JOIN SHOP
-- ================================================================

CREATE OR REPLACE FUNCTION public.request_join_shop(
    p_shop_velmo_id TEXT,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_shop_id UUID;
    v_existing_status TEXT;
BEGIN
    -- 1. Trouver le shop ID à partir du Velmo ID
    SELECT id INTO v_shop_id FROM public.shops WHERE velmo_id = p_shop_velmo_id;
    
    IF v_shop_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Boutique introuvable');
    END IF;

    -- 2. Vérifier si déjà membre
    IF EXISTS (SELECT 1 FROM public.shop_members WHERE shop_id = v_shop_id AND user_id = p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Vous êtes déjà membre de cette boutique');
    END IF;

    -- 3. Vérifier si demande déjà existante
    SELECT status INTO v_existing_status 
    FROM public.shop_requests 
    WHERE shop_id = v_shop_id AND user_id = p_user_id AND status = 'pending';
    
    IF v_existing_status IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Une demande est déjà en attente');
    END IF;

    -- 4. Créer la demande
    INSERT INTO public.shop_requests (
        user_id,
        shop_id,
        status,
        created_at,
        updated_at
    ) VALUES (
        p_user_id,
        v_shop_id,
        'pending',
        NOW(),
        NOW()
    );

    RETURN jsonb_build_object('success', true, 'message', 'Demande envoyée avec succès');
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_join_shop TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_join_shop TO anon;

-- ================================================================
-- 4. RPC: HANDLE SHOP REQUEST (Approve/Reject)
-- ================================================================

CREATE OR REPLACE FUNCTION public.handle_shop_request(
    p_request_id UUID,
    p_admin_id UUID,
    p_status TEXT, -- 'approved' or 'rejected'
    p_role TEXT DEFAULT NULL,
    p_permissions JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request RECORD;
    v_is_admin BOOLEAN;
BEGIN
    -- 1. Récupérer la demande (Lock row for update to prevent race conditions)
    SELECT * INTO v_request 
    FROM public.shop_requests 
    WHERE id = p_request_id 
    FOR UPDATE; -- 🔒 VERROUILLAGE

    IF v_request IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Demande introuvable');
    END IF;

    IF v_request.status != 'pending' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Cette demande a déjà été traitée');
    END IF;

    -- 2. Vérifier que celui qui traite est bien admin du shop
    SELECT EXISTS (
        SELECT 1 FROM public.shops WHERE id = v_request.shop_id AND owner_id = p_admin_id
        UNION
        SELECT 1 FROM public.shop_members WHERE shop_id = v_request.shop_id AND user_id = p_admin_id AND role = 'admin'
    ) INTO v_is_admin;

    IF NOT v_is_admin THEN
        RETURN jsonb_build_object('success', false, 'message', 'Permission refusée: Vous n''êtes pas admin');
    END IF;

    -- 3. Traitement
    IF p_status = 'approved' THEN
        -- Ajouter aux membres
        INSERT INTO public.shop_members (
            shop_id,
            user_id,
            role,
            permissions,
            is_active,
            created_at,
            updated_at
        ) VALUES (
            v_request.shop_id,
            v_request.user_id,
            COALESCE(p_role, 'seller')::user_role,
            COALESCE(p_permissions, '[]'::JSONB),
            true,
            NOW(),
            NOW()
        );
    END IF;

    -- 4. Mettre à jour la demande
    UPDATE public.shop_requests 
    SET 
        status = p_status,
        handled_by = p_admin_id,
        updated_at = NOW()
    WHERE id = p_request_id;

    RETURN jsonb_build_object('success', true, 'message', 'Demande traitée avec succès');
END;
$$;

GRANT EXECUTE ON FUNCTION public.handle_shop_request TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_shop_request TO anon;

-- ================================================================
-- 5. SYNC PUSH UPDATE (COMPLETE)
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
        
        -- Pour les requêtes de join, on est pas encore membre, donc on bypass la vérif standard
        IF p_table_name != 'shop_requests' THEN
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
            -- Fix: Handle NULL debtor_id properly
            IF p_data ? 'debtor_id' AND p_data->>'debtor_id' IS NOT NULL AND p_data->>'debtor_id' != '' THEN
                BEGIN
                    v_debtor_id := (p_data->>'debtor_id')::UUID;
                EXCEPTION WHEN OTHERS THEN
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
                v_debtor_id,
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

        -- ✅ NEW: SHOP REQUESTS
        WHEN 'shop_requests' THEN
            INSERT INTO shop_requests (
                id, user_id, shop_id, requested_role, status, allowed_pages,
                handled_by, created_at, updated_at
            ) VALUES (
                (p_data->>'id')::UUID,
                (p_data->>'user_id')::UUID,
                (p_data->>'shop_id')::UUID,
                p_data->>'requested_role',
                p_data->>'status',
                COALESCE((p_data->'allowed_pages')::JSONB, '[]'::JSONB),
                (p_data->>'handled_by')::UUID,
                v_created_at,
                NOW()
            )
            ON CONFLICT (id) DO UPDATE SET
                status = EXCLUDED.status,
                handled_by = EXCLUDED.handled_by,
                updated_at = NOW()
            RETURNING to_jsonb(shop_requests.*) INTO v_result;

        -- ✅ NEW: SHOP MEMBERS
        WHEN 'shop_members' THEN
            INSERT INTO shop_members (
                id, shop_id, user_id, role, permissions, is_active,
                created_at, updated_at
            ) VALUES (
                (p_data->>'id')::UUID,
                (p_data->>'shop_id')::UUID,
                (p_data->>'user_id')::UUID,
                (p_data->>'role')::user_role,
                COALESCE((p_data->'permissions')::JSONB, '[]'::JSONB),
                (p_data->>'is_active')::BOOLEAN,
                v_created_at,
                NOW()
            )
            ON CONFLICT (id) DO UPDATE SET
                role = EXCLUDED.role,
                permissions = EXCLUDED.permissions,
                is_active = EXCLUDED.is_active,
                updated_at = NOW()
            RETURNING to_jsonb(shop_members.*) INTO v_result;

        ELSE
            RETURN jsonb_build_object('success', false, 'message', 'Table not supported: ' || p_table_name);
    END CASE;

    RETURN jsonb_build_object('success', true, 'data', v_result);

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM, 'detail', SQLSTATE);
END;
$$;

-- Permissions for sync_push_table
GRANT EXECUTE ON FUNCTION sync_push_table TO anon, authenticated, service_role;

-- ================================================================
-- 6. VERIFICATION
-- ================================================================

DO $$ 
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Team Management System installed successfully!';
    RAISE NOTICE '✅ Tables created/updated';
    RAISE NOTICE '✅ RPCs created';
    RAISE NOTICE '✅ sync_push_table updated with new tables';
    RAISE NOTICE '========================================';
END $$;
