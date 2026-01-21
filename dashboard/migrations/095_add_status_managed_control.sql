-- ================================================================
-- 🚀 MIGRATION 095: DYNAMIC CONTROL & STATUS
-- ================================================================
-- Objectif: Ajouter le contrôle de statut granulaire (actif, suspendu, bloqué)
-- pour les utilisateurs et les boutiques, conformément aux exigences
-- du Control Center.
-- ================================================================

BEGIN;

-- 1. Ajout des colonnes de statut si elles n'existent pas
-- Pour les utilisateurs
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'status') THEN
        ALTER TABLE public.users ADD COLUMN status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'blocked'));
    END IF;
END $$;

-- Pour les boutiques
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'shops' AND column_name = 'status') THEN
        ALTER TABLE public.shops ADD COLUMN status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'cancelled'));
    END IF;
END $$;

-- 2. Synchronisation initiale avec is_active
UPDATE public.users SET status = CASE WHEN is_active = FALSE THEN 'suspended' ELSE 'active' END;
UPDATE public.shops SET status = CASE WHEN is_active = FALSE THEN 'suspended' ELSE 'active' END;

-- 3. Mise à jour des vues pour inclure le nouveau statut
-- Vue: Aperçu des boutiques (inclut maintenant le statut texte)
DROP VIEW IF EXISTS v_admin_shops_overview CASCADE;
CREATE OR REPLACE VIEW v_admin_shops_overview AS
SELECT 
    s.id as shop_id,
    s.velmo_id as shop_velmo_id,
    s.name as shop_name,
    s.category,
    s.is_active,
    s.status, -- Nouveau
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
    (SELECT COUNT(*) FROM shop_members sm WHERE sm.shop_id = s.id AND sm.is_active = TRUE) as team_size,
    (SELECT MAX(sa.created_at) FROM sales sa WHERE sa.shop_id = s.id) as last_sale_at
FROM shops s
LEFT JOIN users u ON s.owner_id = u.id
ORDER BY s.created_at DESC;

-- 4. Permissions God Mode
-- S'assurer que les admins du dashboard peuvent modifier ces statuts
-- On réutilise la politique existante Dashboard_Admin_Power si elle existe
-- ou on en crée une spécifique.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Admins_Update_Status_Power'
    ) THEN
        CREATE POLICY "Admins_Update_Status_Power" ON public.users FOR UPDATE USING (
            EXISTS (SELECT 1 FROM admin_users WHERE id = auth.uid()) OR 
            EXISTS (SELECT 1 FROM velmo_admins WHERE user_id = auth.uid())
        );
        
        CREATE POLICY "Admins_Update_Shop_Status_Power" ON public.shops FOR UPDATE USING (
            EXISTS (SELECT 1 FROM admin_users WHERE id = auth.uid()) OR 
            EXISTS (SELECT 1 FROM velmo_admins WHERE user_id = auth.uid())
        );
    END IF;
END $$;

COMMIT;
