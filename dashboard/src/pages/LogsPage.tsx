import { useState, useMemo } from 'react';
import {
    FileText, AlertTriangle, AlertCircle, XCircle, CheckCircle2,
    Filter, RefreshCw, Terminal, ChevronDown, ChevronUp, Search,
    Bug, Cpu, Database, Eye, Ghost, History, Download
} from 'lucide-react';
import { format, formatDistanceToNow } from 'date-fns';
import { fr } from 'date-fns/locale';
import { motion, AnimatePresence } from 'framer-motion';

import { useCriticalEvents, useAdminActions } from '../hooks/useData';
import { useCurrency } from '../contexts/CurrencyContext';
import { useToast } from '../contexts/ToastContext';
import type { CriticalAuditEvent, AuditSeverity } from '../types/database';
import { PageHeader, LoadingSpinner, EmptyState, StatusBadge } from '../components/ui';

// --- TYPES SEVERITY CONFIG ---
const SEVERITY_CONFIG: Record<AuditSeverity, { color: string, bg: string, border: string, icon: any, label: string }> = {
    critical: { color: 'text-[var(--error)]', bg: 'bg-[var(--error)]/10', border: 'border-[var(--error)]/20', icon: XCircle, label: 'CRITIQUE' },
    error: { color: 'text-[var(--warning)]', bg: 'bg-[var(--warning)]/10', border: 'border-[var(--warning)]/20', icon: AlertCircle, label: 'ERREUR' },
    warning: { color: 'text-[var(--warning)]', bg: 'bg-[var(--warning)]/10', border: 'border-[var(--warning)]/20', icon: AlertTriangle, label: 'ALERTE' },
    info: { color: 'text-[var(--primary)]', bg: 'bg-[var(--primary)]/10', border: 'border-[var(--primary)]/20', icon: FileText, label: 'INFO' }
};

