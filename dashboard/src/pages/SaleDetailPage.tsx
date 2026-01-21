import { useParams, useNavigate } from 'react-router-dom';
import {
    ArrowLeft, ShoppingBag, Store, User as UserIcon,
    CreditCard, DollarSign,
    FileText, Zap, ShieldCheck, Printer,
    ExternalLink, Info
} from 'lucide-react';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

import { useSaleDetails } from '../hooks/useData';
import { useCurrency } from '../contexts/CurrencyContext';
import { LoadingSpinner, EmptyState, StatusBadge } from '../components/ui';

export default function SaleDetailPage() {
    const { saleId } = useParams();
    const navigate = useNavigate();
    const { data: sale, isLoading } = useSaleDetails(saleId || null);
    const { formatAmount } = useCurrency();

    if (isLoading) {
        return (
            <div className="min-h-[60vh] flex flex-col items-center justify-center gap-4">
                <LoadingSpinner />
                <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest animate-pulse">Décryptage de la transaction Ledger...</p>
            </div>
        );
    }

    if (!sale) {
        return (
            <EmptyState
                icon={ShoppingBag}
                title="Transaction Introuvable"
                description="Cet index de vente n'existe pas ou n'est pas autorisé pour votre niveau d'accés."
            />
        );
    }

    const isDebt = sale.payment_type === 'credit';

    return (
        <div className="space-y-10 pb-20 animate-fade-in">
            {/* Header */}
            <div className="flex items-center gap-4">
                <button
                    onClick={() => navigate('/sales')}
                    className="p-3 rounded-2xl bg-[var(--bg-card)] border border-[var(--border-subtle)] text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-all shadow-sm"
                >
                    <ArrowLeft size={20} />
                </button>
                <div className="h-10 w-px bg-[var(--border-subtle)] mx-2" />
                <div>
                    <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest">Grand Livre des Opérations</p>
                    <h1 className="text-2xl font-black text-[var(--text-primary)] uppercase tracking-tighter">Fiche de Transaction</h1>
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">

                {/* Transaction Summary */}
                <div className="lg:col-span-1 space-y-6">
                    <div className="card-dashboard p-8 relative overflow-hidden group">
                        <div className="absolute top-0 right-0 p-6 opacity-[0.03] group-hover:opacity-[0.08] transition-opacity">
                            <CreditCard size={150} className="-rotate-12 translate-x-10 translate-y-[-20px]" />
                        </div>

                        <div className="mb-8">
                            <div className="flex items-center justify-between mb-4">
                                <StatusBadge
                                    status={isDebt ? 'warning' : 'active'}
                                    label={isDebt ? 'CRÉDIT ACTIF' : 'PAYÉ'}
                                />
                                <span className="text-[10px] font-mono text-[var(--text-muted)] tracking-tighter">TX_REF: {sale.id.split('-')[0].toUpperCase()}</span>
                            </div>
                            <h2
                                className={`font-black text-[var(--text-primary)] tracking-tighter font-mono italic truncate
                                    ${formatAmount(sale.total_amount).length > 15 ? 'text-2xl sm:text-3xl' : 'text-3xl sm:text-4xl'}`}
                                title={formatAmount(sale.total_amount)}
                            >
                                {formatAmount(sale.total_amount)}
                            </h2>
                            <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-[0.2em] mt-3">{format(new Date(sale.created_at), 'PPP à HH:mm', { locale: fr })}</p>
                        </div>

                        <div className="pt-8 border-t border-[var(--border-subtle)] space-y-5">
                            <div className="flex justify-between items-center group/item cursor-help">
                                <div className="flex items-center gap-3">
                                    <div className="w-8 h-8 rounded-lg bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center text-[var(--text-muted)] group-hover/item:text-[var(--primary)] transition-colors">
                                        <Zap size={14} />
                                    </div>
                                    <span className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest">Méthode</span>
                                </div>
                                <span className="text-xs font-bold text-[var(--text-secondary)] uppercase tracking-tight">{sale.payment_type || 'Cash'}</span>
                            </div>

                            <div className="flex justify-between items-center group/item">
                                <div className="flex items-center gap-3">
                                    <div className="w-8 h-8 rounded-lg bg-[var(--success)]/10 border border-[var(--success)]/10 flex items-center justify-center text-[var(--success)]">
                                        <DollarSign size={14} />
                                    </div>
                                    <span className="text-[10px] font-black text-[var(--success)]/50 uppercase tracking-widest">Profit Net (Est.)</span>
                                </div>
                                <span className="text-xs font-black text-[var(--success)]">+{formatAmount(sale.total_profit || 0)}</span>
                            </div>
                        </div>
                    </div>

                    {/* Parties Involved */}
                    <div className="space-y-4">
                        {/* Shop Context */}
                        <div
                            onClick={() => sale.shop_id && navigate(`/shops/${sale.shop_id}`)}
                            className="card-dashboard p-5 group cursor-pointer border-[var(--border-subtle)] hover:border-[var(--primary)]/30 transition-all bg-[var(--bg-card)] active:scale-95"
                        >
                            <div className="flex items-center gap-4">
                                <div className="w-10 h-10 rounded-xl bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center text-[var(--text-muted)] group-hover:bg-[var(--primary)] group-hover:text-white transition-all">
                                    <Store size={18} />
                                </div>
                                <div className="flex-1">
                                    <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest">Point de Vente</p>
                                    <p className="text-sm font-bold text-[var(--text-secondary)]">{sale.shops?.name}</p>
                                </div>
                                <ExternalLink size={14} className="text-[var(--text-muted)] group-hover:text-[var(--primary)] transition-colors" />
                            </div>
                        </div>

                        {/* Agent Context */}
                        <div
                            onClick={() => sale.user_id && navigate(`/users/${sale.user_id}`)}
                            className="card-dashboard p-5 group cursor-pointer border-[var(--border-subtle)] hover:border-[var(--primary)]/30 transition-all bg-[var(--bg-card)] active:scale-95"
                        >
                            <div className="flex items-center gap-4">
                                <div className="w-10 h-10 rounded-xl bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center text-[var(--text-muted)] group-hover:bg-[var(--primary)] group-hover:text-white transition-all">
                                    <UserIcon size={18} />
                                </div>
                                <div className="flex-1">
                                    <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest">Agent Émetteur</p>
                                    <p className="text-sm font-bold text-[var(--text-secondary)]">{sale.users?.first_name} {sale.users?.last_name}</p>
                                </div>
                                <ExternalLink size={14} className="text-[var(--text-muted)] group-hover:text-[var(--primary)] transition-colors" />
                            </div>
                        </div>
                    </div>
                </div>

                {/* Detailed Ledger & Items */}
                <div className="lg:col-span-2 space-y-8">

                    {/* Security Info */}
                    <div className="flex flex-col sm:flex-row gap-4">
                        <div className="flex-1 card-dashboard p-5 flex items-center gap-4 bg-[var(--success)]/[0.02] border-[var(--success)]/10">
                            <ShieldCheck size={24} className="text-[var(--success)] shrink-0" />
                            <div>
                                <p className="text-[9px] font-black text-[var(--success)] uppercase tracking-widest">Validation Intégrité</p>
                                <p className="text-xs font-bold text-[var(--text-muted)]">Transaction signée et immuable dans le ledger central.</p>
                            </div>
                        </div>
                        <div className="card-dashboard p-5 flex items-center gap-4 border-[var(--border-subtle)] opacity-60">
                            <Info size={18} className="text-[var(--text-muted)]" />
                            <span className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest">Meta_V2.1.0</span>
                        </div>
                    </div>

                    {/* Line Items Placeholder */}
                    <div className="card-dashboard p-8">
                        <div className="flex items-center justify-between mb-8 pb-4 border-b border-[var(--border-subtle)]">
                            <h3 className="text-lg font-black text-[var(--text-primary)] uppercase tracking-tighter flex items-center gap-3">
                                <FileText size={18} className="text-[var(--primary)]" /> Détails de l'Affectation
                            </h3>
                            <span className="text-[10px] font-black text-[var(--text-muted)] uppercase">{sale.items_count} Item(s) Indexé(s)</span>
                        </div>

                        <div className="space-y-4">
                            <div className="grid grid-cols-12 gap-4 p-4 rounded-2xl bg-[var(--bg-app)]/30 border border-[var(--border-subtle)] group hover:bg-[var(--bg-app)]/50 transition-colors">
                                <div className="col-span-6 flex items-center gap-4">
                                    <div className="w-10 h-10 rounded-xl bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center text-[var(--text-muted)]">
                                        <ShoppingBag size={18} />
                                    </div>
                                    <div>
                                        <p className="text-sm font-bold text-[var(--text-secondary)] group-hover:text-[var(--primary)] transition-colors">Vente Directe / Global</p>
                                        <p className="text-[9px] font-black text-[var(--text-muted)] uppercase mt-0.5 tracking-tighter">Référence Stock Non Spécifiée</p>
                                    </div>
                                </div>
                                <div className="col-span-2 flex flex-col justify-center text-center">
                                    <p className="text-[9px] font-black text-[var(--text-muted)] uppercase mb-1">Qte</p>
                                    <p className="text-sm font-bold text-[var(--text-secondary)]">{sale.items_count}</p>
                                </div>
                                <div className="col-span-4 flex flex-col justify-center text-right">
                                    <p className="text-[9px] font-black text-[var(--text-muted)] uppercase mb-1">Montant Total</p>
                                    <p className="text-sm font-black text-[var(--text-primary)] font-mono">{formatAmount(sale.total_amount)}</p>
                                </div>
                            </div>
                        </div>

                        {/* Total Calculation */}
                        <div className="mt-10 pt-8 border-t border-[var(--border-subtle)] flex flex-col items-end gap-3 px-4">
                            <div className="flex gap-10">
                                <span className="text-[11px] font-black text-[var(--text-muted)] uppercase tracking-widest">Sous-Total Hors Taxes</span>
                                <span className="text-sm font-bold text-[var(--text-secondary)]">{formatAmount(sale.total_amount)}</span>
                            </div>
                            <div className="flex gap-10">
                                <span className="text-[11px] font-black text-[var(--text-muted)] uppercase tracking-widest">Ajustement Système</span>
                                <span className="text-sm font-bold text-[var(--text-muted)]">{formatAmount(0)}</span>
                            </div>
                            <div className="flex gap-10 items-end mt-2">
                                <span className="text-[14px] font-black text-[var(--text-primary)] uppercase tracking-[0.2em] italic">Total Net Perçu</span>
                                <span className="text-2xl font-black text-[var(--primary)] font-mono tracking-tighter">{formatAmount(sale.total_amount)}</span>
                            </div>
                        </div>
                    </div>

                    {/* Operational Commands */}
                    <div className="flex flex-wrap gap-4">
                        <button className="flex-1 min-w-[180px] flex items-center justify-center gap-3 bg-[var(--bg-app)] border border-[var(--border-subtle)] hover:bg-[var(--bg-card)] py-4 rounded-2xl text-[10px] font-black text-[var(--text-muted)] hover:text-[var(--text-primary)] uppercase tracking-widest transition-all active:scale-95 shadow-xl">
                            <Printer size={16} /> Générer Reçu Officiel
                        </button>
                        <button className="flex-1 min-w-[180px] flex items-center justify-center gap-3 bg-[var(--bg-app)] border border-[var(--border-subtle)] hover:bg-[var(--bg-card)] py-4 rounded-2xl text-[10px] font-black text-[var(--text-muted)] hover:text-[var(--text-primary)] uppercase tracking-widest transition-all active:scale-95 shadow-xl">
                            <ExternalLink size={16} /> Ouvrir Ledger Client
                        </button>
                    </div>
                </div>

            </div>
        </div>
    );
}
