-- ================================================================
-- SCRIPT DE TEST : VALIDATION SYNCHRONISATION V1
-- Date: 2026-01-07
-- Objectif: Vérifier que toutes les corrections sont appliquées
-- ================================================================

-- ================================================================
-- 1️⃣ VÉRIFIER LES FONCTIONS RPC
-- ================================================================

\echo '🔍 Vérification des fonctions RPC...'

SELECT 
    routine_name,
    routine_type,
    CASE 
        WHEN routine_name = 'sync_push_product' THEN '✅'
        WHEN routine_name = 'sync_push_sale' THEN '✅'
        WHEN routine_name = 'sync_push_sale_item' THEN '✅'
        WHEN routine_name = 'sync_push_debt' THEN '🆕'
        WHEN routine_name = 'sync_push_debt_payment' THEN '🆕'
        WHEN routine_name = 'sync_push_record' THEN '🔄'
        ELSE '❓'
    END as status
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE 'sync_push%'
ORDER BY routine_name;

\echo ''
\echo '📊 Résultat attendu:'
\echo '   ✅ sync_push_product'
\echo '   ✅ sync_push_sale'
\echo '   ✅ sync_push_sale_item'
\echo '   🆕 sync_push_debt (NOUVEAU)'
\echo '   🆕 sync_push_debt_payment (NOUVEAU)'
\echo '   🔄 sync_push_record (MIS À JOUR)'
\echo ''

-- ================================================================
-- 2️⃣ VÉRIFIER LA COLONNE photo_url
-- ================================================================

\echo '🔍 Vérification de la colonne photo_url dans products...'

SELECT 
    column_name,
    data_type,
    is_nullable,
    CASE 
        WHEN column_name = 'photo_url' THEN '✅ OK'
        WHEN column_name = 'photo' THEN '❌ ANCIENNE COLONNE'
        ELSE '❓'
    END as status
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'products'
AND column_name IN ('photo', 'photo_url');

\echo ''
\echo '📊 Résultat attendu:'
\echo '   ✅ photo_url | text | YES'
\echo '   (photo ne devrait PAS apparaître)'
\echo ''

-- ================================================================
-- 3️⃣ VÉRIFIER LES PERMISSIONS
-- ================================================================

\echo '🔍 Vérification des permissions RPC...'

SELECT 
    routine_name,
    grantee,
    privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'
AND routine_name IN (
    'sync_push_product',
    'sync_push_sale',
    'sync_push_sale_item',
    'sync_push_debt',
    'sync_push_debt_payment',
    'sync_push_record'
)
AND grantee IN ('authenticated', 'service_role')
ORDER BY routine_name, grantee;

\echo ''
\echo '📊 Résultat attendu:'
\echo '   Chaque fonction devrait avoir EXECUTE pour authenticated ET service_role'
\echo ''

-- ================================================================
-- 4️⃣ TEST FONCTIONNEL : Insérer un produit avec photo
-- ================================================================

\echo '🧪 Test fonctionnel : Insertion produit avec photo...'

