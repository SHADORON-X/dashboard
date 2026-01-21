-- ================================================================
-- 🔐 MIGRATION 081: AUTH SYSTEM (STRICT)
-- ================================================================
-- Objectif: Sécurité Auth Supabase + Table admin_users
-- ================================================================

BEGIN;

-- 1. Nettoyage de l'ancienne tentative (si elle existe)
DROP TABLE IF EXISTS velmo_admins CASCADE;
DROP TABLE IF EXISTS admin_users CASCADE;

-- 2. Table admin_users (Strictement liée à auth.users)
CREATE TABLE public.admin_users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('super_admin', 'admin', 'viewer')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Contrainte d'unicité sur l'email pour éviter les doublons logiques
  CONSTRAINT admin_users_email_key UNIQUE (email)
);

-- 3. RLS (Sécurité)
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

-- Politique: Les admins peuvent lire leur propre ligne (pour vérifier leur rôle)
CREATE POLICY "Admins can read own row"
ON public.admin_users
FOR SELECT
USING (auth.uid() = id);

-- Politique: Les super_admin peuvent tout voir (gestion d'équipe future)
CREATE POLICY "Super admins can view all"
ON public.admin_users
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE id = auth.uid() AND role = 'super_admin'
  )
);

-- 4. Fonction utilitaire pour vérifier les droits (RPC)
-- Permet de vérifier facilement côté frontend sans exposer toute la table
CREATE OR REPLACE FUNCTION check_admin_access()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text;
BEGIN
  SELECT role INTO v_role
  FROM public.admin_users
  WHERE id = auth.uid();
  
  IF v_role IS NULL THEN
    RETURN jsonb_build_object('authorized', false);
  ELSE
    RETURN jsonb_build_object('authorized', true, 'role', v_role);
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION check_admin_access TO authenticated;

COMMIT;
