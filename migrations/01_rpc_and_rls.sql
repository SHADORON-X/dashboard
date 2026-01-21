-- ================================================================
-- 🔐 RPC + RLS + PERMISSIONS - VENTO DATABASE
-- ================================================================
-- Date: 24 Décembre 2025
-- Objectif: Créer toutes les fonctions RPC et les politiques RLS
-- 
-- À exécuter APRÈS 00_reset_and_schema.sql
-- ================================================================

BEGIN;

-- ================================================================
-- PARTIE 1: FONCTIONS RPC D'AUTHENTIFICATION
-- ================================================================

-- Fonction: verify_pin
CREATE OR REPLACE FUNCTION verify_pin(pin TEXT, pin_hash TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN pin_hash = crypt(pin, pin_hash);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction: create_user_vtl (Création utilisateur + shop)
CREATE OR REPLACE FUNCTION create_user_vtl(
    p_phone text,
    p_first_name text,
    p_last_name text,
    p_pin_hash text,
    p_shop_name text,
    p_shop_category text,
    p_velmo_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_shop_id UUID;
    v_shop_code TEXT;
    v_velmo_shop_id TEXT;
    v_user users%ROWTYPE;
    v_shop shops%ROWTYPE;
    v_result jsonb;
BEGIN
    -- Générer des UUIDs natifs
    v_user_id := gen_random_uuid();
    v_shop_code := 'SHP-' || upper(substring(md5(random()::text) from 1 for 6));
    v_velmo_shop_id := 'VSH-' || upper(substring(md5(random()::text) from 1 for 8));

    -- Créer l'utilisateur
    INSERT INTO users (
        id, velmo_id, phone, first_name, last_name, pin_hash,
        auth_mode, role, is_active, onboarding_completed,
        created_at, updated_at
    ) VALUES (
        v_user_id, p_velmo_id, NULLIF(p_phone, ''),
        p_first_name, p_last_name, crypt(p_pin_hash, gen_salt('bf')),
        'online', 'owner', true, true, now(), now()
    ) RETURNING * INTO v_user;

    -- Créer la boutique
    INSERT INTO shops (
        velmo_id, owner_id, name, category, shop_code,
        is_active, created_at, updated_at
    ) VALUES (
        v_velmo_shop_id, v_user_id, p_shop_name, p_shop_category,
        v_shop_code, true, now(), now()
    ) RETURNING * INTO v_shop;

    v_shop_id := v_shop.id;

    -- Lier la boutique à l'utilisateur
    UPDATE users SET shop_id = v_shop_id WHERE id = v_user_id
    RETURNING * INTO v_user;

    -- Retourner le résultat
    v_result := jsonb_build_object(
        'success', true,
        'message', 'User and shop created successfully',
        'user', to_jsonb(v_user),
        'shop', to_jsonb(v_shop)
    );

    RETURN v_result;

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', SQLERRM,
        'detail', SQLSTATE
    );
END;
$$;

-- Fonction: login_user_vtl
CREATE OR REPLACE FUNCTION login_user_vtl(
    p_velmo_id text,
    p_pin_hash text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user users%ROWTYPE;
    v_shop shops%ROWTYPE;
    v_result jsonb;
BEGIN
    -- Chercher l'utilisateur
    SELECT * INTO v_user FROM users
    WHERE velmo_id = p_velmo_id AND is_active = true;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'User not found');
    END IF;

    -- Vérifier le PIN
    IF v_user.pin_hash IS NULL OR v_user.pin_hash != crypt(p_pin_hash, v_user.pin_hash) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invalid PIN');
    END IF;

    -- Récupérer le shop
    IF v_user.shop_id IS NOT NULL THEN
        SELECT * INTO v_shop FROM shops WHERE id = v_user.shop_id;
    END IF;

    -- Mettre à jour last_login_at et is_logged_in
    UPDATE users SET 
        last_login_at = now(),
        is_logged_in = true
    WHERE id = v_user.id
    RETURNING * INTO v_user;

    -- Retourner le résultat
    v_result := jsonb_build_object(
        'success', true,
        'message', 'Login successful',
        'user', to_jsonb(v_user),
        'shop', to_jsonb(v_shop)
    );

    RETURN v_result;

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM, 'detail', SQLSTATE);
END;
$$;

