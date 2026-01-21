-- ================================================================
-- 🚀 MIGRATION: SUPPRESSION SUPABASE AUTH & PASSAGE À VTLBES_CY
-- ================================================================

-- 1️⃣ CRÉATION DE LA TABLE D'AUTHENTIFICATION (vtlbes_cy)
-- Cette table remplace complètement auth.users et public.users
DROP TABLE IF EXISTS vtlbes_cy CASCADE;
CREATE TABLE vtlbes_cy (
    -- Primary key (UUID généré par nous, pas par Supabase Auth)
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identity
    velmo_id TEXT UNIQUE NOT NULL,
    phone TEXT,
    email TEXT, -- Optionnel, juste pour info
    
    -- Names
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    
    -- Authentication
    pin_hash TEXT NOT NULL, -- Haché (bcrypt ou autre)
    auth_mode TEXT DEFAULT 'offline', -- 'online', 'offline'
    
    -- Permissions
    role TEXT NOT NULL DEFAULT 'owner', -- 'owner', 'employee'
    shop_id UUID, -- Lien vers la boutique principale
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    onboarding_completed BOOLEAN DEFAULT FALSE,
    last_login_at TIMESTAMPTZ,
    
    -- Sync metadata
    sync_status TEXT DEFAULT 'pending',
    synced_at TIMESTAMPTZ,
    created_offline BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT velmo_id_format CHECK (velmo_id ~ '^VLM-[A-Z]{2,3}-[0-9]{3,}$')
);

-- Indexes pour performance
CREATE INDEX idx_vtlbes_cy_velmo_id ON vtlbes_cy(velmo_id);
CREATE INDEX idx_vtlbes_cy_phone ON vtlbes_cy(phone);
CREATE INDEX idx_vtlbes_cy_shop_id ON vtlbes_cy(shop_id);

-- 2️⃣ RPC: CRÉATION DE COMPTE (Sans Supabase Auth)
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
    v_user_id uuid;
    v_shop_id uuid;
    v_shop_code text;
    v_velmo_shop_id text;
    v_user vtlbes_cy%ROWTYPE;
    v_shop shops%ROWTYPE;
    v_result jsonb;
BEGIN
    -- Générer un ID utilisateur
    v_user_id := gen_random_uuid();

    -- 1. Créer l'utilisateur
    INSERT INTO vtlbes_cy (
        id,
        velmo_id,
        phone,
        first_name,
        last_name,
        pin_hash,
        auth_mode,
        role,
        is_active,
        onboarding_completed,
        created_at,
        updated_at
    ) VALUES (
        v_user_id,
        p_velmo_id,
        NULLIF(p_phone, ''),
        p_first_name,
        p_last_name,
        crypt(p_pin_hash, gen_salt('bf')), -- ✅ Hachage sécurisé
        'online',
        'owner',
        true,
        true,
        now(),
        now()
    ) RETURNING * INTO v_user;

    -- 2. Générer codes boutique
    v_shop_code := 'SHP-' || upper(substring(md5(random()::text) from 1 for 6));
    v_velmo_shop_id := 'VSH-' || upper(substring(md5(random()::text) from 1 for 8));

    -- 3. Créer la boutique
    INSERT INTO shops (
        velmo_id,
        owner_id, -- Lien vers vtlbes_cy.id
        name,
        category,
        shop_code,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        v_velmo_shop_id,
        v_user_id,
        p_shop_name,
        p_shop_category,
        v_shop_code,
        true,
        now(),
        now()
    ) RETURNING * INTO v_shop;

    v_shop_id := v_shop.id;

    -- 4. Mettre à jour l'utilisateur avec le shop_id
    UPDATE vtlbes_cy 
    SET shop_id = v_shop_id
    WHERE id = v_user_id
    RETURNING * INTO v_user;

    -- 5. Retourner le résultat
    v_result := jsonb_build_object(
        'success', true,
        'user', to_jsonb(v_user),
        'shop', to_jsonb(v_shop)
    );

    RETURN v_result;

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', SQLERRM
    );
END;
$$;

-- 3️⃣ RPC: LOGIN (Vérification PIN)
CREATE OR REPLACE FUNCTION login_user_vtl(
    p_velmo_id text,
    p_pin_hash text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user vtlbes_cy%ROWTYPE;
    v_shop shops%ROWTYPE;
BEGIN
    -- Trouver l'utilisateur
    SELECT * INTO v_user 
    FROM vtlbes_cy 
    WHERE velmo_id = p_velmo_id 
    AND is_active = true;

    -- Vérifier le PIN
    IF v_user.id IS NULL OR v_user.pin_hash != crypt(p_pin_hash, v_user.pin_hash) THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Identifiants incorrects'
        );
    END IF;

    -- Mettre à jour last_login
    UPDATE vtlbes_cy SET last_login_at = now() WHERE id = v_user.id;

    -- Récupérer la boutique
    SELECT * INTO v_shop FROM shops WHERE id = v_user.shop_id;

    RETURN jsonb_build_object(
        'success', true,
        'user', to_jsonb(v_user),
        'shop', to_jsonb(v_shop)
    );
END;
$$;

-- 4️⃣ RPC: SYNC USER (Pour récupérer les données utilisateur par ID)
CREATE OR REPLACE FUNCTION get_user_vtl(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user vtlbes_cy%ROWTYPE;
BEGIN
    SELECT * INTO v_user FROM vtlbes_cy WHERE id = p_user_id;
    
    IF v_user.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'User not found');
    END IF;

    RETURN jsonb_build_object('success', true, 'user', to_jsonb(v_user));
END;
$$;

-- 5️⃣ PERMISSIONS
GRANT ALL ON vtlbes_cy TO anon;
GRANT ALL ON vtlbes_cy TO authenticated;
GRANT ALL ON vtlbes_cy TO service_role;

GRANT EXECUTE ON FUNCTION create_user_vtl TO anon;
GRANT EXECUTE ON FUNCTION create_user_vtl TO authenticated;
GRANT EXECUTE ON FUNCTION create_user_vtl TO service_role;

GRANT EXECUTE ON FUNCTION login_user_vtl TO anon;
GRANT EXECUTE ON FUNCTION login_user_vtl TO authenticated;
GRANT EXECUTE ON FUNCTION login_user_vtl TO service_role;

GRANT EXECUTE ON FUNCTION get_user_vtl TO anon;
GRANT EXECUTE ON FUNCTION get_user_vtl TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_vtl TO service_role;
