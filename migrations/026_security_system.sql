-- ============================================================================
-- 🛡️ MIGRATION 026 : SYSTÈME DE SÉCURITÉ OPÉRATIONNELLE
-- ============================================================================
-- Objectif : Ajouter le système de sécurité complet pour Velmo
-- - Table audit_logs (immuable)
-- - Colonnes de sécurité sur sales
-- - Fonctions de validation
-- - Triggers de protection
-- ============================================================================

-- ============================================================================
-- 1. TABLE AUDIT_LOGS (IMMUABLE)
-- ============================================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Type d'événement
    type TEXT NOT NULL CHECK (type IN (
        'SALE_CREATED',
        'SALE_CORRECTED',
        'STOCK_FORCED',
        'SYNC_CONFLICT',
        'SYNC_REJECTED',
        'VALIDATION_FAILED',
        'SAFE_MODE_ENTERED',
        'MANUAL_RECONCILE',
        'SUSPICIOUS_ACTIVITY'
    )),
    
    -- Entité concernée
    entity_type TEXT NOT NULL CHECK (entity_type IN (
        'sale', 'product', 'stock', 'user', 'shop', 'sync'
    )),
    entity_id UUID NOT NULL,
    
    -- Contexte
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    device_id TEXT NOT NULL,
    device_name TEXT,
    shop_id UUID REFERENCES shops(id) ON DELETE CASCADE,
    
    -- Données
    timestamp BIGINT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Sévérité
    severity TEXT NOT NULL DEFAULT 'info' CHECK (severity IN (
        'info', 'warning', 'error', 'critical'
    )),
    
    -- Résolution
    resolved BOOLEAN DEFAULT FALSE,
    resolved_at BIGINT,
    resolved_by UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour performance
CREATE INDEX idx_audit_logs_type ON audit_logs(type);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_shop ON audit_logs(shop_id);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX idx_audit_logs_severity ON audit_logs(severity);
CREATE INDEX idx_audit_logs_resolved ON audit_logs(resolved) WHERE resolved = FALSE;

-- ============================================================================
-- 2. COLONNES DE SÉCURITÉ SUR SALES
-- ============================================================================

