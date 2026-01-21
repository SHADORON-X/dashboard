-- ================================================================
-- 🔧 MIGRATION 26: ADAPTER RPC SYNC POUR TOUTES LES TABLES
-- ================================================================
-- Date: 26 Décembre 2025
-- Objectif: Ajouter support pour customers, stock_movements, expenses
-- 
-- Tables supportées:
-- 1. products ✅
-- 2. sales ✅
-- 3. sale_items ✅
-- 4. shops ✅
-- 5. debts ✅
-- 6. orders ✅
-- 7. order_items ✅
-- 8. customers 🆕 (Support ajouté)
-- 9. stock_movements 🆕 (Support ajouté)
-- 10. expenses 🆕 (Support ajouté)
-- ================================================================

BEGIN;

-- ================================================================
-- ÉTAPE 1: CRÉER TABLES MANQUANTES SI NÉCESSAIRE
-- ================================================================

-- Table: customers
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    velmo_id TEXT UNIQUE NOT NULL,
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    address TEXT,
    
    -- Crédits et dettes
    credit_limit NUMERIC(15, 2) DEFAULT 0,
    credit_balance NUMERIC(15, 2) DEFAULT 0,
    
    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    last_purchase_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    synced_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_customers_shop_id ON customers(shop_id);
CREATE INDEX IF NOT EXISTS idx_customers_user_id ON customers(user_id);
CREATE INDEX IF NOT EXISTS idx_customers_velmo_id ON customers(velmo_id);

