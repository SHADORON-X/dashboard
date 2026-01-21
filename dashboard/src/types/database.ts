// ============================================
// DATABASE TYPES (Generated from SQL Migrations)
// ============================================

export type Json =
    | string
    | number
    | boolean
    | null
    | { [key: string]: Json | undefined }
    | Json[];

// Enums
export type AuthMode = 'online' | 'offline' | 'hybrid';
export type SyncStatus = 'pending' | 'synced' | 'failed' | 'partial';
export type PaymentType = 'cash' | 'mobile_money' | 'credit' | 'check';
export type DebtStatus = 'pending' | 'partial' | 'paid' | 'overdue' | 'cancelled' | 'proposed' | 'rejected';
export type UserRole = 'owner' | 'manager' | 'cashier' | 'seller' | 'accountant';
export type UserStatus = 'active' | 'suspended' | 'blocked';
export type ShopStatus = 'active' | 'suspended' | 'cancelled';
export type OrderStatus = 'draft' | 'sent' | 'confirmed' | 'received' | 'cancelled';
export type AuditLogType =
    | 'SALE_CREATED'
    | 'SALE_CORRECTED'
    | 'STOCK_FORCED'
    | 'SYNC_CONFLICT'
    | 'SYNC_REJECTED'
    | 'VALIDATION_FAILED'
    | 'SAFE_MODE_ENTERED'
    | 'MANUAL_RECONCILE'
    | 'SUSPICIOUS_ACTIVITY';

export type AuditSeverity = 'info' | 'warning' | 'error' | 'critical';

// Tables
export interface User {
    id: string;
    velmo_id: string;
    phone: string | null;
    email: string | null;
    first_name: string;
    last_name: string;
    role: UserRole;
    shop_id: string | null;
    pin_hash: string | null;
    avatar_url: string | null;
    is_active: boolean;
    status: UserStatus;
    is_logged_in: boolean;
    onboarding_completed: boolean;
    auth_mode: AuthMode;
    phone_verified: boolean;
    last_login_at: string | null;
    sync_status: SyncStatus;
    synced_at: string | null;
    created_offline: boolean;
    created_at: string;
    updated_at: string;
}

export interface Shop {
    id: string;
    velmo_id: string;
    shop_code: string | null;
    name: string;
    category: string;
    owner_id: string;
    address: string | null;
    phone: string | null;
    logo: string | null;
    logo_icon: string | null;
    logo_color: string | null;
    currency: string;
    currency_symbol: string;
    currency_name: string;
    is_active: boolean;
    status: ShopStatus;
    created_offline: boolean;
    is_synced: boolean;
    sync_status: SyncStatus;
    synced_at: string | null;
    created_at: string;
    updated_at: string;
    // Online Store Features
    slug: string | null;
    is_public: boolean;
    location: string | null;
    whatsapp: string | null;
    opening_hours: string | null;
    is_verified: boolean;
    orders_count: number;
    logo_url: string | null;
    cover_url: string | null;
    description: string | null;
}

export interface Product {
    id: string;
    velmo_id: string;
    shop_id: string;
    user_id: string;
    name: string;
    price_sale: number;
    price_buy: number;
    quantity: number;
    stock_alert: number | null;
    category: string | null;
    description: string | null;
    photo: string | null;
    photo_url: string | null;
    barcode: string | null;
    unit: string | null;
    is_active: boolean;
    is_incomplete: boolean;
    sync_status: SyncStatus;
    synced_at: string | null;
    created_at: string;
    updated_at: string;
    version: number;
}

export interface Sale {
    id: string;
    velmo_id: string;
    shop_id: string;
    user_id: string;
    total_amount: number;
    total_profit: number;
    payment_type: PaymentType;
    customer_name: string | null;
    customer_phone: string | null;
    notes: string | null;
    items_count: number;
    status: string;
    created_by: string | null;
    sync_status: SyncStatus;
    synced_at: string | null;
    created_at: string;
    updated_at: string;
    // Security fields
    security_metadata: Json | null;
    flags: string[] | null;
    conflict: boolean;
    conflict_with: string | null;
    conflict_reason: string | null;
}

