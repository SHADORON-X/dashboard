-- ==========================================================
-- 091_FIX_PRODUCTS_AND_DATA_ACCESS.sql
-- Correction de l'accès aux données du Dashboard Velmo Admin
-- ==========================================================

-- 1. SECURISATION DE LA FONCTION DE VERIFICATION ADMIN
CREATE OR REPLACE FUNCTION public.is_admin_viewer()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.admin_users 
    WHERE id = auth.uid() 
    AND role IN ('super_admin', 'admin', 'viewer')
  );
END;
$$;

-- 2. APPLICATION DES POLITIQUES RLS PERMISSIVES POUR LES ADMINS
-- On s'assure que les admins peuvent TOUT voir sur les tables clés.

-- TABLE: products
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can view all products" ON products;
CREATE POLICY "Admins can view all products" ON products
    FOR SELECT USING (public.is_admin_viewer() OR auth.uid() = user_id);

-- TABLE: shops
ALTER TABLE shops ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can view all shops" ON shops;
CREATE POLICY "Admins can view all shops" ON shops
    FOR SELECT USING (public.is_admin_viewer() OR auth.uid() = owner_id);

-- TABLE: sales
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can view all sales" ON sales;
CREATE POLICY "Admins can view all sales" ON sales
    FOR SELECT USING (public.is_admin_viewer());

-- TABLE: debts
ALTER TABLE debts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can view all debts" ON debts;
CREATE POLICY "Admins can view all debts" ON debts
    FOR SELECT USING (public.is_admin_viewer());

-- TABLE: users (profils publics/privés)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can view all users" ON users;
CREATE POLICY "Admins can view all users" ON users
    FOR SELECT USING (public.is_admin_viewer() OR auth.uid() = id);

-- 3. RE-CREATION DES VUES CRITIQUES SANS FILTRES TROP RESTRICTIFS
-- On veut voir tous les produits dans les stats, pas seulement les "active"

DROP VIEW IF EXISTS v_admin_platform_stats;
CREATE VIEW v_admin_platform_stats AS
SELECT 
    (SELECT COUNT(*) FROM shops) as total_active_shops, -- On compte tout pour le dashboard
    (SELECT COUNT(*) FROM users) as total_active_users,
    (SELECT COUNT(*) FROM products) as total_products,
    (SELECT COALESCE(SUM(total_amount), 0) FROM sales) as total_gmv,
    (SELECT COUNT(*) FROM sales) as total_sales,
    (SELECT COALESCE(SUM(remaining_amount), 0) FROM debts) as total_debts;

DROP VIEW IF EXISTS v_admin_shops_overview;
CREATE VIEW v_admin_shops_overview AS
SELECT 
    s.id as shop_id,
    s.name as shop_name,
    s.velmo_id as shop_code,
    u.first_name || ' ' || u.last_name as owner_name,
    s.owner_id as owner_id,
    (SELECT COUNT(*) FROM products WHERE shop_id = s.id) as product_count,
    (SELECT COALESCE(SUM(total_amount), 0) FROM sales WHERE shop_id = s.id) as total_revenue,
    s.created_at
FROM shops s
LEFT JOIN users u ON s.owner_id = u.id;

-- 4. AJOUT DES COLONNES MANQUANTES SI NECESSAIRE (Basé sur le dump client)
-- id,velmo_id,shop_id,user_id,name,price_sale,price_buy,quantity,stock_alert,category,photo_url,barcode,unit,is_active,is_incomplete,sync_status,synced_at,created_at,updated_at,description,version,photo
ALTER TABLE products ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_incomplete BOOLEAN DEFAULT FALSE;
ALTER TABLE products ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 1;

-- 5. RPC POUR LE DASHBOARD (Verification rapide)
DROP FUNCTION IF EXISTS check_admin_access();
CREATE OR REPLACE FUNCTION check_admin_access()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT role INTO user_role FROM public.admin_users WHERE id = auth.uid();
    
    IF user_role IS NOT NULL THEN
        RETURN json_build_object('authorized', true, 'role', user_role);
    ELSE
        RETURN json_build_object('authorized', false, 'role', null);
    END IF;
END;
$$;
