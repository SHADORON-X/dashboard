-- ================================================================
-- 🔧 CORRECTION RLS RECURSION
-- ================================================================
-- Date: 24 Décembre 2025
-- Objectif: Corriger l'erreur "infinite recursion" dans les politiques RLS
-- ================================================================

BEGIN;

-- 1. Créer une fonction helper sécurisée pour vérifier l'accès aux shops
-- Cette fonction contourne la RLS pour éviter la récursion
CREATE OR REPLACE FUNCTION get_accessible_shop_ids()
RETURNS TABLE (shop_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT s.id 
    FROM shops s
    WHERE s.owner_id = auth.uid()::uuid
    UNION
    SELECT sm.shop_id
    FROM shop_members sm
    WHERE sm.user_id = auth.uid()::uuid;
END;
$$;

-- 2. Supprimer les anciennes politiques récursives
DROP POLICY IF EXISTS "Users see products from their shops" ON products;
DROP POLICY IF EXISTS "Users see sales from their shops" ON sales;
DROP POLICY IF EXISTS "Users see sale items from their shops" ON sale_items;
DROP POLICY IF EXISTS "Users manage their cart items" ON cart_items;
DROP POLICY IF EXISTS "Users see debts from their shops" ON debts;
DROP POLICY IF EXISTS "Users see payments from their shop debts" ON debt_payments;
DROP POLICY IF EXISTS "Users see their orders" ON orders;
DROP POLICY IF EXISTS "Users see their order items" ON order_items;
DROP POLICY IF EXISTS "Shop owners manage members" ON shop_members;

-- 3. Recréer les politiques avec la fonction helper (NON RÉCURSIVE)

-- Products
CREATE POLICY "Users see products from their shops" ON products
FOR ALL USING (
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- Sales
CREATE POLICY "Users see sales from their shops" ON sales
FOR ALL USING (
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- Sale Items
CREATE POLICY "Users see sale items from their shops" ON sale_items
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM sales s
        WHERE s.id = sale_items.sale_id
        AND s.shop_id IN (SELECT get_accessible_shop_ids())
    )
);

-- Cart Items
CREATE POLICY "Users manage their cart items" ON cart_items
FOR ALL USING (
    user_id = auth.uid()::uuid OR 
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- Debts
CREATE POLICY "Users see debts from their shops" ON debts
FOR ALL USING (
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- Debt Payments
CREATE POLICY "Users see payments from their shop debts" ON debt_payments
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM debts d
        WHERE d.id = debt_payments.debt_id
        AND d.shop_id IN (SELECT get_accessible_shop_ids())
    )
);

-- Orders
CREATE POLICY "Users see their orders" ON orders
FOR ALL USING (
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- Order Items
CREATE POLICY "Users see their order items" ON order_items
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM orders o
        WHERE o.id = order_items.order_id
        AND o.shop_id IN (SELECT get_accessible_shop_ids())
    )
);

-- Shop Members (Correction de la récursion ici aussi)
CREATE POLICY "Shop owners manage members" ON shop_members
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM shops s
        WHERE s.id = shop_members.shop_id
        AND s.owner_id = auth.uid()::uuid
    )
);

-- Donner les droits sur la fonction helper
GRANT EXECUTE ON FUNCTION get_accessible_shop_ids TO authenticated, service_role;

COMMIT;

-- ================================================================
-- ✅ RLS CORRIGÉES
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Politiques RLS récursives corrigées !';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔄 La synchronisation ne devrait plus planter';
    RAISE NOTICE '========================================';
END $$;
