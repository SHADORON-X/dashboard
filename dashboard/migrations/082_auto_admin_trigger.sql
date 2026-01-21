-- ================================================================
-- 🔐 MIGRATION 082: AUTO ADMIN TRIGGER
-- ================================================================
-- Objectif: Ajouter automatiquement les nouveaux inscrits dans admin_users
--           avec le rôle 'viewer' pour éviter l'erreur "Accès refusé"
-- ================================================================

-- 1. Fonction du Trigger
CREATE OR REPLACE FUNCTION public.handle_new_admin_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.admin_users (id, email, role)
  VALUES (
    NEW.id,
    NEW.email,
    'viewer' -- Rôle par défaut (sécurisé)
    -- Vous devrez changer ce rôle manuellement en 'super_admin' via SQL ou Dashboard pour avoir tous les droits
  )
  ON CONFLICT (id) DO NOTHING;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Création du Trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_admin_user();

-- 3. (Optionnel pour Dev) Si vous avez déjà créé l'utilisateur mais qu'il n'est pas dans admin_users
-- Insère tous les users existants qui manqueraient (sauf s'ils existent déjà)
INSERT INTO public.admin_users (id, email, role, created_at)
SELECT id, email, 'viewer', created_at
FROM auth.users
ON CONFLICT (id) DO NOTHING;

/*
  👉 APRÈS AVOIR EXÉCUTÉ CE SCRIPT :
  
  1. Inscrivez-vous sur le dashboard (/signup)
  2. Vous aurez l'accès 'viewer'
  3. Pour devenir SUPER ADMIN, exécutez ensuite :
     
     UPDATE public.admin_users 
     SET role = 'super_admin' 
     WHERE email = 'votre@email.com';
*/
