-- ================================================================
-- 🔥 MIGRATION 25: NETTOYAGE ARCHITECTURE SQL
-- ================================================================
-- Date: 26 Décembre 2025
-- Objectif: Éliminer toutes les incohérences et duplications
-- 
-- ACTIONS:
-- 1. Supprimer table vtlbes_cy (doublon de users)
-- 2. Migrer données vtlbes_cy → users (si nécessaire)
-- 3. Corriger tous les types UUID/TEXT
-- 4. Recréer Foreign Keys proprement
-- 5. Nettoyer RPC functions contradictoires
-- ================================================================

BEGIN;

-- ================================================================
-- ÉTAPE 1: BACKUP DES DONNÉES (Sécurité)
-- ================================================================

-- Créer une table de backup temporaire si vtlbes_cy existe
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vtlbes_cy') THEN
        -- Backup vtlbes_cy
        CREATE TABLE IF NOT EXISTS vtlbes_cy_backup_20251226 AS 
        SELECT * FROM vtlbes_cy;
        
        RAISE NOTICE '✅ Backup créé: vtlbes_cy_backup_20251226';
    END IF;
END $$;

-- ================================================================
-- ÉTAPE 2: MIGRER DONNÉES vtlbes_cy → users (Si nécessaire)
-- ================================================================

DO $$
DECLARE
    v_count INTEGER;
BEGIN
    -- Vérifier si vtlbes_cy existe
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vtlbes_cy') THEN
        
        -- Compter les utilisateurs dans vtlbes_cy qui ne sont pas dans users
        SELECT COUNT(*) INTO v_count
        FROM vtlbes_cy v
        WHERE NOT EXISTS (
            SELECT 1 FROM users u 
            WHERE u.velmo_id = v.velmo_id
        );
        
        RAISE NOTICE 'Utilisateurs à migrer: %', v_count;
        
        -- Migrer les utilisateurs manquants
        IF v_count > 0 THEN
            INSERT INTO users (
                id,
                velmo_id,
                phone,
                email,
                first_name,
                last_name,
                role,
                shop_id,
                pin_hash,
                is_active,
                onboarding_completed,
                auth_mode,
                last_login_at,
                sync_status,
                synced_at,
                created_offline,
                created_at,
                updated_at
            )
            SELECT 
                v.id,
                v.velmo_id,
                v.phone,
                v.email,
                v.first_name,
                v.last_name,
                CASE 
                    WHEN v.role = 'owner' THEN 'owner'::user_role
                    WHEN v.role = 'employee' THEN 'cashier'::user_role
                    ELSE 'owner'::user_role
                END,
                v.shop_id,
                v.pin_hash,
                v.is_active,
                v.onboarding_completed,
                CASE 
                    WHEN v.auth_mode = 'online' THEN 'online'::auth_mode
                    WHEN v.auth_mode = 'offline' THEN 'offline'::auth_mode
                    ELSE 'offline'::auth_mode
                END,
                v.last_login_at,
                CASE 
                    WHEN v.sync_status = 'pending' THEN 'pending'::sync_status
                    WHEN v.sync_status = 'synced' THEN 'synced'::sync_status
                    WHEN v.sync_status = 'failed' THEN 'failed'::sync_status
                    ELSE 'pending'::sync_status
                END,
                v.synced_at,
                COALESCE(v.created_offline, false),
                v.created_at,
                v.updated_at
            FROM vtlbes_cy v
            WHERE NOT EXISTS (
                SELECT 1 FROM users u 
                WHERE u.velmo_id = v.velmo_id
            )
            ON CONFLICT (velmo_id) DO NOTHING;
            
            RAISE NOTICE '✅ Migration terminée: % utilisateurs migrés', v_count;
        END IF;
    END IF;
END $$;

-- ================================================================
-- ÉTAPE 3: SUPPRIMER TABLE vtlbes_cy ET SES DÉPENDANCES
-- ================================================================

