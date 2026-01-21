-- ================================================================
-- 🔧 CORRECTION COLONNES PRODUCTS
-- ================================================================
-- Date: 24 Décembre 2025
-- Objectif: Renommer photo -> photo_url pour alignement avec l'app
-- ================================================================

BEGIN;

-- Renommer photo en photo_url si elle existe
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'photo') THEN
        ALTER TABLE products RENAME COLUMN photo TO photo_url;
    END IF;
END $$;

-- Ajouter photo_url si elle n'existe pas (cas où photo n'existait pas)
ALTER TABLE products ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- Vérifier si description existe, sinon l'ajouter
ALTER TABLE products ADD COLUMN IF NOT EXISTS description TEXT;

COMMIT;

-- ================================================================
-- ✅ COLONNES CORRIGÉES
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Colonne photo renommée en photo_url !';
    RAISE NOTICE '✅ Colonne description vérifiée !';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔄 La synchronisation devrait maintenant fonctionner';
    RAISE NOTICE '========================================';
END $$;
