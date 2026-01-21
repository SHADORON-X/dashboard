import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Package, Search, Store, Plus, Filter,
    RefreshCw, AlertTriangle, Box, Layers, ArrowUpRight,
    ArrowRight
} from 'lucide-react';

import { useAllProducts } from '../hooks/useData';
import { useCurrency } from '../contexts/CurrencyContext';
import { PageHeader, DataTable, Pagination, StatCard, StatusBadge } from '../components/ui';

export default function ProductsPage() {
    const navigate = useNavigate();
    const [page, setPage] = useState(1);
    const [search, setSearch] = useState('');
    const { data: productsData, isLoading, refetch, isFetching } = useAllProducts(page, 20, search);
    const { formatAmount, formatNumber } = useCurrency();

    const lowStockCount = productsData?.data.filter((p: any) => p.quantity <= (p.stock_alert || 5)).length || 0;
    const totalValue = productsData?.data.reduce((acc: number, p: any) => acc + (p.price_sale * p.quantity), 0) || 0;

    const columns = [
        {
            key: 'product',
            header: 'Marchandise',
            className: 'w-[30%] min-w-[250px]',
            render: (product: any) => (
                <div className="flex items-center gap-4 group/item">
                    <div className="relative w-12 h-12 rounded-xl bg-[var(--bg-app)] border border-[var(--border-subtle)] overflow-hidden flex items-center justify-center shrink-0 shadow-lg group-hover/item:border-[var(--primary)]/50 transition-colors">
                        {(product.photo_url || product.photo) ? (
                            <img src={product.photo_url || product.photo} alt="" className="w-full h-full object-cover group-hover/item:scale-110 transition-transform duration-700" />
                        ) : (
                            <Package size={20} className="text-[var(--text-muted)] group-hover/item:text-[var(--primary)] transition-colors" />
                        )}
                        <div className="absolute inset-0 bg-gradient-to-t from-black/50 to-transparent opacity-0 group-hover/item:opacity-100 transition-opacity" />
                    </div>
                    <div className="flex flex-col min-w-0">
                        <span className="text-[var(--text-primary)] font-bold text-sm truncate group-hover/item:text-[var(--primary)] transition-colors" title={product.name}>
                            {product.name}
                        </span>
                        <span className="text-[10px] font-mono text-[var(--text-muted)] uppercase tracking-tighter mt-0.5">
                            SKU: {product.id.split('-')[0]}
                        </span>
                    </div>
                </div>
            ),
        },
        {
            key: 'price',
            header: 'Prix de Vente',
            className: 'w-[15%] min-w-[120px]',
            render: (product: any) => (
                <div className="flex flex-col">
                    <span className="font-bold text-[var(--text-primary)] text-base tracking-tight">
                        {formatAmount(product.price_sale)}
                    </span>
                    <span className="text-[9px] text-[var(--text-muted)] font-black uppercase tracking-widest mt-0.5">Unitaire (TTC)</span>
                </div>
            ),
        },
        {
            key: 'quantity',
            header: 'Stock Réel',
            className: 'w-[10%] min-w-[90px]',
            render: (product: any) => (
                <div className="flex flex-col">
                    <span className={`text-base font-black ${product.quantity <= (product.stock_alert || 5) ? 'text-[var(--warning)]' : 'text-[var(--text-primary)]'}`}>
                        {formatNumber(product.quantity)}
                    </span>
                    <span className="text-[9px] text-[var(--text-muted)] font-bold uppercase tracking-widest mt-0.5">Unités</span>
                </div>
            ),
        },
        {
            key: 'status',
            header: 'Disponibilité',
            className: 'w-[15%] min-w-[130px]',
            render: (product: any) => {
                const isLow = product.quantity <= (product.stock_alert || 5);
                const isOut = product.quantity <= 0;

                if (isOut) return <StatusBadge status="error" label="Rupture" />;
                if (isLow) return <StatusBadge status="warning" label="Critique" />;
                return <StatusBadge status="success" label="Optimal" />;
            },
        },
        {
            key: 'assignment',
            header: 'Entrepôt / Boutique',
            className: 'w-[20%] min-w-[160px]',
            render: (product: any) => (
                <div className="flex items-center gap-2.5 group/shop cursor-pointer">
                    <div className="w-8 h-8 rounded-lg bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center shrink-0 group-hover/shop:border-[var(--primary)]/30 transition-colors">
                        <Store size={14} className="text-[var(--text-muted)] group-hover/shop:text-[var(--primary)] transition-colors" />
                    </div>
                    <div className="flex flex-col min-w-0">
                        <span className="text-xs font-bold text-[var(--text-secondary)] group-hover/shop:text-[var(--text-primary)] transition-colors truncate">
                            {product.shops?.name || 'Stock Global'}
                        </span>
                        <span className="text-[9px] text-[var(--text-muted)] font-black uppercase tracking-tighter truncate">
                            {product.category || 'Sans catégorie'}
                        </span>
                    </div>
                </div>
            ),
        },
        {
            key: 'actions',
            header: '',
            className: 'w-[5%] min-w-[50px] text-right',
            render: () => (
                <button className="p-2.5 text-[var(--text-muted)] hover:text-[var(--text-primary)] hover:bg-[var(--primary)]/10 rounded-xl transition-all opacity-0 group-hover:opacity-100">
                    <ArrowUpRight size={18} />
                </button>
            ),
        }
    ];

    return (
        <div className="space-y-10 animate-fade-in pb-20">

            <PageHeader
                title="Catalogue & Inventaire"
                description={`Supervision centralisée des ${productsData?.total ? formatNumber(productsData.total) : '...'} références disponibles sur la plateforme.`}
                actions={
                    <div className="flex items-center gap-3">
                        <button className="px-4 py-2.5 text-xs font-black uppercase tracking-widest text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-colors flex items-center gap-2">
                            <Layers size={14} /> Gérer Catégories
                        </button>
                        <button className="px-5 py-2.5 bg-[var(--primary)] hover:opacity-90 text-white rounded-2xl font-black transition-all shadow-xl shadow-[var(--primary-glow)] flex items-center gap-2 active:scale-95 text-xs uppercase tracking-widest">
                            <Plus size={18} /> Nouveau Produit
                        </button>
                    </div>
                }
            />

            {/* KPI OVERVIEW */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 md:gap-6">
                <StatCard
                    label="Valeur de l'Asset"
                    value={formatAmount(totalValue)}
                    icon={Box}
                    variant="info"
                    changeLabel="Évaluation actuelle"
                />
                <StatCard
                    label="Points de Rupture"
                    value={formatNumber(lowStockCount)}
                    icon={AlertTriangle}
                    variant="warning"
                    change={-12}
                    changeLabel="vs hier"
                />
                <StatCard
                    label="Total Références"
                    value={formatNumber(productsData?.total || 0)}
                    icon={Package}
                    variant="default"
                    changeLabel="Articles distincts"
                />
                <StatCard
                    label="Taux de Rotation"
                    value="4.2x"
                    icon={RefreshCw}
                    variant="success"
                    changeLabel="Performance mensuelle"
                />
            </div>

            {/* SEARCH & FILTER AREA */}
            <div className="flex flex-col lg:flex-row lg:items-center gap-4 bg-[var(--bg-card)] p-3 rounded-2xl border border-[var(--border-subtle)] shadow-inner">
                <div className="relative flex-1">
                    <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-[var(--text-muted)]" size={18} />
                    <input
                        type="text"
                        placeholder="Scanner un code-barre ou rechercher une référence..."
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        className="w-full bg-transparent border-none rounded-xl pl-12 pr-4 py-3 text-sm text-[var(--text-primary)] focus:ring-1 focus:ring-[var(--primary)]/50 placeholder:text-[var(--text-secondary)] transition-all font-bold"
                    />
                </div>
                <div className="hidden lg:block h-8 w-px bg-[var(--border-subtle)] mx-2" />
                <div className="flex items-center gap-3 px-2">
                    <button className="flex items-center gap-2 px-4 py-2 text-xs font-black uppercase tracking-widest text-[var(--text-muted)] hover:text-[var(--text-primary)] hover:bg-[var(--primary)]/10 rounded-xl transition-all">
                        <Filter size={16} /> Filtres Avancés
                    </button>
                    <button
                        onClick={() => refetch()}
                        className={`p-2.5 rounded-xl border border-[var(--border-subtle)] text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-all shadow-sm ${isFetching ? 'bg-[var(--primary)]/10' : 'hover:bg-[var(--primary)]/5'}`}
                    >
                        <RefreshCw size={18} className={isFetching ? 'animate-spin text-[var(--primary)]' : ''} />
                    </button>
                </div>
            </div>

            {/* MAIN DATA TABLE */}
            <div className="relative">
                {isFetching && (
                    <div className="absolute top-0 inset-x-0 h-[2px] bg-gradient-to-r from-transparent via-[var(--primary)] to-transparent z-10 animate-pulse" />
                )}

                <DataTable
                    columns={columns}
                    data={productsData?.data || []}
                    loading={isLoading}
                    emptyMessage="Registre d'inventaire vide pour cette sélection."
                    keyExtractor={(prod) => prod.id}
                    onRowClick={(prod) => navigate(`/products/${prod.id}`)}
                />

                <Pagination
                    page={page}
                    totalPages={productsData?.totalPages || 1}
                    onPageChange={setPage}
                />
            </div>

            {/* Quick Action Banner */}
            <div className="card-dashboard bg-[var(--primary)] shadow-2xl shadow-[var(--primary-glow)] p-6 flex flex-col md:flex-row items-center justify-between gap-6 border-[var(--primary)]/30 overflow-hidden relative">
                <div className="absolute top-0 right-0 w-64 h-64 bg-white/10 blur-3xl rounded-full -mr-20 -mt-20 pointer-events-none" />
                <div className="relative z-10">
                    <h3 className="text-xl font-black text-white uppercase tracking-tight">Besoin d'un réapprovisionnement groupé?</h3>
                    <p className="text-white/70 text-sm font-medium mt-1">Générez un bon de commande automatique basé sur vos alertes de stock.</p>
                </div>
                <button className="relative z-10 px-6 py-3 bg-white text-[var(--primary)] rounded-xl font-black text-xs uppercase tracking-widest shadow-xl hover:scale-105 active:scale-95 transition-all flex items-center gap-2 whitespace-nowrap">
                    Lancer l'automatisation <ArrowRight size={16} />
                </button>
            </div>
        </div>
    );
}