-- Table: stock_movements
CREATE TABLE IF NOT EXISTS stock_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    velmo_id TEXT UNIQUE NOT NULL,
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    
    movement_type TEXT NOT NULL, -- 'in', 'out', 'adjustment', 'loss'
    quantity NUMERIC(15, 2) NOT NULL,
    reason TEXT,
    reference_id TEXT, -- ID de la vente/commande
    reference_type TEXT, -- 'sale', 'order', 'adjustment', etc
    
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    synced_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_stock_movements_shop_id ON stock_movements(shop_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_user_id ON stock_movements(user_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_product_id ON stock_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_velmo_id ON stock_movements(velmo_id);

-- Table: expenses
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    velmo_id TEXT UNIQUE NOT NULL,
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    category TEXT NOT NULL, -- 'rent', 'utilities', 'supplies', etc
    description TEXT NOT NULL,
    amount NUMERIC(15, 2) NOT NULL,
    
    -- Metadata
    payment_method TEXT, -- 'cash', 'mobile_money', 'check', etc
    receipt_url TEXT,
    is_recurring BOOLEAN DEFAULT FALSE,
    recurring_interval TEXT, -- 'daily', 'weekly', 'monthly'
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    synced_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_expenses_shop_id ON expenses(shop_id);
CREATE INDEX IF NOT EXISTS idx_expenses_user_id ON expenses(user_id);
CREATE INDEX IF NOT EXISTS idx_expenses_velmo_id ON expenses(velmo_id);

-- ================================================================
-- ÉTAPE 2: ADAPTER RPC sync_pull_table
-- ================================================================

DROP FUNCTION IF EXISTS sync_pull_table(TEXT, TIMESTAMPTZ, UUID) CASCADE;

CREATE OR REPLACE FUNCTION sync_pull_table(
    p_table_name TEXT,
    p_last_sync_time TIMESTAMPTZ,
    p_user_id UUID
)
RETURNS TABLE (
    result_id UUID,
    result_data JSONB,
    result_updated_at TIMESTAMPTZ
) AS $$
DECLARE
    v_user_exists BOOLEAN;
BEGIN
    -- Vérifier que l'utilisateur existe
    SELECT EXISTS(SELECT 1 FROM users WHERE id = p_user_id) INTO v_user_exists;
    
    IF NOT v_user_exists THEN
        RAISE EXCEPTION 'User % does not exist', p_user_id;
    END IF;

    -- ✅ TABLE: products
    IF p_table_name = 'products' THEN
        RETURN QUERY
        SELECT 
            p.id,
            jsonb_build_object(
                'id', p.id,
                'velmo_id', p.velmo_id,
                'shop_id', p.shop_id,
                'user_id', p.user_id,
                'name', p.name,
                'price_sale', p.price_sale,
                'price_buy', p.price_buy,
                'quantity', p.quantity,
                'stock_alert', p.stock_alert,
                'category', p.category,
                'unit', p.unit,
                'description', p.description,
                'barcode', p.barcode,
                'is_active', p.is_active,
                'created_at', p.created_at,
                'updated_at', p.updated_at
            ),
            p.updated_at
        FROM products p
        WHERE p.shop_id IN (
            SELECT sh.id FROM shops sh WHERE sh.owner_id = p_user_id OR sh.id IN (
                SELECT sm.shop_id FROM shop_members sm WHERE sm.user_id = p_user_id
            )
        )
        AND p.updated_at > p_last_sync_time
        ORDER BY p.updated_at;

    -- ✅ TABLE: sales
    ELSIF p_table_name = 'sales' THEN
        RETURN QUERY
        SELECT 
            s.id,
            jsonb_build_object(
                'id', s.id,
                'velmo_id', s.velmo_id,
                'shop_id', s.shop_id,
                'user_id', s.user_id,
                'total_amount', s.total_amount,
                'total_profit', s.total_profit,
                'payment_type', s.payment_type,
                'customer_name', s.customer_name,
                'customer_phone', s.customer_phone,
                'notes', s.notes,
                'items_count', s.items_count,
                'created_by', s.created_by,
                'created_at', s.created_at,
                'updated_at', s.updated_at
            ),
            s.updated_at
        FROM sales s
        WHERE s.shop_id IN (
            SELECT sh.id FROM shops sh WHERE sh.owner_id = p_user_id OR sh.id IN (
                SELECT sm.shop_id FROM shop_members sm WHERE sm.user_id = p_user_id
            )
        )
        AND s.updated_at > p_last_sync_time
        ORDER BY s.updated_at;

    -- ✅ TABLE: sale_items
    ELSIF p_table_name = 'sale_items' THEN
        RETURN QUERY
        SELECT 
            si.id,
            jsonb_build_object(
                'id', si.id,
                'sale_id', si.sale_id,
                'product_id', si.product_id,
                'user_id', si.user_id,
                'product_name', si.product_name,
                'quantity', si.quantity,
                'unit_price', si.unit_price,
                'purchase_price', si.purchase_price,
                'subtotal', si.subtotal,
                'profit', si.profit,
                'created_at', si.created_at
            ),
            si.created_at
        FROM sale_items si
        JOIN sales s ON si.sale_id = s.id
        WHERE s.shop_id IN (
            SELECT sh.id FROM shops sh WHERE sh.owner_id = p_user_id OR sh.id IN (
                SELECT sm.shop_id FROM shop_members sm WHERE sm.user_id = p_user_id
            )
        )
        AND si.created_at > p_last_sync_time
        ORDER BY si.created_at;

    -- ✅ TABLE: shops
    ELSIF p_table_name = 'shops' THEN
        RETURN QUERY
        SELECT 
            sh.id,
            jsonb_build_object(
                'id', sh.id,
                'velmo_id', sh.velmo_id,
                'shop_code', sh.shop_code,
                'name', sh.name,
                'category', sh.category,
                'owner_id', sh.owner_id,
                'currency', sh.currency,
                'currency_symbol', sh.currency_symbol,
                'currency_name', sh.currency_name,
                'logo', sh.logo,
                'logo_icon', sh.logo_icon,
                'logo_color', sh.logo_color,
                'address', sh.address,
                'phone', sh.phone,
                'is_active', sh.is_active,
                'created_at', sh.created_at,
                'updated_at', sh.updated_at
            ),
            sh.updated_at
        FROM shops sh
        WHERE (sh.owner_id = p_user_id OR sh.id IN (
            SELECT sm.shop_id FROM shop_members sm WHERE sm.user_id = p_user_id
        ))
        AND sh.updated_at > p_last_sync_time
        ORDER BY sh.updated_at;

    -- ✅ TABLE: debts
    ELSIF p_table_name = 'debts' THEN
        RETURN QUERY
        SELECT 
            d.id,
            jsonb_build_object(
                'id', d.id,
                'velmo_id', d.velmo_id,
                'shop_id', d.shop_id,
                'user_id', d.user_id,
                'debtor_id', d.debtor_id,
                'customer_name', d.customer_name,
                'customer_phone', d.customer_phone,
                'customer_address', d.customer_address,
                'total_amount', d.total_amount,
                'paid_amount', d.paid_amount,
                'remaining_amount', d.remaining_amount,
                'status', d.status,
                'type', d.type,
                'category', d.category,
                'due_date', d.due_date,
                'reliability_score', d.reliability_score,
                'trust_level', d.trust_level,
                'payment_count', d.payment_count,
                'on_time_payment_count', d.on_time_payment_count,
                'products_json', d.products_json,
                'notes', d.notes,
                'created_at', d.created_at,
                'updated_at', d.updated_at
            ),
            d.updated_at
        FROM debts d
        WHERE d.shop_id IN (
            SELECT sh.id FROM shops sh WHERE sh.owner_id = p_user_id OR sh.id IN (
                SELECT sm.shop_id FROM shop_members sm WHERE sm.user_id = p_user_id
            )
        )
        AND d.updated_at > p_last_sync_time
        ORDER BY d.updated_at;

    -- ✅ TABLE: orders
    ELSIF p_table_name = 'orders' THEN
        RETURN QUERY
        SELECT 
            o.id,
            jsonb_build_object(
                'id', o.id,
                'shop_id', o.shop_id,
                'supplier_id', o.supplier_id,
                'supplier_name', o.supplier_name,
                'supplier_phone', o.supplier_phone,
                'supplier_velmo_id', o.supplier_velmo_id,
                'status', o.status,
                'total_amount', o.total_amount,
                'paid_amount', o.paid_amount,
                'payment_condition', o.payment_condition,
                'expected_delivery_date', o.expected_delivery_date,
                'notes', o.notes,
                'created_at', o.created_at,
                'updated_at', o.updated_at
            ),
            o.updated_at
        FROM orders o
        WHERE o.shop_id IN (
            SELECT sh.id FROM shops sh WHERE sh.owner_id = p_user_id OR sh.id IN (
                SELECT sm.shop_id FROM shop_members sm WHERE sm.user_id = p_user_id
            )
        )
        AND o.updated_at > p_last_sync_time
        ORDER BY o.updated_at;

    -- ✅ TABLE: order_items
    ELSIF p_table_name = 'order_items' THEN
        RETURN QUERY
        SELECT 
            oi.id,
            jsonb_build_object(
                'id', oi.id,
                'order_id', oi.order_id,
                'product_name', oi.product_name,
                'quantity', oi.quantity,
                'unit_price', oi.unit_price,
                'total_price', oi.total_price,
                'photo_uri', oi.photo_uri,
                'is_confirmed', oi.is_confirmed,
                'created_at', oi.created_at
            ),
            oi.created_at
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        WHERE o.shop_id IN (
            SELECT sh.id FROM shops sh WHERE sh.owner_id = p_user_id OR sh.id IN (
                SELECT sm.shop_id FROM shop_members sm WHERE sm.user_id = p_user_id
            )
        )
        AND oi.created_at > p_last_sync_time
        ORDER BY oi.created_at;

    -- 🆕 TABLE: customers (NOUVEAU)
    ELSIF p_table_name = 'customers' THEN
        RETURN QUERY
        SELECT 
            c.id,
            jsonb_build_object(
                'id', c.id,
                'velmo_id', c.velmo_id,
                'shop_id', c.shop_id,
                'user_id', c.user_id,
                'name', c.name,
                'phone', c.phone,
                'email', c.email,
                'address', c.address,
                'credit_limit', c.credit_limit,
                'credit_balance', c.credit_balance,
                'is_active', c.is_active,
                'last_purchase_at', c.last_purchase_at,
                'created_at', c.created_at,
                'updated_at', c.updated_at
            ),
            c.updated_at
        FROM customers c
        WHERE c.shop_id IN (
            SELECT sh.id FROM shops sh WHERE sh.owner_id = p_user_id OR sh.id IN (
                SELECT sm.shop_id FROM shop_members sm WHERE sm.user_id = p_user_id
            )
        )
        AND c.updated_at > p_last_sync_time
        ORDER BY c.updated_at;

    -- 🆕 TABLE: stock_movements (NOUVEAU)
    ELSIF p_table_name = 'stock_movements' THEN
        RETURN QUERY
        SELECT 
            sm.id,
            jsonb_build_object(
                'id', sm.id,
                'velmo_id', sm.velmo_id,
                'shop_id', sm.shop_id,
                'user_id', sm.user_id,
                'product_id', sm.product_id,
                'movement_type', sm.movement_type,
                'quantity', sm.quantity,
                'reason', sm.reason,
                'reference_id', sm.reference_id,
                'reference_type', sm.reference_type,
                'notes', sm.notes,
                'created_at', sm.created_at,
                'updated_at', sm.updated_at
            ),
            sm.updated_at
        FROM stock_movements sm
        WHERE sm.shop_id IN (
            SELECT sh.id FROM shops sh WHERE sh.owner_id = p_user_id OR sh.id IN (
                SELECT sm2.shop_id FROM shop_members sm2 WHERE sm2.user_id = p_user_id
            )
        )
        AND sm.updated_at > p_last_sync_time
        ORDER BY sm.updated_at;

    -- 🆕 TABLE: expenses (NOUVEAU)
    ELSIF p_table_name = 'expenses' THEN
        RETURN QUERY
        SELECT 
            e.id,
            jsonb_build_object(
                'id', e.id,
                'velmo_id', e.velmo_id,
                'shop_id', e.shop_id,
                'user_id', e.user_id,
                'category', e.category,
                'description', e.description,
                'amount', e.amount,
                'payment_method', e.payment_method,
                'receipt_url', e.receipt_url,
                'is_recurring', e.is_recurring,
                'recurring_interval', e.recurring_interval,
                'created_at', e.created_at,
                'updated_at', e.updated_at
            ),
            e.updated_at
        FROM expenses e
        WHERE e.shop_id IN (
            SELECT sh.id FROM shops sh WHERE sh.owner_id = p_user_id OR sh.id IN (
                SELECT sm.shop_id FROM shop_members sm WHERE sm.user_id = p_user_id
            )
        )
        AND e.updated_at > p_last_sync_time
        ORDER BY e.updated_at;

    ELSE
        RAISE EXCEPTION 'Table % not supported for sync_pull_table', p_table_name;
    END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- ÉTAPE 3: ADAPTER RPC sync_push_record
-- ================================================================

-- Cette RPC gère déjà toutes les tables (elle utilise EXECUTE dynamique)
-- Vérifier que les permissions sont correctes

GRANT EXECUTE ON FUNCTION sync_pull_table(TEXT, TIMESTAMPTZ, UUID) TO anon, authenticated, service_role;

-- ================================================================
-- ÉTAPE 4: PERMISSIONS RLS (ajouter si manquantes)
-- ================================================================

-- Customers
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS customers_owner_access ON customers;
DROP POLICY IF EXISTS customers_service_role ON customers;

CREATE POLICY customers_owner_access ON customers
    FOR ALL USING (
        shop_id IN (
            SELECT id FROM shops WHERE owner_id = auth.uid()
        )
        OR user_id = auth.uid()
    );

CREATE POLICY customers_service_role ON customers
    FOR ALL USING (auth.role() = 'service_role');

-- Stock movements
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS stock_movements_owner_access ON stock_movements;
DROP POLICY IF EXISTS stock_movements_service_role ON stock_movements;

CREATE POLICY stock_movements_owner_access ON stock_movements
    FOR ALL USING (
        shop_id IN (
            SELECT id FROM shops WHERE owner_id = auth.uid()
        )
        OR user_id = auth.uid()
    );

CREATE POLICY stock_movements_service_role ON stock_movements
    FOR ALL USING (auth.role() = 'service_role');

-- Expenses
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS expenses_owner_access ON expenses;
DROP POLICY IF EXISTS expenses_service_role ON expenses;

CREATE POLICY expenses_owner_access ON expenses
    FOR ALL USING (
        shop_id IN (
            SELECT id FROM shops WHERE owner_id = auth.uid()
        )
        OR user_id = auth.uid()
    );

CREATE POLICY expenses_service_role ON expenses
    FOR ALL USING (auth.role() = 'service_role');

COMMIT;

-- ================================================================
-- ✅ SUMMARY
-- ================================================================
-- Tables créées:
-- ✅ customers (avec indexes)
-- ✅ stock_movements (avec indexes)
-- ✅ expenses (avec indexes)
--
-- RPC adaptées:
-- ✅ sync_pull_table - Support complet 10 tables
-- ✅ sync_push_record - Pas de changement (déjà générique)
--
-- RLS ajoutée:
-- ✅ customers (owner + service_role)
-- ✅ stock_movements (owner + service_role)
-- ✅ expenses (owner + service_role)
-- ================================================================