-- Fonction: get_user_vtl
CREATE OR REPLACE FUNCTION get_user_vtl(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user users%ROWTYPE;
    v_shop shops%ROWTYPE;
    v_result jsonb;
BEGIN
    SELECT * INTO v_user FROM users WHERE id = p_user_id AND is_active = true;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'User not found');
    END IF;

    IF v_user.shop_id IS NOT NULL THEN
        SELECT * INTO v_shop FROM shops WHERE id = v_user.shop_id;
    END IF;

    v_result := jsonb_build_object(
        'success', true,
        'user', to_jsonb(v_user),
        'shop', to_jsonb(v_shop)
    );

    RETURN v_result;

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

-- ================================================================
-- PARTIE 2: FONCTIONS RPC POUR SHOPS
-- ================================================================

-- Fonction: sync_user_shops
CREATE OR REPLACE FUNCTION sync_user_shops(p_user_uuid uuid)
RETURNS SETOF shops
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM shops
    WHERE owner_id = p_user_uuid AND is_active = true
    ORDER BY created_at DESC;
END;
$$;

-- Fonction: create_shop_custom_auth
CREATE OR REPLACE FUNCTION create_shop_custom_auth(
    p_shop_id uuid,
    p_name text,
    p_category text,
    p_currency text,
    p_owner_id uuid,
    p_shop_code text,
    p_velmo_id text,
    p_logo_icon text DEFAULT NULL,
    p_logo_color text DEFAULT NULL
)
RETURNS shops
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_shop shops;
BEGIN
    INSERT INTO shops (
        id, name, category, currency, owner_id, shop_code, velmo_id,
        logo_icon, logo_color, created_at, updated_at, is_active, created_offline
    ) VALUES (
        p_shop_id, p_name, p_category, p_currency, p_owner_id, p_shop_code, p_velmo_id,
        p_logo_icon, p_logo_color, NOW(), NOW(), true, false
    )
    RETURNING * INTO new_shop;
    
    RETURN new_shop;
END;
$$;

-- Fonction: update_shop_custom_auth
CREATE OR REPLACE FUNCTION update_shop_custom_auth(
    p_shop_id uuid,
    p_name text DEFAULT NULL,
    p_category text DEFAULT NULL,
    p_currency text DEFAULT NULL,
    p_logo_icon text DEFAULT NULL,
    p_logo_color text DEFAULT NULL
)
RETURNS shops
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    updated_shop shops;
BEGIN
    UPDATE shops
    SET
        name = COALESCE(p_name, name),
        category = COALESCE(p_category, category),
        currency = COALESCE(p_currency, currency),
        logo_icon = COALESCE(p_logo_icon, logo_icon),
        logo_color = COALESCE(p_logo_color, logo_color),
        updated_at = NOW()
    WHERE id = p_shop_id
    RETURNING * INTO updated_shop;
    
    RETURN updated_shop;
END;
$$;

