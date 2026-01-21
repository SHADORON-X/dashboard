-- ================================================================
-- MIGRATION: Fix JoinShop - CREATE RPC FOR EMPLOYEE CREATION
-- Date: 2026-01-03
-- Description: Créer RPC complète pour rejoindre une boutique
--              Bypass RLS sur users ET shops
-- ================================================================

-- ================================================================
-- 1️⃣ DROP OLD FUNCTION IF EXISTS
-- ================================================================
DROP FUNCTION IF EXISTS public.join_shop_as_employee CASCADE;

-- ================================================================
-- 2️⃣ CREATE COMPLETE RPC (SECURITY DEFINER)
-- ================================================================
CREATE OR REPLACE FUNCTION public.join_shop_as_employee(
    p_shop_id uuid,
    p_first_name text,
    p_last_name text,
    p_phone text,
    p_pin_hash text,
    p_velmo_id text,
    p_role text DEFAULT 'cashier'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_shop_exists boolean;
    v_new_user_id uuid;
    v_shop_name text;
    v_result jsonb;
BEGIN
    -- 1. Vérifier que la boutique existe et est active
    SELECT EXISTS(
        SELECT 1 FROM shops 
        WHERE id = p_shop_id 
        AND is_active = true
    ), name INTO v_shop_exists, v_shop_name
    FROM shops 
    WHERE id = p_shop_id;

    IF NOT v_shop_exists THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'shop_not_found',
            'message', 'Boutique introuvable ou inactive'
        );
    END IF;

    -- 2. Créer l'utilisateur employé
    INSERT INTO users (
        velmo_id,
        first_name,
        last_name,
        phone,
        role,
        pin_hash,
        auth_mode,
        phone_verified,
        onboarding_completed,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        p_velmo_id,
        p_first_name,
        p_last_name,
        p_phone,
        'seller', -- Rôle par défaut
        p_pin_hash,
        'online',
        true,
        true,
        true,
        NOW(),
        NOW()
    )
    RETURNING id INTO v_new_user_id;

    -- 3. Créer la demande de rejoindre (shop_request)
    INSERT INTO shop_requests (
        user_id,
        shop_id,
        requested_role,
        status,
        created_at,
        updated_at
    ) VALUES (
        v_new_user_id,
        p_shop_id,
        p_role,
        'pending',
        NOW(),
        NOW()
    );

    -- 4. Retourner le résultat
    RETURN jsonb_build_object(
        'success', true,
        'user', jsonb_build_object(
            'id', v_new_user_id,
            'velmo_id', p_velmo_id,
            'first_name', p_first_name,
            'last_name', p_last_name,
            'phone', p_phone,
            'role', 'seller'
        ),
        'shop', jsonb_build_object(
            'id', p_shop_id,
            'name', v_shop_name
        ),
        'message', 'Demande envoyée au propriétaire'
    );

EXCEPTION 
    WHEN unique_violation THEN
        -- Gérer les erreurs de duplication
        IF SQLERRM LIKE '%velmo_id%' THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'duplicate_velmo_id',
                'message', 'Ce Velmo ID existe déjà. Veuillez réessayer.'
            );
        ELSIF SQLERRM LIKE '%phone%' THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'duplicate_phone',
                'message', 'Ce numéro de téléphone est déjà utilisé.'
            );
        ELSE
            RETURN jsonb_build_object(
                'success', false,
                'error', 'duplicate_error',
                'message', 'Données en double détectées.'
            );
        END IF;
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'unknown_error',
            'message', SQLERRM
        );
END;
$$;

-- ================================================================
-- 3️⃣ GRANT PERMISSIONS (accessible sans auth)
-- ================================================================
GRANT EXECUTE ON FUNCTION public.join_shop_as_employee(uuid, text, text, text, text, text, text) TO authenticated, anon;

-- ================================================================
-- 4️⃣ TEST
-- ================================================================
-- SELECT * FROM join_shop_as_employee(
--     '667fad42-e96a-48a7-990d-59a15d4d3a93',
--     'Fode',
--     'Bah',
--     '211114111',
--     'MTIzNA==',
--     'VLM-FB-123',
--     'cashier'
-- );

-- ================================================================
-- ✅ DONE - Complete JoinShop RPC
-- ================================================================
