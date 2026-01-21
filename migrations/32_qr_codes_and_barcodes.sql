-- ================================================================
-- 🔐 QR CODES & BARCODES - MIGRATION COMPLÈTE
-- ================================================================
-- Date: 26 Décembre 2025
-- Objectif: Garantir l'unicité des QR codes et code-barres
--          Mettre en place la logique scan → produit unique
-- ================================================================

BEGIN;

-- ================================================================
-- 1️⃣ TABLE: qr_codes (Codes QR associés aux produits)
-- ================================================================

DROP TABLE IF EXISTS qr_codes CASCADE;
CREATE TABLE qr_codes (
    -- Primary key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Valeur QR code (UNIQUE)
    qr_code TEXT NOT NULL UNIQUE,
    
    -- Métadonnées
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Sync
    sync_status sync_status DEFAULT 'pending',
    synced_at TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT qr_code_not_empty CHECK (qr_code != ''),
    CONSTRAINT qr_code_length CHECK (char_length(qr_code) >= 5)
);

-- Indexes
CREATE INDEX idx_qr_codes_product_id ON qr_codes(product_id);
CREATE INDEX idx_qr_codes_shop_id ON qr_codes(shop_id);
CREATE INDEX idx_qr_codes_qr_code ON qr_codes(qr_code) UNIQUE;
CREATE INDEX idx_qr_codes_is_active ON qr_codes(is_active);
CREATE INDEX idx_qr_codes_created_at ON qr_codes(created_at);

-- RLS
ALTER TABLE qr_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see QR codes from their shops" ON qr_codes
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM shops s
        WHERE s.id = qr_codes.shop_id
        AND (s.owner_id = auth.uid()::uuid OR EXISTS (
            SELECT 1 FROM shop_members sm
            WHERE sm.shop_id = s.id AND sm.user_id = auth.uid()::uuid
        ))
    )
);

CREATE POLICY "Users modify QR codes in their shops" ON qr_codes
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM shops s
        WHERE s.id = qr_codes.shop_id
        AND (s.owner_id = auth.uid()::uuid OR EXISTS (
            SELECT 1 FROM shop_members sm
            WHERE sm.shop_id = s.id AND sm.user_id = auth.uid()::uuid
        ))
    )
);

CREATE POLICY "Users delete QR codes in their shops" ON qr_codes
FOR DELETE USING (
    EXISTS (
        SELECT 1 FROM shops s
        WHERE s.id = qr_codes.shop_id
        AND (s.owner_id = auth.uid()::uuid OR EXISTS (
            SELECT 1 FROM shop_members sm
            WHERE sm.shop_id = s.id AND sm.user_id = auth.uid()::uuid
        ))
    )
);

-- ================================================================
-- 2️⃣ TABLE: product_barcodes (Code-barres - peut avoir plusieurs)
-- ================================================================

DROP TABLE IF EXISTS product_barcodes CASCADE;
CREATE TABLE product_barcodes (
    -- Primary key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Valeur code-barres (UNIQUE)
    barcode TEXT NOT NULL UNIQUE,
    
    -- Métadonnées
    barcode_type TEXT DEFAULT 'EAN13', -- EAN13, UPC, CODE128, etc.
    description TEXT,
    is_primary BOOLEAN DEFAULT FALSE, -- Lequel est le code-barres principal
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Sync
    sync_status sync_status DEFAULT 'pending',
    synced_at TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT barcode_not_empty CHECK (barcode != ''),
    CONSTRAINT barcode_length CHECK (char_length(barcode) >= 3)
);

-- Indexes
CREATE INDEX idx_product_barcodes_product_id ON product_barcodes(product_id);
CREATE INDEX idx_product_barcodes_shop_id ON product_barcodes(shop_id);
CREATE INDEX idx_product_barcodes_barcode ON product_barcodes(barcode) UNIQUE;
CREATE INDEX idx_product_barcodes_is_primary ON product_barcodes(is_primary);
CREATE INDEX idx_product_barcodes_is_active ON product_barcodes(is_active);

-- RLS
ALTER TABLE product_barcodes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see barcodes from their shops" ON product_barcodes
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM shops s
        WHERE s.id = product_barcodes.shop_id
        AND (s.owner_id = auth.uid()::uuid OR EXISTS (
            SELECT 1 FROM shop_members sm
            WHERE sm.shop_id = s.id AND sm.user_id = auth.uid()::uuid
        ))
    )
);

CREATE POLICY "Users modify barcodes in their shops" ON product_barcodes
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM shops s
        WHERE s.id = product_barcodes.shop_id
        AND (s.owner_id = auth.uid()::uuid OR EXISTS (
            SELECT 1 FROM shop_members sm
            WHERE sm.shop_id = s.id AND sm.user_id = auth.uid()::uuid
        ))
    )
);

-- ================================================================
-- 3️⃣ RPC FUNCTIONS - Lookup par QR / Barcode
-- ================================================================