-- Créer un utilisateur de test (si n'existe pas)
DO $$
DECLARE
    v_user_id UUID;
    v_shop_id UUID;
    v_product_id UUID := gen_random_uuid();
    v_result JSONB;
BEGIN
    -- Trouver un utilisateur existant
    SELECT id, shop_id INTO v_user_id, v_shop_id FROM users LIMIT 1;
    
    IF v_user_id IS NULL THEN
        RAISE NOTICE '⚠️ Aucun utilisateur trouvé. Créez un utilisateur d''abord.';
        RETURN;
    END IF;
    
    RAISE NOTICE '👤 Utilisateur de test: %', v_user_id;
    RAISE NOTICE '🏪 Boutique de test: %', v_shop_id;
    
    -- Tester sync_push_product avec photo_url
    v_result := sync_push_product(
        jsonb_build_object(
            'id', v_product_id,
            'velmo_id', 'TEST-PROD-' || EXTRACT(EPOCH FROM NOW())::TEXT,
            'shop_id', v_shop_id,
            'name', 'Produit Test Sync',
            'price_sale', 1000,
            'price_buy', 500,
            'quantity', 10,
            'photo_url', 'https://example.com/test.jpg',
            'category', 'Test',
            'is_active', true
        ),
        v_user_id
    );
    
    IF v_result ? 'error' THEN
        RAISE NOTICE '❌ ERREUR lors du test: %', v_result->>'error';
    ELSE
        RAISE NOTICE '✅ Produit créé avec succès!';
        RAISE NOTICE '   ID: %', v_product_id;
        RAISE NOTICE '   Photo URL: %', v_result->>'photo_url';
        
        -- Vérifier que photo_url est bien enregistré
        IF v_result->>'photo_url' = 'https://example.com/test.jpg' THEN
            RAISE NOTICE '✅ Photo URL correctement enregistrée!';
        ELSE
            RAISE NOTICE '❌ Photo URL incorrecte: %', v_result->>'photo_url';
        END IF;
        
        -- Nettoyer
        DELETE FROM products WHERE id = v_product_id;
        RAISE NOTICE '🧹 Produit de test supprimé';
    END IF;
END $$;

\echo ''

-- ================================================================
-- 5️⃣ TEST FONCTIONNEL : Insérer une dette
-- ================================================================

\echo '🧪 Test fonctionnel : Insertion dette...'

DO $$
DECLARE
    v_user_id UUID;
    v_shop_id UUID;
    v_debt_id UUID := gen_random_uuid();
    v_result JSONB;
BEGIN
    -- Trouver un utilisateur existant
    SELECT id, shop_id INTO v_user_id, v_shop_id FROM users LIMIT 1;
    
    IF v_user_id IS NULL THEN
        RAISE NOTICE '⚠️ Aucun utilisateur trouvé. Créez un utilisateur d''abord.';
        RETURN;
    END IF;
    
    -- Tester sync_push_debt
    v_result := sync_push_debt(
        jsonb_build_object(
            'id', v_debt_id,
            'velmo_id', 'TEST-DEBT-' || EXTRACT(EPOCH FROM NOW())::TEXT,
            'shop_id', v_shop_id,
            'customer_name', 'Client Test',
            'customer_phone', '+224600000000',
            'total_amount', 50000,
            'paid_amount', 0,
            'remaining_amount', 50000,
            'status', 'pending',
            'type', 'credit',
            'products_json', '[]'::JSONB
        ),
        v_user_id
    );
    
    IF v_result ? 'error' THEN
        RAISE NOTICE '❌ ERREUR lors du test: %', v_result->>'error';
    ELSE
        RAISE NOTICE '✅ Dette créée avec succès!';
        RAISE NOTICE '   ID: %', v_debt_id;
        RAISE NOTICE '   Client: %', v_result->>'customer_name';
        RAISE NOTICE '   Montant: %', v_result->>'total_amount';
        
        -- Nettoyer
        DELETE FROM debts WHERE id = v_debt_id;
        RAISE NOTICE '🧹 Dette de test supprimée';
    END IF;
END $$;

\echo ''

-- ================================================================
-- 6️⃣ RÉSUMÉ FINAL
-- ================================================================

\echo '═══════════════════════════════════════════════════════════'
\echo '📊 RÉSUMÉ DE LA VALIDATION'
\echo '═══════════════════════════════════════════════════════════'
\echo ''
\echo 'Si tous les tests sont ✅, la synchronisation V1 est prête!'
\echo ''
\echo 'Prochaines étapes:'
\echo '  1. Tester sur mobile (créer produit, vente, dette)'
\echo '  2. Cliquer sur "Sync"'
\echo '  3. Vérifier dans Supabase que les données sont présentes'
\echo '  4. Tester sur Desktop (pull des données)'
\echo ''
\echo '═══════════════════════════════════════════════════════════'