-- Fonction: delete_shop_custom_auth
CREATE OR REPLACE FUNCTION delete_shop_custom_auth(p_shop_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE shops SET is_active = false WHERE id = p_shop_id;
    RETURN FOUND;
END;
$$;

-- ================================================================
-- PARTIE 3: FONCTIONS RPC POUR USERS
-- ================================================================

-- Fonction: update_user_profile
CREATE OR REPLACE FUNCTION update_user_profile(
    p_user_id uuid,
    p_first_name text DEFAULT NULL,
    p_last_name text DEFAULT NULL,
    p_phone text DEFAULT NULL,
    p_email text DEFAULT NULL,
    p_avatar_url text DEFAULT NULL
)
RETURNS users
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    updated_user users;
BEGIN
    UPDATE users
    SET
        first_name = COALESCE(p_first_name, first_name),
        last_name = COALESCE(p_last_name, last_name),
        phone = COALESCE(p_phone, phone),
        email = COALESCE(p_email, email),
        avatar_url = COALESCE(p_avatar_url, avatar_url),
        updated_at = NOW()
    WHERE id = p_user_id
    RETURNING * INTO updated_user;
    
    RETURN updated_user;
END;
$$;

-- Fonction: update_user_pin
CREATE OR REPLACE FUNCTION update_user_pin(
    p_user_id uuid,
    p_new_pin_hash text
)
RETURNS users
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    updated_user users;
BEGIN
    UPDATE users
    SET
        pin_hash = crypt(p_new_pin_hash, gen_salt('bf')),
        updated_at = NOW()
    WHERE id = p_user_id
    RETURNING * INTO updated_user;
    
    RETURN updated_user;
END;
$$;

-- ================================================================
-- PARTIE 4: FONCTIONS RPC POUR OTP
-- ================================================================

-- Fonction: create_otp
CREATE OR REPLACE FUNCTION create_otp(
    p_phone TEXT,
    p_method TEXT DEFAULT 'sms'
)
RETURNS TABLE (code TEXT, expires_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_code TEXT;
    v_code_hash TEXT;
    v_expires_at TIMESTAMPTZ;
BEGIN
    -- Générer code 4 chiffres
    v_code := LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
    v_code_hash := crypt(v_code, gen_salt('bf'));
    v_expires_at := NOW() + INTERVAL '5 minutes';
    
    -- Supprimer les anciens codes
    DELETE FROM otp_codes WHERE phone = p_phone AND verified = FALSE;
    
    -- Insérer nouveau code
    INSERT INTO otp_codes (phone, code, code_hash, method, expires_at)
    VALUES (p_phone, v_code, v_code_hash, p_method::otp_method, v_expires_at);
    
    RETURN QUERY SELECT v_code, v_expires_at;
END;
$$;

-- ================================================================
-- PARTIE 5: FONCTIONS RPC POUR SYNCHRONISATION
-- ================================================================

-- Fonction: sync_pull_table (Pull générique pour toutes les tables)
CREATE OR REPLACE FUNCTION sync_pull_table(
    p_table_name TEXT,
    p_user_id UUID,
    p_last_sync_time TIMESTAMPTZ DEFAULT '1970-01-01'::TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
    v_query TEXT;
    v_shop_id UUID;
BEGIN
    -- Récupérer le shop_id de l'utilisateur
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    -- Construire la requête selon la table
    CASE p_table_name
        WHEN 'shops' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM shops
                WHERE owner_id = p_user_id
                AND updated_at > p_last_sync_time
                ORDER BY updated_at DESC
            ) t;
            
        WHEN 'products' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM products
                WHERE shop_id = v_shop_id
                AND updated_at > p_last_sync_time
                ORDER BY updated_at DESC
            ) t;
            
        WHEN 'sales' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM sales
                WHERE shop_id = v_shop_id
                AND updated_at > p_last_sync_time
                ORDER BY created_at DESC
            ) t;
            
        WHEN 'sale_items' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT si.* FROM sale_items si
                INNER JOIN sales s ON si.sale_id = s.id
                WHERE s.shop_id = v_shop_id
                ORDER BY s.created_at DESC
            ) t;
            
        WHEN 'debts' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM debts
                WHERE shop_id = v_shop_id
                AND updated_at > p_last_sync_time
                ORDER BY updated_at DESC
            ) t;
            
        WHEN 'debt_payments' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT dp.* FROM debt_payments dp
                INNER JOIN debts d ON dp.debt_id = d.id
                WHERE d.shop_id = v_shop_id
                AND dp.updated_at > p_last_sync_time
                ORDER BY dp.created_at DESC
            ) t;
            
        WHEN 'cart_items' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM cart_items
                WHERE shop_id = v_shop_id
                AND updated_at > p_last_sync_time
                ORDER BY created_at DESC
            ) t;
            
        WHEN 'merchant_relations' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM merchant_relations
                WHERE (shop_a_id = v_shop_id OR shop_b_id = v_shop_id)
                AND updated_at > p_last_sync_time
                ORDER BY updated_at DESC
            ) t;
            
        WHEN 'orders' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT * FROM orders
                WHERE shop_id = v_shop_id
                AND updated_at > p_last_sync_time
                ORDER BY created_at DESC
            ) t;
            
        WHEN 'order_items' THEN
            SELECT jsonb_agg(row_to_json(t)) INTO v_result
            FROM (
                SELECT oi.* FROM order_items oi
                INNER JOIN orders o ON oi.order_id = o.id
                WHERE o.shop_id = v_shop_id
                ORDER BY o.created_at DESC
            ) t;
            
        ELSE
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Unknown table: ' || p_table_name
            );
    END CASE;
    
    -- Retourner le résultat
    RETURN COALESCE(v_result, '[]'::jsonb);
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', SQLERRM,
        'detail', SQLSTATE
    );
END;
$$;

-- ================================================================
-- PARTIE 6: ROW LEVEL SECURITY (RLS)
-- ================================================================

