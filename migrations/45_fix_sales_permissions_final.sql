-- ================================================================
-- 🔐 MIGRATION 45: FIX SALES PERMISSIONS (FINAL)
-- ================================================================
-- Date: 4 Janvier 2026
-- Objectif: Corriger les erreurs de permission RLS sur sales/sale_items
-- 
-- PROBLÈME IDENTIFIÉ:
-- - RLS enabled mais policies conflictuelles
-- - Utilisateur ne peut pas insérer/updater sales
-- - Erreur: "new row violates row-level security policy"
-- ================================================================

BEGIN;

-- ================================================================
-- 1️⃣ DÉSACTIVER RLS TEMPORAIREMENT POUR NETTOYER
-- ================================================================

ALTER TABLE sales DISABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items DISABLE ROW LEVEL SECURITY;

-- ================================================================
-- 2️⃣ SUPPRIMER TOUTES LES POLICIES EXISTANTES
-- ================================================================

DROP POLICY IF EXISTS "Users see sales from their shops" ON sales;
DROP POLICY IF EXISTS "Service role bypass" ON sales;
DROP POLICY IF EXISTS "Users insert sales for their shops" ON sales;
DROP POLICY IF EXISTS "Users update sales for their shops" ON sales;
DROP POLICY IF EXISTS "Users delete sales for their shops" ON sales;
DROP POLICY IF EXISTS "Users can insert sales for their shops" ON sales;
DROP POLICY IF EXISTS "Users can update sales for their shops" ON sales;
DROP POLICY IF EXISTS "Users see sales from their shops" ON sale_items;
DROP POLICY IF EXISTS "Service role bypass" ON sale_items;
DROP POLICY IF EXISTS "Users can insert sale_items for their shops" ON sale_items;
DROP POLICY IF EXISTS "Users can view sale_items for their shops" ON sale_items;

-- ================================================================
-- 3️⃣ RÉACTIVER RLS
-- ================================================================

ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;

-- ================================================================
-- 4️⃣ CRÉER LES POLICIES CORRECTES (SIMPLE ET FONCTIONNELLES)
-- ================================================================

-- 📌 SALES TABLE

-- Policy 1: Les utilisateurs peuvent voir les ventes de leurs boutiques
CREATE POLICY "sales_select_own_shops"
ON sales FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM shops s
    WHERE s.id = sales.shop_id
    AND (
      s.owner_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM shop_members sm
        WHERE sm.shop_id = s.id AND sm.user_id = auth.uid()
      )
    )
  )
);

-- Policy 2: Les utilisateurs peuvent créer des ventes dans leurs boutiques
CREATE POLICY "sales_insert_own_shops"
ON sales FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM shops s
    WHERE s.id = sales.shop_id
    AND (
      s.owner_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM shop_members sm
        WHERE sm.shop_id = s.id AND sm.user_id = auth.uid()
      )
    )
  )
);

-- Policy 3: Les utilisateurs peuvent modifier les ventes de leurs boutiques
CREATE POLICY "sales_update_own_shops"
ON sales FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM shops s
    WHERE s.id = sales.shop_id
    AND (
      s.owner_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM shop_members sm
        WHERE sm.shop_id = s.id AND sm.user_id = auth.uid()
      )
    )
  )
);

-- Policy 4: Les utilisateurs peuvent supprimer les ventes de leurs boutiques
CREATE POLICY "sales_delete_own_shops"
ON sales FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM shops s
    WHERE s.id = sales.shop_id
    AND (
      s.owner_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM shop_members sm
        WHERE sm.shop_id = s.id AND sm.user_id = auth.uid()
      )
    )
  )
);

-- 📌 SALE_ITEMS TABLE

-- Policy 1: Les utilisateurs peuvent voir les articles des ventes de leurs boutiques
CREATE POLICY "sale_items_select_own_shops"
ON sale_items FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM sales s
    INNER JOIN shops sh ON sh.id = s.shop_id
    WHERE s.id = sale_items.sale_id
    AND (
      sh.owner_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM shop_members sm
        WHERE sm.shop_id = sh.id AND sm.user_id = auth.uid()
      )
    )
  )
);

-- Policy 2: Les utilisateurs peuvent insérer des articles dans les ventes de leurs boutiques
CREATE POLICY "sale_items_insert_own_shops"
ON sale_items FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM sales s
    INNER JOIN shops sh ON sh.id = s.shop_id
    WHERE s.id = sale_items.sale_id
    AND (
      sh.owner_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM shop_members sm
        WHERE sm.shop_id = sh.id AND sm.user_id = auth.uid()
      )
    )
  )
);

-- Policy 3: Les utilisateurs peuvent modifier les articles des ventes de leurs boutiques
CREATE POLICY "sale_items_update_own_shops"
ON sale_items FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM sales s
    INNER JOIN shops sh ON sh.id = s.shop_id
    WHERE s.id = sale_items.sale_id
    AND (
      sh.owner_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM shop_members sm
        WHERE sm.shop_id = sh.id AND sm.user_id = auth.uid()
      )
    )
  )
);

-- Policy 4: Les utilisateurs peuvent supprimer les articles des ventes de leurs boutiques
CREATE POLICY "sale_items_delete_own_shops"
ON sale_items FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM sales s
    INNER JOIN shops sh ON sh.id = s.shop_id
    WHERE s.id = sale_items.sale_id
    AND (
      sh.owner_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM shop_members sm
        WHERE sm.shop_id = sh.id AND sm.user_id = auth.uid()
      )
    )
  )
);

-- ================================================================
-- 5️⃣ VÉRIFICATION
-- ================================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ SALES PERMISSIONS FIXED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ 4 policies pour sales';
  RAISE NOTICE '✅ 4 policies pour sale_items';
  RAISE NOTICE '✅ SELECT, INSERT, UPDATE, DELETE';
  RAISE NOTICE '✅ Basées sur shop_id et shop_members';
  RAISE NOTICE '========================================';
END $$;

COMMIT;
