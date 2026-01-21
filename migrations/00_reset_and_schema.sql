-- ================================================================
-- 🔥 RESET COMPLET + SCHEMA - VENTO DATABASE
-- ================================================================
-- Date: 24 Décembre 2025
-- Objectif: DROP tout et recréer une base propre et cohérente
-- 
-- ⚠️ ATTENTION: Ce script SUPPRIME TOUTES LES DCONNÉES !
-- Créer un backup AVANT d'exécuter ce script !
-- ================================================================

BEGIN;

-- ================================================================
-- ÉTAPE 1: SUPPRIMER TOUT (RESET COMPLET)
-- ================================================================

-- Supprimer toutes les vues matérialisées
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT matviewname FROM pg_matviews WHERE schemaname = 'public') 
    LOOP
        EXECUTE 'DROP MATERIALIZED VIEW IF EXISTS ' || quote_ident(r.matviewname) || ' CASCADE';
    END LOOP;
END $$;

-- Supprimer toutes les vues
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT viewname FROM pg_views WHERE schemaname = 'public') 
    LOOP
        EXECUTE 'DROP VIEW IF EXISTS ' || quote_ident(r.viewname) || ' CASCADE';
    END LOOP;
END $$;

-- Supprimer toutes les fonctions (sauf celles des extensions)
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT proname, oidvectortypes(proargtypes) as argtypes
        FROM pg_proc 
        INNER JOIN pg_namespace ON pg_proc.pronamespace = pg_namespace.oid
        WHERE pg_namespace.nspname = 'public'
        AND NOT EXISTS (
            SELECT 1 FROM pg_depend
            WHERE pg_depend.objid = pg_proc.oid
            AND pg_depend.deptype = 'e'
        )
    ) 
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || quote_ident(r.proname) || '(' || r.argtypes || ') CASCADE';
    END LOOP;
END $$;

-- Supprimer toutes les tables
DROP TABLE IF EXISTS shop_members CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS merchant_relations CASCADE;
DROP TABLE IF EXISTS sync_queue CASCADE;
DROP TABLE IF EXISTS debt_payments CASCADE;
DROP TABLE IF EXISTS debts CASCADE;
DROP TABLE IF EXISTS cart_items CASCADE;
DROP TABLE IF EXISTS sale_items CASCADE;
DROP TABLE IF EXISTS sales CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS shops CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS otp_codes CASCADE;
DROP TABLE IF EXISTS vtlbes_cy CASCADE;
DROP TABLE IF EXISTS vtlbes_cy_backup CASCADE;

-- Supprimer tous les types ENUM
DROP TYPE IF EXISTS auth_mode CASCADE;
DROP TYPE IF EXISTS sync_status CASCADE;
DROP TYPE IF EXISTS payment_type CASCADE;
DROP TYPE IF EXISTS debt_status CASCADE;
DROP TYPE IF EXISTS user_role CASCADE;
DROP TYPE IF EXISTS otp_method CASCADE;
DROP TYPE IF EXISTS order_status CASCADE;

-- ================================================================
-- ÉTAPE 2: ACTIVER LES EXTENSIONS
-- ================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ================================================================
-- ÉTAPE 3: CRÉER LES TYPES ENUM
-- ================================================================

CREATE TYPE auth_mode AS ENUM ('online', 'offline', 'hybrid');
CREATE TYPE sync_status AS ENUM ('pending', 'synced', 'failed', 'partial');
CREATE TYPE payment_type AS ENUM ('cash', 'mobile_money', 'credit', 'check');
CREATE TYPE debt_status AS ENUM ('pending', 'partial', 'paid', 'overdue', 'cancelled', 'proposed', 'rejected');
CREATE TYPE user_role AS ENUM ('owner', 'manager', 'cashier', 'seller', 'accountant');
CREATE TYPE otp_method AS ENUM ('sms', 'whatsapp', 'email');
CREATE TYPE order_status AS ENUM ('draft', 'sent', 'confirmed', 'received', 'cancelled');

-- ================================================================
-- ÉTAPE 4: CRÉER LES TABLES (100% alignées avec WatermelonDB)
-- ================================================================

-- TABLE: users
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    velmo_id TEXT UNIQUE NOT NULL,
    phone TEXT,
    email TEXT,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'owner',
    shop_id UUID,
    pin_hash TEXT,
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    is_logged_in BOOLEAN DEFAULT FALSE,
    onboarding_completed BOOLEAN DEFAULT FALSE,
    auth_mode auth_mode NOT NULL DEFAULT 'offline',
    phone_verified BOOLEAN DEFAULT FALSE,
    last_login_at TIMESTAMPTZ,
    sync_status sync_status DEFAULT 'pending',
    synced_at TIMESTAMPTZ,
    created_offline BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT velmo_id_format CHECK (velmo_id ~ '^VLM-[A-Z]{2}-[0-9]{3}$'),
    CONSTRAINT phone_format CHECK (phone IS NULL OR phone ~ '^\+[0-9]{10,15}$'),
    CONSTRAINT email_format CHECK (email IS NULL OR email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$')
);

