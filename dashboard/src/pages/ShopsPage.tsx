import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Store,
    AlertCircle,
    ShieldCheck,
    Search,
    MapPin,
    ArrowUpRight,
    Calendar,
    ShoppingBag,
    TrendingUp,
    Package
} from 'lucide-react';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

import { useShopsOverview, useAdminActions, useSearchShops } from '../hooks/useData';
import { useCurrency } from '../contexts/CurrencyContext';
import { useToast } from '../contexts/ToastContext';
import type { ShopOverview, ShopStatus } from '../types/database';
import { PageHeader, StatCard, StatusBadge, LoadingSpinner, EmptyState } from '../components/ui';

// ============================================
// COMPOSANT CARTE BOUTIQUE (Premium Grid)
// ============================================

const ShopCard = ({
    shop,
    onClick,
    onAction,
    formatAmount,
    formatNumber
}: {
    shop: ShopOverview;
    onClick: () => void;
    onAction: (id: string, status: ShopStatus) => void;
    formatAmount: (v: number) => string;
    formatNumber: (v: number) => string
}) => {
    return (
        <div
            onClick={onClick}
            className="card-dashboard group cursor-pointer relative flex flex-col hover:-translate-y-2 hover:shadow-2xl transition-all duration-500 border-[var(--border-subtle)] bg-[var(--bg-card)]"
        >
            {/* Glossy Overlay */}
            <div className="absolute inset-0 bg-gradient-to-tr from-[var(--primary)]/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />

            {/* Header: Icon + Status */}
            <div className="flex justify-between items-start mb-6 relative z-10">
                <div className="w-14 h-14 rounded-2xl bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center text-[var(--primary)] group-hover:scale-110 group-hover:border-[var(--primary)]/50 group-hover:bg-[var(--primary)] transition-all duration-500 shadow-xl group-hover:text-white group-hover:shadow-[var(--primary-glow)]">
                    <Store size={26} />
                </div>
                <div className="flex flex-col items-end gap-2">
                    <StatusBadge
                        status={shop.status === 'active' ? 'success' : shop.status === 'suspended' ? 'warning' : 'inactive'}
                        label={shop.status === 'active' ? 'OPÉRATIONNELLE' : shop.status === 'suspended' ? 'SUSPENDUE' : 'ANNULÉE'}
                    />
                    <div className="flex gap-1">
                        {shop.status === 'active' ? (
                            <button
                                onClick={(e) => { e.stopPropagation(); onAction(shop.shop_id, 'suspended'); }}
                                className="p-1.5 rounded-lg bg-[var(--error)]/10 text-[var(--error)] border border-[var(--error)]/20 hover:bg-[var(--error)] hover:text-white transition-all shadow-lg active:scale-90"
                                title="Suspendre immédiatement"
                            >
                                <AlertCircle size={14} />
                            </button>
                        ) : (
                            <button
                                onClick={(e) => { e.stopPropagation(); onAction(shop.shop_id, 'active'); }}
                                className="p-1.5 rounded-lg bg-[var(--success)]/10 text-[var(--success)] border border-[var(--success)]/20 hover:bg-[var(--success)] hover:text-white transition-all shadow-lg active:scale-90"
                                title="Réactiver"
                            >
                                <ShieldCheck size={14} />
                            </button>
                        )}
                    </div>
                </div>
            </div>

            {/* Info Principale */}
            <div className="mb-8 relative z-10">
                <div className="flex items-center gap-2 mb-2">
                    <span className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-[0.2em]">Partner Node</span>
                    <div className="h-px flex-1 bg-[var(--border-subtle)]" />
                </div>
                <h3 className="text-xl font-black text-[var(--text-primary)] group-hover:text-[var(--primary)] transition-colors tracking-tight">
                    {shop.shop_name}
                </h3>
                <div className="flex items-center gap-2 mt-2">
                    <MapPin size={12} className="text-[var(--text-muted)]" />
                    <span className="text-xs text-[var(--text-secondary)] font-bold uppercase tracking-tighter">
                        {shop.category || 'Commerce de détail'}
                    </span>
                </div>
            </div>

            {/* Metrics Dashboard */}
            <div className="grid grid-cols-2 gap-4 py-6 border-y border-[var(--border-subtle)] relative z-10">
                <div className="flex flex-col min-w-0">
                    <span className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest mb-1.5 flex items-center gap-1">
                        <TrendingUp size={10} /> Revenu (GMV)
                    </span>
                    <p className="text-sm font-black text-[var(--text-secondary)] group-hover:text-[var(--text-primary)] transition-colors truncate" title={formatAmount(shop.total_revenue)}>
                        {formatAmount(shop.total_revenue)}
                    </p>
                </div>
                <div className="flex flex-col min-w-0">
                    <span className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest mb-1.5 flex items-center gap-1">
                        <ShoppingBag size={10} /> Transactions
                    </span>
                    <p className="text-sm font-black text-[var(--text-secondary)] group-hover:text-[var(--text-primary)] transition-colors truncate" title={String(shop.total_sales)}>
                        {formatNumber(shop.total_sales)}
                    </p>
                </div>
            </div>

            {/* Footer Metadata */}
            <div className="mt-6 flex items-center justify-between relative z-10">
                <div className="flex items-center gap-2">
                    <div className="w-6 h-6 rounded-full bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center text-[10px] font-black text-[var(--text-muted)] uppercase">
                        {shop.owner_name?.charAt(0)}
                    </div>
                    <span className="text-[11px] font-bold text-[var(--text-muted)] truncate max-w-[100px]">{shop.owner_name}</span>
                </div>
                <div className="flex items-center gap-1.5 text-[var(--text-muted)]/60">
                    <Calendar size={12} />
                    <span className="text-[10px] font-black uppercase tracking-tighter">
                        {shop.last_sale_at ? format(new Date(shop.last_sale_at), 'dd MMM', { locale: fr }) : 'Aucune v.'}
                    </span>
                </div>
            </div>

            {/* Hover Indicator */}
            <div className="absolute top-6 right-6 opacity-0 -translate-x-4 group-hover:opacity-100 group-hover:translate-x-0 transition-all duration-500">
                <div className="p-2 bg-[var(--primary)]/10 rounded-full border border-[var(--primary)]/20 text-[var(--primary)]">
                    <ArrowUpRight size={18} />
                </div>
            </div>
        </div>
    );
};


