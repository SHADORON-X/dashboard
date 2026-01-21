import { useState } from 'react';
import {
    Search, Store, Phone,
    RefreshCw, AlertCircle, DollarSign, Clock, User,
    ArrowUpRight, MessageSquare, AlertTriangle, ShieldCheck
} from 'lucide-react';
import { format, isPast } from 'date-fns';
import { fr } from 'date-fns/locale';

import { useNavigate } from 'react-router-dom';
import { useAllDebts } from '../hooks/useData';
import { useCurrency } from '../contexts/CurrencyContext';
import { PageHeader, DataTable, Pagination, StatCard, StatusBadge } from '../components/ui';

export default function DebtsPage() {
    const navigate = useNavigate();
    const [page, setPage] = useState(1);
    const [search, setSearch] = useState('');
    const { data: debtsData, isLoading, refetch, isFetching } = useAllDebts(page, 20);
    const { formatAmount } = useCurrency();

    // Debug logging
    console.log("DebtsPage Render:", {
        count: debtsData?.data.length,
        total: debtsData?.total,
        isLoading,
        isFetching
    });

    const columns = [
        {
            key: 'customer',
            header: 'Débiteur',
            className: 'w-[25%] min-w-[200px]',
            render: (debt: any) => (
                <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl bg-[var(--error)]/10 border border-[var(--error)]/20 text-[var(--error)] flex items-center justify-center shrink-0 shadow-lg shadow-[var(--error)]/5 group-hover:bg-[var(--error)] group-hover:text-white transition-all">
                        <User size={18} />
                    </div>
                    <div className="flex flex-col min-w-0">
                        <span className="text-[var(--text-primary)] font-bold text-sm truncate group-hover:text-[var(--primary)] transition-colors">
                            {debt.customer_name || 'Anonyme'}
                        </span>
                        <div className="flex items-center gap-1.5 mt-0.5 text-[9px] text-[var(--text-muted)] font-black uppercase tracking-tighter">
                            <Phone size={10} /> {debt.customer_phone || 'Non renseigné'}
                        </div>
                    </div>
                </div>
            ),
        },
        {
            key: 'remaining',
            header: 'Reste à Recouvrer',
            className: 'w-[15%] min-w-[120px]',
            render: (debt: any) => (
                <div className="flex flex-col">
                    <span className="font-black text-[var(--error)] text-base tracking-tight">
                        {formatAmount(debt.remaining_amount)}
                    </span>
                    <span className="text-[9px] text-[var(--text-muted)] font-bold uppercase tracking-widest mt-0.5">Sur {formatAmount(debt.total_amount)}</span>
                </div>
            ),
        },
        {
            key: 'status',
            header: 'Risque / État',
            className: 'w-[15%] min-w-[130px]',
            render: (debt: any) => {
                if (!debt.due_date) return <StatusBadge status="pending" label="Indéfini" />;
                const isOverdue = debt.due_date ? isPast(new Date(debt.due_date)) && debt.status !== 'paid' : false;
                return isOverdue ? (
                    <StatusBadge status="error" label="SURENDETTÉ" />
                ) : (
                    <StatusBadge status="warning" label="PROCHE" />
                );
            },
        },
        {
            key: 'shop',
            header: 'Boutique Créancière',
            className: 'w-[20%] min-w-[160px]',
            render: (debt: any) => (
                <div className="flex items-center gap-2.5 group/shop cursor-pointer">
                    <div className="w-8 h-8 rounded-lg bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center shrink-0 group-hover/shop:border-[var(--primary)]/30 transition-colors">
                        <Store size={14} className="text-[var(--text-muted)] group-hover/shop:text-[var(--primary)] transition-colors" />
                    </div>
                    <span className="text-xs font-bold text-[var(--text-muted)] group-hover/shop:text-[var(--text-primary)] transition-colors truncate">
                        {debt.shops?.name || 'Inconnue'}
                    </span>
                </div>
            ),
        },
        {
            key: 'duedate',
            header: 'Échéance Fatale',
            className: 'w-[15%] min-w-[120px]',
            render: (debt: any) => (
                <div className="flex flex-col">
                    <span className="text-[var(--text-secondary)] font-bold text-sm">
                        {debt.due_date ? format(new Date(debt.due_date), 'dd MMM yyyy', { locale: fr }) : 'Non fixée'}
                    </span>
                    <span className="text-[9px] text-[var(--text-muted)] font-black uppercase tracking-tighter mt-0.5">Date limite de paiement</span>
                </div>
            ),
        },
        {
            key: 'actions',
            header: '',
            className: 'w-[10%] min-w-[100px] text-right',
            render: (debt: any) => (
                <div className="flex justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button className="p-2 rounded-xl bg-[var(--success)]/10 text-[var(--success)] hover:bg-[var(--success)] hover:text-white transition-all border border-[var(--success)]/20" title="Relancer">
                        <MessageSquare size={16} />
                    </button>
                    <button
                        onClick={() => navigate(`/debts/${debt.id}`)}
                        className="p-2 rounded-xl bg-[var(--bg-app)] text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-all border border-[var(--border-subtle)]"
                    >
                        <ArrowUpRight size={16} />
                    </button>
                </div>
            ),
        }
    ];

    return (
        <div className="space-y-10 animate-fade-in pb-20">

            <PageHeader
                title="Registre des Créances"
                description={`Pilotage des risques et suivi des ${debtsData?.total || '...'} crédits clients en cours.`}
                actions={
                    <div className="flex items-center gap-3">
                        <button className="px-4 py-2.5 text-xs font-black uppercase tracking-widest text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-colors flex items-center gap-2">
                            <AlertTriangle size={14} /> Rapports de Risque
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

            {/* RISK OVERVIEW */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <StatCard
                    label="Volume d'Impayés"
                    value={formatAmount(debtsData?.data.reduce((acc: number, d: any) => acc + d.remaining_amount, 0) || 0)}
                    icon={DollarSign}
                    variant="error"
                    changeLabel="Exposition totale"
                />
                <StatCard
                    label="Dossiers Critique"
                    value={debtsData?.data.filter((d: any) => d.due_date && isPast(new Date(d.due_date))).length || 0}
                    icon={AlertCircle}
                    variant="warning"
                    change={+2}
                    changeLabel="Retards de paiement"
                />
                <StatCard
                    label="Recouvrement /30j"
                    value="1.2M"
                    icon={ShieldCheck}
                    variant="success"
                    changeLabel="Fonds sécurisés"
                />
                <StatCard
                    label="Délai Moyen"
                    value="14 jours"
                    icon={Clock}
                    variant="default"
                    changeLabel="Délai de paiement"
                />
            </div>

            {/* FILTER AREA */}
            <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4 bg-[var(--bg-card)] p-3 rounded-2xl border border-[var(--border-subtle)] shadow-inner">
                <div className="relative flex-1">
                    <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-[var(--text-muted)]" size={18} />
                    <input
                        type="text"
                        placeholder="Rechercher un client, un dossier ou une boutique..."
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        className="w-full bg-transparent border-none rounded-xl pl-12 pr-4 py-3 text-sm text-[var(--text-primary)] focus:ring-1 focus:ring-[var(--primary)]/50 placeholder:text-[var(--text-muted)]/40 transition-all font-bold"
                    />
                </div>
                <div className="flex items-center gap-2 px-2">
                    <div className="flex bg-[var(--bg-app)]/50 p-1 rounded-xl border border-[var(--border-subtle)]">
                        {['Tous', 'En Retard', 'Sains'].map((f) => (
                            <button
                                key={f}
                                className={`px-4 py-1.5 text-[10px] font-black uppercase tracking-tighter rounded-lg transition-all ${f === 'Tous' ? 'bg-[var(--primary)] text-white shadow-lg shadow-[var(--primary-glow)]' : 'text-[var(--text-muted)] hover:text-[var(--text-primary)]'}`}
                            >
                                {f}
                            </button>
                        ))}
                    </div>
                </div>
            </div>

            {/* MAIN DATA TABLE */}
            <div className="relative">
                {isFetching && (
                    <div className="absolute top-0 inset-x-0 h-[2px] bg-gradient-to-r from-transparent via-[var(--primary)] to-transparent z-10 animate-pulse" />
                )}

                <DataTable
                    columns={columns}
                    data={debtsData?.data || []}
                    loading={isLoading}
                    emptyMessage="Dossier vide. Aucune créance identifiée ! 🎉"
                    keyExtractor={(debt) => debt.id}
                    onRowClick={(debt) => {
                        console.log("👆 Row Clicked:", debt.id);
                        navigate(`/debts/${debt.id}`);
                    }}
                />

                <Pagination
                    page={page}
                    totalPages={debtsData?.totalPages || 1}
                    onPageChange={setPage}
                />
            </div>
        </div>
    );
}
