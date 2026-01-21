import { useState } from 'react';
import {
    Globe,
    ShoppingBag,
    Zap,
    ShieldCheck,
    Link as LinkIcon,
    Clock,
    ArrowUpRight,
    MessageCircle,
    ExternalLink,
    AlertCircle,
    Copy,
    Check,
    MapPin
} from 'lucide-react';
import {
    useOnlineShops,
    useCustomerOrders,
    useUpdateOnlineSettings
} from '../hooks/useData';
import { useCurrency } from '../contexts/CurrencyContext';
import {
    PageHeader,
    StatCard,
    DataTable,
    Badge,
    LoadingSpinner,
    ExpandableValue
} from '../components/ui';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';
import type { CustomerOrder, Shop } from '../types/database';

export default function OnlineServicesPage() {
    const [ordersPage] = useState(1);
    const limit = 10;

    // Utilisation du nouveau hook technique qui tape directement dans la table 'shops'
    const { data: shopsData, isLoading: shopsLoading } = useOnlineShops(1, 100);
    const { data: ordersData, isLoading: ordersLoading } = useCustomerOrders(ordersPage, limit);
    const updateSettings = useUpdateOnlineSettings();
    const [copiedShopId, setCopiedShopId] = useState<string | null>(null);
    const { formatAmount } = useCurrency();

    const handleCopyUrl = (slug: string, shopId: string) => {
        const url = `https://velmo.shop/${slug}`;
        navigator.clipboard.writeText(url);
        setCopiedShopId(shopId);
        setTimeout(() => setCopiedShopId(null), 2000);
    };

    // Mapping correct par rapport à la table 'shops' (name au lieu de shop_name)
    const allShops = (shopsData?.data || []) as Shop[];
    const publicShops = allShops.filter(s => s.is_public);
    const shopsWithSlugs = allShops.filter(s => s.slug);

    const totalOrders = ordersData?.total || 0;
    const pendingOrders = ordersData?.data?.filter((o: CustomerOrder) => o.status === 'pending').length || 0;

    const toggleShopPublic = async (shopId: string, currentStatus: boolean) => {
        try {
            await updateSettings.mutateAsync({
                shopId,
                updates: { is_public: !currentStatus }
            });
        } catch (err) {
            console.error("Failed to update shop status", err);
        }
    };

    return (
        <div className="space-y-10 animate-fade-in pb-20">
            <PageHeader
                title="Services Digitaux"
                description="Supervision de la présence en ligne, des boutiques publiques et des commandes clients directes."
                actions={
                    <div className="flex items-center gap-3">
                        <div className="flex items-center gap-2 px-4 py-2 bg-[var(--primary)]/10 rounded-xl border border-[var(--primary)]/20">
                            <Zap size={16} className="text-[var(--primary)] animate-pulse" />
                            <span className="text-[10px] font-black uppercase text-[var(--primary)] tracking-widest">Sentinel Online Actif</span>
                        </div>
                    </div>
                }
            />

            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 md:gap-6">
                <StatCard
                    label="Boutiques Publiques"
                    value={publicShops.length}
                    icon={Globe}
                    variant="info"
                    changeLabel="Indexées sur le web"
                />
                <StatCard
                    label="Commandes Web"
                    value={totalOrders}
                    icon={ShoppingBag}
                    variant="success"
                    changeLabel="Total historique"
                />
                <StatCard
                    label="À Traiter"
                    value={pendingOrders}
                    icon={Clock}
                    variant="warning"
                    changeLabel="Nouveaux flux"
                />
                <StatCard
                    label="Taux de Conversion"
                    value="3.8%"
                    icon={ArrowUpRight}
                    variant="default"
                    changeLabel="Performance web"
                />
            </div>

            <div className="grid grid-cols-1 xl:grid-cols-3 gap-8">
                <div className="xl:col-span-2 space-y-6">
                    <h2 className="heading-2 flex items-center gap-3">
                        <div className="p-2 bg-[var(--primary)]/10 rounded-lg">
                            <ShoppingBag size={20} className="text-[var(--primary)]" />
                        </div>
                        Flux des Commandes Clients
                    </h2>

                    <div className="card-dashboard overflow-hidden p-0">
                        <DataTable
                            data={ordersData?.data || []}
                            loading={ordersLoading}
                            keyExtractor={(order) => order.id}
                            columns={[
                                {
                                    key: 'customer',
                                    header: 'Client',
                                    render: (order: CustomerOrder) => (
                                        <div className="flex flex-col">
                                            <span className="font-bold text-[var(--text-primary)]">{order.customer_name}</span>
                                            <span className="text-[10px] text-[var(--text-muted)] font-mono">{order.customer_phone}</span>
                                        </div>
                                    )
                                },
                                {
                                    key: 'shop',
                                    header: 'Boutique Cible',
                                    render: (order: CustomerOrder) => (
                                        <span className="px-2 py-1 bg-[var(--bg-app)] rounded-lg text-xs font-bold border border-[var(--border-subtle)]">
                                            {order.shop_name}
                                        </span>
                                    )
                                },
                                {
                                    key: 'amount',
                                    header: 'Montant',
                                    render: (order: CustomerOrder) => (
                                        <ExpandableValue
                                            value={formatAmount(order.total_amount)}
                                            className="font-black text-[var(--primary)]"
                                        />
                                    )
                                },
                                {
                                    key: 'status',
                                    header: 'État',
                                    render: (order: CustomerOrder) => (
                                        <Badge
                                            status={
                                                order.status === 'delivered' ? 'success' :
                                                    order.status === 'cancelled' ? 'error' :
                                                        order.status === 'pending' ? 'warning' : 'info'
                                            }
                                            label={order.status.toUpperCase()}
                                        />
                                    )
                                },
                                {
                                    key: 'date',
                                    header: 'Date',
                                    render: (order: CustomerOrder) => (
                                        <span className="text-xs text-[var(--text-muted)] font-medium">
                                            {format(new Date(order.created_at), 'dd MMM', { locale: fr })}
                                        </span>
                                    )
                                }
                            ]}
                        />
                    </div>
                </div>

                <div className="space-y-6">
                    <h2 className="heading-2 flex items-center gap-3">
                        <div className="p-2 bg-violet-500/10 rounded-lg">
                            <LinkIcon size={20} className="text-violet-400" />
                        </div>
                        Index des Slugs & URLs
                    </h2>

                    <div className="space-y-4">
                        {shopsLoading ? (
                            <div className="py-20 flex justify-center"><LoadingSpinner /></div>
                        ) : allShops.length === 0 ? (
                            <div className="card-dashboard p-10 text-center opacity-60">
                                <AlertCircle size={32} className="mx-auto mb-4 text-[var(--error)]" />
                                <p className="text-xs font-bold uppercase tracking-widest text-[var(--error)]">Accès Refusé / Vide</p>
                                <p className="text-[10px] text-[var(--text-muted)] mt-2 italic">Problème de permissions RLS détecté sur la table 'shops'</p>
                            </div>
                        ) : shopsWithSlugs.length === 0 ? (
                            <div className="card-dashboard p-10 text-center opacity-60">
                                <Globe size={32} className="mx-auto mb-4 text-[var(--text-muted)]" />
                                <p className="text-xs font-bold uppercase tracking-widest text-[var(--text-muted)]">Aucun slug configuré</p>
                            </div>
                        ) : (
                            shopsWithSlugs.map((shop) => (
                                <div key={shop.id} className="card-dashboard p-5 group hover:border-[var(--primary)]/30 transition-all duration-300">
                                    {/* En-tête de la carte */}
                                    <div className="flex items-start justify-between mb-4">
                                        <div className="flex items-center gap-4">
                                            <div className="w-12 h-12 rounded-2xl bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center text-xl shadow-inner group-hover:scale-105 transition-transform">
                                                🏪
                                            </div>
                                            <div>
                                                <h4 className="text-base font-bold text-[var(--text-primary)] group-hover:text-[var(--primary)] transition-colors">{shop.name}</h4>
                                                <div className="flex items-center gap-2 mt-1.5">
                                                    <span className={`w-2 h-2 rounded-full ${shop.is_active ? 'bg-[var(--success)] shadow-[0_0_8px_var(--success)] animate-pulse' : 'bg-[var(--text-muted)]'}`} />
                                                    <span className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-wider">
                                                        {shop.is_active ? 'Terminal Online' : 'Offline'}
                                                    </span>
                                                </div>
                                            </div>
                                        </div>
                                        <button
                                            onClick={() => toggleShopPublic(shop.id, shop.is_public)}
                                            className={`px-3 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-widest transition-all ${shop.is_public
                                                ? 'bg-[var(--success)]/10 text-[var(--success)] border border-[var(--success)]/20 shadow-[0_0_10px_var(--success)]/20 hover:bg-[var(--success)]/20'
                                                : 'bg-[var(--text-muted)]/10 text-[var(--text-muted)] border border-[var(--border-subtle)] hover:bg-[var(--text-muted)]/20'
                                                }`}
                                        >
                                            {shop.is_public ? 'Publié' : 'Privé'}
                                        </button>
                                    </div>

                                    {/* Lien Slug */}
                                    <div className="bg-[var(--bg-app)] rounded-xl p-3 border border-[var(--border-subtle)] group-hover:border-[var(--primary)]/30 transition-colors flex items-center justify-between gap-3 mb-4">
                                        <div className="flex items-center gap-2 truncate min-w-0">
                                            <LinkIcon size={14} className="text-[var(--primary)] shrink-0" />
                                            <a
                                                href={`https://velmo.shop/${shop.slug}`}
                                                target="_blank"
                                                rel="noopener noreferrer"
                                                className="text-xs font-mono font-bold text-[var(--text-secondary)] truncate hover:text-[var(--primary)] transition-colors hover:underline"
                                            >
                                                velmo.shop/{shop.slug}
                                            </a>
                                        </div>
                                        <div className="flex items-center gap-1 shrink-0">
                                            <button
                                                onClick={() => handleCopyUrl(shop.slug!, shop.id)}
                                                className={`p-1.5 rounded-lg transition-colors ${copiedShopId === shop.id
                                                    ? 'bg-[var(--success)]/10 text-[var(--success)]'
                                                    : 'hover:bg-[var(--bg-card)] text-[var(--text-muted)] hover:text-[var(--text-primary)]'
                                                    }`}
                                                title="Copier le lien"
                                            >
                                                {copiedShopId === shop.id ? <Check size={12} /> : <Copy size={12} />}
                                            </button>
                                            <a
                                                href={`https://velmo.shop/${shop.slug}`}
                                                target="_blank"
                                                rel="noopener noreferrer"
                                                className="p-1.5 hover:bg-[var(--bg-card)] rounded-lg text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-colors"
                                            >
                                                <ExternalLink size={12} />
                                            </a>
                                        </div>
                                    </div>

                                    {/* Métriques */}
                                    <div className="grid grid-cols-2 gap-3">
                                        <div className="flex items-center gap-2.5 px-3 py-2 rounded-xl bg-[var(--bg-app)]/50 border border-[var(--border-subtle)]">
                                            <ShoppingBag size={14} className="text-[var(--text-muted)]" />
                                            <div className="flex flex-col">
                                                <span className="text-[9px] font-bold text-[var(--text-muted)] uppercase tracking-tighter">Commandes</span>
                                                <span className="text-xs font-black text-[var(--text-primary)]">{shop.orders_count || 0}</span>
                                            </div>
                                        </div>
                                        <div className="flex items-center gap-2.5 px-3 py-2 rounded-xl bg-[var(--bg-app)]/50 border border-[var(--border-subtle)]">
                                            <ShieldCheck size={14} className={shop.is_verified ? 'text-[var(--success)]' : 'text-[var(--text-muted)]'} />
                                            <div className="flex flex-col">
                                                <span className="text-[9px] font-bold text-[var(--text-muted)] uppercase tracking-tighter">Statut</span>
                                                <span className="text-xs font-black text-[var(--text-primary)]">{shop.is_verified ? 'Certifié' : 'Standard'}</span>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            ))
                        )}
                    </div>
                </div>
            </div>

            <div className="space-y-6">
                <h2 className="heading-2 flex items-center gap-3">
                    <div className="p-2 bg-amber-500/10 rounded-lg">
                        <Zap size={20} className="text-amber-400" />
                    </div>
                    Services de Catalogue & Média
                </h2>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    <ServiceCard
                        icon={Globe}
                        title="Vitrine Digitale"
                        description="Hébergement du catalogue interactif accessible via QR Code ou lien court."
                        status="Actif"
                        color="text-[var(--info)]"
                    />
                    <ServiceCard
                        icon={MessageCircle}
                        title="Relais WhatsApp"
                        description="Envoi automatique des commandes directement sur le mobile du vendeur."
                        status="Actif"
                        color="text-[var(--success)]"
                    />
                    <ServiceCard
                        icon={MapPin}
                        title="Géo-Localisation"
                        description="Indexation Google Maps et affichage de la position exacte du point de vente."
                        status="Configuré"
                        color="text-amber-400"
                    />
                </div>
            </div>
        </div>
    );
}