-- TABLE: shops
CREATE TABLE shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    velmo_id TEXT UNIQUE NOT NULL,
    shop_code TEXT UNIQUE,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    address TEXT,
    phone TEXT,
    logo TEXT,
    logo_icon TEXT,
    logo_color TEXT,
    currency TEXT DEFAULT 'XOF',
    currency_symbol TEXT DEFAULT 'FCFA',
    currency_name TEXT DEFAULT 'Franc CFA',
    is_active BOOLEAN DEFAULT TRUE,
    created_offline BOOLEAN DEFAULT FALSE,
    is_synced BOOLEAN DEFAULT FALSE,
    velmo_sync_status TEXT,
    sync_error TEXT,
    sync_retry_count INTEGER DEFAULT 0,
    sync_status sync_status DEFAULT 'pending',
    synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT shop_name_length CHECK (char_length(name) >= 2 AND char_length(name) <= 100)
);

-- TABLE: products
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    velmo_id TEXT UNIQUE NOT NULL,
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    price_sale DECIMAL(12, 2) NOT NULL,
    price_buy DECIMAL(12, 2) NOT NULL,
    quantity DECIMAL(10, 3) NOT NULL DEFAULT 0,
    stock_alert DECIMAL(10, 3),
    category TEXT,
    description TEXT,
    photo TEXT,
    barcode TEXT UNIQUE,
    unit TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    is_incomplete BOOLEAN DEFAULT FALSE,
    sync_status sync_status DEFAULT 'pending',
    synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT price_sale_check CHECK (price_sale >= 0),
    CONSTRAINT price_buy_check CHECK (price_buy >= 0),
    CONSTRAINT quantity_check CHECK (quantity >= 0)
);

-- TABLE: sales
CREATE TABLE sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    velmo_id TEXT UNIQUE NOT NULL,
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    total_profit DECIMAL(12, 2) DEFAULT 0,
    payment_type payment_type DEFAULT 'cash',
    customer_name TEXT,
    customer_phone TEXT,
    notes TEXT,
    items_count INTEGER DEFAULT 0,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    sync_status sync_status DEFAULT 'pending',
    synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT total_amount_check CHECK (total_amount >= 0)
);

-- TABLE: sale_items
CREATE TABLE sale_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_name TEXT NOT NULL,
    quantity DECIMAL(10, 3) NOT NULL,
    unit_price DECIMAL(12, 2) NOT NULL,
    purchase_price DECIMAL(12, 2) NOT NULL,
    subtotal DECIMAL(12, 2) NOT NULL,
    profit DECIMAL(12, 2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT quantity_check CHECK (quantity > 0),
    CONSTRAINT subtotal_check CHECK (subtotal >= 0)
);

-- TABLE: cart_items
CREATE TABLE cart_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    quantity DECIMAL(10, 3) NOT NULL,
    price DECIMAL(12, 2) NOT NULL,
    total DECIMAL(12, 2) NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT quantity_check CHECK (quantity > 0),
    CONSTRAINT total_check CHECK (total >= 0)
);

-- TABLE: debts
CREATE TABLE debts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    velmo_id TEXT UNIQUE NOT NULL,
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    debtor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    customer_name TEXT NOT NULL,
    customer_phone TEXT,
    customer_address TEXT,
    total_amount DECIMAL(12, 2) NOT NULL,
    paid_amount DECIMAL(12, 2) DEFAULT 0,
    remaining_amount DECIMAL(12, 2) NOT NULL,
    status debt_status DEFAULT 'pending',
    type TEXT NOT NULL,
    category TEXT,
    due_date TIMESTAMPTZ,
    reliability_score DECIMAL(5, 2) DEFAULT 0,
    trust_level TEXT DEFAULT 'new',
    payment_count INTEGER DEFAULT 0,
    on_time_payment_count INTEGER DEFAULT 0,
    products_json JSONB,
    notes TEXT,
    sync_status sync_status DEFAULT 'pending',
    synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT total_amount_check CHECK (total_amount > 0),
    CONSTRAINT paid_amount_check CHECK (paid_amount >= 0),
    CONSTRAINT remaining_amount_check CHECK (remaining_amount >= 0),
    CONSTRAINT type_check CHECK (type IN ('credit', 'debit')),
    CONSTRAINT reliability_score_check CHECK (reliability_score >= 0 AND reliability_score <= 100)
);

