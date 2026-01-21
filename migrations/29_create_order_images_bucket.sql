-- ================================================================
-- 🔥 MIGRATION 29: CRÉER BUCKET ORDER-IMAGES
-- ================================================================
-- Date: 26 Décembre 2025
-- Objectif: Créer le bucket de stockage pour les images de commande
-- 
-- ================================================================

BEGIN;

-- 1. Créer le bucket s'il n'existe pas
INSERT INTO storage.buckets (id, name, public)
VALUES ('order-images', 'order-images', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Activer RLS sur storage.objects (normalement déjà actif)
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 3. Supprimer les anciennes politiques pour éviter les conflits
DROP POLICY IF EXISTS "Public Access Order Images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Upload Order Images" ON storage.objects;
DROP POLICY IF EXISTS "Owner Update Order Images" ON storage.objects;
DROP POLICY IF EXISTS "Owner Delete Order Images" ON storage.objects;

-- 4. Créer les politiques

-- Lecture publique (tout le monde peut voir les images s'ils ont le lien)
CREATE POLICY "Public Access Order Images"
ON storage.objects FOR SELECT
USING ( bucket_id = 'order-images' );

-- Upload authentifié (seuls les utilisateurs connectés peuvent uploader)
CREATE POLICY "Authenticated Upload Order Images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK ( bucket_id = 'order-images' );

-- Mise à jour par le propriétaire (celui qui a uploadé)
CREATE POLICY "Owner Update Order Images"
ON storage.objects FOR UPDATE
TO authenticated
USING ( bucket_id = 'order-images' AND auth.uid() = owner );

-- Suppression par le propriétaire
CREATE POLICY "Owner Delete Order Images"
ON storage.objects FOR DELETE
TO authenticated
USING ( bucket_id = 'order-images' AND auth.uid() = owner );

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ BUCKET ORDER-IMAGES CRÉÉ !';
    RAISE NOTICE '========================================';
END $$;

COMMIT;
