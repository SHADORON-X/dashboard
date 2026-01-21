-- ================================================================
-- 🔐 MIGRATION 080: ADMIN DASHBOARD INFRASTRUCTURE
-- ================================================================
-- Date: 2026-01-19
-- Objectif: Créer les éléments nécessaires pour le dashboard admin
--           - Table velmo_admins pour gestion des accès
--           - Vues optimisées pour analytics
--           - RPC sécurisées pour admin
-- ================================================================

BEGIN;

-- ================================================================
-- 1️⃣ TABLE: velmo_admins (Contrôle d'accès admin)
-- ================================================================

-- Suppression si existe (pour réexécution safe)
DROP TABLE IF EXISTS velmo_admins CASCADE;

CREATE TABLE velmo_admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Lien vers l'utilisateur Supabase Auth
    user_id UUID NOT NULL UNIQUE,
    
    -- Rôle admin
    role TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('super_admin', 'admin', 'support', 'viewer')),
    
    -- Permissions granulaires (JSONB pour flexibilité)
    permissions JSONB DEFAULT '{
        "view_shops": true,
        "view_users": true,
        "view_sales": true,
        "view_logs": true,
        "view_analytics": true,
        "manage_admins": false
    }'::JSONB,
    
    -- Métadonnées
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    
    -- Audit
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index
CREATE INDEX idx_velmo_admins_user_id ON velmo_admins(user_id);
CREATE INDEX idx_velmo_admins_role ON velmo_admins(role);
CREATE INDEX idx_velmo_admins_is_active ON velmo_admins(is_active);

-- Trigger updated_at
CREATE TRIGGER velmo_admins_updated_at
BEFORE UPDATE ON velmo_admins
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE velmo_admins ENABLE ROW LEVEL SECURITY;

-- Seuls les super_admins voient cette table
CREATE POLICY "Super admins view all" ON velmo_admins
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM velmo_admins va 
        WHERE va.user_id = auth.uid() 
        AND va.role = 'super_admin' 
        AND va.is_active = TRUE
    )
);

-- Seuls les super_admins peuvent modifier
CREATE POLICY "Super admins manage" ON velmo_admins
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM velmo_admins va 
        WHERE va.user_id = auth.uid() 
        AND va.role = 'super_admin' 
        AND va.is_active = TRUE
    )
);

-- ================================================================
-- 2️⃣ FONCTION: is_velmo_super_admin
-- ================================================================

CREATE OR REPLACE FUNCTION is_velmo_super_admin(p_user_id UUID DEFAULT NULL)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Utiliser le paramètre ou l'utilisateur courant
    v_user_id := COALESCE(p_user_id, auth.uid());
    
    IF v_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    RETURN EXISTS (
        SELECT 1 FROM velmo_admins 
        WHERE user_id = v_user_id 
        AND role = 'super_admin'
        AND is_active = TRUE
    );
END;
$$;

-- ================================================================
-- 3️⃣ FONCTION: is_velmo_admin (any admin role)
-- ================================================================

CREATE OR REPLACE FUNCTION is_velmo_admin(p_user_id UUID DEFAULT NULL)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := COALESCE(p_user_id, auth.uid());
    
    IF v_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    RETURN EXISTS (
        SELECT 1 FROM velmo_admins 
        WHERE user_id = v_user_id 
        AND is_active = TRUE
    );
END;
$$;

-- ================================================================
-- 4️⃣ VUE: v_admin_platform_stats (Stats globales)
-- ================================================================

DROP VIEW IF EXISTS v_admin_platform_stats CASCADE;

CREATE OR REPLACE VIEW v_admin_platform_stats AS
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

-- ================================================================
-- 5️⃣ VUE: v_admin_daily_sales (Ventes par jour)
-- ================================================================

DROP VIEW IF EXISTS v_admin_daily_sales CASCADE;

CREATE OR REPLACE VIEW v_admin_daily_sales AS
SELECT 
    DATE(created_at) as sale_date,
    COUNT(*) as sales_count,
    COALESCE(SUM(total_amount), 0) as total_amount,
    COALESCE(SUM(total_profit), 0) as total_profit,
    COUNT(DISTINCT shop_id) as active_shops
FROM sales
WHERE created_at >= NOW() - INTERVAL '90 days'
GROUP BY DATE(created_at)
ORDER BY sale_date DESC;

-- ================================================================
-- 6️⃣ VUE: v_admin_shops_overview (Aperçu boutiques)
-- ================================================================