-- TABLE: debt_payments
CREATE TABLE debt_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    debt_id UUID NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(12, 2) NOT NULL,
    payment_method payment_type DEFAULT 'cash',
    notes TEXT,
    reference_code TEXT,
    sync_status sync_status DEFAULT 'pending',
    synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT amount_check CHECK (amount > 0)
);

-- TABLE: sync_queue
CREATE TABLE sync_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    operation TEXT NOT NULL,
    data TEXT NOT NULL,
    status TEXT NOT NULL,
    error TEXT,
    last_error TEXT,
    retry_count INTEGER DEFAULT 0,
    processed_at TIMESTAMPTZ,
    synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE: merchant_relations
CREATE TABLE merchant_relations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_a_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    shop_b_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    shop_a_name TEXT NOT NULL,
    shop_b_name TEXT NOT NULL,
    shop_a_velmo_id TEXT,
    shop_b_velmo_id TEXT,
    shop_a_phone TEXT,
    shop_b_phone TEXT,
    status TEXT NOT NULL,
    initiated_by TEXT NOT NULL,
    shop_a_owes DECIMAL(12, 2) DEFAULT 0,
    shop_b_owes DECIMAL(12, 2) DEFAULT 0,
    net_balance DECIMAL(12, 2) DEFAULT 0,
    total_transactions INTEGER DEFAULT 0,
    total_compensations INTEGER DEFAULT 0,
    last_transaction_date TIMESTAMPTZ,
    relationship_score DECIMAL(5, 2) DEFAULT 0,
    relationship_status TEXT,
    notes TEXT,
    accepted_at TIMESTAMPTZ,
    sync_status sync_status DEFAULT 'pending',
    synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT not_self_relation CHECK (shop_a_id != shop_b_id),
    CONSTRAINT unique_relation UNIQUE(shop_a_id, shop_b_id)
);

-- TABLE: orders
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    supplier_id UUID REFERENCES shops(id) ON DELETE SET NULL,
    supplier_name TEXT NOT NULL,
    supplier_phone TEXT,
    supplier_velmo_id TEXT,
    status order_status DEFAULT 'draft',
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    paid_amount DECIMAL(12, 2) DEFAULT 0,
    payment_condition TEXT,
    expected_delivery_date TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE: order_items
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_name TEXT NOT NULL,
    quantity DECIMAL(10, 3) NOT NULL,
    unit_price DECIMAL(12, 2) NOT NULL,
    total_price DECIMAL(12, 2) NOT NULL,
    photo_uri TEXT,
    is_confirmed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- TABLE: shop_members
CREATE TABLE shop_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role user_role NOT NULL DEFAULT 'cashier',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT unique_shop_member UNIQUE(shop_id, user_id)
);

-- TABLE: otp_codes (pour l'authentification)
CREATE TABLE otp_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone TEXT NOT NULL,
    code TEXT NOT NULL,
    code_hash TEXT NOT NULL,
    method otp_method NOT NULL DEFAULT 'sms',
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    expires_at TIMESTAMPTZ NOT NULL,
    verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT code_format CHECK (code ~ '^[0-9]{4}$'),
    CONSTRAINT phone_format CHECK (phone ~ '^\+[0-9]{10,15}$'),
    CONSTRAINT attempts_check CHECK (attempts <= max_attempts)
);

-- ================================================================
-- ÉTAPE 5: CRÉER LES INDEX
-- ================================================================

-- Users
CREATE INDEX idx_users_velmo_id ON users(velmo_id);
CREATE INDEX idx_users_phone ON users(phone) WHERE phone IS NOT NULL;
CREATE INDEX idx_users_email ON users(email) WHERE email IS NOT NULL;
CREATE INDEX idx_users_shop_id ON users(shop_id);
CREATE INDEX idx_users_is_logged_in ON users(is_logged_in);
CREATE INDEX idx_users_is_active ON users(is_active);

-- Shops
CREATE INDEX idx_shops_owner_id ON shops(owner_id);
CREATE INDEX idx_shops_velmo_id ON shops(velmo_id);
CREATE INDEX idx_shops_shop_code ON shops(shop_code) WHERE shop_code IS NOT NULL;
CREATE INDEX idx_shops_category ON shops(category);
CREATE INDEX idx_shops_is_active ON shops(is_active);