export interface SaleItem {
    id: string;
    sale_id: string;
    product_id: string;
    user_id: string;
    product_name: string;
    quantity: number;
    unit_price: number;
    purchase_price: number;
    subtotal: number;
    profit: number | null;
    created_at: string;
}

export interface Debt {
    id: string;
    velmo_id: string;
    shop_id: string;
    user_id: string;
    debtor_id: string | null;
    customer_name: string;
    customer_phone: string | null;
    customer_address: string | null;
    total_amount: number;
    paid_amount: number;
    remaining_amount: number;
    status: DebtStatus;
    type: 'credit' | 'debit';
    category: string | null;
    due_date: string | null;
    reliability_score: number;
    trust_level: string;
    payment_count: number;
    on_time_payment_count: number;
    products_json: Json | null;
    notes: string | null;
    sync_status: SyncStatus;
    synced_at: string | null;
    created_at: string;
    updated_at: string;
}

export interface DebtPayment {
    id: string;
    debt_id: string;
    user_id: string;
    amount: number;
    payment_method: PaymentType;
    notes: string | null;
    reference_code: string | null;
    sync_status: SyncStatus;
    synced_at: string | null;
    created_at: string;
    updated_at: string;
}

export interface Order {
    id: string;
    shop_id: string;
    supplier_id: string | null;
    supplier_name: string;
    supplier_phone: string | null;
    supplier_velmo_id: string | null;
    status: OrderStatus;
    total_amount: number;
    paid_amount: number;
    payment_condition: string | null;
    expected_delivery_date: string | null;
    notes: string | null;
    created_at: string;
    updated_at: string;
}

export interface ShopMember {
    id: string;
    shop_id: string;
    user_id: string;
    role: UserRole;
    permissions: Json | null;
    is_active: boolean;
    created_at: string;
    updated_at: string;
}

export interface AuditLog {
    id: string;
    type: AuditLogType;
    entity_type: 'sale' | 'product' | 'stock' | 'user' | 'shop' | 'sync';
    entity_id: string;
    user_id: string | null;
    device_id: string;
    device_name: string | null;
    shop_id: string | null;
    timestamp: number;
    metadata: Json;
    severity: AuditSeverity;
    resolved: boolean;
    resolved_at: number | null;
    resolved_by: string | null;
    created_at: string;
    updated_at: string;
}

export interface VelmoAdmin {
    id: string;
    user_id: string;
    role: 'super_admin' | 'admin' | 'support' | 'viewer';
    permissions: Json;
    is_active: boolean;
    created_at: string;
    updated_at: string;
}

export type CustomerOrderStatus = 'pending' | 'confirmed' | 'preparing' | 'ready' | 'shipped' | 'delivered' | 'cancelled';
export type DeliveryMethod = 'pickup' | 'delivery';

export interface CustomerOrder {
    id: string;
    shop_id: string;
    customer_name: string;
    customer_phone: string;
    customer_address: string | null;
    items: Json;
    total_amount: number;
    delivery_method: DeliveryMethod;
    order_note: string | null;
    status: CustomerOrderStatus;
    created_at: string;
    updated_at: string;
    confirmed_at: string | null;
    delivered_at: string | null;
    // Joined fields
    shop_name?: string;
}

export interface OrderNotification {
    id: string;
    shop_id: string;
    order_id: string | null;
    user_id: string;
    type: 'new_order' | 'order_confirmed' | 'order_cancelled' | 'low_stock' | 'out_of_stock';
    title: string;
    body: string;
    data: Json;
    is_read: boolean;
    read_at: string | null;
    created_at: string;
}

// Views
export interface ShopOverview {
    shop_id: string;
    shop_velmo_id: string;
    shop_name: string;
    category: string;
    is_active: boolean;
    status: ShopStatus;
    created_at: string;
    owner_id: string;
    owner_velmo_id: string;
    owner_name: string;
    owner_phone: string | null;
    products_count: number;
    total_sales: number;
    total_revenue: number;
    total_profit: number;
    active_debts: number;
    total_outstanding_debt: number;
    team_size: number;
    last_sale_at: string | null;
}

