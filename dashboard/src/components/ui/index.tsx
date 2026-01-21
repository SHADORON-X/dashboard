import React from 'react';
import { TrendingUp, TrendingDown, Minus, Search } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';

// ============================================
// STAT CARD (Enhanced Premium)
// ============================================

interface StatCardProps {
    label: string;
    value: string | number;
    icon?: LucideIcon;
    change?: number;
    changeLabel?: string;
    variant?: 'default' | 'success' | 'warning' | 'error' | 'info' | 'indigo' | 'violet';
    loading?: boolean;
}

export function StatCard({
    label,
    value,
    icon: Icon,
    change,
    changeLabel,
    variant = 'default',
    loading = false
}: StatCardProps) {
    const variantStyles: Record<string, { bg: string, text: string, border: string }> = {
        default: { bg: 'bg-[var(--primary)]/10', text: 'text-[var(--primary)]', border: 'border-[var(--primary)]/20' },
        success: { bg: 'bg-[var(--success)]/10', text: 'text-[var(--success)]', border: 'border-[var(--success)]/20' },
        warning: { bg: 'bg-[var(--warning)]/10', text: 'text-[var(--warning)]', border: 'border-[var(--warning)]/20' },
        error: { bg: 'bg-[var(--error)]/10', text: 'text-[var(--error)]', border: 'border-[var(--error)]/20' },
        info: { bg: 'bg-[var(--info)]/10', text: 'text-[var(--info)]', border: 'border-[var(--info)]/20' },
        indigo: { bg: 'bg-[var(--primary)]/10', text: 'text-[var(--primary)]', border: 'border-[var(--primary)]/20' },
        violet: { bg: 'bg-violet-500/10', text: 'text-violet-400', border: 'border-violet-500/20' },
    };

    const style = variantStyles[variant] || variantStyles.default;

    if (loading) {
        return (
            <div className="card-dashboard animate-pulse">
                <div className="flex items-center justify-between mb-4">
                    <div className="h-4 w-24 bg-[var(--border-subtle)] rounded" />
                    <div className="h-10 w-10 bg-[var(--border-subtle)] rounded-xl" />
                </div>
                <div className="h-8 w-32 bg-[var(--border-subtle)] rounded mb-2" />
                <div className="h-3 w-20 bg-[var(--border-subtle)] rounded" />
            </div>
        );
    }

    return (
        <div className="card-dashboard group relative overflow-hidden">
            {/* Background Glow Effect */}
            <div className={`absolute -right-4 -top-4 w-24 h-24 rounded-full blur-3xl opacity-0 group-hover:opacity-20 transition-opacity duration-700 ${style.bg}`} />

            <div className="flex items-center justify-between relative z-10">
                <span className="text-sm font-medium text-[var(--text-secondary)] group-hover:text-[var(--text-primary)] transition-colors uppercase tracking-wider">{label}</span>
                {Icon && (
                    <div className={`p-2.5 rounded-xl border ${style.border} ${style.bg} shadow-lg shadow-black/20 group-hover:scale-110 transition-transform duration-500`}>
                        <Icon size={20} className={style.text} />
                    </div>
                )}
            </div>

            <div className="mt-4 relative z-10 min-w-0">
                <h3
                    className={`font-black tracking-tight text-[var(--text-primary)] group-hover:translate-x-1 transition-transform duration-500 truncate
                        ${String(value).length > 15 ? 'text-xl sm:text-2xl' :
                            String(value).length > 12 ? 'text-2xl sm:text-3xl' :
                                'text-3xl sm:text-4xl'}`}
                    title={String(value)}
                >
                    {value}
                </h3>

                {change !== undefined && (
                    <div className="flex items-center gap-1.5 mt-2">
                        <div className={`flex items-center gap-0.5 text-xs font-bold px-1.5 py-0.5 rounded-full border ${change > 0
                            ? 'text-[var(--success)] bg-[var(--success)]/10 border-[var(--success)]/20'
                            : change < 0
                                ? 'text-[var(--error)] bg-[var(--error)]/10 border-[var(--error)]/20'
                                : 'text-[var(--text-secondary)] bg-[var(--bg-app)]/50 border-[var(--border-subtle)]'
                            }`}>
                            {change > 0 ? <TrendingUp size={12} /> : change < 0 ? <TrendingDown size={12} /> : <Minus size={12} />}
                            <span>{Math.abs(change)}%</span>
                        </div>
                        {changeLabel && <span className="text-[10px] text-[var(--text-muted)] font-bold uppercase tracking-tight">{changeLabel}</span>}
                    </div>
                )}
            </div>
        </div>
    );
}

// ============================================
// DATA TABLE
// ============================================

interface Column<T> {
    key: string;
    header: string;
    render?: (item: T) => React.ReactNode;
    className?: string;
}

interface DataTableProps<T> {
    columns: Column<T>[];
    data: T[];
    loading?: boolean;
    emptyMessage?: string;
    onRowClick?: (item: T) => void;
    keyExtractor: (item: T) => string;
}

