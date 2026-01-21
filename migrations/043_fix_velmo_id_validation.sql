-- ================================================================
-- 🔧 MIGRATION 043: Correction Validation Velmo ID
-- ================================================================
-- Date: 31 Décembre 2025
-- Objectif: Harmoniser la validation Velmo ID entre SQL et code
-- Format accepté: VLM-[A-Z0-9-]{4,} (flexible)
-- ================================================================

-- ================================================================
-- 1. TABLE USERS - Correction contrainte Velmo ID
-- ================================================================

-- Supprimer l'ancienne contrainte stricte
ALTER TABLE users DROP CONSTRAINT IF EXISTS velmo_id_format;

-- Ajouter la nouvelle contrainte flexible
-- Accepte: VLM-DM-506, VLM-ABC-123, VLM-A1B2C3, etc.
ALTER TABLE users ADD CONSTRAINT velmo_id_format 
  CHECK (velmo_id ~ '^VLM-[A-Z0-9-]{4,}$');

-- ================================================================
-- 2. TABLE SHOPS - Correction contrainte Velmo ID
-- ================================================================

-- Supprimer l'ancienne contrainte (si elle existe)
ALTER TABLE shops DROP CONSTRAINT IF EXISTS shops_velmo_id_format;

-- Ajouter la nouvelle contrainte flexible
ALTER TABLE shops ADD CONSTRAINT shops_velmo_id_format 
  CHECK (velmo_id ~ '^VLM-[A-Z0-9-]{4,}$');

-- ================================================================
-- 3. TABLE PRODUCTS - Vérifier contrainte Velmo ID
-- ================================================================

-- Supprimer l'ancienne contrainte (si elle existe)
ALTER TABLE products DROP CONSTRAINT IF EXISTS products_velmo_id_format;

-- Ajouter la nouvelle contrainte flexible
ALTER TABLE products ADD CONSTRAINT products_velmo_id_format 
  CHECK (velmo_id ~ '^VLM-[A-Z0-9-]{4,}$');

-- ================================================================
-- 4. TABLE SALES - Vérifier contrainte Velmo ID
-- ================================================================

-- Supprimer l'ancienne contrainte (si elle existe)
ALTER TABLE sales DROP CONSTRAINT IF EXISTS sales_velmo_id_format;

-- Ajouter la nouvelle contrainte flexible
ALTER TABLE sales ADD CONSTRAINT sales_velmo_id_format 
  CHECK (velmo_id ~ '^VLM-[A-Z0-9-]{4,}$');

-- ================================================================
-- 5. TABLE DEBTS - Vérifier contrainte Velmo ID
-- ================================================================

-- Supprimer l'ancienne contrainte (si elle existe)
ALTER TABLE debts DROP CONSTRAINT IF EXISTS debts_velmo_id_format;

-- Ajouter la nouvelle contrainte flexible
ALTER TABLE debts ADD CONSTRAINT debts_velmo_id_format 
  CHECK (velmo_id ~ '^VLM-[A-Z0-9-]{4,}$');

-- ================================================================
-- 6. VÉRIFICATION
-- ================================================================

-- Tester que les formats suivants sont acceptés:
DO $$
BEGIN
    -- Test 1: Format classique (VLM-XX-XXX)
    ASSERT 'VLM-DM-506' ~ '^VLM-[A-Z0-9-]{4,}$', 'Format VLM-DM-506 doit être accepté';
    
    -- Test 2: Format alphanumérique (VLM-ABC123)
    ASSERT 'VLM-ABC123' ~ '^VLM-[A-Z0-9-]{4,}$', 'Format VLM-ABC123 doit être accepté';
    
    -- Test 3: Format avec tirets (VLM-A1-B2-C3)
    ASSERT 'VLM-A1-B2-C3' ~ '^VLM-[A-Z0-9-]{4,}$', 'Format VLM-A1-B2-C3 doit être accepté';
    
    -- Test 4: Format court (VLM-ABCD)
    ASSERT 'VLM-ABCD' ~ '^VLM-[A-Z0-9-]{4,}$', 'Format VLM-ABCD doit être accepté';
    
    RAISE NOTICE '✅ Tous les tests de validation Velmo ID ont réussi';
END $$;

-- ================================================================
-- 7. INDEX (vérifier qu'ils existent toujours)
-- ================================================================

-- Recréer les index si nécessaire
CREATE INDEX IF NOT EXISTS idx_users_velmo_id ON users(velmo_id);
CREATE INDEX IF NOT EXISTS idx_shops_velmo_id ON shops(velmo_id);
CREATE INDEX IF NOT EXISTS idx_products_velmo_id ON products(velmo_id);
CREATE INDEX IF NOT EXISTS idx_sales_velmo_id ON sales(velmo_id);
CREATE INDEX IF NOT EXISTS idx_debts_velmo_id ON debts(velmo_id);

-- ================================================================
-- CONFIRMATION
-- ================================================================

SELECT '✅ Migration 043 : Validation Velmo ID flexible appliquée avec succès' as status;
