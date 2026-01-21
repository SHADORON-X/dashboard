import { useState, useEffect } from 'react';
import {
    Activity, Filter, RefreshCw, Clock,
    ShoppingBag, AlertTriangle, UserPlus,
    ArrowRight, Zap, Store, DollarSign, Layers
} from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';
import { fr } from 'date-fns/locale';

import { useRealtimeActivity } from '../hooks/useData';
import { useCurrency } from '../contexts/CurrencyContext';
import supabase from '../lib/supabase';
import { PageHeader, StatCard, LoadingSpinner, EmptyState, StatusBadge } from '../components/ui';

// Helper pour l'icone selon le type
const ActivityIcon = ({ type }: { type: string }) => {
    switch (type) {
        case 'sale': return <ShoppingBag size={18} />;
        case 'debt': return <AlertTriangle size={18} />;
        case 'user_created': return <UserPlus size={18} />;
        default: return <Zap size={18} />;
    }
};

// Helper pour la couleur selon le type
const getActivityColor = (type: string) => {
    switch (type) {
        case 'sale': return 'text-[var(--success)] bg-[var(--success)]/10 border-[var(--success)]/20 shadow-[var(--success)]/10';
        case 'debt': return 'text-[var(--error)] bg-[var(--error)]/10 border-[var(--error)]/20 shadow-[var(--error)]/10';
        case 'user_created': return 'text-[var(--primary)] bg-[var(--primary)]/10 border-[var(--primary)]/20 shadow-[var(--primary)]/10';
        default: return 'text-[var(--primary)] bg-[var(--primary)]/10 border-[var(--primary)]/20 shadow-[var(--primary)]/10';
    }
};

