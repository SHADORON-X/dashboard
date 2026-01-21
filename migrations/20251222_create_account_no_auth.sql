-- ================================================================
-- 🚀 RPC: CRÉATION DE COMPTE SANS AUTH (Offline → Online)
-- ================================================================
-- 
-- Cette RPC permet de créer un compte même si l'utilisateur
-- n'a pas encore de session Supabase Auth active.
-- Utilisée lors de l'inscription offline qui devient online.
-- 
-- ================================================================

DROP FUNCTION IF EXISTS create_account_no_auth(uuid, text, text, text, text, text, text, text);

CREATE OR REPLACE FUNCTION create_account_no_auth(
    p_user_id uuid,
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
    v_shop_id uuid;
    v_shop_code text;
    v_velmo_shop_id text;
    v_user users%ROWTYPE;
    v_shop shops%ROWTYPE;
    v_result jsonb;
BEGIN
    -- 1. Vérifier si l'utilisateur existe déjà
    SELECT * INTO v_user FROM users WHERE id = p_user_id;
    
    IF v_user.id IS NULL THEN
        -- Créer l'utilisateur s'il n'existe pas
        -- ✅ Utiliser NULLIF pour convertir chaîne vide en NULL
        INSERT INTO users (
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
            p_user_id,
            p_velmo_id,
            NULLIF(p_phone, ''),  -- ✅ Convertir '' en NULL
            p_first_name,
            p_last_name,
            p_pin_hash,
            'online',
            'owner',
            true,
            true,
            now(),
            now()
        ) RETURNING * INTO v_user;
    END IF;

    -- 2. Générer un code boutique unique
    v_shop_code := 'SHP-' || upper(substring(md5(random()::text) from 1 for 6));
    v_velmo_shop_id := 'VSH-' || upper(substring(md5(random()::text) from 1 for 8));

    -- 3. Créer la boutique
    INSERT INTO shops (
        velmo_id,
        owner_id,
        name,
        category,
        shop_code,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        v_velmo_shop_id,
        p_user_id,
        p_shop_name,
        p_shop_category,
        v_shop_code,
        true,
        now(),
        now()
    ) RETURNING * INTO v_shop;

    v_shop_id := v_shop.id;

    -- 4. Mettre à jour l'utilisateur avec le shop_id
    UPDATE users 
    SET 
        first_name = p_first_name,
        last_name = p_last_name,
        pin_hash = p_pin_hash,
        velmo_id = p_velmo_id,
        shop_id = v_shop_id,
        role = 'owner',
        onboarding_completed = true,
        updated_at = now()
    WHERE id = p_user_id
    RETURNING * INTO v_user;

    -- 5. Construire la réponse
    v_result := jsonb_build_object(
        'success', true,
        'user', to_jsonb(v_user),
        'shop', to_jsonb(v_shop)
    );

    RETURN v_result;

EXCEPTION WHEN OTHERS THEN
    -- En cas d'erreur, on retourne un objet d'erreur
    RETURN jsonb_build_object(
        'success', false,
        'message', SQLERRM
    );
END;
$$;

-- ================================================================
-- GRANT PERMISSIONS
-- ================================================================

-- Permettre à tous les utilisateurs authentifiés d'appeler cette fonction
GRANT EXECUTE ON FUNCTION create_account_no_auth(uuid, text, text, text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION create_account_no_auth(uuid, text, text, text, text, text, text, text) TO anon;
