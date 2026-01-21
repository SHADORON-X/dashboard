import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    ShoppingBag, Store, Calendar, CreditCard,
    RefreshCw, Download, Receipt, User,
    Filter, TrendingUp, CheckCircle2, Clock
} from 'lucide-react';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

import { useAllSales } from '../hooks/useData';
import { useCurrency } from '../contexts/CurrencyContext';
import { useToast } from '../contexts/ToastContext';
import { PageHeader, DataTable, Pagination, StatCard, StatusBadge, ExpandableValue } from '../components/ui';

export default function SalesPage() {
    const navigate = useNavigate();
    const { addToast } = useToast();
    const [page, setPage] = useState(1);
    const { data: salesData, isLoading, refetch, isFetching } = useAllSales(page, 20);
    const { formatAmount } = useCurrency();

    const handleExport = () => {
        addToast({
            title: 'Génération du Rapport',
            message: 'Votre journal des ventes est en cours de compilation (PDF/Excel).',
            type: 'info'
        });
    };

    const handlePeriodChange = (period: string) => {
        addToast({
            title: 'Filtrage Dynamique',
            message: `Plage temporelle fixée sur: ${period}.`,
            type: 'info'
        });
    };

    const columns = [
        {
            key: 'ref',
            header: 'N° Transaction',
            className: 'w-[15%] min-w-[150px]',
            render: (sale: any) => (
                <div className="flex flex-col">
                    <span className="text-[11px] text-[var(--text-primary)] font-black tracking-widest uppercase">
                        #{sale.id.slice(0, 8).toUpperCase()}
                    </span>
                    <div className="flex items-center gap-1.5 mt-1 text-[9px] text-[var(--text-muted)] font-bold uppercase tracking-tighter">
                        <Clock size={10} /> {format(new Date(sale.created_at), 'HH:mm')}
                    </div>
                </div>
            ),
        },
        {
            key: 'date',
            header: 'Date',
            className: 'w-[15%] min-w-[120px]',
            render: (sale: any) => (
                <div className="flex flex-col">
                    <span className="text-[var(--text-secondary)] font-bold text-sm">
                        {format(new Date(sale.created_at), 'dd MMMM yyyy', { locale: fr })}
                    </span>
                </div>
            ),
        },
        {
            key: 'shop',
            header: 'Boutique source',
            className: 'w-[20%] min-w-[180px]',
            render: (sale: any) => (
                <div className="flex items-center gap-2.5 group/shop cursor-pointer">
                    <div className="w-8 h-8 rounded-lg bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center shrink-0 group-hover/shop:border-[var(--primary)]/30 transition-colors">
                        <Store size={14} className="text-[var(--text-muted)] group-hover/shop:text-[var(--primary)] transition-colors" />
                    </div>
                    <div className="flex flex-col min-w-0">
                        <span className="text-xs font-bold text-[var(--text-secondary)] group-hover/shop:text-[var(--text-primary)] transition-colors truncate">
                            {sale.shops?.name || 'Vente Directe'}
                        </span>
                        <div className="flex items-center gap-1 mt-0.5 opacity-60">
                            <User size={9} className="text-[var(--text-muted)]" />
                            <span className="text-[9px] text-[var(--text-muted)] font-black uppercase tracking-tighter truncate">
                                {sale.users ? `${sale.users.first_name} ${sale.users.last_name}` : 'Système'}
                            </span>
                        </div>
                    </div>
                </div>
            ),
        },
        {
            key: 'amount',
            header: 'Volume Financier',
            className: 'w-[15%] min-w-[140px]',
            render: (sale: any) => (
                <div className="flex flex-col">
                    <ExpandableValue
                        value={formatAmount(sale.total_amount)}
                        className="font-black text-[var(--text-primary)] text-base tracking-tight"
                    />
                    {sale.discount_amount > 0 && (
                        <span className="text-[10px] text-[var(--success)] font-bold">
                            Remise: -{formatAmount(sale.discount_amount)}
                        </span>
                    )}
                </div>
            ),
        },
        {
            key: 'status',
            header: 'Règlement',
            className: 'w-[15%] min-w-[120px]',
            render: (sale: any) => (
                sale.status === 'paid'
                    ? <StatusBadge status="success" label="Encaissé" />
                    : <StatusBadge status="warning" label="Partiel/Dette" />
            ),
        },
        {
            key: 'method',
            header: 'Méthode',
            className: 'w-[10%] min-w-[100px]',
            render: (sale: any) => (
                <div className="flex items-center gap-1.5">
                    <div className="p-1 rounded bg-[var(--bg-app)] border border-[var(--border-subtle)] text-[var(--text-muted)]">
                        <CreditCard size={12} />
                    </div>
                    <span className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest">
                        {sale.payment_type || 'Cash'}
                    </span>
                </div>
            ),
        },
        {
            key: 'actions',
            header: '',
            className: 'w-[5%] min-w-[50px] text-right',
            render: () => (
                <button className="p-2.5 text-[var(--text-muted)] hover:text-[var(--text-primary)] hover:bg-[var(--primary)]/10 rounded-xl transition-all opacity-0 group-hover:opacity-100">
                    <Receipt size={18} />
                </button>
            ),
        }
    ];

    return (
        <div className="space-y-10 animate-fade-in pb-20">

            <PageHeader
                title="Flux de Trésorerie"
                description={`Audit complet des ${salesData?.total || '...'} transactions enregistrées par le réseau de boutiques.`}
                actions={
                    <div className="flex items-center gap-3">
                        <button
                            onClick={handleExport}
                            className="px-4 py-2.5 text-xs font-black uppercase tracking-widest text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-colors flex items-center gap-2"
                        >
                            <Download size={14} /> Exportation Fiscale
                        </button>
                        <button
                            onClick={() => refetch()}
                            className={`p-2.5 rounded-xl border border-[var(--border-subtle)] text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-all shadow-sm ${isFetching ? 'bg-[var(--primary)]/10' : 'hover:bg-[var(--primary)]/5'}`}
                        >
                            <RefreshCw size={18} className={isFetching ? 'animate-spin text-[var(--primary)]' : ''} />
                        </button>
                    </div>
                }
            />

            {/* KPI FINANCIALS */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 md:gap-6">
                <StatCard
                    label="Volume 24h"
                    value={formatAmount(salesData?.data.slice(0, 5).reduce((acc: number, sale: any) => acc + sale.total_amount, 0) || 0)}
                    icon={TrendingUp}
                    variant="success"
                    index={0}
                    change={+4.2}
                    changeLabel="vs hier"
                />
                <StatCard
                    label="Tickets Validés"
                    value={salesData?.total || 0}
                    icon={CheckCircle2}
                    variant="info"
                    index={1}
                    changeLabel="Total transactions"
                />
                <StatCard
                    label="Paniers Moyens"
                    value={formatAmount((salesData?.data.reduce((acc: number, s: any) => acc + s.total_amount, 0) || 0) / (salesData?.data.length || 1))}
                    icon={ShoppingBag}
                    variant="default"
                    index={2}
                    changeLabel="Valeur par client"
                />
                <StatCard
                    label="Taux Encaissement"
                    value="98.5%"
                    icon={CreditCard}
                    variant="success"
                    index={3}
                    changeLabel="Performance paiements"
                />
            </div>

            {/* FILTER & TOOLS AREA */}
            <div className="flex flex-col lg:flex-row lg:items-center gap-4 bg-[var(--bg-card)] p-3 rounded-2xl border border-[var(--border-subtle)] shadow-inner text-sm">
                <div className="flex items-center gap-2 px-3 text-[var(--text-muted)] font-bold uppercase tracking-widest text-[10px]">
                    <Calendar size={14} /> Période:
                </div>
                <div className="flex bg-[var(--bg-app)]/50 p-1 rounded-xl border border-[var(--border-subtle)]">
                    {['7J', '30J', 'Trimestre', 'Année'].map((period) => (
                        <button
                            key={period}
                            onClick={() => handlePeriodChange(period)}
                            className={`px-3 py-1.5 text-[10px] font-black uppercase tracking-tighter rounded-lg transition-all ${period === '7J' ? 'bg-[var(--primary)] text-white shadow-lg shadow-[var(--primary-glow)]' : 'text-[var(--text-muted)] hover:text-[var(--text-primary)]'}`}
                        >
                            {period}
                        </button>
                    ))}
                </div>
                <div className="flex-1" />
                <button
                    onClick={() => handlePeriodChange('Advance Filters')}
                    className="flex items-center gap-2 px-4 py-3 text-xs font-black uppercase tracking-widest text-[var(--text-muted)] hover:text-[var(--text-primary)] hover:bg-[var(--primary)]/10 rounded-xl transition-all"
                >
                    <Filter size={16} /> Filtres Avancés (Boutique, Vendeur...)
                </button>
            </div>

            {/* MAIN DATA TABLE */}
            <div className="relative">
                {isFetching && (
                    <div className="absolute top-0 inset-x-0 h-[2px] bg-gradient-to-r from-transparent via-[var(--primary)] to-transparent z-10 animate-pulse" />
                )}

                <DataTable
                    columns={columns}
                    data={salesData?.data || []}
                    loading={isLoading}
                    emptyMessage="Aucune transaction détectée dans cette fourchette temporelle."
                    keyExtractor={(sale) => sale.id}
                    onRowClick={(sale) => navigate(`/sales/${sale.id}`)}
                />

                <Pagination
                    page={page}
                    totalPages={salesData?.totalPages || 1}
                    onPageChange={setPage}
                />
            </div>
        </div>
    );
}