-- Activer RLS sur toutes les tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE debts ENABLE ROW LEVEL SECURITY;
ALTER TABLE debt_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE merchant_relations ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_members ENABLE ROW LEVEL SECURITY;

-- RLS: Users
CREATE POLICY "Users see only themselves" ON users
FOR SELECT USING (auth.uid() = id OR auth.uid()::text = id::text);

CREATE POLICY "Users update only themselves" ON users
FOR UPDATE USING (auth.uid() = id OR auth.uid()::text = id::text);

CREATE POLICY "Service role bypass" ON users
FOR ALL USING (current_setting('app.bypass_rls', true)::text = 'true');

-- RLS: Shops
CREATE POLICY "Users see their own shops" ON shops
FOR SELECT USING (
    owner_id = auth.uid()::uuid
    OR EXISTS (
        SELECT 1 FROM shop_members sm
        WHERE sm.shop_id = shops.id AND sm.user_id = auth.uid()::uuid
    )
);

CREATE POLICY "Users update their own shops" ON shops
FOR UPDATE USING (owner_id = auth.uid()::uuid);

CREATE POLICY "Service role bypass" ON shops
FOR ALL USING (current_setting('app.bypass_rls', true)::text = 'true');

-- RLS: Products
CREATE POLICY "Users see products from their shops" ON products
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM shops s
        WHERE s.id = products.shop_id
        AND (s.owner_id = auth.uid()::uuid OR EXISTS (
            SELECT 1 FROM shop_members sm
            WHERE sm.shop_id = s.id AND sm.user_id = auth.uid()::uuid
        ))
    )
);

CREATE POLICY "Service role bypass" ON products
FOR ALL USING (current_setting('app.bypass_rls', true)::text = 'true');

-- RLS: Sales
CREATE POLICY "Users see sales from their shops" ON sales
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM shops s
        WHERE s.id = sales.shop_id
        AND (s.owner_id = auth.uid()::uuid OR EXISTS (
            SELECT 1 FROM shop_members sm
            WHERE sm.shop_id = s.id AND sm.user_id = auth.uid()::uuid
        ))
    )
);

CREATE POLICY "Service role bypass" ON sales
FOR ALL USING (current_setting('app.bypass_rls', true)::text = 'true');

-- RLS: Sale Items (hérite de sales)
CREATE POLICY "Users see sale items from their shops" ON sale_items
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM sales s
        WHERE s.id = sale_items.sale_id
        AND EXISTS (
            SELECT 1 FROM shops sh
            WHERE sh.id = s.shop_id
            AND (sh.owner_id = auth.uid()::uuid OR EXISTS (
                SELECT 1 FROM shop_members sm
                WHERE sm.shop_id = sh.id AND sm.user_id = auth.uid()::uuid
            ))
        )
    )
);

CREATE POLICY "Service role bypass" ON sale_items
FOR ALL USING (current_setting('app.bypass_rls', true)::text = 'true');

-- RLS: Cart Items
CREATE POLICY "Users manage their cart items" ON cart_items
FOR ALL USING (
    user_id = auth.uid()::uuid OR EXISTS (
        SELECT 1 FROM shops s
        WHERE s.id = cart_items.shop_id
        AND (s.owner_id = auth.uid()::uuid OR EXISTS (
            SELECT 1 FROM shop_members sm
            WHERE sm.shop_id = s.id AND sm.user_id = auth.uid()::uuid
        ))
    )
);

CREATE POLICY "Service role bypass" ON cart_items
FOR ALL USING (current_setting('app.bypass_rls', true)::text = 'true');

-- RLS: Debts
CREATE POLICY "Users see debts from their shops" ON debts
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM shops s
        WHERE s.id = debts.shop_id
        AND (s.owner_id = auth.uid()::uuid OR EXISTS (
            SELECT 1 FROM shop_members sm
            WHERE sm.shop_id = s.id AND sm.user_id = auth.uid()::uuid
        ))
    )
);

CREATE POLICY "Service role bypass" ON debts
FOR ALL USING (current_setting('app.bypass_rls', true)::text = 'true');

-- RLS: Debt Payments (hérite de debts)
CREATE POLICY "Users see payments from their shop debts" ON debt_payments
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM debts d
        WHERE d.id = debt_payments.debt_id
        AND EXISTS (
            SELECT 1 FROM shops s
            WHERE s.id = d.shop_id
            AND (s.owner_id = auth.uid()::uuid OR EXISTS (
                SELECT 1 FROM shop_members sm
                WHERE sm.shop_id = s.id AND sm.user_id = auth.uid()::uuid
            ))
        )
    )
);