export interface PlatformStats {
    total_active_shops: number;
    total_active_users: number;
    total_products: number;
    total_sales: number;
    total_gmv: number;
    total_profit: number;
    active_debts_count: number;
    total_outstanding_debt: number;
    sales_last_24h: number;
    new_users_last_7d: number;
    new_shops_last_7d: number;
}

export interface DailySales {
    sale_date: string;
    sales_count: number;
    total_amount: number;
    total_profit: number;
    active_shops: number;
}

export interface RealtimeActivity {
    activity_type: 'sale' | 'debt' | 'user_created';
    entity_id: string;
    shop_name: string;
    shop_id: string;
    amount: number | null;
    activity_at: string;
    status: string | null;
}

export interface StockAlert {
    product_id: string;
    product_name: string;
    current_stock: number;
    alert_threshold: number;
    shop_id: string;
    shop_name: string;
    owner_name: string;
    owner_phone: string | null;
}

export interface CriticalAuditEvent {
    id: string;
    type: AuditLogType;
    entity_type: string;
    entity_id: string;
    user_id: string | null;
    user_name: string | null;
    shop_id: string | null;
    shop_name: string | null;
    timestamp: number;
    severity: AuditSeverity;
    metadata: Json;
    resolved: boolean;
}

// Database schema type
export interface Database {
    public: {
        Tables: {
            users: {
                Row: User;
                Insert: Partial<User>;
                Update: Partial<User>;
            };
            shops: {
                Row: Shop;
                Insert: Partial<Shop>;
                Update: Partial<Shop>;
            };
            products: {
                Row: Product;
                Insert: Partial<Product>;
                Update: Partial<Product>;
            };
            sales: {
                Row: Sale;
                Insert: Partial<Sale>;
                Update: Partial<Sale>;
            };
            sale_items: {
                Row: SaleItem;
                Insert: Partial<SaleItem>;
                Update: Partial<SaleItem>;
            };
            debts: {
                Row: Debt;
                Insert: Partial<Debt>;
                Update: Partial<Debt>;
            };
            debt_payments: {
                Row: DebtPayment;
                Insert: Partial<DebtPayment>;
                Update: Partial<DebtPayment>;
            };
            orders: {
                Row: Order;
                Insert: Partial<Order>;
                Update: Partial<Order>;
            };
            shop_members: {
                Row: ShopMember;
                Insert: Partial<ShopMember>;
                Update: Partial<ShopMember>;
            };
            audit_logs: {
                Row: AuditLog;
                Insert: Partial<AuditLog>;
                Update: Partial<AuditLog>;
            };
            admin_users: {
                Row: {
                    id: string;
                    email: string;
                    role: 'super_admin' | 'admin' | 'viewer';
                    created_at: string;
                };
                Insert: {
                    id: string;
                    email: string;
                    role?: 'super_admin' | 'admin' | 'viewer';
                    created_at?: string;
                };
                Update: {
                    id?: string;
                    email?: string;
                    role?: 'super_admin' | 'admin' | 'viewer';
                    created_at?: string;
                };
            };
            customer_orders: {
                Row: CustomerOrder;
                Insert: Partial<CustomerOrder>;
                Update: Partial<CustomerOrder>;
            };
            order_notifications: {
                Row: OrderNotification;
                Insert: Partial<OrderNotification>;
                Update: Partial<OrderNotification>;
            };
        };
        Views: {
            v_admin_shops_overview: {
                Row: ShopOverview;
            };
            v_admin_platform_stats: {
                Row: PlatformStats;
            };
            v_admin_daily_sales: {
                Row: DailySales;
            };
            v_admin_realtime_activity: {
                Row: RealtimeActivity;
            };
            v_admin_stock_alerts: {
                Row: StockAlert;
            };
            critical_audit_events: {
                Row: CriticalAuditEvent;
            };
        };
        Functions: {
            is_velmo_super_admin: {
                Args: { p_user_id: string };
                Returns: boolean;
            };
            admin_get_shop_details: {
                Args: { p_admin_user_id: string; p_shop_id: string };
                Returns: Json;
            };
            admin_search_shops: {
                Args: { p_admin_user_id: string; p_search_term?: string; p_limit?: number };
                Returns: Json;
            };
        };
    };
}