export function DataTable<T>({
    columns,
    data,
    loading = false,
    emptyMessage = 'Aucune donnée trouvée',
    onRowClick,
    keyExtractor
}: DataTableProps<T>) {
    if (loading) {
        return (
            <div className="card-dashboard overflow-hidden p-0 border-[var(--border-subtle)]">
                <div className="overflow-x-auto custom-scrollbar">
                    <table className="w-full text-left border-collapse">
                        <thead>
                            <tr className="border-b border-[var(--border-subtle)] bg-[var(--bg-card)]/50">
                                {columns.map((col) => (
                                    <th key={col.key} className="px-6 py-4 text-[10px] font-black uppercase tracking-widest text-[var(--text-muted)]">
                                        <div className="h-3 w-16 bg-[var(--border-subtle)] rounded animate-pulse" />
                                    </th>
                                ))}
                            </tr>
                        </thead>
                        <tbody>
                            {[...Array(5)].map((_, i) => (
                                <tr key={i} className="border-b border-[var(--border-subtle)]">
                                    {columns.map((col) => (
                                        <td key={col.key} className="px-6 py-4">
                                            <div className="h-4 w-full bg-[var(--border-subtle)]/50 rounded animate-pulse" />
                                        </td>
                                    ))}
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            </div>
        );
    }

    if (data.length === 0) {
        return (
            <div className="card-dashboard flex flex-col items-center justify-center py-20 text-center">
                <div className="w-16 h-16 rounded-full bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center mb-4">
                    <Search className="text-[var(--text-muted)]" size={32} />
                </div>
                <h3 className="text-[var(--text-secondary)] font-medium">{emptyMessage}</h3>
                <p className="text-[var(--text-muted)] text-sm mt-1">Essayez d'ajuster vos filtres</p>
            </div>
        );
    }

    return (
        <div className="card-dashboard overflow-hidden p-0 border-[var(--border-subtle)] shadow-2xl">
            <div className="overflow-x-auto custom-scrollbar pb-2">
                <table className="w-full text-left border-collapse">
                    <thead>
                        <tr className="border-b border-[var(--border-subtle)] bg-[var(--bg-card)]/30">
                            {columns.map((col) => (
                                <th key={col.key} className={`px-6 py-5 text-[10px] font-black uppercase tracking-widest text-[var(--text-muted)] ${col.className}`}>
                                    {col.header}
                                </th>
                            ))}
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-[var(--border-subtle)]">
                        {data.map((item) => (
                            <tr
                                key={keyExtractor(item)}
                                onClick={() => onRowClick?.(item)}
                                className={`
                                    group transition-all duration-300
                                    ${onRowClick ? 'cursor-pointer hover:bg-[var(--primary)]/5' : 'hover:bg-[var(--primary)]/2'}
                                `}
                            >
                                {columns.map((col) => (
                                    <td key={col.key} className={`px-6 py-4 text-sm text-[var(--text-secondary)] group-hover:text-[var(--text-primary)] transition-colors ${col.className}`}>
                                        {col.render
                                            ? col.render(item)
                                            : (item as Record<string, unknown>)[col.key] as React.ReactNode
                                        }
                                    </td>
                                ))}
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        </div>
    );
}

// ============================================
// PAGINATION
// ============================================

interface PaginationProps {
    page: number;
    totalPages: number;
    onPageChange: (page: number) => void;
}

export function Pagination({ page, totalPages, onPageChange }: PaginationProps) {
    if (totalPages <= 1) return null;

    const pages = [];
    const showEllipsisStart = page > 3;
    const showEllipsisEnd = page < totalPages - 2;

    for (let i = 1; i <= totalPages; i++) {
        if (
            i === 1 ||
            i === totalPages ||
            (i >= page - 1 && i <= page + 1)
        ) {
            pages.push(i);
        } else if (
            (showEllipsisStart && i === 2) ||
            (showEllipsisEnd && i === totalPages - 1)
        ) {
            pages.push(-i);
        }
    }

    return (
        <div className="flex items-center justify-center gap-2 mt-8">
            <button
                onClick={() => onPageChange(page - 1)}
                disabled={page === 1}
                className="px-4 py-2 text-xs font-bold text-[var(--text-secondary)] hover:text-[var(--text-primary)] disabled:opacity-30 disabled:hover:text-[var(--text-secondary)] transition-colors uppercase tracking-widest"
            >
                Précédent
            </button>

            <div className="flex items-center gap-1 bg-[var(--bg-card)]/50 p-1 rounded-xl border border-[var(--border-subtle)] shadow-inner">
                {pages.map((p, i) => (
                    p < 0 ? (
                        <span key={i} className="px-2 text-[var(--text-muted)]">...</span>
                    ) : (
                        <button
                            key={p}
                            onClick={() => onPageChange(p)}
                            className={`
                                min-w-[36px] h-9 px-3 rounded-lg text-xs font-bold transition-all
                                ${p === page
                                    ? 'bg-[var(--primary)] text-white shadow-lg shadow-[var(--primary-glow)] border border-white/10'
                                    : 'text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--border-subtle)]'
                                }
                            `}
                        >
                            {p}
                        </button>
                    )
                ))}
            </div>

            <button
                onClick={() => onPageChange(page + 1)}
                disabled={page === totalPages}
                className="px-4 py-2 text-xs font-bold text-[var(--text-secondary)] hover:text-[var(--text-primary)] disabled:opacity-30 disabled:hover:text-[var(--text-secondary)] transition-colors uppercase tracking-widest"
            >
                Suivant
            </button>
        </div>
    );
}

// ============================================
// STATUS BADGE
// ============================================

interface StatusBadgeProps {
    status: 'active' | 'inactive' | 'warning' | 'error' | 'pending' | 'success' | 'info' | 'default';
    label?: string;
}

export function StatusBadge({ status, label }: StatusBadgeProps) {
    const statusConfig: Record<string, { className: string, dot: string, label: string }> = {
        active: { className: 'text-[var(--success)] bg-[var(--success)]/10 border-[var(--success)]/20', dot: 'bg-[var(--success)]', label: label || 'Actif' },
        success: { className: 'text-[var(--success)] bg-[var(--success)]/10 border-[var(--success)]/20', dot: 'bg-[var(--success)]', label: label || 'Succès' },
        inactive: { className: 'text-[var(--text-muted)] bg-[var(--text-muted)]/10 border-[var(--text-muted)]/20', dot: 'bg-[var(--text-muted)]', label: label || 'Inactif' },
        warning: { className: 'text-[var(--warning)] bg-[var(--warning)]/10 border-[var(--warning)]/20', dot: 'bg-[var(--warning)]', label: label || 'Attention' },
        error: { className: 'text-[var(--error)] bg-[var(--error)]/10 border-[var(--error)]/20', dot: 'bg-[var(--error)]', label: label || 'Erreur' },
        pending: { className: 'text-[var(--info)] bg-[var(--info)]/10 border-[var(--info)]/20', dot: 'bg-[var(--info)]', label: label || 'En attente' },
        info: { className: 'text-[var(--primary)] bg-[var(--primary)]/10 border-[var(--primary)]/20', dot: 'bg-[var(--primary)]', label: label || 'Info' },
        default: { className: 'text-[var(--text-muted)] bg-[var(--text-muted)]/10 border-[var(--text-muted)]/20', dot: 'bg-[var(--text-muted)]', label: label || 'N/A' },
    };

    const config = statusConfig[status] || statusConfig.info;

    return (
        <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-[10px] font-black uppercase tracking-wider border shadow-sm ${config.className}`}>
            <span className={`w-1.5 h-1.5 rounded-full mr-2 shadow-[0_0_5px_currentColor] ${config.dot} ${status === 'active' || status === 'success' ? 'animate-pulse' : ''}`} />
            {config.label}
        </span>
    );
}

// ============================================
// PAGE HEADER
// ============================================

interface PageHeaderProps {
    title: string;
    description?: React.ReactNode;
    actions?: React.ReactNode;
}

export function PageHeader({ title, description, actions }: PageHeaderProps) {
    return (
        <div className="flex flex-col md:flex-row md:items-end md:justify-between gap-6 mb-10">
            <div>
                <h1 className="heading-1">{title}</h1>
                {description && <p className="text-[var(--text-secondary)] max-w-2xl text-sm md:text-base font-medium leading-relaxed">{description}</p>}
            </div>
            {actions && <div className="flex items-center gap-3 animate-fade-in stagger-2 shrink-0">{actions}</div>}
        </div>
    );
}

// ============================================
// HELPER COMPONENTS
// ============================================

export function LoadingSpinner({ className = '' }: { className?: string }) {
    return <div className={`w-8 h-8 border-3 border-[var(--primary)] border-t-transparent rounded-full animate-spin ${className}`} />;
}

export function EmptyState({ icon: Icon, title, description, action }: { icon?: LucideIcon, title: string, description?: string, action?: React.ReactNode }) {
    return (
        <div className="card-dashboard text-center py-20 bg-[var(--bg-app)]/30">
            {Icon && (
                <div className="w-20 h-20 mx-auto mb-6 bg-[var(--bg-app)] border border-[var(--border-subtle)] rounded-3xl flex items-center justify-center shadow-2xl">
                    <Icon size={40} className="text-[var(--text-muted)]" />
                </div>
            )}
            <h3 className="text-xl font-bold text-[var(--text-primary)] mb-2">{title}</h3>
            {description && <p className="text-[var(--text-secondary)] mb-8 max-w-sm mx-auto text-sm leading-relaxed">{description}</p>}
            {action}
        </div>
    );
}
