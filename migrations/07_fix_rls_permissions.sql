-- ================================================================
-- 🔧 CORRECTION RLS PERMISSIONS (INSERT/UPDATE/DELETE)
-- ================================================================
-- Date: 24 Décembre 2025
-- Objectif: Ajouter les permissions manquantes pour l'écriture
-- ================================================================

BEGIN;

-- 1. PRODUCTS
-- INSERT
CREATE POLICY "Users insert products for their shops" ON products
FOR INSERT WITH CHECK (
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- UPDATE
CREATE POLICY "Users update products for their shops" ON products
FOR UPDATE USING (
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- DELETE
CREATE POLICY "Users delete products for their shops" ON products
FOR DELETE USING (
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- 2. SALES
-- INSERT
CREATE POLICY "Users insert sales for their shops" ON sales
FOR INSERT WITH CHECK (
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- UPDATE
CREATE POLICY "Users update sales for their shops" ON sales
FOR UPDATE USING (
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- DELETE
CREATE POLICY "Users delete sales for their shops" ON sales
FOR DELETE USING (
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- 3. SALE ITEMS
-- INSERT
CREATE POLICY "Users insert sale items for their shops" ON sale_items
FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM sales s
        WHERE s.id = sale_items.sale_id
        AND s.shop_id IN (SELECT get_accessible_shop_ids())
    )
);

-- UPDATE
CREATE POLICY "Users update sale items for their shops" ON sale_items
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM sales s
        WHERE s.id = sale_items.sale_id
        AND s.shop_id IN (SELECT get_accessible_shop_ids())
    )
);

-- DELETE
CREATE POLICY "Users delete sale items for their shops" ON sale_items
FOR DELETE USING (
    EXISTS (
        SELECT 1 FROM sales s
        WHERE s.id = sale_items.sale_id
        AND s.shop_id IN (SELECT get_accessible_shop_ids())
    )
);

-- 4. CART ITEMS
-- INSERT
CREATE POLICY "Users insert cart items" ON cart_items
FOR INSERT WITH CHECK (
    user_id = auth.uid()::uuid OR 
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- UPDATE
CREATE POLICY "Users update cart items" ON cart_items
FOR UPDATE USING (
    user_id = auth.uid()::uuid OR 
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- DELETE
CREATE POLICY "Users delete cart items" ON cart_items
FOR DELETE USING (
    user_id = auth.uid()::uuid OR 
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- 5. DEBTS
-- INSERT
CREATE POLICY "Users insert debts for their shops" ON debts
FOR INSERT WITH CHECK (
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- UPDATE
CREATE POLICY "Users update debts for their shops" ON debts
FOR UPDATE USING (
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- DELETE
CREATE POLICY "Users delete debts for their shops" ON debts
FOR DELETE USING (
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- 6. DEBT PAYMENTS
-- INSERT
CREATE POLICY "Users insert payments for their shops" ON debt_payments
FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM debts d
        WHERE d.id = debt_payments.debt_id
        AND d.shop_id IN (SELECT get_accessible_shop_ids())
    )
);

-- UPDATE
CREATE POLICY "Users update payments for their shops" ON debt_payments
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM debts d
        WHERE d.id = debt_payments.debt_id
        AND d.shop_id IN (SELECT get_accessible_shop_ids())
    )
);

-- DELETE
CREATE POLICY "Users delete payments for their shops" ON debt_payments
FOR DELETE USING (
    EXISTS (
        SELECT 1 FROM debts d
        WHERE d.id = debt_payments.debt_id
        AND d.shop_id IN (SELECT get_accessible_shop_ids())
    )
);

-- 7. ORDERS
-- INSERT
CREATE POLICY "Users insert orders for their shops" ON orders
FOR INSERT WITH CHECK (
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- UPDATE
CREATE POLICY "Users update orders for their shops" ON orders
FOR UPDATE USING (
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- DELETE
CREATE POLICY "Users delete orders for their shops" ON orders
FOR DELETE USING (
    shop_id IN (SELECT get_accessible_shop_ids())
);

-- 8. ORDER ITEMS
-- INSERT
CREATE POLICY "Users insert order items for their shops" ON order_items
FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM orders o
        WHERE o.id = order_items.order_id
        AND o.shop_id IN (SELECT get_accessible_shop_ids())
    )
);

-- UPDATE
CREATE POLICY "Users update order items for their shops" ON order_items
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM orders o
        WHERE o.id = order_items.order_id
        AND o.shop_id IN (SELECT get_accessible_shop_ids())
    )
);

-- DELETE
CREATE POLICY "Users delete order items for their shops" ON order_items
FOR DELETE USING (
    EXISTS (
        SELECT 1 FROM orders o
        WHERE o.id = order_items.order_id
        AND o.shop_id IN (SELECT get_accessible_shop_ids())
    )
);

-- 9. SHOPS
-- INSERT (Seul le owner peut créer un shop via RPC, mais au cas où)
CREATE POLICY "Users insert shops" ON shops
FOR INSERT WITH CHECK (
    owner_id = auth.uid()::uuid
);

-- UPDATE
CREATE POLICY "Users update their shops" ON shops
FOR UPDATE USING (
    owner_id = auth.uid()::uuid
);

-- DELETE
CREATE POLICY "Users delete their shops" ON shops
FOR DELETE USING (
    owner_id = auth.uid()::uuid
);

COMMIT;

-- ================================================================
-- ✅ PERMISSIONS D'ÉCRITURE AJOUTÉES
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Permissions INSERT/UPDATE/DELETE ajoutées !';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔄 La synchronisation devrait (enfin) fonctionner';
    RAISE NOTICE '========================================';
END $$;