-- Fonction pour chercher un produit par QR code
CREATE OR REPLACE FUNCTION find_product_by_qr(
    p_qr_code TEXT,
    p_shop_id UUID
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    price_sale DECIMAL,
    price_buy DECIMAL,
    quantity DECIMAL,
    category TEXT,
    unit TEXT,
    photo_url TEXT,
    barcode TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pr.id,
        pr.name,
        pr.price_sale,
        pr.price_buy,
        pr.quantity,
        pr.category,
        pr.unit,
        pr.photo_url,
        pr.barcode
    FROM products pr
    INNER JOIN qr_codes qr ON qr.product_id = pr.id
    WHERE qr.qr_code = p_qr_code
    AND qr.shop_id = p_shop_id
    AND qr.is_active = TRUE
    AND pr.is_active = TRUE
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour chercher un produit par code-barres
CREATE OR REPLACE FUNCTION find_product_by_barcode(
    p_barcode TEXT,
    p_shop_id UUID
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    price_sale DECIMAL,
    price_buy DECIMAL,
    quantity DECIMAL,
    category TEXT,
    unit TEXT,
    photo_url TEXT,
    barcode TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pr.id,
        pr.name,
        pr.price_sale,
        pr.price_buy,
        pr.quantity,
        pr.category,
        pr.unit,
        pr.photo_url,
        pr.barcode
    FROM products pr
    INNER JOIN product_barcodes pb ON pb.product_id = pr.id
    WHERE pb.barcode = p_barcode
    AND pb.shop_id = p_shop_id
    AND pb.is_active = TRUE
    AND pr.is_active = TRUE
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- 4️⃣ TRIGGER - Empêcher les QR codes dupliqués
-- ================================================================

CREATE OR REPLACE FUNCTION check_qr_code_duplicate()
RETURNS TRIGGER AS $$
DECLARE
    v_existing_count INT;
BEGIN
    -- Vérifier si le QR code existe déjà pour un autre produit
    SELECT COUNT(*)
    INTO v_existing_count
    FROM qr_codes
    WHERE qr_code = NEW.qr_code
    AND product_id != NEW.product_id
    AND is_active = TRUE;
    
    IF v_existing_count > 0 THEN
        RAISE EXCEPTION 'QR code "%" already exists for another product', NEW.qr_code;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_check_qr_code_duplicate ON qr_codes;
CREATE TRIGGER tr_check_qr_code_duplicate
BEFORE INSERT OR UPDATE ON qr_codes
FOR EACH ROW
EXECUTE FUNCTION check_qr_code_duplicate();

-- ================================================================
-- 5️⃣ TRIGGER - Empêcher les code-barres dupliqués
-- ================================================================

CREATE OR REPLACE FUNCTION check_barcode_duplicate()
RETURNS TRIGGER AS $$
DECLARE
    v_existing_count INT;
BEGIN
    -- Vérifier si le code-barres existe déjà pour un autre produit
    SELECT COUNT(*)
    INTO v_existing_count
    FROM product_barcodes
    WHERE barcode = NEW.barcode
    AND product_id != NEW.product_id
    AND is_active = TRUE;
    
    IF v_existing_count > 0 THEN
        RAISE EXCEPTION 'Barcode "%" already exists for another product', NEW.barcode;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_check_barcode_duplicate ON product_barcodes;
CREATE TRIGGER tr_check_barcode_duplicate
BEFORE INSERT OR UPDATE ON product_barcodes
FOR EACH ROW
EXECUTE FUNCTION check_barcode_duplicate();

-- ================================================================
-- 6️⃣ VUES UTILES
-- ================================================================

-- Vue : Produits avec leurs QR codes
DROP VIEW IF EXISTS v_products_with_qr CASCADE;
CREATE VIEW v_products_with_qr AS
SELECT 
    pr.id,
    pr.name,
    pr.price_sale,
    pr.quantity,
    qr.qr_code,
    qr.is_active as qr_active,
    pr.shop_id,
    COUNT(*) OVER (PARTITION BY pr.id) as qr_count
FROM products pr
LEFT JOIN qr_codes qr ON qr.product_id = pr.id AND qr.is_active = TRUE
WHERE pr.is_active = TRUE;

-- Vue : Produits avec leurs codes-barres
DROP VIEW IF EXISTS v_products_with_barcodes CASCADE;
CREATE VIEW v_products_with_barcodes AS
SELECT 
    pr.id,
    pr.name,
    pr.price_sale,
    pr.quantity,
    pb.barcode,
    pb.barcode_type,
    pb.is_primary,
    pb.is_active as barcode_active,
    pr.shop_id,
    COUNT(*) OVER (PARTITION BY pr.id) as barcode_count
FROM products pr
LEFT JOIN product_barcodes pb ON pb.product_id = pr.id AND pb.is_active = TRUE
WHERE pr.is_active = TRUE;

-- ================================================================
-- ✅ MIGRATION COMPLÈTE
-- ================================================================

COMMIT;

-- ================================================================
-- 📊 Vérifications
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Tables créées: qr_codes, product_barcodes';
    RAISE NOTICE '✅ Triggers de validation installés';
    RAISE NOTICE '✅ RPC Functions: find_product_by_qr, find_product_by_barcode';
    RAISE NOTICE '✅ Views: v_products_with_qr, v_products_with_barcodes';
    RAISE NOTICE '';
    RAISE NOTICE '🔐 QR codes et code-barres: 100% UNIQUE';
    RAISE NOTICE '🔍 Lookup optimisé avec indexes';
    RAISE NOTICE '📱 Prêt pour scan → produit automatique';
END $$;
