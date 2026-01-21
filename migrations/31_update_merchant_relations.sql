-- ================================================================
-- 🔥 MIGRATION 31: UPDATE MERCHANT RELATIONS
-- ================================================================
-- Date: 26 Décembre 2025
-- Objectif: Mettre à jour la table merchant_relations pour correspondre
-- aux spécifications complètes du système de liaison.
-- ================================================================

-- 1. Ajouter les colonnes manquantes
ALTER TABLE merchant_relations
ADD COLUMN IF NOT EXISTS shop_a_name TEXT,
ADD COLUMN IF NOT EXISTS shop_b_name TEXT,
ADD COLUMN IF NOT EXISTS shop_a_velmo_id TEXT,
ADD COLUMN IF NOT EXISTS shop_b_velmo_id TEXT,
ADD COLUMN IF NOT EXISTS shop_a_phone TEXT,
ADD COLUMN IF NOT EXISTS shop_b_phone TEXT,
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'suspended', 'rejected')),
ADD COLUMN IF NOT EXISTS initiated_by UUID,
ADD COLUMN IF NOT EXISTS shop_a_owes DECIMAL(12, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS shop_b_owes DECIMAL(12, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS net_balance DECIMAL(12, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_transactions INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_compensations INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_transaction_date TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS relationship_score INTEGER DEFAULT 50 CHECK (relationship_score >= 0 AND relationship_score <= 100),
ADD COLUMN IF NOT EXISTS relationship_status TEXT DEFAULT 'healthy' CHECK (relationship_status IN ('healthy', 'balanced', 'unbalanced', 'toxic')),
ADD COLUMN IF NOT EXISTS notes TEXT,
ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ;

-- 2. Supprimer les anciennes colonnes si elles existent et sont redondantes (optionnel, on garde pour compatibilité si besoin)
-- ALTER TABLE merchant_relations DROP COLUMN IF EXISTS a_owes_b;
-- ALTER TABLE merchant_relations DROP COLUMN IF EXISTS b_owes_a;

-- 3. Index supplémentaires
CREATE INDEX IF NOT EXISTS idx_merchant_relations_status ON merchant_relations(status);

-- 4. Fonction pour recalculer les soldes
CREATE OR REPLACE FUNCTION recalculate_relation_balances(p_relation_id UUID)
RETURNS VOID AS $$
DECLARE
    v_relation RECORD;
    v_shop_a_owes DECIMAL(12, 2);
    v_shop_b_owes DECIMAL(12, 2);
BEGIN
    SELECT * INTO v_relation FROM merchant_relations WHERE id = p_relation_id;
    
    -- Calculer ce que A doit à B (Dettes de A vers B)
    -- On cherche les dettes où shop_id = A et customer_name = Nom de B (ou lié via debtor_id si on l'avait)
    -- Pour l'instant on se base sur le nom ou une liaison plus forte si disponible
    SELECT COALESCE(SUM(remaining_amount), 0) INTO v_shop_a_owes
    FROM debts
    WHERE shop_id = v_relation.shop_a_id
      AND (customer_name = v_relation.shop_b_name OR velmo_id = v_relation.shop_b_velmo_id);
    
    -- Calculer ce que B doit à A
    SELECT COALESCE(SUM(remaining_amount), 0) INTO v_shop_b_owes
    FROM debts
    WHERE shop_id = v_relation.shop_b_id
      AND (customer_name = v_relation.shop_a_name OR velmo_id = v_relation.shop_a_velmo_id);
    
    -- Mettre à jour
    UPDATE merchant_relations
    SET 
        shop_a_owes = v_shop_a_owes,
        shop_b_owes = v_shop_b_owes,
        net_balance = v_shop_a_owes - v_shop_b_owes,
        last_transaction_date = NOW(),
        updated_at = NOW()
    WHERE id = p_relation_id;
END;
$$ LANGUAGE plpgsql;

-- 5. RPC pour créer une demande de relation
CREATE OR REPLACE FUNCTION request_merchant_relation(
    p_requester_shop_id UUID,
    p_target_velmo_id TEXT,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_target_user RECORD;
    v_target_shop RECORD;
    v_requester_shop RECORD;
    v_relation_id TEXT;
BEGIN
    -- Vérifier que l'utilisateur est propriétaire ou gérant de la boutique demandeuse
    IF NOT EXISTS (
        SELECT 1 FROM shops WHERE id = p_requester_shop_id AND owner_id = p_user_id
    ) AND NOT EXISTS (
        SELECT 1 FROM shop_members WHERE shop_id = p_requester_shop_id AND user_id = p_user_id
    ) THEN
        RAISE EXCEPTION 'Permission denied';
    END IF;

    -- ÉTAPE 1: Récupérer l'utilisateur propriétaire cible par velmo_id
    SELECT id, shop_id INTO v_target_user
    FROM users
    WHERE velmo_id = UPPER(TRIM(p_target_velmo_id))
      AND role = 'owner'
    LIMIT 1;
    
    IF v_target_user IS NULL THEN
        RAISE EXCEPTION 'Target shop not found';
    END IF;

    -- ÉTAPE 2: Récupérer la boutique cible
    SELECT * INTO v_target_shop FROM shops WHERE id = v_target_user.shop_id;
    IF v_target_shop IS NULL THEN
        RAISE EXCEPTION 'Target shop not found';
    END IF;

    -- Récupérer la boutique demandeuse
    SELECT * INTO v_requester_shop FROM shops WHERE id = p_requester_shop_id;

    -- Vérifier si relation existe déjà
    IF EXISTS (
        SELECT 1 FROM merchant_relations 
        WHERE (requester_shop_id = p_requester_shop_id AND target_shop_id = v_target_shop.id)
           OR (requester_shop_id = v_target_shop.id AND target_shop_id = p_requester_shop_id)
    ) THEN
        RAISE EXCEPTION 'Relation already exists';
    END IF;

    -- Créer la relation
    INSERT INTO merchant_relations (
        id,
        requester_shop_id, target_shop_id,
        shop_a_name, shop_b_name,
        shop_a_velmo_id, shop_b_velmo_id,
        shop_a_phone, shop_b_phone,
        status, initiated_by,
        created_at, updated_at
    ) VALUES (
        gen_random_uuid(),
        p_requester_shop_id, v_target_shop.id,
        v_requester_shop.name, v_target_shop.name,
        v_requester_shop.velmo_id, v_target_shop.velmo_id,
        v_requester_shop.phone, v_target_shop.phone,
        'pending', p_user_id,
        NOW(), NOW()
    ) RETURNING id INTO v_relation_id;

    RETURN jsonb_build_object('id', v_relation_id, 'status', 'pending');
END;
$$;

-- ================================================================
-- GRANT PERMISSIONS
-- ================================================================
GRANT EXECUTE ON FUNCTION public.request_merchant_relation(UUID, TEXT, UUID) TO authenticated, anon, service_role;
