-- ================================================================
-- 🛡️ HARDENING ARCHITECTURE - PROTECTION INDUSTRIELLE
-- ================================================================
-- Objectif : Versioning, intégrité stricte du stock, Optimistic Locking
-- ================================================================

BEGIN;

-- 1. AJOUT DU VERSIONING ET CONTRAINTES
-- On ajoute une colonne version pour gérer les conflits concurrents
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 1;

-- Protection ultime : La base de données refuse physiquement un stock négatif
-- Note: On utilise une contrainte CHECK. Si une requête tente de passer en négatif, ça crash proprement.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_quantity_positive'
    ) THEN
        ALTER TABLE products 
        ADD CONSTRAINT check_quantity_positive CHECK (quantity >= 0);
    END IF;
END $$;

-- 2. RPC ATOMIQUE INTELLIGENTE (Safe Push)
-- Cette fonction gère les conflits et le stock de manière atomique
DROP FUNCTION IF EXISTS sync_product_smart;

CREATE OR REPLACE FUNCTION sync_product_smart(
    p_user_id UUID,
    p_product_id UUID,
    p_client_version INTEGER,
    p_delta_quantity DECIMAL DEFAULT 0, -- Changement relatif (+1, -5) plutôt que valeur absolue
    p_force_data JSONB DEFAULT NULL     -- Données à mettre à jour (nom, prix...)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_version INTEGER;
    v_current_quantity DECIMAL;
    v_shop_id UUID;
    v_is_owner BOOLEAN;
BEGIN
    -- A. Vérification des permissions (Shop Access)
    SELECT shop_id INTO v_shop_id FROM products WHERE id = p_product_id;
    
    IF NOT EXISTS (
        SELECT 1 FROM shops s 
        WHERE s.id = v_shop_id 
        AND (s.owner_id = p_user_id OR EXISTS (
            SELECT 1 FROM shop_members sm WHERE sm.shop_id = s.id AND sm.user_id = p_user_id
        ))
    ) THEN
        RETURN jsonb_build_object('success', false, 'code', 'PERMISSION_DENIED');
    END IF;

    -- B. Verrouillage de la ligne (Mutex DB)
    SELECT version, quantity INTO v_current_version, v_current_quantity
    FROM products WHERE id = p_product_id FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'code', 'PRODUCT_NOT_FOUND');
    END IF;

    -- C. Détection de Conflit (Optimistic Locking)
    -- Si la version serveur est plus grande que la version client, quelqu'un a modifié entre temps.
    IF v_current_version > p_client_version THEN
        -- Stratégie de résolution :
        -- Si c'est juste une mise à jour de stock (vente), on peut essayer de l'appliquer quand même
        -- SI et SEULEMENT SI p_force_data est NULL (pas de changement de nom/prix)
        IF p_force_data IS NOT NULL THEN
             RETURN jsonb_build_object(
                'success', false, 
                'code', 'VERSION_CONFLICT',
                'server_version', v_current_version,
                'server_state', (SELECT row_to_json(p) FROM products p WHERE id = p_product_id)
            );
        END IF;
    END IF;

    -- D. Protection du Stock (Business Logic)
    IF (v_current_quantity + p_delta_quantity) < 0 THEN
        RETURN jsonb_build_object(
            'success', false, 
            'code', 'INSUFFICIENT_STOCK', 
            'current_stock', v_current_quantity,
            'requested_delta', p_delta_quantity
        );
    END IF;

    -- E. Application de la mise à jour
    UPDATE products SET
        quantity = quantity + p_delta_quantity,
        version = version + 1,
        updated_at = NOW(),
        -- Mise à jour conditionnelle des autres champs si fournis
        name = COALESCE(p_force_data->>'name', name),
        price_sale = COALESCE((p_force_data->>'price_sale')::DECIMAL, price_sale),
        price_buy = COALESCE((p_force_data->>'price_buy')::DECIMAL, price_buy),
        stock_alert = COALESCE((p_force_data->>'stock_alert')::DECIMAL, stock_alert),
        category = COALESCE(p_force_data->>'category', category),
        photo_url = COALESCE(p_force_data->>'photo_url', photo_url),
        barcode = COALESCE(p_force_data->>'barcode', barcode),
        unit = COALESCE(p_force_data->>'unit', unit),
        is_active = COALESCE((p_force_data->>'is_active')::BOOLEAN, is_active)
    WHERE id = p_product_id;

    RETURN jsonb_build_object(
        'success', true, 
        'new_version', v_current_version + 1,
        'new_stock', v_current_quantity + p_delta_quantity
    );
END;
$$;

COMMIT;

DO $$
BEGIN
    RAISE NOTICE '✅ Architecture durcie : Versioning + Check Stock + RPC Smart Sync appliqués.';
END $$;
