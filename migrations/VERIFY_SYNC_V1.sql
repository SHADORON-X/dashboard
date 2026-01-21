-- ================================================================
-- VÉRIFICATION COMPLÈTE - SYNC V1 BULLETPROOF
-- Date: 2026-01-07
-- Objectif: Vérifier que toutes les corrections sont bien appliquées
-- ================================================================

\echo '🔍 VÉRIFICATION SYNC V1 BULLETPROOF'
\echo ''

-- ================================================================
-- 1️⃣ VÉRIFIER LES FONCTIONS RPC
-- ================================================================
\echo '📦 1. Vérification des fonctions RPC...'
SELECT 
    routine_name,
    CASE 
        WHEN routine_name = 'sync_push_product' THEN '✅ Products (avec stock concurrent)'
        WHEN routine_name = 'sync_push_sale' THEN '✅ Sales (atomique)'
        WHEN routine_name = 'sync_push_sale_item' THEN '✅ Sale Items (auto-heal)'
        WHEN routine_name = 'sync_push_debt' THEN '✅ Debts (complet)'
        WHEN routine_name = 'sync_push_debt_payment' THEN '✅ Debt Payments (complet)'
        WHEN routine_name = 'sync_push_record' THEN '✅ Wrapper générique'
        WHEN routine_name = 'sync_pull_table' THEN '✅ Pull avec epoch'
        ELSE '❓ Autre'
    END as description
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE 'sync_%'
ORDER BY routine_name;

\echo ''

-- ================================================================
-- 2️⃣ VÉRIFIER LA COLONNE photo_url
-- ================================================================
\echo '📸 2. Vérification colonne photo_url...'
SELECT 
    column_name,
    data_type,
    CASE 
        WHEN column_name = 'photo_url' THEN '✅ Correct'
        WHEN column_name = 'photo' THEN '❌ Ancienne colonne (devrait être photo_url)'
        ELSE '❓'
    END as status
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'products'
AND column_name IN ('photo', 'photo_url');

\echo ''

-- ================================================================
-- 3️⃣ VÉRIFIER LES PERMISSIONS
-- ================================================================
\echo '🔐 3. Vérification des permissions...'
SELECT 
    routine_name,
    COUNT(DISTINCT grantee) as nb_grantees,
    CASE 
        WHEN COUNT(DISTINCT grantee) >= 2 THEN '✅ OK (authenticated + service_role)'
        ELSE '⚠️ Permissions incomplètes'
    END as status
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'
AND routine_name IN (
    'sync_push_product',
    'sync_push_sale',
    'sync_push_sale_item',
    'sync_push_debt',
    'sync_push_debt_payment',
    'sync_push_record',
    'sync_pull_table'
)
AND grantee IN ('authenticated', 'service_role')
GROUP BY routine_name
ORDER BY routine_name;

\echo ''

-- ================================================================
-- 4️⃣ TEST FONCTIONNEL : Stock Concurrent
-- ================================================================
\echo '🧪 4. Test stock concurrent...'
DO $$
DECLARE
    v_test_product_id UUID := gen_random_uuid();
    v_test_user_id UUID;
    v_test_shop_id UUID;
    v_initial_quantity NUMERIC := 1000;
    v_final_quantity NUMERIC;
    v_result JSONB;
BEGIN
    -- Trouver un utilisateur de test
    SELECT id, shop_id INTO v_test_user_id, v_test_shop_id FROM users LIMIT 1;
    
    IF v_test_user_id IS NULL THEN
        RAISE NOTICE '⚠️ Aucun utilisateur trouvé. Créez un utilisateur pour tester.';
        RETURN;
    END IF;
    
    RAISE NOTICE '👤 Test avec user: % / shop: %', v_test_user_id, v_test_shop_id;
    
    -- Créer produit de test
    INSERT INTO products (id, shop_id, user_id, name, quantity, created_at, updated_at)
    VALUES (v_test_product_id, v_test_shop_id, v_test_user_id, 'TEST Stock Concurrent', v_initial_quantity, NOW(), NOW());
    
    RAISE NOTICE '📦 Produit créé avec quantity = %', v_initial_quantity;
    
    -- Test 1: Opération relative (vente de 5)
    v_result := sync_push_product(
        jsonb_build_object(
            'id', v_test_product_id,
            'shop_id', v_test_shop_id,
            'quantity_delta', -5
        ),
        v_test_user_id
    );
    
    SELECT quantity INTO v_final_quantity FROM products WHERE id = v_test_product_id;
    
    IF v_final_quantity = 995 THEN
        RAISE NOTICE '✅ Test 1 RÉUSSI: Opération relative (1000 - 5 = %)', v_final_quantity;
    ELSE
        RAISE NOTICE '❌ Test 1 ÉCHOUÉ: Attendu 995, obtenu %', v_final_quantity;
    END IF;
    
    -- Test 2: Opération absolue (inventaire manuel)
    v_result := sync_push_product(
        jsonb_build_object(
            'id', v_test_product_id,
            'shop_id', v_test_shop_id,
            'name', 'TEST Stock Concurrent',
            'quantity', 500
        ),
        v_test_user_id
    );
    
    SELECT quantity INTO v_final_quantity FROM products WHERE id = v_test_product_id;
    
    IF v_final_quantity = 500 THEN
        RAISE NOTICE '✅ Test 2 RÉUSSI: Opération absolue (quantity = %)', v_final_quantity;
    ELSE
        RAISE NOTICE '❌ Test 2 ÉCHOUÉ: Attendu 500, obtenu %', v_final_quantity;
    END IF;
    
    -- Nettoyage
    DELETE FROM products WHERE id = v_test_product_id;
    RAISE NOTICE '🧹 Produit de test supprimé';
    
