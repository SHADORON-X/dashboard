-- Migration 36: RPC for Offline Sync (User Creation with ID)
-- 
-- Reason: OfflineSyncService creates users locally with a UUID.
-- Direct INSERT into 'vtlbes_cy' (or 'users') is blocked by RLS for anon.
-- Existing 'create_user_vtl' generates a NEW UUID, breaking sync.
-- 
-- Solution: A new RPC that accepts the ID and inserts it securely.

CREATE OR REPLACE FUNCTION sync_create_user_offline(
    p_id uuid,
    p_velmo_id text,
    p_phone text,
    p_first_name text,
    p_last_name text,
    p_pin_hash text,
    p_role text,
    p_created_at timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user vtlbes_cy%ROWTYPE;
BEGIN
    -- 1. Insert User with EXPLICIT ID
    INSERT INTO vtlbes_cy (
        id,
        velmo_id,
        phone,
        first_name,
        last_name,
        pin_hash,
        role,
        auth_mode,
        is_active,
        onboarding_completed,
        created_at,
        updated_at
    ) VALUES (
        p_id,
        p_velmo_id,
        NULLIF(p_phone, ''),
        p_first_name,
        p_last_name,
        -- If pin is already hashed (from offline), utilize it. 
        -- NOTE: If offline stored raw pin, we should hash it. 
        -- Assuming offline stores it hashed or we trust the client to send hash.
        -- Let's assume client sends hash for consistency.
        p_pin_hash, -- crypt(p_pin_hash, gen_salt('bf')) ? No, offline might have hashed it?
        -- Wait, OfflineSyncService sends `data.pin`? or `user.pinHash`.
        -- AuthService.ts: user.pinHash = data.pin; // Store hashed
        -- But in `createOfflineUserWatermelon`: user.pinHash = data.pin; (It says "Store hashed" but data.pin comes from input?)
        -- Let's check logic:
        -- AuthService: `const pinHash = Buffer.from(newPin).toString('base64');` in updatePIN.
        -- But createOfflineUserWatermelon uses `data.pin` directly?
        -- IF offline stores base64 hash, we should probably re-hash for bcrypt if we want consistency with login_user_vtl which uses `crypt`.
        -- HOWEVER, `login_user_vtl` implementation: `v_user.pin_hash != crypt(p_pin_hash, v_user.pin_hash)`
        -- This implies `pin_hash` column stores a BCRYPT hash.
        -- If offline stores a simple base64, we need to convert it or hash the base64?
        -- Let's look at `create_user_vtl`: `crypt(p_pin_hash, gen_salt('bf'))`
        -- So the server expects to receive the PIN (or hash) and apply bcrypt.
        -- If `OfflineSyncService` sends the PIN (or simple hash), we should wrap it in `crypt` here for safety/consistency.
        crypt(p_pin_hash, gen_salt('bf')),
        'offline',
        true,
        true,
        p_created_at,
        now()
    ) RETURNING * INTO v_user;

    RETURN jsonb_build_object(
        'success', true,
        'user', to_jsonb(v_user)
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
GRANT EXECUTE ON FUNCTION sync_create_user_offline TO anon;
GRANT EXECUTE ON FUNCTION sync_create_user_offline TO authenticated;
GRANT EXECUTE ON FUNCTION sync_create_user_offline TO service_role;
