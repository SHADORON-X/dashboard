import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Filter, XCircle,
    Zap, Search, CheckCircle2,
    Activity, ArrowUpRight, ShieldAlert, RefreshCw,
    Phone, Store
} from 'lucide-react';

import { useStockAlerts, useSilentShops, useCriticalEvents } from '../hooks/useData';
import type { StockAlert } from '../types/database';
import { useCurrency } from '../contexts/CurrencyContext';
import { PageHeader, StatCard, LoadingSpinner, EmptyState } from '../components/ui';

// --- COMPONENTS ---

const StockProgressBar = ({ current, threshold, formatNumber }: { current: number, threshold: number, formatNumber: (v: number) => string }) => {
    const isCritical = current <= 0;
    const isWarning = current <= threshold / 2;

    const colorClass = isCritical
        ? 'bg-[var(--error)] shadow-[0_0_10px_var(--error)]/50'
        : isWarning
            ? 'bg-[var(--warning)] shadow-[0_0_10px_var(--warning)]/50'
            : 'bg-[var(--warning)] shadow-[0_0_10px_var(--warning)]/50';

    const percent = Math.min(100, (current / (threshold * 1.5)) * 100);

    return (
        <div className="w-full mt-4">
            <div className="flex justify-between text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest mb-1.5">
                <span>Disponibilité</span>
                <span className={isCritical ? 'text-[var(--error)]' : 'text-[var(--text-muted)]'}>{formatNumber(current)} / {formatNumber(threshold)} Seuil</span>
            </div>
            <div className="h-1.5 w-full bg-[var(--bg-app)] rounded-full overflow-hidden p-[1px] border border-[var(--border-subtle)]">
                <div
                    className={`h-full rounded-full ${colorClass} transition-all duration-1000 ease-out`}
                    style={{ width: `${isCritical ? 0 : Math.max(5, percent)}%` }}
                />
            </div>
        </div>
    );
}

const AlertCard = ({ alert, onClick, formatNumber }: { alert: StockAlert, onClick: () => void, formatNumber: (v: number) => string }) => {
    const isCritical = alert.current_stock <= 0;

    return (
        <div
            onClick={onClick}
            className={`
                group relative card-dashboard p-6 flex flex-col hover:-translate-y-2 hover:shadow-2xl transition-all duration-500 cursor-pointer
                ${isCritical ? 'border-[var(--error)]/20 bg-[var(--error)]/[0.02]' : 'border-[var(--border-subtle)] hover:border-[var(--primary)]/30'}
            `}
        >
            {/* Dynamic Accent */}
            <div className={`absolute top-0 left-0 w-1 h-full rounded-l-2xl ${isCritical ? 'bg-[var(--error)]' : 'bg-[var(--warning)]'} opacity-50`} />

            {/* Header: Shop Context */}
            <div className="flex justify-between items-start mb-6">
                <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center text-[var(--text-muted)] group-hover:border-[var(--primary)]/50 group-hover:text-[var(--primary)] transition-all duration-500">
                        <Store size={18} />
                    </div>
                    <div>
                        <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest">{alert.owner_name}</p>
                        <h4 className="text-sm font-black text-[var(--text-primary)] group-hover:text-[var(--primary)] transition-colors uppercase tracking-tight">{alert.shop_name}</h4>
                    </div>
                </div>

                <div className="flex items-center gap-2">
                    {alert.owner_phone && (
                        <a
                            href={`tel:${alert.owner_phone}`}
                            onClick={(e) => e.stopPropagation()}
                            className="p-2 rounded-xl bg-[var(--bg-app)] text-[var(--text-muted)] hover:text-[var(--text-primary)] hover:bg-[var(--primary)] transition-all border border-[var(--border-subtle)]"
                        >
                            <Phone size={14} />
                        </a>
                    )}
                </div>
            </div>

            {/* Product Body */}
            <div className="flex-1 mb-6">
                <div className="flex flex-col gap-1">
                    <div className="flex items-center justify-between">
                        <span className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest">Référence Produit</span>
                        {isCritical && (
                            <span className="px-2 py-0.5 rounded-lg text-[8px] font-black uppercase bg-[var(--error)] text-white animate-pulse">Critical Hit</span>
                        )}
                    </div>
                    <h3 className="text-lg font-black text-[var(--text-secondary)] group-hover:text-[var(--text-primary)] transition-colors">{alert.product_name}</h3>
                    <div className="flex items-center gap-2 mt-1">
                        <span className="text-[10px] font-mono text-[var(--text-muted)]">#{alert.product_id?.split('-')[0].toUpperCase()}</span>
                        <div className="w-1 h-1 rounded-full bg-[var(--border-subtle)]" />
                        <span className="text-[10px] text-[var(--text-muted)] font-black uppercase tracking-tighter">SKU Index 1.0</span>
                    </div>
                </div>

                <StockProgressBar current={alert.current_stock} threshold={alert.alert_threshold} formatNumber={formatNumber} />
            </div>

            {/* Footer Metrics */}
            <div className="pt-4 border-t border-[var(--border-subtle)] flex items-center justify-between">
                <div className="flex items-center gap-1.5 text-[var(--text-muted)]">
                    <Activity size={12} />
                    <span className="text-[9px] font-black uppercase tracking-widest">Flux logistique actif</span>
                </div>
                <ArrowUpRight size={16} className="text-[var(--text-muted)] group-hover:text-[var(--primary)] group-hover:translate-x-1 group-hover:-translate-y-1 transition-all" />
            </div>
        </div>
    );
};