export default function ActivityPage() {
    const { data: activity, isLoading, refetch, isFetching } = useRealtimeActivity(100);
    const [autoRefresh, setAutoRefresh] = useState(true);
    const [filterType, setFilterType] = useState<string | null>(null);
    const { formatAmount } = useCurrency();

    // Auto-refresh every 15 seconds as fallback
    useEffect(() => {
        if (!autoRefresh) return;
        const interval = setInterval(() => refetch(), 15000);
        return () => clearInterval(interval);
    }, [autoRefresh, refetch]);

    // Subscribe to realtime changes (Direct Supabase)
    useEffect(() => {
        const channel = supabase.channel('activity-feed-realtime')
            .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'sales' }, () => refetch())
            .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'debts' }, () => refetch())
            .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'users' }, () => refetch())
            .subscribe();
        return () => { supabase.removeChannel(channel); };
    }, [refetch]);

    const filteredActivity = filterType
        ? activity?.filter(a => a.activity_type === filterType)
        : activity;

    const activityCounts = {
        sale: activity?.filter(a => a.activity_type === 'sale').length || 0,
        debt: activity?.filter(a => a.activity_type === 'debt').length || 0,
        user_created: activity?.filter(a => a.activity_type === 'user_created').length || 0,
    };

    return (
        <div className="space-y-10 pb-20 animate-fade-in">

            <PageHeader
                title="Flux d'Activité"
                description="Surveillance en temps réel de tous les événements critiques survenant dans l'écosystème Velmo."
                actions={
                    <div className="flex items-center gap-3">
                        <button
                            onClick={() => setAutoRefresh(!autoRefresh)}
                            className={`flex items-center gap-2 px-4 py-2.5 rounded-2xl text-[10px] font-black uppercase tracking-widest transition-all border shadow-lg ${autoRefresh
                                ? 'bg-[var(--success)]/10 text-[var(--success)] border-[var(--success)]/20'
                                : 'bg-[var(--bg-app)]/50 text-[var(--text-muted)] border-[var(--border-subtle)] hover:text-[var(--text-primary)]'}`}
                        >
                            <span className={`w-1.5 h-1.5 rounded-full ${autoRefresh ? 'bg-[var(--success)] animate-pulse' : 'bg-[var(--text-muted)]'}`} />
                            {autoRefresh ? 'Monitor Actif' : 'Monitor Suspendu'}
                        </button>
                        <button
                            onClick={() => refetch()}
                            className={`p-2.5 rounded-2xl border border-[var(--border-subtle)] text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-all shadow-sm ${isFetching ? 'bg-[var(--primary)]/10' : 'hover:bg-[var(--primary)]/5'}`}
                        >
                            <RefreshCw size={18} className={isFetching ? 'animate-spin text-[var(--primary)]' : ''} />
                        </button>
                    </div>
                }
            />

            {/* PERFORMANCE KPI */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <StatCard
                    label="Transactions (1h)"
                    value={activityCounts.sale}
                    icon={DollarSign}
                    variant="success"
                    changeLabel="Ventes confirmées"
                />
                <StatCard
                    label="Alertes Risque"
                    value={activityCounts.debt}
                    icon={AlertTriangle}
                    variant="error"
                    changeLabel="Dettes enregistrées"
                />
                <StatCard
                    label="Nouveaux Agents"
                    value={activityCounts.user_created}
                    icon={UserPlus}
                    variant="info"
                    changeLabel="Collaborateurs inscrits"
                />
            </div>

            {/* MAIN CONTENT LAYOUT */}
            <div className="grid grid-cols-1 lg:grid-cols-4 gap-8">

                {/* TOOLBAR & FILTERS */}
                <div className="lg:col-span-1 space-y-6">
                    <div className="card-dashboard bg-[var(--bg-card)] border-[var(--border-subtle)]">
                        <h3 className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest mb-6 flex items-center gap-2">
                            <Filter size={14} /> Filtres Systèmes
                        </h3>
                        <div className="flex flex-col gap-1.5">
                            {[
                                { label: 'Tous les flux', val: null, icon: Activity },
                                { label: 'Ventes Uniquement', val: 'sale', icon: ShoppingBag },
                                { label: 'Dettes & Risques', val: 'debt', icon: AlertTriangle },
                                { label: 'Membres & Agents', val: 'user_created', icon: UserPlus },
                            ].map((f) => (
                                <button
                                    key={String(f.val)}
                                    onClick={() => setFilterType(f.val)}
                                    className={`flex items-center gap-3 px-4 py-3 rounded-xl text-xs font-bold transition-all border
                                        ${filterType === f.val
                                            ? 'bg-[var(--primary)]/10 text-[var(--text-primary)] border-[var(--primary)]/30 shadow-lg'
                                            : 'text-[var(--text-muted)] border-transparent hover:text-[var(--text-secondary)] hover:bg-[var(--bg-app)]/50'}`}
                                >
                                    <f.icon size={16} className={filterType === f.val ? 'text-[var(--primary)]' : 'text-[var(--text-muted)]/50'} />
                                    {f.label}
                                </button>
                            ))}
                        </div>
                    </div>

                    <div className="card-dashboard bg-[var(--primary)] shadow-2xl shadow-[var(--primary-glow)] p-6 border-[var(--primary)]/30 overflow-hidden relative">
                        <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 blur-2xl rounded-full -mr-10 -mt-10" />
                        <p className="text-[9px] font-black text-white/50 uppercase tracking-widest mb-2">Audit Express</p>
                        <p className="text-white font-bold text-sm mb-4 leading-relaxed">Générez un rapport complet des 24 dernières heures.</p>
                        <button className="w-full py-2.5 bg-white text-[var(--primary)] rounded-xl font-black text-[10px] uppercase tracking-widest shadow-xl flex items-center justify-center gap-2 hover:scale-105 active:scale-95 transition-all">
                            Télécharger PDF <ArrowRight size={14} />
                        </button>
                    </div>
                </div>

                {/* TIMELINE FEED (Premium Timeline Style) */}
                <div className="lg:col-span-3 card-dashboard bg-[var(--bg-card)] border-[var(--border-subtle)] min-h-[600px] flex flex-col p-8">
                    <div className="flex items-center justify-between mb-10">
                        <h2 className="text-xl font-black text-[var(--text-primary)] uppercase tracking-tighter">Observatoire Tactique</h2>
                        <span className="px-3 py-1 bg-[var(--bg-app)]/50 rounded-lg text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest">
                            {filteredActivity?.length || 0} Événements capturés
                        </span>
                    </div>

                    {isLoading ? (
                        <div className="flex-1 flex flex-col items-center justify-center gap-4">
                            <LoadingSpinner />
                            <p className="text-[10px] font-black text-[var(--text-muted)] uppercase animate-pulse">Synchronisation avec le cloud...</p>
                        </div>
                    ) : !filteredActivity?.length ? (
                        <EmptyState
                            icon={Layers}
                            title="Néant Opérationnel"
                            description="Aucun événement n'a été signalé dans cette catégorie pour le moment."
                        />
                    ) : (
                        <div className="relative space-y-8 before:absolute before:inset-y-0 before:left-[27px] before:w-px before:bg-gradient-to-b before:from-[var(--primary)]/50 before:via-[var(--border-subtle)] before:to-transparent">
                            {filteredActivity.map((item, idx) => (
                                <div key={idx} className="relative flex gap-6 items-start group animate-fade-in">
                                    {/* Icon Node */}
                                    <div className={`
                                        w-14 h-14 rounded-2xl flex items-center justify-center border shadow-2xl z-10 shrink-0
                                        ${getActivityColor(item.activity_type)}
                                    `}>
                                        <ActivityIcon type={item.activity_type} />
                                    </div>

                                    {/* Event Card */}
                                    <div className="flex-1 bg-[var(--bg-app)]/50 border border-[var(--border-subtle)] rounded-3xl p-5 hover:bg-[var(--primary)]/5 hover:border-[var(--primary)]/20 transition-all duration-300 relative group/card">
                                        <div className="absolute top-5 right-5 opacity-0 group-hover/card:opacity-100 transition-opacity">
                                            <ArrowRight size={16} className="text-[var(--text-muted)]" />
                                        </div>

                                        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                                            <div>
                                                <div className="flex items-center gap-2">
                                                    <h4 className="text-[var(--text-primary)] font-black text-sm uppercase tracking-tight">
                                                        {item.activity_type === 'sale' && 'Encaissement Boutique'}
                                                        {item.activity_type === 'debt' && 'Alerte de Crédit'}
                                                        {item.activity_type === 'user_created' && 'Déploiement Agent'}
                                                    </h4>
                                                    <span className="w-1 h-1 rounded-full bg-[var(--border-subtle)]" />
                                                    <p className="text-[var(--text-muted)] text-[10px] font-black uppercase tracking-widest flex items-center gap-1.5">
                                                        <Clock size={10} />
                                                        {formatDistanceToNow(new Date(item.activity_at), { addSuffix: true, locale: fr })}
                                                    </p>
                                                </div>
                                                <div className="mt-2 flex items-center gap-4">
                                                    <div className="flex items-center gap-1.5 text-[11px] font-bold text-[var(--text-muted)]">
                                                        <Store size={12} className="text-[var(--text-muted)]/50" />
                                                        {item.shop_name}
                                                    </div>
                                                </div>
                                            </div>

                                            {item.amount && (
                                                <div className="flex flex-col items-end">
                                                    <div className={`text-lg font-black font-mono tracking-tighter ${item.activity_type === 'debt' ? 'text-[var(--error)]' : 'text-[var(--success)]'}`}>
                                                        {formatAmount(item.amount)}
                                                    </div>
                                                    <span className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest mt-0.5">Volume Transactionnel</span>
                                                </div>
                                            )}
                                        </div>

                                        <div className="mt-4 pt-4 border-t border-[var(--border-subtle)] flex items-center gap-3">
                                            {item.activity_type === 'debt' && <StatusBadge status="warning" label={item.status || 'Impayé'} />}
                                            {item.activity_type === 'sale' && <StatusBadge status="success" label="Validé" />}
                                            {item.activity_type === 'user_created' && <StatusBadge status="info" label="Confirmé" />}

                                            <div className="h-4 w-px bg-[var(--border-subtle)] mx-1" />
                                            <p className="text-[10px] text-[var(--text-muted)] font-bold italic">Réf: {item.activity_at.slice(-8).toUpperCase()}</p>
                                        </div>
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}
