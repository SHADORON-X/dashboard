-- Supprimer TOUTES les versions de sync_pull_table
DROP FUNCTION IF EXISTS sync_pull_table CASCADE;
DROP FUNCTION IF EXISTS sync_pull_table(TEXT, TIMESTAMPTZ, UUID) CASCADE;
DROP FUNCTION IF EXISTS sync_pull_table(TEXT, TIMESTAMP, UUID) CASCADE;
DROP FUNCTION IF EXISTS sync_pull_table(TEXT, TEXT, UUID) CASCADE;

-- Maintenant on peut créer la nouvelle version
CREATE OR REPLACE FUNCTION sync_pull_table(
    p_table_name TEXT,
    p_last_sync_time TIMESTAMPTZ,
    p_user_id UUID
)
RETURNS TABLE(
    id UUID,
    data JSONB,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_shop_id UUID;
BEGIN
    -- Récupérer le shop_id de l'utilisateur
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'User not found or not associated with a shop';
    END IF;
    
    -- Router vers la bonne table
    IF p_table_name = 'products' THEN
        RETURN QUERY
        SELECT 
            p.id,
            to_jsonb(p.*) as data,
            p.updated_at
        FROM products p
        WHERE p.shop_id = v_shop_id
        AND p.updated_at > p_last_sync_time
        ORDER BY p.updated_at ASC;
        
    ELSIF p_table_name = 'sales' THEN
        RETURN QUERY
        SELECT 
            s.id,
            to_jsonb(s.*) as data,
            s.updated_at
        FROM sales s
        WHERE s.shop_id = v_shop_id
        AND s.updated_at > p_last_sync_time
        ORDER BY s.updated_at ASC;
        
    ELSIF p_table_name = 'sale_items' THEN
        RETURN QUERY
        SELECT 
            si.id,
            to_jsonb(si.*) as data,
            si.created_at as updated_at
        FROM sale_items si
        JOIN sales s ON s.id = si.sale_id
        WHERE s.shop_id = v_shop_id
        AND si.created_at > p_last_sync_time
        ORDER BY si.created_at ASC;
        
    ELSIF p_table_name = 'shops' THEN
        RETURN QUERY
        SELECT 
            sh.id,
            to_jsonb(sh.*) as data,
            sh.updated_at
        FROM shops sh
        WHERE sh.id = v_shop_id
        AND sh.updated_at > p_last_sync_time
        ORDER BY sh.updated_at ASC;
        
    ELSIF p_table_name = 'debts' THEN
        RETURN QUERY
        SELECT 
            d.id,
            to_jsonb(d.*) as data,
            d.updated_at
        FROM debts d
        WHERE d.shop_id = v_shop_id
        AND d.updated_at > p_last_sync_time
        ORDER BY d.updated_at ASC;
        
    ELSIF p_table_name = 'debt_payments' THEN
        RETURN QUERY
        SELECT 
            dp.id,
            to_jsonb(dp.*) as data,
            dp.created_at as updated_at
        FROM debt_payments dp
        JOIN debts d ON d.id = dp.debt_id
        WHERE d.shop_id = v_shop_id
        AND dp.created_at > p_last_sync_time
        ORDER BY dp.created_at ASC;
        
    ELSIF p_table_name = 'merchant_relations' THEN
        RETURN QUERY
        SELECT 
            mr.id,
            to_jsonb(mr.*) as data,
            mr.updated_at
        FROM merchant_relations mr
        WHERE mr.shop_id = v_shop_id
        AND mr.updated_at > p_last_sync_time
        ORDER BY mr.updated_at ASC;
        
    ELSIF p_table_name = 'orders' THEN
        RETURN QUERY
        SELECT 
            o.id,
            to_jsonb(o.*) as data,
            o.updated_at
        FROM orders o
        WHERE o.shop_id = v_shop_id
        AND o.updated_at > p_last_sync_time
        ORDER BY o.updated_at ASC;
        
    ELSIF p_table_name = 'order_items' THEN
        RETURN QUERY
        SELECT 
            oi.id,
            to_jsonb(oi.*) as data,
            oi.created_at as updated_at
        FROM order_items oi
        JOIN orders o ON o.id = oi.order_id
        WHERE o.shop_id = v_shop_id
        AND oi.created_at > p_last_sync_time
        ORDER BY oi.created_at ASC;
        
    ELSE
        RAISE EXCEPTION 'Table % not supported for sync_pull_table', p_table_name;
    END IF;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION sync_pull_table TO authenticated;
