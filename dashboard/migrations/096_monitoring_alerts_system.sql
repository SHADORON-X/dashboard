-- ================================================================
-- 🚀 MIGRATION 096: MONITORING & ALERT SYSTEM
-- ================================================================
-- Objectif: Implémenter les vues de monitoring Sentinel pour
-- détecter les anomalies, les conflits et les boutiques inactives.
-- ================================================================

BEGIN;

-- 1. Vue: Événements d'Audit Critiques ( Sentinel )
DROP VIEW IF EXISTS critical_audit_events CASCADE;
CREATE OR REPLACE VIEW critical_audit_events AS
SELECT 
    id,
    created_at as timestamp,
    event_type as type,
    details,
    severity,
    entity_type,
    entity_id,
    user_id,
    (SELECT CONCAT(first_name, ' ', last_name) FROM users WHERE id = al.user_id) as user_name,
    shop_id,
    (SELECT name FROM shops WHERE id = al.shop_id) as shop_name,
    COALESCE((metadata->>'resolved')::boolean, false) as resolved
FROM audit_logs al
WHERE severity IN ('critical', 'error', 'warning')
ORDER BY created_at DESC;

-- 2. Vue: Boutiques Silencieuses (Inactivité > 24h)
-- Utile pour l'Alert Center
DROP VIEW IF EXISTS v_admin_silent_shops CASCADE;
CREATE OR REPLACE VIEW v_admin_silent_shops AS
SELECT 
    s.id as shop_id,
    s.name as shop_name,
    s.velmo_id as shop_velmo_id,
    u.phone as owner_phone,
    (SELECT MAX(created_at) FROM sales WHERE shop_id = s.id) as last_activity_at,
    NOW() - (SELECT MAX(created_at) FROM sales WHERE shop_id = s.id) as inactivity_duration
FROM shops s
JOIN users u ON s.owner_id = u.id
WHERE s.is_active = TRUE
AND (SELECT MAX(created_at) FROM sales WHERE shop_id = s.id) < (NOW() - INTERVAL '24 hours')
OR (SELECT MAX(created_at) FROM sales WHERE shop_id = s.id) IS NULL;

-- 3. Permissions
GRANT SELECT ON critical_audit_events TO authenticated;
GRANT SELECT ON v_admin_silent_shops TO authenticated;

-- Politique God Mode pour la lecture
DROP POLICY IF EXISTS "Admins_Read_Critical_Events" ON audit_logs;
CREATE POLICY "Admins_Read_Critical_Events" ON audit_logs FOR SELECT USING (
    EXISTS (SELECT 1 FROM admin_users WHERE id = auth.uid()) OR 
    EXISTS (SELECT 1 FROM velmo_admins WHERE user_id = auth.uid())
);

COMMIT;
