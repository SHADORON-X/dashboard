-- ================================================================
-- 🛠️ MIGRATION 098: ENSURE SCHEMA INTEGRITY
-- ================================================================
-- Objectif: Garantir que les tables et colonnes requises existent
--           et que les relations (Foreign Keys) sont correctes.
-- ================================================================

BEGIN;

-- 1. S'ASSURER QUE LA COLONNE SLUG EXISTE SUR SHOPS
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS slug TEXT;
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT false;

-- Index sur le slug pour la performance
CREATE INDEX IF NOT EXISTS idx_shops_slug ON public.shops(slug);

-- 2. CRÉATION DE LA TABLE CUSTOMER_ORDERS (Si manquante)
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
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index pour les tris et filtres
CREATE INDEX IF NOT EXISTS idx_customer_orders_shop_id ON public.customer_orders(shop_id);
CREATE INDEX IF NOT EXISTS idx_customer_orders_status ON public.customer_orders(status);
CREATE INDEX IF NOT EXISTS idx_customer_orders_created_at ON public.customer_orders(created_at DESC);

-- 3. CRÉATION DE LA TABLE ORDER_NOTIFICATIONS (Si manquante)
CREATE TABLE IF NOT EXISTS public.order_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.customer_orders(id) ON DELETE CASCADE,
    shop_id UUID REFERENCES public.shops(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. VÉRIFICATION DES PERMISSIONS (Au cas où 097 n'est pas passé)
ALTER TABLE public.customer_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_notifications ENABLE ROW LEVEL SECURITY;

-- Accès Admin via admin_users
DROP POLICY IF EXISTS "Admins can view all customer orders" ON public.customer_orders;
CREATE POLICY "Admins can view all customer orders" ON public.customer_orders
FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.admin_users WHERE id = auth.uid())
);

DROP POLICY IF EXISTS "Admins can view notifications" ON public.order_notifications;
CREATE POLICY "Admins can view notifications" ON public.order_notifications
FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.admin_users WHERE id = auth.uid())
);

GRANT SELECT, INSERT, UPDATE ON public.customer_orders TO authenticated;
GRANT SELECT, UPDATE ON public.order_notifications TO authenticated;

COMMIT;