DROP VIEW IF EXISTS v_admin_shops_overview CASCADE;

CREATE OR REPLACE VIEW v_admin_shops_overview AS
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
    -- Stats calculées via sous-requêtes
    (SELECT COUNT(*) FROM products p WHERE p.shop_id = s.id AND p.is_active = TRUE) as products_count,
    (SELECT COUNT(*) FROM sales sa WHERE sa.shop_id = s.id) as total_sales,
    (SELECT COALESCE(SUM(sa.total_amount), 0) FROM sales sa WHERE sa.shop_id = s.id) as total_revenue,
    (SELECT COALESCE(SUM(sa.total_profit), 0) FROM sales sa WHERE sa.shop_id = s.id) as total_profit,
    (SELECT COUNT(*) FROM debts d WHERE d.shop_id = s.id AND d.status NOT IN ('paid', 'cancelled')) as active_debts,
    (SELECT COALESCE(SUM(d.remaining_amount), 0) FROM debts d WHERE d.shop_id = s.id AND d.status NOT IN ('paid', 'cancelled')) as total_outstanding_debt,
    (SELECT COUNT(*) FROM shop_members sm WHERE sm.shop_id = s.id AND sm.is_active = TRUE) as team_size,
    (SELECT MAX(sa.created_at) FROM sales sa WHERE sa.shop_id = s.id) as last_sale_at
FROM shops s
LEFT JOIN users u ON s.owner_id = u.id
ORDER BY s.created_at DESC;

-- ================================================================
-- 7️⃣ VUE: v_admin_stock_alerts (Alertes stock)
-- ================================================================

DROP VIEW IF EXISTS v_admin_stock_alerts CASCADE;

CREATE OR REPLACE VIEW v_admin_stock_alerts AS
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
AND p.quantity <= p.stock_alert
ORDER BY p.quantity ASC;

-- ================================================================
-- 8️⃣ VUE: v_admin_realtime_activity (Activité récente)
-- ================================================================

DROP VIEW IF EXISTS v_admin_realtime_activity CASCADE;

CREATE OR REPLACE VIEW v_admin_realtime_activity AS
SELECT * FROM (
    SELECT 
        'sale'::TEXT as activity_type,
        s.id as entity_id,
        sh.name as shop_name,
        sh.id as shop_id,
        s.total_amount as amount,
        s.created_at as activity_at,
        NULL::TEXT as status
    FROM sales s
    INNER JOIN shops sh ON s.shop_id = sh.id
    WHERE s.created_at >= NOW() - INTERVAL '1 hour'
    
    UNION ALL
    
    SELECT 
        'debt'::TEXT as activity_type,
        d.id as entity_id,
        sh.name as shop_name,
        sh.id as shop_id,
        d.total_amount as amount,
        d.created_at as activity_at,
        d.status::TEXT as status
    FROM debts d
    INNER JOIN shops sh ON d.shop_id = sh.id
    WHERE d.created_at >= NOW() - INTERVAL '1 hour'
    
    UNION ALL
    
    SELECT 
        'user_created'::TEXT as activity_type,
        u.id as entity_id,
        COALESCE(s.name, 'N/A') as shop_name,
        s.id as shop_id,
        NULL::NUMERIC as amount,
        u.created_at as activity_at,
        NULL::TEXT as status
    FROM users u
    LEFT JOIN shops s ON u.shop_id = s.id
    WHERE u.created_at >= NOW() - INTERVAL '1 hour'
) activities
ORDER BY activity_at DESC
LIMIT 100;

-- ================================================================
-- 9️⃣ RPC: admin_get_shop_details
-- ================================================================

