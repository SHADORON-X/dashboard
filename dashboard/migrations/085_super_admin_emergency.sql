-- ================================================================
-- 🔐 MIGRATION 085: SUPER ADMIN EMERGENCY ACCESS
-- ================================================================
-- Objectif: Débloquer l'accès RLS via l'email direct (méthode infaillible)
-- ================================================================

BEGIN;

-- 1. DROP OLD POLICIES (Nettoyage)
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.shops;
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.users;
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.products;
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.sales;
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.debts;
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.debt_payments;
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.shop_members;
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.audit_logs;

-- 2. CREATE NEW "SUPER POLICY"
-- Cette politique vérifie si l'email dans le JWT se termine par @gmail.com (pour test large)
-- OU MIEUX : Si l'utilisateur est présent dans la table admin_users (sans passer par une fonction complexe)

-- SHOPS
CREATE POLICY "Super Admin Access" ON public.shops
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.admin_users 
    WHERE id = auth.uid()
  )
);

-- USERS
CREATE POLICY "Super Admin Access" ON public.users
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.admin_users 
    WHERE id = auth.uid()
  )
);

-- PRODUCTS
CREATE POLICY "Super Admin Access" ON public.products
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.admin_users 
    WHERE id = auth.uid()
  )
);

-- SALES
CREATE POLICY "Super Admin Access" ON public.sales
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.admin_users 
    WHERE id = auth.uid()
  )
);

-- DEBTS
CREATE POLICY "Super Admin Access" ON public.debts
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.admin_users 
    WHERE id = auth.uid()
  )
);

-- DEBT_PAYMENTS
CREATE POLICY "Super Admin Access" ON public.debt_payments
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.admin_users 
    WHERE id = auth.uid()
  )
);

-- SHOP_MEMBERS
CREATE POLICY "Super Admin Access" ON public.shop_members
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.admin_users 
    WHERE id = auth.uid()
  )
);

-- AUDIT_LOGS
CREATE POLICY "Super Admin Access" ON public.audit_logs
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.admin_users 
    WHERE id = auth.uid()
  )
);

RAISE NOTICE '✅ Accès Super Admin débloqué via vérification directe.';

COMMIT;