-- Ajouter les colonnes de sécurité si elles n'existent pas
ALTER TABLE sales 
ADD COLUMN IF NOT EXISTS security_metadata JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS flags TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN IF NOT EXISTS conflict BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS conflict_with UUID,
ADD COLUMN IF NOT EXISTS conflict_reason TEXT,
ADD COLUMN IF NOT EXISTS conflict_resolved_at BIGINT,
ADD COLUMN IF NOT EXISTS correction_of_sale_id UUID REFERENCES sales(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS corrected_by_sale_id UUID REFERENCES sales(id) ON DELETE SET NULL;

-- Index pour les conflits et corrections
CREATE INDEX IF NOT EXISTS idx_sales_conflict ON sales(conflict) WHERE conflict = TRUE;
CREATE INDEX IF NOT EXISTS idx_sales_correction ON sales(correction_of_sale_id) WHERE correction_of_sale_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_sales_flags ON sales USING GIN(flags);

-- ============================================================================
-- 3. TRIGGER POUR EMPÊCHER LA MODIFICATION DES VENTES
-- ============================================================================

-- Fonction pour protéger l'immutabilité des ventes
CREATE OR REPLACE FUNCTION protect_sale_immutability()
RETURNS TRIGGER AS $$
DECLARE
    grace_period INTERVAL := '1 minute';
    time_since_creation INTERVAL;
BEGIN
    -- Calculer le temps depuis la création
    time_since_creation := NOW() - OLD.created_at;
    
    -- Si modification après la période de grâce
    IF time_since_creation > grace_period THEN
        -- Vérifier si c'est une modification autorisée (résolution de conflit)
        IF NEW.conflict_resolved_at IS DISTINCT FROM OLD.conflict_resolved_at THEN
            -- Autoriser la résolution de conflit
            RETURN NEW;
        END IF;
        
        -- Sinon, bloquer la modification
        RAISE EXCEPTION 'Modification interdite : les ventes sont immuables après %', grace_period
            USING HINT = 'Créez une vente corrective au lieu de modifier la vente existante';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Créer le trigger
DROP TRIGGER IF EXISTS trigger_protect_sale_immutability ON sales;
CREATE TRIGGER trigger_protect_sale_immutability
    BEFORE UPDATE ON sales
    FOR EACH ROW
    EXECUTE FUNCTION protect_sale_immutability();

-- ============================================================================
-- 4. TRIGGER POUR EMPÊCHER LA SUPPRESSION DES VENTES
-- ============================================================================

CREATE OR REPLACE FUNCTION prevent_sale_deletion()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Suppression interdite : les ventes ne peuvent pas être supprimées'
        USING HINT = 'Créez une vente corrective au lieu de supprimer la vente';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_prevent_sale_deletion ON sales;
CREATE TRIGGER trigger_prevent_sale_deletion
    BEFORE DELETE ON sales
    FOR EACH ROW
    EXECUTE FUNCTION prevent_sale_deletion();

-- ============================================================================
-- 5. TRIGGER POUR EMPÊCHER LA MODIFICATION/SUPPRESSION DES AUDIT LOGS
-- ============================================================================

CREATE OR REPLACE FUNCTION protect_audit_log_immutability()
RETURNS TRIGGER AS $$
BEGIN
    -- Autoriser uniquement la résolution
    IF TG_OP = 'UPDATE' THEN
        IF NEW.resolved IS DISTINCT FROM OLD.resolved 
           OR NEW.resolved_at IS DISTINCT FROM OLD.resolved_at 
           OR NEW.resolved_by IS DISTINCT FROM OLD.resolved_by THEN
            -- Autoriser la résolution
            RETURN NEW;
        END IF;
        
        RAISE EXCEPTION 'Modification interdite : les logs d''audit sont immuables';
    END IF;
    
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Suppression interdite : les logs d''audit ne peuvent pas être supprimés';
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_protect_audit_log_immutability ON audit_logs;
CREATE TRIGGER trigger_protect_audit_log_immutability
    BEFORE UPDATE OR DELETE ON audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION protect_audit_log_immutability();

-- ============================================================================
-- 6. FONCTION DE VALIDATION DES VENTES
-- ============================================================================

CREATE OR REPLACE FUNCTION validate_sale_before_insert()
RETURNS TRIGGER AS $$
DECLARE
    calculated_total NUMERIC;
    items_total NUMERIC;
BEGIN
    -- Vérifier que le montant total est positif (sauf si vente corrective)
    IF NEW.total_amount < 0 AND NEW.correction_of_sale_id IS NULL THEN
        RAISE EXCEPTION 'Montant total négatif non autorisé sans vente corrective';
    END IF;
    
    -- Vérifier que le nombre d'articles est positif
    IF NEW.items_count <= 0 THEN
        RAISE EXCEPTION 'Nombre d''articles invalide : %', NEW.items_count;
    END IF;
    
    -- Vérifier les timestamps
    IF NEW.created_at > EXTRACT(EPOCH FROM NOW() + INTERVAL '5 minutes') * 1000 THEN
        RAISE EXCEPTION 'Timestamp dans le futur : %', to_timestamp(NEW.created_at / 1000);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_validate_sale_before_insert ON sales;
CREATE TRIGGER trigger_validate_sale_before_insert
    BEFORE INSERT ON sales
    FOR EACH ROW
    EXECUTE FUNCTION validate_sale_before_insert();

-- ============================================================================
-- 7. RLS (ROW LEVEL SECURITY) POUR AUDIT_LOGS
-- ============================================================================

-- Activer RLS
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Policy : Les utilisateurs peuvent voir leurs propres logs
CREATE POLICY audit_logs_select_own ON audit_logs
    FOR SELECT
    USING (
        user_id = auth.uid()
        OR shop_id IN (
            SELECT shop_id FROM shop_members WHERE user_id = auth.uid()
        )
    );

-- Policy : Les utilisateurs peuvent créer des logs
CREATE POLICY audit_logs_insert ON audit_logs
    FOR INSERT
    WITH CHECK (TRUE); -- Tout le monde peut créer des logs

-- Policy : Seuls les owners et managers peuvent résoudre les logs
CREATE POLICY audit_logs_update_resolve ON audit_logs
    FOR UPDATE
    USING (
        shop_id IN (
            SELECT shop_id FROM shop_members 
            WHERE user_id = auth.uid() 
            AND role IN ('owner', 'manager')
        )
    );

-- ============================================================================
-- 8. FONCTIONS UTILITAIRES
-- ============================================================================

-- Fonction pour compter les ventes forcées récentes
CREATE OR REPLACE FUNCTION count_recent_forced_sales(
    p_user_id UUID,
    p_shop_id UUID,
    p_hours INTEGER DEFAULT 24
)
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM audit_logs
    WHERE type = 'STOCK_FORCED'
    AND user_id = p_user_id
    AND shop_id = p_shop_id
    AND timestamp >= EXTRACT(EPOCH FROM NOW() - (p_hours || ' hours')::INTERVAL) * 1000;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour obtenir les conflits non résolus
CREATE OR REPLACE FUNCTION get_unresolved_conflicts(p_shop_id UUID)
RETURNS TABLE (
    sale_id UUID,
    conflict_type TEXT,
    created_at BIGINT,
    total_amount NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.conflict_reason,
        s.created_at,
        s.total_amount
    FROM sales s
    WHERE s.shop_id = p_shop_id
    AND s.conflict = TRUE
    AND s.conflict_resolved_at IS NULL
    ORDER BY s.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 9. VUES UTILES
-- ============================================================================

-- Vue des événements critiques
CREATE OR REPLACE VIEW critical_audit_events AS
SELECT 
    al.*,
    CONCAT(u.first_name, ' ', u.last_name) as user_name,
    s.name as shop_name
FROM audit_logs al
LEFT JOIN users u ON al.user_id = u.id
LEFT JOIN shops s ON al.shop_id = s.id
WHERE al.severity IN ('error', 'critical')
AND al.resolved = FALSE
ORDER BY al.timestamp DESC;

-- Vue des ventes suspectes
CREATE OR REPLACE VIEW suspicious_sales AS
SELECT 
    s.*,
    CONCAT(u.first_name, ' ', u.last_name) as user_name,
    COUNT(al.id) as audit_count
FROM sales s
LEFT JOIN users u ON s.user_id = u.id
LEFT JOIN audit_logs al ON al.entity_id = s.id AND al.entity_type = 'sale'
WHERE 'SUSPICIOUS' = ANY(s.flags)
OR s.conflict = TRUE
GROUP BY s.id, u.first_name, u.last_name
ORDER BY s.created_at DESC;

-- ============================================================================
-- 10. GRANTS
-- ============================================================================

-- Permissions pour les utilisateurs authentifiés
GRANT SELECT, INSERT ON audit_logs TO authenticated;
GRANT SELECT ON critical_audit_events TO authenticated;
GRANT SELECT ON suspicious_sales TO authenticated;

-- ============================================================================
-- CONFIRMATION
-- ============================================================================

SELECT '✅ Migration 026 : Système de sécurité opérationnelle appliquée avec succès' as status;