interface ServiceCardProps {
    icon: React.ElementType;
    title: string;
    description: string;
    status: string;
    color: string;
}

function ServiceCard({ icon: Icon, title, description, status, color }: ServiceCardProps) {
    return (
        <div className="card-dashboard group hover:translate-y-[-4px] transition-all p-6">
            <div className="flex items-start justify-between gap-4 mb-6">
                <div className={`p-4 rounded-2xl bg-[var(--bg-app)] border border-[var(--border-subtle)] group-hover:border-[var(--primary)]/30 transition-all shadow-sm ${color}`}>
                    <Icon size={28} />
                </div>
                <Badge status="success" label={status} />
            </div>
            <h3 className="text-lg font-bold text-[var(--text-primary)] mb-3 group-hover:text-[var(--primary)] transition-colors">{title}</h3>
            <p className="text-sm text-[var(--text-secondary)] font-medium leading-relaxed">{description}</p>
            <div className="mt-8 pt-5 border-t border-[var(--border-subtle)] flex items-center justify-between">
                <span className="text-[10px] font-black uppercase tracking-widest text-[var(--text-muted)] opacity-70">v4.0.0</span>
                <button className="flex items-center gap-2 text-[10px] font-black uppercase tracking-widest text-[var(--primary)] hover:underline group-hover:translate-x-1 transition-transform">
                    Configurer <ArrowUpRight size={10} />
                </button>
            </div>
        </div>
    );
}
