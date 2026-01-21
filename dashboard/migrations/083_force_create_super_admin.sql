-- ================================================================
-- 🔐 MIGRATION 083: FORCE CREATE SUPER ADMIN
-- ================================================================
-- Objectif: Créer manuellement un utilisateur Super Admin avec mot de passe
-- Email: cyberninjatyper20@gmail.com
-- Pass : 2009Diallo
-- ================================================================

BEGIN;

-- 1. Activer l'extension pgcrypto pour le hachage du mot de passe
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Variables pour le script
DO $$
DECLARE
  v_user_id UUID;
  v_email TEXT := 'cyberninjatyper20@gmail.com';
  v_password TEXT := '2009Diallo';
BEGIN

  -- 3. Nettoyage si l'utilisateur existe déjà (pour éviter les erreurs de duplicatas lors des tests)
  -- Attention: Cela supprime l'ancien compte s'il existe !
  DELETE FROM auth.users WHERE email = v_email;

  -- 4. Insertion dans auth.users (la table système de Supabase)
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    recovery_sent_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000', -- instance_id par défaut Supabase
    gen_random_uuid(), -- ID généré
    'authenticated',
    'authenticated',
    v_email,
    crypt(v_password, gen_salt('bf')), -- Hachage sécurisé du mot de passe
    NOW(), -- Email confirmé immédiatement
    NOW(),
    NOW(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    NOW(),
    NOW(),
    '',
    '',
    '',
    ''
  )
  RETURNING id INTO v_user_id;

  -- 5. Insertion / Mise à jour dans admin_users avec le rôle SUPER_ADMIN
  -- On utilise ON CONFLICT au cas où le trigger auto_admin l'aurait déjà créé
  INSERT INTO public.admin_users (id, email, role)
  VALUES (v_user_id, v_email, 'super_admin')
  ON CONFLICT (id) 
  DO UPDATE SET role = 'super_admin'; 

  RAISE NOTICE '✅ Utilisateur créé avec succès : % (ID: %)', v_email, v_user_id;

END $$;

COMMIT;
