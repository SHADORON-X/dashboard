-- ================================================================
-- 🚑 MIGRATION 101: TOTAL RLS REPAIR FOR ALL TABLES
-- ================================================================
-- Objectif: S'assurer que le dashboard a accès à TOUTES les tables
--           en utilisant la fonction is_admin_safe() qui évite la récursion.
-- ================================================================

BEGIN;

-- On s'assure que la fonction helper existe (déjà créée en 099 mais on sécurise)
CREATE OR REPLACE FUNCTION public.is_admin_safe()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.admin_users 
        WHERE id = auth.uid()
    );
END;
$$;

-- 1. USERS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.users;
DROP POLICY IF EXISTS "Admin_Full_Access" ON public.users;
CREATE POLICY "Admin_Full_Access_v2" ON public.users FOR ALL USING (public.is_admin_safe());

-- 2. PRODUCTS
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.products;
DROP POLICY IF EXISTS "Admin_Full_Access" ON public.products;
CREATE POLICY "Admin_Full_Access_v2" ON public.products FOR ALL USING (public.is_admin_safe());

-- 3. SALES
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.sales;
DROP POLICY IF EXISTS "Admin_Full_Access" ON public.sales;
CREATE POLICY "Admin_Full_Access_v2" ON public.sales FOR ALL USING (public.is_admin_safe());

-- 4. DEBTS
ALTER TABLE public.debts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.debts;
DROP POLICY IF EXISTS "Admin_Full_Access" ON public.debts;
CREATE POLICY "Admin_Full_Access_v2" ON public.debts FOR ALL USING (public.is_admin_safe());

-- 5. DEBT PAYMENTS
ALTER TABLE public.debt_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.debt_payments;
DROP POLICY IF EXISTS "Admin_Full_Access" ON public.debt_payments;
CREATE POLICY "Admin_Full_Access_v2" ON public.debt_payments FOR ALL USING (public.is_admin_safe());

-- 6. SHOP MEMBERS
ALTER TABLE public.shop_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.shop_members;
DROP POLICY IF EXISTS "Admin_Full_Access" ON public.shop_members;
CREATE POLICY "Admin_Full_Access_v2" ON public.shop_members FOR ALL USING (public.is_admin_safe());

-- 7. AUDIT LOGS
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.audit_logs;
DROP POLICY IF EXISTS "Admin_Full_Access" ON public.audit_logs;
CREATE POLICY "Admin_Full_Access_v2" ON public.audit_logs FOR ALL USING (public.is_admin_safe());

-- GRANTS
GRANT ALL ON public.users TO authenticated;
GRANT ALL ON public.products TO authenticated;
GRANT ALL ON public.sales TO authenticated;
GRANT ALL ON public.debts TO authenticated;
GRANT ALL ON public.debt_payments TO authenticated;
GRANT ALL ON public.shop_members TO authenticated;
GRANT ALL ON public.audit_logs TO authenticated;

COMMIT;