// --- MAIN PAGE ---

export default function AlertsPage() {
    const navigate = useNavigate();
    const [page] = useState(1);
    const { data: alertsData, isLoading: stockLoading, refetch: refetchStock, isFetching: stockFetching } = useStockAlerts(page, 100);
    const { data: silentShops, isLoading: silentLoading } = useSilentShops();
    const { data: criticalEvents } = useCriticalEvents(1, 10);
    const { formatNumber } = useCurrency();
    const [filter, setFilter] = useState<'all' | 'critical' | 'warning'>('all');

    const isLoading = stockLoading || silentLoading;
    const isFetching = stockFetching;
    const refetch = () => refetchStock();

    // Counts
    const criticalCount = (alertsData?.data || []).filter(a => a.current_stock <= 0).length || 0;
    const warningCount = (alertsData?.data || []).filter(a => a.current_stock > 0 && a.current_stock <= a.alert_threshold / 2).length || 0;
    const silentCount = silentShops?.length || 0;

    // Filter Logic
    const displayData = (alertsData?.data || []).filter(a => {
        if (filter === 'critical') return a.current_stock <= 0;
        if (filter === 'warning') return a.current_stock > 0 && a.current_stock <= a.alert_threshold / 2;
        return true;
    }) || [];

    return (
        <div className="space-y-10 pb-20 animate-fade-in">

            <PageHeader
                title="Alert Center & Monitoring"
                description="Surveillance proactive des ruptures de stock, de la connectivité des boutiques et des anomalies système."
                actions={
                    <div className="flex items-center gap-3">
                        <button
                            onClick={() => refetch()}
                            className={`p-2.5 rounded-2xl border border-[var(--border-subtle)] text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-all shadow-sm ${isFetching ? 'bg-[var(--primary)]/10' : 'hover:bg-[var(--primary)]/5'}`}
                        >
                            <RefreshCw size={18} className={isFetching ? 'animate-spin text-[var(--primary)]' : ''} />
                        </button>
                    </div>
                }
            />

            {/* SYSTEM ALERTS (SILENT SHOPS & CRITICAL EVENTS) */}
            {(silentCount > 0 || (criticalEvents?.total || 0) > 0) && (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    {/* Silent Shops Alert */}
                    {silentCount > 0 && (
                        <div className="bg-[var(--warning)]/10 border border-[var(--warning)]/20 rounded-3xl p-6 flex items-start gap-4">
                            <div className="w-12 h-12 rounded-2xl bg-[var(--warning)] text-white flex items-center justify-center shrink-0 shadow-lg shadow-[var(--warning)]/20">
                                <Activity size={24} className="animate-pulse" />
                            </div>
                            <div className="flex-1">
                                <h3 className="text-sm font-black text-[var(--warning)] uppercase tracking-widest">Boutiques Silencieuses</h3>
                                <p className="text-xs text-[var(--text-muted)] mt-1 leading-relaxed">
                                    <span className="text-[var(--text-primary)] font-bold">{formatNumber(silentCount)} boutiques</span> n'ont pas synchronisé de données depuis plus de 24 heures. Risque de déconnexion ou panne de terminal.
                                </p>
                                <div className="mt-4 flex gap-2">
                                    <button
                                        onClick={() => navigate('/shops?status=silent')}
                                        className="px-3 py-1.5 bg-[var(--warning)] text-[10px] font-black uppercase text-white rounded-lg hover:brightness-110 transition-all"
                                    >
                                        Inspecter les boutiques
                                    </button>
                                </div>
                            </div>
                        </div>
                    )}

                    {/* Sentinel Critical Events Alert */}
                    {(criticalEvents?.total || 0) > 0 && (
                        <div className="bg-[var(--error)]/10 border border-[var(--error)]/20 rounded-3xl p-6 flex items-start gap-4">
                            <div className="w-12 h-12 rounded-2xl bg-[var(--error)] text-white flex items-center justify-center shrink-0 shadow-lg shadow-[var(--error)]/20">
                                <ShieldAlert size={24} />
                            </div>
                            <div className="flex-1">
                                <h3 className="text-sm font-black text-[var(--error)] opacity-80 uppercase tracking-widest">Sentinel : Alertes Sécurité</h3>
                                <p className="text-xs text-[var(--text-muted)] mt-1 leading-relaxed">
                                    Le système a détecté <span className="text-[var(--text-primary)] font-bold">{formatNumber(criticalEvents?.total || 0)} incidents critiques</span> nécessitant une revue immédiate.
                                </p>
                                <div className="mt-4 flex gap-2">
                                    <button
                                        onClick={() => navigate('/logs?severity=critical')}
                                        className="px-3 py-1.5 bg-[var(--error)] text-[10px] font-black uppercase text-white rounded-lg hover:brightness-110 transition-all"
                                    >
                                        Ouvrir le journal Sentinel
                                    </button>
                                </div>
                            </div>
                        </div>
                    )}
                </div>
            )}

            {/* Summary Filter Cards (Inventory) */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div onClick={() => setFilter('all')} className="cursor-pointer">
                    <StatCard
                        label="Flux Inventaire"
                        value={formatNumber(alertsData?.total || 0)}
                        icon={Filter}
                        variant="info"
                        loading={isLoading}
                        changeLabel="Total des alertes stock"
                    />
                </div>
                <div onClick={() => setFilter('critical')} className="cursor-pointer">
                    <StatCard
                        label="Ruptures Totales"
                        value={formatNumber(criticalCount)}
                        icon={XCircle}
                        variant="error"
                        loading={isLoading}
                        changeLabel="Urgence maximale"
                    />
                </div>
                <div onClick={() => setFilter('warning')} className="cursor-pointer">
                    <StatCard
                        label="Seuils Critiques"
                        value={formatNumber(warningCount)}
                        icon={Zap}
                        variant="warning"
                        loading={isLoading}
                        changeLabel="Réapprovisionnement requis"
                    />
                </div>
            </div>

            {/* Toolbar */}
            <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4 bg-[var(--bg-card)] p-3 rounded-2xl border border-[var(--border-subtle)] shadow-inner">
                <div className="relative flex-1">
                    <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-[var(--text-muted)]" size={18} />
                    <input
                        type="text"
                        placeholder="Rechercher par boutique, produit ou propriétaire..."
                        className="w-full bg-transparent border-none rounded-xl pl-12 pr-4 py-3 text-sm text-[var(--text-primary)] focus:ring-0 placeholder:text-[var(--text-secondary)] font-bold"
                    />
                </div>
                <div className="flex bg-[var(--bg-app)]/50 p-1 rounded-xl border border-[var(--border-subtle)]">
                    {[
                        { label: 'Tous les flux', val: 'all' },
                        { label: 'Ruptures', val: 'critical' },
                        { label: 'Alerte Stock', val: 'warning' }
                    ].map((f) => (
                        <button
                            key={f.val}
                            onClick={() => setFilter(f.val as any)}
                            className={`px-4 py-1.5 text-[10px] font-black uppercase tracking-tighter rounded-lg transition-all ${filter === f.val ? 'bg-[var(--primary)] text-white shadow-lg shadow-[var(--primary-glow)]' : 'text-[var(--text-muted)] hover:text-[var(--text-primary)]'}`}
                        >
                            {f.label}
                        </button>
                    ))}
                </div>
            </div>

            {/* Grid of Alerts */}
            {isLoading ? (
                <div className="flex flex-col items-center justify-center py-24 gap-4">
                    <LoadingSpinner />
                    <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest animate-pulse">Audit des inventaires en cours...</p>
                </div>
            ) : displayData.length === 0 ? (
                <EmptyState
                    icon={CheckCircle2}
                    title="Chaîne Logistique Nominale"
                    description="Aucune anomalie de stock n'a été détectée dans les paramètres actuels."
                />
            ) : (
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-8 animate-fade-in">
                    {displayData.map((alert) => (
                        <AlertCard
                            key={`${alert.shop_id}-${alert.product_id}`}
                            alert={alert}
                            formatNumber={formatNumber}
                            onClick={() => navigate(`/shops/${alert.shop_id}`)}
                        />
                    ))}
                </div>
            )}

            {/* Footer Metadata */}
            {!isLoading && (
                <div className="flex justify-center pt-10 border-t border-[var(--border-subtle)]">
                    <div className="px-4 py-1.5 bg-[var(--bg-app)]/50 rounded-full border border-[var(--border-subtle)] shadow-inner">
                        <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest">
                            Synchro Cloud <span className="text-[var(--success)]">Live</span> • {formatNumber(displayData.length)} Incidents indexés
                        </p>
                    </div>
                </div>
            )}
        </div>
    );
}
