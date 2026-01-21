-- ================================================================
-- MIGRATION 082: FIX CUSTOMER_NAME NOT NULL
-- Date: 2025-01-XX
-- Objectif: Sécuriser les colonnes customer_name dans sales et debts
--           avec contraintes NOT NULL et valeurs par défaut
-- ================================================================

BEGIN;

-- ================================================================
-- 1️⃣ FIX SALES TABLE - customer_name NOT NULL
-- ================================================================

-- Mettre à jour les enregistrements existants avec NULL ou vide
UPDATE sales 
SET customer_name = 'Client Inconnu' 
WHERE customer_name IS NULL OR customer_name = '';

-- Ajouter valeur par défaut et contrainte NOT NULL
ALTER TABLE sales 
    ALTER COLUMN customer_name SET DEFAULT 'Client Inconnu',
    ALTER COLUMN customer_name SET NOT NULL;

-- ================================================================
-- 2️⃣ FIX DEBTS TABLE - customer_name DEFAULT
-- ================================================================

-- Mettre à jour les enregistrements existants avec NULL ou vide
UPDATE debts 
SET customer_name = 'Client Inconnu' 
WHERE customer_name IS NULL OR customer_name = '';

-- Ajouter valeur par défaut (NOT NULL existe déjà)
ALTER TABLE debts 
    ALTER COLUMN customer_name SET DEFAULT 'Client Inconnu';

-- ================================================================
-- 3️⃣ VERIFICATION
-- ================================================================
DO $$
DECLARE
    v_sales_null_count INTEGER;
    v_debts_null_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_sales_null_count FROM sales WHERE customer_name IS NULL;
    SELECT COUNT(*) INTO v_debts_null_count FROM debts WHERE customer_name IS NULL;
    
    IF v_sales_null_count > 0 OR v_debts_null_count > 0 THEN
        RAISE EXCEPTION 'Migration failed: Found NULL customer_name values (sales: %, debts: %)', 
            v_sales_null_count, v_debts_null_count;
    END IF;
    
    RAISE NOTICE '✅ Migration 082 terminée avec succès!';
    RAISE NOTICE '   - sales.customer_name: NOT NULL + DEFAULT';
    RAISE NOTICE '   - debts.customer_name: DEFAULT ajouté';
    RAISE NOTICE '   - Aucun NULL détecté';
END $$;

COMMIT;
