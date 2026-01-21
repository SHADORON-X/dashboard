-- ================================================================
-- 🔐 MIGRATION 084: FIX DASHBOARD DATA ACCESS (RLS)
-- ================================================================
-- Objectif: Autoriser le dashboard (super_admin) à lire toutes les données
--           sans casser la sécurité des utilisateurs normaux.
-- ================================================================

BEGIN;

-- 1. Fonction helper pour simplifier les policies
-- (Vérifie si l'user courant est un admin autorisé)
CREATE OR REPLACE FUNCTION public.is_admin_viewer()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_users 
    WHERE id = auth.uid() 
    AND (role = 'super_admin' OR role = 'admin' OR role = 'support' OR role = 'viewer')
  );
$$;

-- 2. APPLIQUER LES POLITIQUES DE LECTURE (SELECT) POUR LE DASHBOARD

-- SHOPS
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.shops;
CREATE POLICY "Dashboard Admin Read Access" ON public.shops
FOR SELECT USING ( public.is_admin_viewer() );

-- USERS
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.users;
CREATE POLICY "Dashboard Admin Read Access" ON public.users
FOR SELECT USING ( public.is_admin_viewer() );

-- PRODUCTS
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.products;
CREATE POLICY "Dashboard Admin Read Access" ON public.products
FOR SELECT USING ( public.is_admin_viewer() );

-- SALES
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.sales;
CREATE POLICY "Dashboard Admin Read Access" ON public.sales
FOR SELECT USING ( public.is_admin_viewer() );

-- DEBTS
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.debts;
CREATE POLICY "Dashboard Admin Read Access" ON public.debts
FOR SELECT USING ( public.is_admin_viewer() );

-- DEBT PAYMENTS
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.debt_payments;
CREATE POLICY "Dashboard Admin Read Access" ON public.debt_payments
FOR SELECT USING ( public.is_admin_viewer() );

-- SHOP MEMBERS
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.shop_members;
CREATE POLICY "Dashboard Admin Read Access" ON public.shop_members
FOR SELECT USING ( public.is_admin_viewer() );

-- AUDIT LOGS
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.audit_logs;
CREATE POLICY "Dashboard Admin Read Access" ON public.audit_logs
FOR SELECT USING ( public.is_admin_viewer() );

-- 3. REFRESH DES VUES (Pour être sûr qu'elles utilisent les nouvelles policies)
-- Parfois les vues gardent d'anciennes permissions en cache

-- Rien à faire de spécial ici car les VUES utilisent le contexte de l'utilisateur qui requête (SECURITY INVOKER par défaut)
-- Sauf si elles sont SECURITY DEFINER. Nos vues 080 ne le sont (par défaut) pas, donc elles respecteront le RLS ci-dessus.

RAISE NOTICE '✅ Permissions Dashboard appliquées avec succès sur toutes les tables principales.';

COMMIT;