END $$;

\echo ''

-- ================================================================
-- 5️⃣ TEST FONCTIONNEL : Server-Side Truth
-- ================================================================
\echo '⏰ 5. Test Server-Side Truth (updated_at)...'
DO $$
DECLARE
    v_test_product_id UUID := gen_random_uuid();
    v_test_user_id UUID;
    v_test_shop_id UUID;
    v_result JSONB;
    v_updated_at_1 TIMESTAMPTZ;
    v_updated_at_2 TIMESTAMPTZ;
BEGIN
    SELECT id, shop_id INTO v_test_user_id, v_test_shop_id FROM users LIMIT 1;
    
    IF v_test_user_id IS NULL THEN
        RAISE NOTICE '⚠️ Aucun utilisateur trouvé.';
        RETURN;
    END IF;
    
    -- Créer produit
    v_result := sync_push_product(
        jsonb_build_object(
            'id', v_test_product_id,
            'shop_id', v_test_shop_id,
            'name', 'TEST Server Truth',
            'quantity', 100
        ),
        v_test_user_id
    );
    
    v_updated_at_1 := (v_result->>'updated_at')::TIMESTAMPTZ;
    RAISE NOTICE '📅 Premier updated_at: %', v_updated_at_1;
    
    -- Attendre 1 seconde
    PERFORM pg_sleep(1);
    
    -- Modifier produit
    v_result := sync_push_product(
        jsonb_build_object(
            'id', v_test_product_id,
            'shop_id', v_test_shop_id,
            'name', 'TEST Server Truth MODIFIÉ',
            'quantity', 200
        ),
        v_test_user_id
    );
    
    v_updated_at_2 := (v_result->>'updated_at')::TIMESTAMPTZ;
    RAISE NOTICE '📅 Deuxième updated_at: %', v_updated_at_2;
    
    IF v_updated_at_2 > v_updated_at_1 THEN
        RAISE NOTICE '✅ Server-Side Truth FONCTIONNE: updated_at est mis à jour par le serveur';
    ELSE
        RAISE NOTICE '❌ Server-Side Truth ÉCHOUÉ: updated_at non mis à jour';
    END IF;
    
    -- Nettoyage
    DELETE FROM products WHERE id = v_test_product_id;
    
END $$;

\echo ''

-- ================================================================
-- 6️⃣ RÉSUMÉ FINAL
-- ================================================================
\echo '═══════════════════════════════════════════════════════════'
\echo '📊 RÉSUMÉ DE LA VÉRIFICATION'
\echo '═══════════════════════════════════════════════════════════'
\echo ''
\echo 'Vérifications effectuées:'
\echo '  ✅ Fonctions RPC créées'
\echo '  ✅ Colonne photo_url correcte'
\echo '  ✅ Permissions accordées'
\echo '  ✅ Stock concurrent testé'
\echo '  ✅ Server-Side Truth testé'
\echo ''
\echo 'Si tous les tests sont ✅, SYNC V1 est BULLETPROOF!'
\echo ''
\echo 'Prochaines étapes:'
\echo '  1. Tester sur mobile (créer produit, vente, dette)'
\echo '  2. Vérifier synchronisation multi-devices'
\echo '  3. Tester avec 20+ utilisateurs simultanés'
\echo ''
\echo '═══════════════════════════════════════════════════════════'
