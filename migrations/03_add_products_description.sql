-- ================================================================
-- 🔧 AJOUT COLONNE DESCRIPTION À PRODUCTS
-- ================================================================
-- Date: 24 Décembre 2025
-- Objectif: Ajouter la colonne description manquante
-- ================================================================

BEGIN;

-- Ajouter la colonne description à products
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS description TEXT;

-- Créer un index pour la recherche
CREATE INDEX IF NOT EXISTS idx_products_description ON products USING gin(to_tsvector('french', description))
WHERE description IS NOT NULL;

COMMIT;

-- ================================================================
-- ✅ COLONNE DESCRIPTION AJOUTÉE
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Colonne description ajoutée à products !';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔄 La synchronisation des produits devrait maintenant fonctionner';
    RAISE NOTICE '========================================';
END $$;
