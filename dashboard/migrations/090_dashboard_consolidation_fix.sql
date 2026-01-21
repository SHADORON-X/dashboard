-- ==============================================================================
-- 🛠️ VELMO ADMIN DASHBOARD: FINAL REPAIR & DATA RESTORATION (VERSION 2)
-- ==============================================================================
-- Objectif: Réparer l'accès intégral aux données du dashboard.
-- Fixe: Erreur "Boutique introuvable" et blocages RLS.
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. IDENTITÉ & SECURITY DEFINER FUNCTIONS
-- ------------------------------------------------------------------------------

-- Fonction source de vérité pour les accès Admin
CREATE OR REPLACE FUNCTION public.is_admin_viewer()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_users 
    WHERE id = auth.uid() 
    AND (role = 'super_admin' OR role = 'admin' OR role = 'viewer')
  );
$$;

-- Redéfinition de auth.is_admin si utilisée par d'autres systèmes
CREATE OR REPLACE FUNCTION auth.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT public.is_admin_viewer();
$$;

-- ------------------------------------------------------------------------------
-- 2. RESTAURATION DES VUES (Modèle exact pour Dashboard React)
-- ------------------------------------------------------------------------------

-- VUE: v_admin_shops_overview
DROP VIEW IF EXISTS v_admin_shops_overview CASCADE;
CREATE VIEW v_admin_shops_overview AS
SELECT 
    s.id as shop_id,
    s.velmo_id as shop_velmo_id,
    s.name as shop_name,
    s.category,
    s.is_active,
    s.created_at,
    s.owner_id,
    u.velmo_id as owner_velmo_id,
    CONCAT(u.first_name, ' ', u.last_name) as owner_name,
    u.phone as owner_phone,
    (SELECT COUNT(*) FROM products p WHERE p.shop_id = s.id AND p.is_active = TRUE) as products_count,
    (SELECT COUNT(*) FROM sales sa WHERE sa.shop_id = s.id) as total_sales,
    (SELECT COALESCE(SUM(sa.total_amount), 0) FROM sales sa WHERE sa.shop_id = s.id) as total_revenue,
    (SELECT COALESCE(SUM(sa.total_profit), 0) FROM sales sa WHERE sa.shop_id = s.id) as total_profit,
    (SELECT COUNT(*) FROM debts d WHERE d.shop_id = s.id AND d.status NOT IN ('paid', 'cancelled')) as active_debts,
    (SELECT COALESCE(SUM(d.remaining_amount), 0) FROM debts d WHERE d.shop_id = s.id AND d.status NOT IN ('paid', 'cancelled')) as total_outstanding_debt,
    (SELECT MAX(sa.created_at) FROM sales sa WHERE sa.shop_id = s.id) as last_sale_at
FROM shops s
LEFT JOIN users u ON s.owner_id = u.id
ORDER BY s.created_at DESC;

-- VUE: v_admin_platform_stats
DROP VIEW IF EXISTS v_admin_platform_stats CASCADE;
CREATE VIEW v_admin_platform_stats AS
SELECT 
    (SELECT COUNT(*) FROM shops WHERE is_active = TRUE) as total_active_shops,
    (SELECT COUNT(*) FROM users WHERE is_active = TRUE) as total_active_users,
    (SELECT COUNT(*) FROM products WHERE is_active = TRUE) as total_products,
    (SELECT COUNT(*) FROM sales) as total_sales,
    (SELECT COALESCE(SUM(total_amount), 0) FROM sales) as total_gmv,
    (SELECT COALESCE(SUM(total_profit), 0) FROM sales) as total_profit,
    (SELECT COUNT(*) FROM debts WHERE status NOT IN ('paid', 'cancelled')) as active_debts_count,
    (SELECT COALESCE(SUM(remaining_amount), 0) FROM debts WHERE status NOT IN ('paid', 'cancelled')) as total_outstanding_debt,
    (SELECT COUNT(*) FROM sales WHERE created_at >= NOW() - INTERVAL '24 hours') as sales_last_24h,
    (SELECT COUNT(*) FROM users WHERE created_at >= NOW() - INTERVAL '7 days') as new_users_last_7d,
    (SELECT COUNT(*) FROM shops WHERE created_at >= NOW() - INTERVAL '7 days') as new_shops_last_7d,
    NOW() as generated_at;

-- VUE: v_admin_stock_alerts
DROP VIEW IF EXISTS v_admin_stock_alerts CASCADE;
CREATE VIEW v_admin_stock_alerts AS
SELECT 
    p.id as product_id,
    p.name as product_name,
    p.quantity as current_stock,
    p.stock_alert as alert_threshold,
    s.id as shop_id,
    s.name as shop_name,
    CONCAT(u.first_name, ' ', u.last_name) as owner_name,
    u.phone as owner_phone
FROM products p
INNER JOIN shops s ON p.shop_id = s.id
INNER JOIN users u ON s.owner_id = u.id
WHERE p.is_active = TRUE 
AND p.stock_alert IS NOT NULL
AND p.quantity <= p.stock_alert;

-- ------------------------------------------------------------------------------
-- 3. SÉCURITÉ (RLS): Déblocage des Tables pour les Administrateurs
-- ------------------------------------------------------------------------------

-- Applique une politique de lecture "Admin Read Only" sur toutes les tables
DO $$
DECLARE
    t text;
BEGIN
    FOR t IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name IN ('shops', 'users', 'products', 'sales', 'debts', 'debt_payments', 'shop_members', 'audit_logs', 'sale_items')
    LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
        EXECUTE format('DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.%I', t);
        EXECUTE format('CREATE POLICY "Dashboard Admin Read Access" ON public.%I FOR SELECT USING ( public.is_admin_viewer() )', t);
    END LOOP;
END $$;

-- ------------------------------------------------------------------------------
-- 4. PERMISSIONS & FINITIONS
-- ------------------------------------------------------------------------------

GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO service_role;

GRANT SELECT ON v_admin_shops_overview TO authenticated;
GRANT SELECT ON v_admin_platform_stats TO authenticated;
GRANT SELECT ON v_admin_stock_alerts TO authenticated;

COMMIT;

SELECT 'DASHBOARD CONSOLIDATED: Migration 090 Complete.' as status;
