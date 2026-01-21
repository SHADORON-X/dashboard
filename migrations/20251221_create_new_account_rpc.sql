-- ================================================================
-- 🚀 RPC: CRÉATION DE COMPTE (User + Shop + Link)
-- ================================================================

DROP FUNCTION IF EXISTS create_new_account(text, text, text, text, text, text);

CREATE OR REPLACE FUNCTION create_new_account(
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
    v_user users%ROWTYPE;
    v_shop shops%ROWTYPE;
    v_result jsonb;
BEGIN
    -- 1. Récupérer l'ID de l'utilisateur authentifié
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- 2. Générer un code boutique unique
    v_shop_code := 'SHP-' || upper(substring(md5(random()::text) from 1 for 6));

    -- 3. Créer la boutique
    INSERT INTO shops (
        owner_id,
        name,
        category,
        shop_code,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        v_user_id,
        p_shop_name,
        p_shop_category,
        v_shop_code,
        true,
        now(),
        now()
    ) RETURNING id INTO v_shop_id;

    -- 4. Mettre à jour l'utilisateur
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
    WHERE id = v_user_id
    RETURNING * INTO v_user;

    -- 5. Récupérer la boutique créée
    SELECT * INTO v_shop FROM shops WHERE id = v_shop_id;

    -- 6. Construire la réponse
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
