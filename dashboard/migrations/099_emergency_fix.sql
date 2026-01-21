-- ================================================================
-- 🚑 MIGRATION 099: EMERGENCY RLS REPAIR
-- ================================================================
-- Objectif: Réparer les erreurs 500 causées par des politiques RLS
--           défectueuses ou des récursions.
-- ================================================================

BEGIN;

-- 1. FONCTION DE SÉCURITÉ ROBUSTE (Casse la récursion RLS)
-- Cette fonction est SECURITY DEFINER : elle s'exécute avec les droits du système,
-- contournant ainsi les RLS potentielles sur la table admin_users.
CREATE OR REPLACE FUNCTION public.is_admin_safe()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public -- Sécurité: force le schema public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.admin_users 
        WHERE id = auth.uid()
    );
END;
$$;

-- 2. NETTOYAGE DES ANCIENNES POLITIQUES DOUTEUSES SUR SHOPS
DROP POLICY IF EXISTS "Dashboard Admin Full Access" ON public.shops;
DROP POLICY IF EXISTS "Admins can view all shops" ON public.shops;
DROP POLICY IF EXISTS "Dashboard Admin Read Access" ON public.shops;

-- 3. NOUVELLE POLITIQUE SHOPS (Lecture seule pour l'instant pour tester, ou ALL ?)
-- On met ALL pour permettre l'édition du status public/privé
CREATE POLICY "Admin_Full_Access_v2" ON public.shops
FOR ALL USING (
    public.is_admin_safe()
);

-- On ajoute une policy pour que les 'anon' (visiteurs web) puissent voir les shops 'is_public'
-- C'est nécessaire si on veut que 'velmo.shop/slug' fonctionne en public
CREATE POLICY "Public_View_Public_Shops" ON public.shops
FOR SELECT USING (
    is_public = true
);

-- 4. RÉPARATION TABLE CUSTOMER_ORDERS
-- Création table si manquante (copie de sécurité)
CREATE TABLE IF NOT EXISTS public.customer_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    customer_name TEXT NOT NULL,
    customer_phone TEXT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    items JSONB DEFAULT '[]'::jsonb,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'preparing', 'shipped', 'delivered', 'cancelled')),
    delivery_method TEXT DEFAULT 'pickup',
    delivery_address TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    search_vector tsvector -- Ajout optionnel pour future recherche
);

-- Sécurité customer_orders
ALTER TABLE public.customer_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view all customer orders" ON public.customer_orders;
DROP POLICY IF EXISTS "Admin_Orders_Access" ON public.customer_orders;

CREATE POLICY "Admin_Orders_Access_v2" ON public.customer_orders
FOR ALL USING (
    public.is_admin_safe()
);

-- 5. RÉPARATION TABLE NOTIFICATIONS
CREATE TABLE IF NOT EXISTS public.order_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.customer_orders(id) ON DELETE CASCADE,
    shop_id UUID REFERENCES public.shops(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.order_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view notifications" ON public.order_notifications;

CREATE POLICY "Admin_Notif_Access_v2" ON public.order_notifications
FOR ALL USING (
    public.is_admin_safe()
);

-- 6. GRANT FINAUX (Pour éviter les 403 Forbidden)
GRANT usage ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.customer_orders TO authenticated;
GRANT ALL ON public.order_notifications TO authenticated;
GRANT ALL ON public.shops TO authenticated;
GRANT SELECT ON public.admin_users TO authenticated; -- Nécessaire pour le check côté client parfois

COMMIT;