// ============================================
// PAGE PRINCIPALE
// ============================================

export default function ShopsPage() {
    const navigate = useNavigate();
    const { addToast } = useToast();
    const [page] = useState(1);
    const [searchQuery, setSearchQuery] = useState('');
    const [filterActive, setFilterActive] = useState<boolean | null>(null);

    const { data: shopsData, isLoading } = useShopsOverview(page, 20);
    const { data: searchResults, isLoading: searchLoading } = useSearchShops(searchQuery);
    const { formatAmount, formatNumber } = useCurrency();
    const { updateShopStatus } = useAdminActions();

    const rawData = searchQuery.length >= 2 ? (searchResults || []) : (shopsData?.data || []);
    const displayData = rawData.filter(shop =>
        filterActive === null || (shop.status === 'active' ? true : false) === filterActive
    );

    const handleAction = async (shopId: string, status: ShopStatus) => {
        const actionLabel = status === 'active' ? 'réactivée' : 'suspendue';
        try {
            await updateShopStatus.mutateAsync({ shopId, status });
            addToast({
                title: 'Opération réussie',
                message: `La boutique a été ${actionLabel} avec succès.`,
                type: 'success'
            });
        } catch (err) {
            addToast({
                title: 'Erreur',
                message: `Échec de l'opération : ${err instanceof Error ? err.message : 'Inconnu'}`,
                type: 'error'
            });
        }
    };

    return (
        <div className="space-y-10 animate-fade-in pb-20">

            <PageHeader
                title="Réseau de Boutiques"
                description={`Supervision centralisée des ${shopsData?.total ? formatNumber(shopsData.total) : '...'} terminaux de vente connectés au système.`}
                actions={
                    <button className="px-5 py-2.5 bg-[var(--primary)] hover:brightness-110 text-white rounded-2xl font-black transition-all shadow-xl shadow-[var(--primary-glow)] flex items-center gap-2 active:scale-95 text-xs uppercase tracking-widest">
                        <Store size={18} /> Déployer une Boutique
                    </button>
                }
            />

            {/* FLEET KPI */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <StatCard
                    label="Points de Vente"
                    value={formatNumber(shopsData?.total || 0)}
                    icon={Store}
                    variant="info"
                    changeLabel="Terminaux installés"
                />
                <StatCard
                    label="État du Réseau"
                    value={formatNumber(shopsData?.data.filter(s => s.is_active).length || 0)}
                    icon={ShieldCheck}
                    variant="success"
                    changeLabel="Unités opérationnelles"
                />
                <StatCard
                    label="Capacité Stock"
                    value={formatNumber(shopsData?.data.reduce((a, b) => a + (b.products_count || 0), 0) || 0)}
                    icon={Package}
                    variant="default"
                    changeLabel="Articles en rayon"
                />
                <StatCard
                    label="Incidents"
                    value="0"
                    icon={AlertCircle}
                    variant="info"
                    changeLabel="Dernières 24h"
                />
            </div>

            {/* CONTROLS */}
            <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4 bg-[var(--bg-card)] p-3 rounded-2xl border border-[var(--border-subtle)] shadow-inner">
                <div className="relative flex-1">
                    <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-[var(--text-muted)]" size={18} />
                    <input
                        type="text"
                        placeholder="Rechercher par nom de boutique, ID Velmo ou propriétaire..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        className="w-full bg-transparent border-none rounded-xl pl-12 pr-4 py-3 text-sm text-[var(--text-primary)] focus:ring-1 focus:ring-[var(--primary)]/50 placeholder:text-[var(--text-muted)]/40 transition-all font-bold"
                    />
                </div>

                <div className="flex bg-[var(--bg-app)]/50 p-1 rounded-xl border border-[var(--border-subtle)]">
                    {[
                        { label: 'Toutes', val: null },
                        { label: 'Actives', val: true },
                        { label: 'Inactives', val: false }
                    ].map((f) => (
                        <button
                            key={f.val === null ? 'all' : String(f.val)}
                            onClick={() => setFilterActive(f.val)}
                            className={`px-4 py-1.5 text-[10px] font-black uppercase tracking-tighter rounded-lg transition-all ${filterActive === f.val ? 'bg-[var(--primary)] text-white shadow-lg shadow-[var(--primary-glow)]' : 'text-[var(--text-muted)] hover:text-[var(--text-primary)]'}`}
                        >
                            {f.label}
                        </button>
                    ))}
                </div>
            </div>

            {/* CONTENT GRID */}
            <div className="relative">
                {(isLoading || searchLoading) ? (
                    <div className="min-h-[40vh] flex flex-col items-center justify-center gap-4">
                        <LoadingSpinner />
                        <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest animate-pulse">Scan du réseau en cours...</p>
                    </div>
                ) : displayData.length === 0 ? (
                    <EmptyState
                        icon={Store}
                        title="Nœud non identifié"
                        description="Aucun terminal de vente ne répond à ces critères de recherche."
                    />
                ) : (
                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-8 animate-fade-in">
                        {displayData.map((shop: ShopOverview) => (
                            <ShopCard
                                key={shop.shop_id}
                                shop={shop}
                                formatAmount={formatAmount}
                                formatNumber={formatNumber}
                                onClick={() => navigate(`/shops/${shop.shop_id}`)}
                                onAction={handleAction}
                            />
                        ))}
                    </div>
                )}
            </div>

            {/* PAGER FOOTER */}
            {!isLoading && !searchQuery && (
                <div className="flex justify-center pt-10 border-t border-[var(--border-subtle)]">
                    <div className="px-4 py-1.5 bg-[var(--bg-app)]/50 rounded-full border border-[var(--border-subtle)] shadow-inner">
                        <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest">
                            Affichage <span className="text-[var(--text-primary)]">{formatNumber(displayData.length)}</span> / {formatNumber(shopsData?.total || 0)} boutiques
                        </p>
                    </div>
                </div>
            )}
        </div>
    );
}