CREATE POLICY "Service role bypass" ON debt_payments
FOR ALL USING (current_setting('app.bypass_rls', true)::text = 'true');

-- RLS: Merchant Relations
CREATE POLICY "Users see their merchant relations" ON merchant_relations
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM shops s
        WHERE (s.id = merchant_relations.shop_a_id OR s.id = merchant_relations.shop_b_id)
        AND s.owner_id = auth.uid()::uuid
    )
);

CREATE POLICY "Service role bypass" ON merchant_relations
FOR ALL USING (current_setting('app.bypass_rls', true)::text = 'true');

-- RLS: Orders
CREATE POLICY "Users see their orders" ON orders
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM shops s
        WHERE s.id = orders.shop_id
        AND (s.owner_id = auth.uid()::uuid OR EXISTS (
            SELECT 1 FROM shop_members sm
            WHERE sm.shop_id = s.id AND sm.user_id = auth.uid()::uuid
        ))
    )
);

CREATE POLICY "Service role bypass" ON orders
FOR ALL USING (current_setting('app.bypass_rls', true)::text = 'true');

-- RLS: Order Items (hérite de orders)
CREATE POLICY "Users see their order items" ON order_items
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM orders o
        WHERE o.id = order_items.order_id
        AND EXISTS (
            SELECT 1 FROM shops s
            WHERE s.id = o.shop_id
            AND (s.owner_id = auth.uid()::uuid OR EXISTS (
                SELECT 1 FROM shop_members sm
                WHERE sm.shop_id = s.id AND sm.user_id = auth.uid()::uuid
            ))
        )
    )
);

CREATE POLICY "Service role bypass" ON order_items
FOR ALL USING (current_setting('app.bypass_rls', true)::text = 'true');

-- RLS: Shop Members
CREATE POLICY "Shop owners manage members" ON shop_members
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM shops s
        WHERE s.id = shop_members.shop_id
        AND s.owner_id = auth.uid()::uuid
    )
);

CREATE POLICY "Service role bypass" ON shop_members
FOR ALL USING (current_setting('app.bypass_rls', true)::text = 'true');

-- ================================================================
-- PARTIE 6: PERMISSIONS
-- ================================================================

-- Permissions pour les fonctions RPC
GRANT EXECUTE ON FUNCTION verify_pin TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION create_user_vtl TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION login_user_vtl TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_user_vtl TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_user_shops TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION create_shop_custom_auth TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_shop_custom_auth TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION delete_shop_custom_auth TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_user_profile TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_user_pin TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION create_otp TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_pull_table TO anon, authenticated, service_role;

-- Ownership des fonctions
ALTER FUNCTION verify_pin OWNER TO postgres;
ALTER FUNCTION create_user_vtl OWNER TO postgres;
ALTER FUNCTION login_user_vtl OWNER TO postgres;
ALTER FUNCTION get_user_vtl OWNER TO postgres;
ALTER FUNCTION sync_user_shops OWNER TO postgres;
ALTER FUNCTION create_shop_custom_auth OWNER TO postgres;
ALTER FUNCTION update_shop_custom_auth OWNER TO postgres;
ALTER FUNCTION delete_shop_custom_auth OWNER TO postgres;
ALTER FUNCTION update_user_profile OWNER TO postgres;
ALTER FUNCTION update_user_pin OWNER TO postgres;
ALTER FUNCTION create_otp OWNER TO postgres;
ALTER FUNCTION sync_pull_table OWNER TO postgres;

COMMIT;

-- ================================================================
-- ✅ RPC + RLS CRÉÉS AVEC SUCCÈS
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ RPC + RLS CRÉÉS AVEC SUCCÈS !';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📊 Fonctions RPC créées: 12';
    RAISE NOTICE '🔐 Politiques RLS créées: 24';
    RAISE NOTICE '🔑 Permissions accordées';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🎯 Base de données prête !';
    RAISE NOTICE '   Vous pouvez maintenant tester:';
    RAISE NOTICE '   - create_user_vtl()';
    RAISE NOTICE '   - login_user_vtl()';
    RAISE NOTICE '   - sync_user_shops()';
    RAISE NOTICE '   - sync_pull_table()';
    RAISE NOTICE '========================================';
END $$;