// --- LOG ROW COMPONENT ---
const LogRow = ({ event, index }: { event: CriticalAuditEvent; index: number }) => {
    const [expanded, setExpanded] = useState(false);
    const { addToast } = useToast();
    const { resolveAuditLog } = useAdminActions();
    const config = SEVERITY_CONFIG[event.severity] || SEVERITY_CONFIG.info;
    const Icon = config.icon;

    const handleResolve = async (e: React.MouseEvent) => {
        e.stopPropagation();
        if (event.resolved) return;

        try {
            await resolveAuditLog.mutateAsync(event.id);
            addToast({
                title: 'Incident Résolu',
                message: "L'événement a été marqué comme traité dans le Sentinel.",
                type: 'success'
            });
        } catch (err) {
            addToast({
                title: 'Erreur',
                message: "Impossible de clore l'incident pour le moment.",
                type: 'error'
            });
        }
    };

    return (
        <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3, delay: Math.min(index * 0.05, 0.5) }}
            className={`group border-b border-[var(--border-subtle)] transition-all duration-300 ${expanded ? 'bg-[var(--primary)]/5' : 'hover:bg-[var(--primary)]/5'}`}
        >
            <div
                onClick={() => setExpanded(!expanded)}
                className="flex items-center gap-6 py-4 px-6 cursor-pointer"
            >
                {/* Node Status Indicator */}
                <div className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 border shadow-lg ${config.bg} ${config.color} ${config.border} group-hover:scale-105 transition-transform`}>
                    <Icon size={18} />
                </div>

                {/* Identity & Origin */}
                <div className="flex-1 min-w-0 grid grid-cols-12 gap-6 items-center">
                    <div className="col-span-3 lg:col-span-2">
                        <div className={`inline-flex items-center px-2 py-0.5 rounded text-[9px] font-black tracking-widest border ${config.bg} ${config.color} ${config.border}`}>
                            {config.label}
                        </div>
                    </div>

                    <div className="col-span-12 lg:col-span-4 flex flex-col">
                        <span className="text-sm font-bold text-[var(--text-primary)] truncate font-mono tracking-tighter group-hover:text-[var(--primary)] transition-colors">
                            {event.type.toUpperCase()}
                        </span>
                        <span className="text-[10px] text-[var(--text-muted)] font-bold uppercase tracking-tighter mt-0.5">Entité: {event.entity_type}</span>
                    </div>

                    <div className="col-span-4 lg:col-span-4 hidden md:block">
                        <div className="flex items-center gap-2">
                            <div className="w-1.5 h-1.5 rounded-full bg-[var(--bg-card)]" />
                            <p className="text-[10px] text-[var(--text-muted)] font-mono truncate">
                                TRACE_{event.id.split('-')[0].toUpperCase()}
                            </p>
                        </div>
                    </div>

                    <div className="col-span-4 lg:col-span-2 text-right">
                        <span className="text-[10px] text-[var(--text-muted)] font-black uppercase tracking-tighter">
                            {formatDistanceToNow(new Date(event.timestamp), { addSuffix: true, locale: fr })}
                        </span>
                    </div>
                </div>

                {/* Chev Down */}
                <div className="text-[var(--text-muted)] group-hover:text-[var(--text-primary)] transition-colors">
                    {expanded ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                </div>
            </div>

            {/* EXPANDED SYSTEM DATA */}
            <AnimatePresence>
                {expanded && (
                    <motion.div
                        initial={{ height: 0, opacity: 0 }}
                        animate={{ height: 'auto', opacity: 1 }}
                        exit={{ height: 0, opacity: 0 }}
                        className="px-6 pb-6 pt-2 pl-[84px] overflow-hidden"
                    >
                        <div className="bg-[var(--bg-app)] rounded-2xl border border-[var(--border-subtle)] p-6 font-mono text-xs overflow-hidden relative shadow-inner">
                            {/* Glossy Overlay */}
                            <div className="absolute top-0 right-0 p-4 opacity-10">
                                <Database size={64} className="text-[var(--text-primary)]" />
                            </div>

                            <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mb-6 relative z-10">
                                <div className="space-y-3">
                                    <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest">Metadata Context</p>
                                    <div className="space-y-2">
                                        <div className="flex justify-between border-b border-[var(--border-subtle)] pb-1">
                                            <span className="text-[var(--text-muted)]">Timestamp</span>
                                            <span className="text-[var(--text-secondary)]">{format(new Date(event.timestamp), 'HH:mm:ss.SSS')}</span>
                                        </div>
                                        <div className="flex justify-between border-b border-[var(--border-subtle)] pb-1">
                                            <span className="text-[var(--text-muted)]">Node ID</span>
                                            <span className="text-[var(--text-secondary)] font-mono">{event.entity_id?.slice(0, 12) || 'N/A'}</span>
                                        </div>
                                    </div>
                                </div>
                                <div className="space-y-3">
                                    <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest">Actor & Location</p>
                                    <div className="space-y-2">
                                        <div className="flex justify-between border-b border-[var(--border-subtle)] pb-1">
                                            <span className="text-[var(--text-muted)]">Operator</span>
                                            <span className="text-[var(--primary)] font-bold">{event.user_name || 'SYSTEM_CORE'}</span>
                                        </div>
                                        <div className="flex justify-between border-b border-[var(--border-subtle)] pb-1">
                                            <span className="text-[var(--text-muted)]">Terminal</span>
                                            <span className="text-[var(--text-secondary)]">{event.shop_name || 'HEADQUARTERS'}</span>
                                        </div>
                                    </div>
                                </div>
                                <div className="space-y-3">
                                    <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest">Internal Status</p>
                                    <div className="flex items-center gap-2 h-full">
                                        <StatusBadge status={event.resolved ? 'success' : 'error'} label={event.resolved ? 'RÉSOLU' : 'NON RÉSOLU'} />
                                    </div>
                                </div>
                            </div>

                            {/* Payload Viewer */}
                            <div className="bg-[var(--bg-card)]/40 rounded-xl p-5 border border-[var(--border-subtle)] font-mono text-[11px] leading-relaxed relative">
                                <div className="absolute top-3 right-4 flex gap-2">
                                    <div className="w-2 h-2 rounded-full bg-[var(--error)]/20" />
                                    <div className="w-2 h-2 rounded-full bg-[var(--warning)]/20" />
                                    <div className="w-2 h-2 rounded-full bg-[var(--success)]/20" />
                                </div>
                                <p className="text-[var(--primary)]/80 mb-2">// DEBUG_PAYLOAD_DUMP</p>
                                <pre className="text-[var(--text-muted)] whitespace-pre-wrap">
                                    {JSON.stringify({
                                        message: (event as any).details || (event.metadata as any)?.message || "No supplementary data",
                                        source: "velmo-api-gateway",
                                        stack: "VelmoRuntime.Exec(opcode: 0x4F)",
                                        trace_id: event.id
                                    }, null, 2)}
                                </pre>
                            </div>
                        </div>

                        {!event.resolved && (
                            <div className="mt-4 flex gap-3">
                                <button
                                    onClick={handleResolve}
                                    className="text-[10px] font-black uppercase tracking-widest flex items-center gap-2 px-4 py-2.5 bg-[var(--success)] hover:brightness-110 text-white rounded-xl transition-all shadow-lg shadow-[var(--success-glow)] active:scale-95 disabled:opacity-50"
                                    disabled={resolveAuditLog.isPending}
                                >
                                    <CheckCircle2 size={14} className={resolveAuditLog.isPending ? 'animate-pulse' : ''} />
                                    {resolveAuditLog.isPending ? 'Traitement...' : "Fermer l'Incident"}
                                </button>
                                <button className="text-[10px] font-black uppercase tracking-widest flex items-center gap-2 px-4 py-2.5 bg-[var(--bg-card)] border border-[var(--border-subtle)] hover:bg-[var(--primary)]/10 text-[var(--text-secondary)] rounded-xl transition-all">
                                    <History size={14} /> Analyser Historique
                                </button>
                            </div>
                        )}
                    </motion.div>
                )}
            </AnimatePresence>
        </motion.div>
    );
};

// --- MAIN PAGE ---

export default function LogsPage() {
    const [page, setPage] = useState(1);
    const [searchTerm, setSearchTerm] = useState('');
    const [severityFilter, setSeverityFilter] = useState<AuditSeverity | null>(null);
    const { data: eventsData, isLoading, refetch, isFetching } = useCriticalEvents(page, 50);
    const { formatNumber } = useCurrency();
    const { addToast } = useToast();

    const filteredData = useMemo(() => {
        if (!eventsData?.data) return [];
        return eventsData.data.filter(e => {
            const matchesSeverity = severityFilter ? e.severity === severityFilter : true;
            const matchesSearch = searchTerm === '' ||
                e.type.toLowerCase().includes(searchTerm.toLowerCase()) ||
                e.entity_type.toLowerCase().includes(searchTerm.toLowerCase()) ||
                e.user_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                e.shop_name?.toLowerCase().includes(searchTerm.toLowerCase());
            return matchesSeverity && matchesSearch;
        });
    }, [eventsData, severityFilter, searchTerm]);

    const handleExport = () => {
        addToast({
            title: 'Export Sentinel',
            message: 'Le vidage des registres audit-log a été initié. Téléchargement imminent.',
            type: 'info'
        });
    };

    const stats = {
        total: eventsData?.total || 0,
        critical: eventsData?.data.filter(e => e.severity === 'critical').length || 0,
        error: eventsData?.data.filter(e => e.severity === 'error').length || 0,
        warning: eventsData?.data.filter(e => e.severity === 'warning').length || 0,
    };

    return (
        <div className="space-y-10 pb-20 animate-fade-in">
            <PageHeader
                title="Logs de Sécurité"
                description="Auditez les événements critiques et les anomalies capturées par le système Velmo Sentinel."
                actions={
                    <button
                        onClick={() => refetch()}
                        className={`p-2.5 rounded-2xl border border-[var(--border-subtle)] text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-all shadow-sm ${isFetching ? 'bg-[var(--primary)]/10' : 'hover:bg-[var(--primary)]/5'}`}
                    >
                        <RefreshCw size={18} className={isFetching ? 'animate-spin text-[var(--primary)]' : ''} />
                    </button>
                }
            />

            {/* MONITORING STATS TILES */}
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-6">
                <div
                    onClick={() => setSeverityFilter(null)}
                    className={`card-dashboard p-6 cursor-pointer transition-all border group relative overflow-hidden ${severityFilter === null ? 'border-[var(--primary)]/50 bg-[var(--primary)]/5' : 'border-[var(--border-subtle)] hover:border-[var(--primary)]/10'}`}
                >
                    <div className="absolute top-0 right-0 p-4 opacity-[0.03] group-hover:scale-110 transition-transform">
                        <FileText size={48} />
                    </div>
                    <span className="text-[10px] text-[var(--text-muted)] font-black uppercase tracking-widest">Volume Audit</span>
                    <p className="text-3xl text-[var(--text-primary)] font-black mt-2">{formatNumber(stats.total)}</p>
                    <div className="mt-4 flex items-center gap-1.5 text-[9px] font-black text-[var(--text-muted)] uppercase">
                        <Cpu size={10} /> Registres cumulés
                    </div>
                </div>

                {[
                    { key: 'critical', label: 'Critique', icon: Ghost, color: 'text-[var(--error)]', bg: 'bg-[var(--error)]/5', border: 'border-[var(--error)]/50', val: stats.critical },
                    { key: 'error', label: 'Erreurs', icon: Bug, color: 'text-[var(--warning)]', bg: 'bg-[var(--warning)]/5', border: 'border-[var(--warning)]/50', val: stats.error },
                    { key: 'warning', label: 'Alertes', icon: AlertTriangle, color: 'text-[var(--warning)]', bg: 'bg-[var(--warning)]/5', border: 'border-[var(--warning)]/50', val: stats.warning },
                ].map((item) => (
                    <div
                        key={item.key}
                        onClick={() => setSeverityFilter(item.key as AuditSeverity)}
                        className={`card-dashboard p-6 cursor-pointer transition-all border group relative overflow-hidden ${severityFilter === item.key ? `${item.border} ${item.bg}` : 'border-[var(--border-subtle)] hover:border-[var(--primary)]/10'}`}
                    >
                        <div className="absolute top-0 right-0 p-4 opacity-[0.03] group-hover:scale-110 transition-transform">
                            <item.icon size={48} />
                        </div>
                        <span className={`text-[10px] font-black uppercase tracking-widest ${item.color}`}>{item.label}</span>
                        <p className={`text-3xl font-black mt-2 ${item.color}`}>{formatNumber(item.val)}</p>
                        <div className="mt-4 flex items-center gap-1.5 text-[var(--text-muted)] font-black uppercase">
                            <Eye size={10} /> Surveillance active
                        </div>
                    </div>
                ))}
            </div>

            {/* CONSOLE VIEW */}
            <div className="card-dashboard p-0 overflow-hidden flex flex-col border-[var(--border-subtle)] bg-[var(--bg-card)] shadow-2xl relative">
                {/* Header Toolbar */}
                <div className="border-b border-[var(--border-subtle)] bg-[var(--primary)]/5 px-6 py-4 flex flex-col sm:flex-row items-center justify-between gap-4">
                    <div className="flex items-center gap-3 text-[var(--text-muted)] text-[10px] font-black uppercase tracking-widest">
                        <Terminal size={14} className="text-[var(--primary)]" />
                        <span className="text-[var(--text-muted)]/60">Protected</span> / Sentinel / <span className="text-[var(--text-primary)]">Audit.log</span>
                    </div>
                    <div className="flex items-center gap-4 w-full sm:w-auto">
                        <div className="relative flex-1 sm:min-w-[240px]">
                            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--text-muted)]" />
                            <input
                                type="text"
                                value={searchTerm}
                                onChange={(e) => setSearchTerm(e.target.value)}
                                placeholder="Grep pattern search..."
                                className="w-full bg-[var(--bg-card)]/50 border border-[var(--border-subtle)] rounded-xl py-2 pl-9 pr-4 text-xs text-[var(--text-primary)] placeholder:text-[var(--text-muted)] focus:ring-1 focus:ring-[var(--primary)]/50 transition-all font-bold"
                            />
                        </div>
                        <div className="h-8 w-px bg-[var(--border-subtle)]" />
                        <button
                            onClick={handleExport}
                            className="text-[10px] font-black text-[var(--text-muted)] hover:text-[var(--text-primary)] uppercase tracking-widest transition-colors flex items-center gap-2"
                        >
                            <Download size={14} /> Export
                        </button>
                    </div>
                </div>

                {/* Log List */}
                <div className="flex-1 divide-y divide-[var(--border-subtle)]">
                    {isLoading ? (
                        <div className="flex flex-col items-center justify-center py-24 gap-4">
                            <LoadingSpinner />
                            <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest animate-pulse">Scanning Sentinel Records...</p>
                        </div>
                    ) : filteredData.length === 0 ? (
                        <EmptyState
                            icon={CheckCircle2}
                            title="Système Nominal"
                            description="Aucun log critique n'est actuellement indexé pour ces filtres."
                        />
                    ) : (
                        filteredData.map((event, idx) => (
                            <LogRow key={event.id} event={event} index={idx} />
                        ))
                    )}
                </div>

                {/* Pagination Footer */}
                <div className="border-t border-[var(--border-subtle)] px-6 py-4 flex justify-between items-center text-[10px] font-black uppercase tracking-widest text-[var(--text-muted)] bg-[var(--primary)]/5">
                    <div className="flex items-center gap-2">
                        ID Sentinel <span className="text-[var(--text-muted)]/60">Node-Alpha</span> • Page <span className="text-[var(--text-primary)]">{page}</span> / {eventsData?.totalPages || 1}
                    </div>
                    <div className="flex gap-4">
                        <button
                            disabled={page === 1}
                            onClick={() => setPage(p => Math.max(1, p - 1))}
                            className="hover:text-[var(--text-primary)] transition-colors disabled:opacity-20 flex items-center gap-1"
                        >
                            PREV
                        </button>
                        <button
                            disabled={page >= (eventsData?.totalPages || 1)}
                            onClick={() => setPage(p => p + 1)}
                            className="hover:text-[var(--text-primary)] transition-colors disabled:opacity-20 flex items-center gap-1"
                        >
                            NEXT
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}