-- Products
CREATE INDEX idx_products_shop_id ON products(shop_id);
CREATE INDEX idx_products_user_id ON products(user_id);
CREATE INDEX idx_products_velmo_id ON products(velmo_id);
CREATE INDEX idx_products_name ON products(name);
CREATE INDEX idx_products_barcode ON products(barcode) WHERE barcode IS NOT NULL;
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_is_active ON products(is_active);

-- Sales
CREATE INDEX idx_sales_shop_id ON sales(shop_id);
CREATE INDEX idx_sales_user_id ON sales(user_id);
CREATE INDEX idx_sales_velmo_id ON sales(velmo_id);
CREATE INDEX idx_sales_created_at ON sales(created_at DESC);

-- Sale Items
CREATE INDEX idx_sale_items_sale_id ON sale_items(sale_id);
CREATE INDEX idx_sale_items_product_id ON sale_items(product_id);
CREATE INDEX idx_sale_items_user_id ON sale_items(user_id);

-- Cart Items
CREATE INDEX idx_cart_items_shop_id ON cart_items(shop_id);
CREATE INDEX idx_cart_items_user_id ON cart_items(user_id);
CREATE INDEX idx_cart_items_product_id ON cart_items(product_id);

-- Debts
CREATE INDEX idx_debts_shop_id ON debts(shop_id);
CREATE INDEX idx_debts_user_id ON debts(user_id);
CREATE INDEX idx_debts_debtor_id ON debts(debtor_id) WHERE debtor_id IS NOT NULL;
CREATE INDEX idx_debts_velmo_id ON debts(velmo_id);
CREATE INDEX idx_debts_status ON debts(status);
CREATE INDEX idx_debts_type ON debts(type);
CREATE INDEX idx_debts_customer_name ON debts(customer_name);
CREATE INDEX idx_debts_created_at ON debts(created_at DESC);

-- Debt Payments
CREATE INDEX idx_debt_payments_debt_id ON debt_payments(debt_id);
CREATE INDEX idx_debt_payments_user_id ON debt_payments(user_id);

-- Sync Queue
CREATE INDEX idx_sync_queue_table_name ON sync_queue(table_name);
CREATE INDEX idx_sync_queue_record_id ON sync_queue(record_id);
CREATE INDEX idx_sync_queue_status ON sync_queue(status);

-- Merchant Relations
CREATE INDEX idx_merchant_relations_shop_a_id ON merchant_relations(shop_a_id);
CREATE INDEX idx_merchant_relations_shop_b_id ON merchant_relations(shop_b_id);
CREATE INDEX idx_merchant_relations_status ON merchant_relations(status);
CREATE INDEX idx_merchant_relations_created_at ON merchant_relations(created_at DESC);

-- Orders
CREATE INDEX idx_orders_shop_id ON orders(shop_id);
CREATE INDEX idx_orders_supplier_id ON orders(supplier_id) WHERE supplier_id IS NOT NULL;
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);

-- Order Items
CREATE INDEX idx_order_items_order_id ON order_items(order_id);

-- Shop Members
CREATE INDEX idx_shop_members_shop_id ON shop_members(shop_id);
CREATE INDEX idx_shop_members_user_id ON shop_members(user_id);
CREATE INDEX idx_shop_members_role ON shop_members(role);

-- OTP Codes
CREATE INDEX idx_otp_phone ON otp_codes(phone);
CREATE INDEX idx_otp_expires_at ON otp_codes(expires_at);

-- ================================================================
-- ÉTAPE 6: CRÉER LES TRIGGERS
-- ================================================================

-- Fonction pour mettre à jour updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Appliquer le trigger sur toutes les tables avec updated_at
CREATE TRIGGER users_update_updated_at BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER shops_update_updated_at BEFORE UPDATE ON shops
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER products_update_updated_at BEFORE UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER sales_update_updated_at BEFORE UPDATE ON sales
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER cart_items_update_updated_at BEFORE UPDATE ON cart_items
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER debts_update_updated_at BEFORE UPDATE ON debts
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER debt_payments_update_updated_at BEFORE UPDATE ON debt_payments
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER merchant_relations_update_updated_at BEFORE UPDATE ON merchant_relations
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER orders_update_updated_at BEFORE UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER shop_members_update_updated_at BEFORE UPDATE ON shop_members
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMIT;

-- ================================================================
-- ✅ SCHEMA CRÉÉ AVEC SUCCÈS
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ SCHEMA CRÉÉ AVEC SUCCÈS !';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📊 Tables créées: 15';
    RAISE NOTICE '🔑 Index créés: 50+';
    RAISE NOTICE '⚡ Triggers créés: 10';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🎯 Prochaine étape:';
    RAISE NOTICE '   Exécuter 01_rpc_and_rls.sql';
    RAISE NOTICE '========================================';
END $$;