-- Supprimer les RPC functions liées à vtlbes_cy
DROP FUNCTION IF EXISTS create_user_vtl(text, text, text, text, text, text, text) CASCADE;
DROP FUNCTION IF EXISTS login_user_vtl(text, text) CASCADE;
DROP FUNCTION IF EXISTS get_user_vtl(uuid) CASCADE;

-- Supprimer la table vtlbes_cy
DROP TABLE IF EXISTS vtlbes_cy CASCADE;

DO $$
BEGIN
    RAISE NOTICE '✅ Table vtlbes_cy supprimée';
END $$;

-- ================================================================
-- ÉTAPE 4: CORRIGER LES TYPES UUID/TEXT
-- ================================================================

-- Vérifier et corriger les types de colonnes
DO $$
BEGIN
    -- users.id doit être UUID
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'id' 
        AND data_type != 'uuid'
    ) THEN
        -- Convertir en UUID si nécessaire
        ALTER TABLE users ALTER COLUMN id TYPE UUID USING id::UUID;
        RAISE NOTICE '✅ users.id converti en UUID';
    END IF;
    
    -- shops.owner_id doit être UUID
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'shops' 
        AND column_name = 'owner_id' 
        AND data_type != 'uuid'
    ) THEN
        ALTER TABLE shops ALTER COLUMN owner_id TYPE UUID USING owner_id::UUID;
        RAISE NOTICE '✅ shops.owner_id converti en UUID';
    END IF;
    
    -- products.user_id doit être UUID
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' 
        AND column_name = 'user_id' 
        AND data_type != 'uuid'
    ) THEN
        ALTER TABLE products ALTER COLUMN user_id TYPE UUID USING user_id::UUID;
        RAISE NOTICE '✅ products.user_id converti en UUID';
    END IF;
END $$;

-- ================================================================
-- ÉTAPE 5: RECRÉER FOREIGN KEYS PROPREMENT
-- ================================================================

-- Supprimer toutes les FK conflictuelles
ALTER TABLE shops DROP CONSTRAINT IF EXISTS shops_owner_id_fkey CASCADE;
ALTER TABLE products DROP CONSTRAINT IF EXISTS products_user_id_fkey CASCADE;
ALTER TABLE sales DROP CONSTRAINT IF EXISTS sales_user_id_fkey CASCADE;
ALTER TABLE sale_items DROP CONSTRAINT IF EXISTS sale_items_user_id_fkey CASCADE;
ALTER TABLE cart_items DROP CONSTRAINT IF EXISTS cart_items_user_id_fkey CASCADE;
ALTER TABLE debts DROP CONSTRAINT IF EXISTS debts_user_id_fkey CASCADE;
ALTER TABLE debts DROP CONSTRAINT IF EXISTS debts_debtor_id_fkey CASCADE;
ALTER TABLE debt_payments DROP CONSTRAINT IF EXISTS debt_payments_user_id_fkey CASCADE;
ALTER TABLE shop_members DROP CONSTRAINT IF EXISTS shop_members_user_id_fkey CASCADE;