CREATE OR REPLACE FUNCTION admin_get_shop_details(
    p_admin_user_id UUID,
    p_shop_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
    v_shop JSONB;
    v_owner JSONB;
    v_stats JSONB;
BEGIN
    -- Vérifier admin
    IF NOT is_velmo_admin(p_admin_user_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;
    
    -- Shop
    SELECT to_jsonb(s) INTO v_shop
    FROM shops s WHERE s.id = p_shop_id;
    
    IF v_shop IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Shop not found');
    END IF;
    
    -- Owner
    SELECT to_jsonb(u) INTO v_owner
    FROM users u WHERE u.id = (v_shop->>'owner_id')::UUID;
    
    -- Stats
    v_stats := jsonb_build_object(
        'products_count', (SELECT COUNT(*) FROM products WHERE shop_id = p_shop_id AND is_active = TRUE),
        'total_sales', (SELECT COUNT(*) FROM sales WHERE shop_id = p_shop_id),
        'total_revenue', (SELECT COALESCE(SUM(total_amount), 0) FROM sales WHERE shop_id = p_shop_id),
        'sales_last_7d', (SELECT COUNT(*) FROM sales WHERE shop_id = p_shop_id AND created_at >= NOW() - INTERVAL '7 days'),
        'revenue_last_7d', (SELECT COALESCE(SUM(total_amount), 0) FROM sales WHERE shop_id = p_shop_id AND created_at >= NOW() - INTERVAL '7 days'),
        'active_debts', (SELECT COUNT(*) FROM debts WHERE shop_id = p_shop_id AND status NOT IN ('paid', 'cancelled')),
        'total_debt_amount', (SELECT COALESCE(SUM(remaining_amount), 0) FROM debts WHERE shop_id = p_shop_id AND status NOT IN ('paid', 'cancelled')),
        'team_members', (SELECT COUNT(*) FROM shop_members WHERE shop_id = p_shop_id AND is_active = TRUE)
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'shop', v_shop,
            'owner', v_owner,
            'stats', v_stats,
            'recent_sales', (
                SELECT COALESCE(jsonb_agg(to_jsonb(sa)), '[]'::JSONB) 
                FROM (SELECT * FROM sales WHERE shop_id = p_shop_id ORDER BY created_at DESC LIMIT 10) sa
            )
        )
    );
END;
$$;

-- ================================================================
-- 🔟 RPC: admin_search_shops
-- ================================================================

CREATE OR REPLACE FUNCTION admin_search_shops(
    p_admin_user_id UUID,
    p_search_term TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 50
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    IF NOT is_velmo_admin(p_admin_user_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;
    
    SELECT jsonb_agg(row_to_json(t)) INTO v_result
    FROM (
        SELECT 
            s.id, 
            s.velmo_id, 
            s.name, 
            s.category, 
            s.is_active, 
            s.created_at,
            u.first_name || ' ' || u.last_name as owner_name,
            u.phone as owner_phone
        FROM shops s
        INNER JOIN users u ON s.owner_id = u.id
        WHERE (
            p_search_term IS NULL 
            OR s.name ILIKE '%' || p_search_term || '%'
            OR s.velmo_id ILIKE '%' || p_search_term || '%'
            OR u.phone ILIKE '%' || p_search_term || '%'
        )
        ORDER BY s.created_at DESC
        LIMIT p_limit
    ) t;
    
    RETURN jsonb_build_object('success', true, 'data', COALESCE(v_result, '[]'::JSONB));
END;
$$;

-- ================================================================
-- 🔐 PERMISSIONS
-- ================================================================

-- Tables
GRANT SELECT ON velmo_admins TO authenticated;
GRANT ALL ON velmo_admins TO service_role;

-- Vues
GRANT SELECT ON v_admin_platform_stats TO authenticated;
GRANT SELECT ON v_admin_daily_sales TO authenticated;
GRANT SELECT ON v_admin_shops_overview TO authenticated;
GRANT SELECT ON v_admin_stock_alerts TO authenticated;
GRANT SELECT ON v_admin_realtime_activity TO authenticated;

-- Fonctions
GRANT EXECUTE ON FUNCTION is_velmo_super_admin TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION is_velmo_admin TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION admin_get_shop_details TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION admin_search_shops TO authenticated, service_role;

-- ================================================================
-- ✅ VERIFICATION
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ MIGRATION 080 - ADMIN DASHBOARD';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📦 Table créée: velmo_admins';
    RAISE NOTICE '🔐 Fonctions: is_velmo_super_admin, is_velmo_admin';
    RAISE NOTICE '📊 Vues: v_admin_platform_stats, v_admin_daily_sales';
    RAISE NOTICE '📊 Vues: v_admin_shops_overview, v_admin_stock_alerts';
    RAISE NOTICE '📊 Vues: v_admin_realtime_activity';
    RAISE NOTICE '🔧 RPC: admin_get_shop_details, admin_search_shops';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️ IMPORTANT: Créez le premier super_admin avec:';
    RAISE NOTICE 'INSERT INTO velmo_admins (user_id, role)';
    RAISE NOTICE 'VALUES (''YOUR_AUTH_USER_UUID'', ''super_admin'');';
    RAISE NOTICE '';
END $$;

COMMIT;
