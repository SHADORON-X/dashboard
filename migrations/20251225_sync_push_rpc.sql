-- ==============================================================================
-- RPC: sync_push_record - Version Robuste et Simplifiée
-- Permet d'insérer/mettre à jour des enregistrements en contournant RLS
-- mais en vérifiant les permissions via vtlbes_cy (Custom Auth)
-- ==============================================================================

-- ============== PRODUCTS ==============
CREATE OR REPLACE FUNCTION sync_push_product(
    p_data JSONB,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_shop_id UUID;
    v_result JSONB;
BEGIN
    -- Vérifier que l'utilisateur appartient à la boutique
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    IF (p_data->>'shop_id')::UUID != v_shop_id THEN
        RAISE EXCEPTION 'Permission denied: shop_id mismatch';
    END IF;
    
    -- Upsert
    INSERT INTO products (
        id, velmo_id, shop_id, user_id, name, description, 
        photo_url, price_buy, price_sale, quantity, category, 
        stock_alert, is_active, created_at, updated_at
    )
    VALUES (
        (p_data->>'id')::UUID,
        p_data->>'velmo_id',
        (p_data->>'shop_id')::UUID,
        p_user_id,
        p_data->>'name',
        p_data->>'description',
        p_data->>'photo',
        (p_data->>'price_buy')::NUMERIC,
        (p_data->>'price_sale')::NUMERIC,
        (p_data->>'quantity')::INTEGER,
        p_data->>'category',
        COALESCE((p_data->>'stock_alert')::INTEGER, 5),
        COALESCE((p_data->>'is_active')::BOOLEAN, true),
        COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW()),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        photo_url = EXCLUDED.photo_url,
        price_buy = EXCLUDED.price_buy,
        price_sale = EXCLUDED.price_sale,
        quantity = EXCLUDED.quantity,
        category = EXCLUDED.category,
        stock_alert = EXCLUDED.stock_alert,
        is_active = EXCLUDED.is_active,
        updated_at = NOW()
    RETURNING to_jsonb(products.*) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- ============== SALES ==============
CREATE OR REPLACE FUNCTION sync_push_sale(
    p_data JSONB,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_shop_id UUID;
    v_result JSONB;
BEGIN
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    IF (p_data->>'shop_id')::UUID != v_shop_id THEN
        RAISE EXCEPTION 'Permission denied: shop_id mismatch';
    END IF;
    
    INSERT INTO sales (
        id, velmo_id, shop_id, user_id, total_amount, total_profit,
        payment_type, customer_name, customer_phone, notes, items_count,
        created_at, updated_at
    )
    VALUES (
        (p_data->>'id')::UUID,
        p_data->>'velmo_id',
        (p_data->>'shop_id')::UUID,
        p_user_id,
        (p_data->>'total_amount')::NUMERIC,
        (p_data->>'total_profit')::NUMERIC,
        (p_data->>'payment_type')::payment_type,
        p_data->>'customer_name',
        p_data->>'customer_phone',
        p_data->>'notes',
        (p_data->>'items_count')::INTEGER,
        COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW()),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        total_amount = EXCLUDED.total_amount,
        total_profit = EXCLUDED.total_profit,
        payment_type = EXCLUDED.payment_type,
        customer_name = EXCLUDED.customer_name,
        customer_phone = EXCLUDED.customer_phone,
        notes = EXCLUDED.notes,
        items_count = EXCLUDED.items_count,
        updated_at = NOW()
    RETURNING to_jsonb(sales.*) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- ============== SALE_ITEMS ==============
CREATE OR REPLACE FUNCTION sync_push_sale_item(
    p_data JSONB,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_shop_id UUID;
    v_sale_shop_id UUID;
    v_result JSONB;
BEGIN
    SELECT shop_id INTO v_shop_id FROM users WHERE id = p_user_id;
    
    IF v_shop_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Vérifier que la vente appartient à la boutique
    SELECT shop_id INTO v_sale_shop_id FROM sales WHERE id = (p_data->>'sale_id')::UUID;
    
    IF v_sale_shop_id != v_shop_id THEN
        RAISE EXCEPTION 'Permission denied: sale does not belong to your shop';
    END IF;
    
    INSERT INTO sale_items (
        id, sale_id, product_id, user_id, product_name,
        quantity, unit_price, purchase_price, subtotal, profit,
        created_at
    )
    VALUES (
        (p_data->>'id')::UUID,
        (p_data->>'sale_id')::UUID,
        (p_data->>'product_id')::UUID,
        p_user_id,
        p_data->>'product_name',
        (p_data->>'quantity')::INTEGER,
        (p_data->>'unit_price')::NUMERIC,
        (p_data->>'purchase_price')::NUMERIC,
        (p_data->>'subtotal')::NUMERIC,
        (p_data->>'profit')::NUMERIC,
        COALESCE((p_data->>'created_at')::TIMESTAMPTZ, NOW())
    )
    ON CONFLICT (id) DO UPDATE SET
        quantity = EXCLUDED.quantity,
        unit_price = EXCLUDED.unit_price,
        purchase_price = EXCLUDED.purchase_price,
        subtotal = EXCLUDED.subtotal,
        profit = EXCLUDED.profit
    RETURNING to_jsonb(sale_items.*) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- ============== WRAPPER GÉNÉRIQUE ==============
CREATE OR REPLACE FUNCTION sync_push_record(
    p_table_name TEXT,
    p_data JSONB,
    p_user_id UUID,
    p_operation TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    IF p_table_name = 'products' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM products WHERE id = (p_data->>'id')::UUID
            RETURNING to_jsonb(products.*) INTO v_result;
        ELSE
            v_result := sync_push_product(p_data, p_user_id);
        END IF;
        
    ELSIF p_table_name = 'sales' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM sales WHERE id = (p_data->>'id')::UUID
            RETURNING to_jsonb(sales.*) INTO v_result;
        ELSE
            v_result := sync_push_sale(p_data, p_user_id);
        END IF;
        
    ELSIF p_table_name = 'sale_items' THEN
        IF p_operation = 'delete' THEN
            DELETE FROM sale_items WHERE id = (p_data->>'id')::UUID
            RETURNING to_jsonb(sale_items.*) INTO v_result;
        ELSE
            v_result := sync_push_sale_item(p_data, p_user_id);
        END IF;
        
    ELSE
        RAISE EXCEPTION 'Table % not supported by sync_push_record', p_table_name;
    END IF;
    
    RETURN v_result;
END;
$$;