-- Recréer les FK vers users (UUID)
ALTER TABLE shops
ADD CONSTRAINT shops_owner_id_fkey 
FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE products
ADD CONSTRAINT products_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE sales
ADD CONSTRAINT sales_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE sale_items
ADD CONSTRAINT sale_items_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE cart_items
ADD CONSTRAINT cart_items_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE debts
ADD CONSTRAINT debts_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE debts
ADD CONSTRAINT debts_debtor_id_fkey 
FOREIGN KEY (debtor_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE debt_payments
ADD CONSTRAINT debt_payments_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE shop_members
ADD CONSTRAINT shop_members_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

DO $$
BEGIN
    RAISE NOTICE '✅ Foreign Keys recréées proprement';
END $$;

-- ================================================================
-- ÉTAPE 6: CRÉER RPC create_user_vtl UNIFIÉE (Utilise users)
-- ================================================================

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
    v_user users%ROWTYPE;
    v_shop shops%ROWTYPE;
    v_result jsonb;
BEGIN
    -- Générer un ID utilisateur
    v_user_id := gen_random_uuid();

    -- 1. Créer l'utilisateur dans users (pas vtlbes_cy)
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
        v_user_id,
        p_velmo_id,
        NULLIF(p_phone, ''),
        p_first_name,
        p_last_name,
        crypt(p_pin_hash, gen_salt('bf')), -- ✅ Hachage sécurisé
        'online'::auth_mode,
        'owner'::user_role,
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
        owner_id, -- ✅ Lien vers users.id (UUID)
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
    UPDATE users 
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

-- ================================================================
-- ÉTAPE 7: CRÉER RPC login_user_vtl UNIFIÉE (Utilise users)
-- ================================================================

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
BEGIN
    -- Trouver l'utilisateur dans users (pas vtlbes_cy)
    SELECT * INTO v_user 
    FROM users 
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
    UPDATE users SET last_login_at = now() WHERE id = v_user.id;

    -- Récupérer la boutique
    SELECT * INTO v_shop FROM shops WHERE id = v_user.shop_id;

    RETURN jsonb_build_object(
        'success', true,
        'user', to_jsonb(v_user),
        'shop', to_jsonb(v_shop)
    );
END;
$$;

-- ================================================================
-- ÉTAPE 8: CRÉER RPC get_user_vtl UNIFIÉE (Utilise users)
-- ================================================================

CREATE OR REPLACE FUNCTION get_user_vtl(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user users%ROWTYPE;
BEGIN
    SELECT * INTO v_user FROM users WHERE id = p_user_id;
    
    IF v_user.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'User not found');
    END IF;

    RETURN jsonb_build_object('success', true, 'user', to_jsonb(v_user));
END;
$$;

-- ================================================================
-- ÉTAPE 9: PERMISSIONS
-- ================================================================

GRANT EXECUTE ON FUNCTION create_user_vtl TO anon;
GRANT EXECUTE ON FUNCTION create_user_vtl TO authenticated;
GRANT EXECUTE ON FUNCTION create_user_vtl TO service_role;

GRANT EXECUTE ON FUNCTION login_user_vtl TO anon;
GRANT EXECUTE ON FUNCTION login_user_vtl TO authenticated;
GRANT EXECUTE ON FUNCTION login_user_vtl TO service_role;

GRANT EXECUTE ON FUNCTION get_user_vtl TO anon;
GRANT EXECUTE ON FUNCTION get_user_vtl TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_vtl TO service_role;

-- ================================================================
-- ÉTAPE 10: VÉRIFICATIONS FINALES
-- ================================================================

DO $$
DECLARE
    v_users_count INTEGER;
    v_shops_count INTEGER;
    v_fk_count INTEGER;
BEGIN
    -- Compter les utilisateurs
    SELECT COUNT(*) INTO v_users_count FROM users;
    
    -- Compter les boutiques
    SELECT COUNT(*) INTO v_shops_count FROM shops;
    
    -- Compter les FK
    SELECT COUNT(*) INTO v_fk_count
    FROM information_schema.table_constraints
    WHERE constraint_type = 'FOREIGN KEY'
    AND table_name IN ('shops', 'products', 'sales', 'debts');
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ NETTOYAGE TERMINÉ AVEC SUCCÈS !';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📊 Utilisateurs: %', v_users_count;
    RAISE NOTICE '🏪 Boutiques: %', v_shops_count;
    RAISE NOTICE '🔗 Foreign Keys: %', v_fk_count;
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Table vtlbes_cy supprimée';
    RAISE NOTICE '✅ Données migrées vers users';
    RAISE NOTICE '✅ Types UUID corrigés';
    RAISE NOTICE '✅ Foreign Keys recréées';
    RAISE NOTICE '✅ RPC functions unifiées';
    RAISE NOTICE '========================================';
END $$;

COMMIT;

-- ================================================================
-- ✅ MIGRATION 25 TERMINÉE
-- ================================================================
