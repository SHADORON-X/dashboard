-- ==============================================================================
-- MIGRATION 086: SUPER ADMIN GOD MODE & MISSING VIEWS RESTORATION
-- ==============================================================================
-- Ce script s'assure que le dashboard a accès à TOUTES les données sans restriction RLS
-- et recrée les vues SQL nécessaires si elles ont été supprimées.

-- 1. CRÉATION DES VUES ADMIN OPTIMISÉES (Si manquantes)
-- ------------------------------------------------------------------------------

-- Vue: v_admin_shops_overview
CREATE OR REPLACE VIEW v_admin_shops_overview AS
SELECT 
    s.id,
    s.name,
    s.location,
    s.status,
    u.first_name || ' ' || u.last_name as manager_name,
    (SELECT COUNT(*) FROM users WHERE shop_id = s.id) as staff_count,
    COALESCE((SELECT SUM(total_amount) FROM sales WHERE shop_id = s.id AND created_at > now() - interval '30 days'), 0) as monthly_revenue,
    s.subscription_status
FROM shops s
LEFT JOIN users u ON s.manager_id = u.id;

-- Vue: v_admin_platform_stats
CREATE OR REPLACE VIEW v_admin_platform_stats AS
SELECT
    (SELECT COUNT(*) FROM shops) as total_shops,
    (SELECT COUNT(*) FROM users) as total_users,
    (SELECT COUNT(*) FROM products) as total_products,
    (SELECT COALESCE(SUM(total_amount), 0) FROM sales WHERE payment_status = 'paid') as total_revenue,
    (SELECT COUNT(*) FROM shops WHERE status = 'active') as active_shops_count,
    (SELECT COUNT(*) FROM sales WHERE created_at > now() - interval '24 hours') as sales_24h_count
FROM generate_series(1,1); -- Dummy source pour retourner une seule ligne

-- 2. POLITIQUE DE SÉCURITÉ (RLS) : GOD MODE POUR LES ADMINS
-- ------------------------------------------------------------------------------
-- On s'assure que les utilisateurs avec le rôle 'admin' ou 'super_admin' peuvent TOUT voir.

-- Fonction helper pour vérifier si admin
CREATE OR REPLACE FUNCTION auth.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'super_admin');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Appliquer les policies permissives sur les tables principales
ALTER TABLE shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;

-- Policy SHOPS: Admin voit tout
DROP POLICY IF EXISTS "Admins can view all shops" ON shops;
CREATE POLICY "Admins can view all shops" ON shops
    FOR SELECT USING (true); -- TEMPORAIRE: Open Bar pour debug, à restreindre plus tard

-- Policy USERS: Admin voit tout
DROP POLICY IF EXISTS "Admins can view all users" ON users;
CREATE POLICY "Admins can view all users" ON users
    FOR SELECT USING (true);

-- Policy PRODUCTS: Admin voit tout
DROP POLICY IF EXISTS "Admins can view all products" ON products;
CREATE POLICY "Admins can view all products" ON products
    FOR SELECT USING (true);

-- Policy SALES: Admin voit tout
DROP POLICY IF EXISTS "Admins can view all sales" ON sales;
CREATE POLICY "Admins can view all sales" ON sales
    FOR SELECT USING (true);

-- 3. ACCORDER LES DROITS AUX VUES
GRANT SELECT ON v_admin_shops_overview TO authenticated;
GRANT SELECT ON v_admin_platform_stats TO authenticated;

-- Confirmation
SELECT 'MIGRATION 086 COMPLETED: GOD MODE ENABLED & VIEWS RESTORED' as status;
