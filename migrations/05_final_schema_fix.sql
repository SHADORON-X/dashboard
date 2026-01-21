-- ================================================================
-- 🔧 CORRECTION FINALE SCHEMA - ALIGNEMENT APP
-- ================================================================
-- Date: 24 Décembre 2025
-- Objectif: Aligner le schéma Supabase avec ce que l'app envoie réellement
-- ================================================================

BEGIN;

-- 1. PRODUCTS
-- Renommer photo -> photo_url
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'photo') THEN
        ALTER TABLE products RENAME COLUMN photo TO photo_url;
    END IF;
END $$;

-- Ajouter photo_url si elle n'existe pas
ALTER TABLE products ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- Ajouter description (manquante dans schema.ts mais envoyée par l'app)
ALTER TABLE products ADD COLUMN IF NOT EXISTS description TEXT;

-- 2. SHOPS
-- Vérifier logo -> logo_url ? (A vérifier, mais gardons logo pour l'instant)
-- L'app envoie: logo, logo_icon, logo_color. C'est OK.

-- 3. SALES
-- L'app envoie: payment_type, customer_name, etc. C'est OK.

-- 4. DEBTS
-- L'app envoie: debtor_id, etc. C'est OK.

COMMIT;

-- ================================================================
-- ✅ SCHEMA ALIGNÉ
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Schema products corrigé (photo_url, description)';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔄 La synchronisation devrait fonctionner maintenant';
    RAISE NOTICE '========================================';
END $$;
