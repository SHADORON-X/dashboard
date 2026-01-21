-- ================================================================
-- 🔐 MIGRATION 097: FIX ONLINE SHOP FEATURES RLS
-- ================================================================
-- Objectif: Autoriser les administrateurs du dashboard à accéder
--           aux nouvelles tables Online Shop (commandes, slugs, etc.)
-- ================================================================

BEGIN;

-- 1. S'ASSURER QUE LES TABLES EXISTENT
ALTER TABLE IF EXISTS public.customer_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.order_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.customer_favorites ENABLE ROW LEVEL SECURITY;

-- 2. POLITIQUES POUR CUSTOMER_ORDERS
DROP POLICY IF EXISTS "Admins can view all customer orders" ON public.customer_orders;
CREATE POLICY "Admins can view all customer orders" ON public.customer_orders
FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.admin_users WHERE id = auth.uid())
);

-- 3. POLITIQUES POUR SHOPS (Renforcement pour SELECT)
-- On s'assure que si un admin est connecté, il voit TOUT sans exception
-- Utilisation de admin_users qui est la table de référence
DROP POLICY IF EXISTS "Dashboard Admin Full Access" ON public.shops;
CREATE POLICY "Dashboard Admin Full Access" ON public.shops
FOR ALL USING (
  EXISTS (SELECT 1 FROM public.admin_users WHERE id = auth.uid())
);

-- 4. POLITIQUES POUR LES AUTRES TABLES ONLINE
DROP POLICY IF EXISTS "Admins can view notifications" ON public.order_notifications;
CREATE POLICY "Admins can view notifications" ON public.order_notifications
FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.admin_users WHERE id = auth.uid())
);

-- 5. AUTORISER LES JOINS (Cas des 403 sur les relations)
-- Parfois Supabase nécessite des SELECT sur les Foreign Keys
GRANT SELECT ON public.customer_orders TO authenticated;
GRANT SELECT ON public.shops TO authenticated;
GRANT SELECT ON public.users TO authenticated;

COMMIT;
