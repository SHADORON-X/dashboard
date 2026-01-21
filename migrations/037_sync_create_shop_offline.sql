-- Migration 37: RPC for Offline Sync (Shop Creation with ID)
-- 
-- Reason: OfflineSyncService creates shops locally with a UUID.
-- Direct INSERT into 'shops' is blocked by RLS for anon user (or unauthenticated context).
-- We need to allow creation of shops with explicit IDs and Owners that matches the offline created data.

CREATE OR REPLACE FUNCTION sync_create_shop_offline(
    p_id uuid,
    p_velmo_id text,
    p_name text,
    p_category text,
    p_owner_id uuid,
    p_shop_code text,
    p_created_at timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_shop shops%ROWTYPE;
BEGIN
    -- 1. Insert Shop with EXPLICIT ID
    INSERT INTO shops (
        id,
        velmo_id,
        name,
        category,
        owner_id,
        shop_code,
        is_active,
        created_offline,
        created_at,
        updated_at
    ) VALUES (
        p_id,
        p_velmo_id,
        p_name,
        p_category,
        p_owner_id,
        p_shop_code,
        true,
        true,
        p_created_at,
        now()
    ) RETURNING * INTO v_shop;

    RETURN jsonb_build_object(
        'success', true,
        'shop', to_jsonb(v_shop)
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', SQLERRM,
        'code', SQLSTATE
    );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION sync_create_shop_offline TO anon;
GRANT EXECUTE ON FUNCTION sync_create_shop_offline TO authenticated;
GRANT EXECUTE ON FUNCTION sync_create_shop_offline TO service_role;
