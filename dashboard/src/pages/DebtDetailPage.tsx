import { useParams, useNavigate } from 'react-router-dom';
import {
    ArrowLeft, User as UserIcon, Store, Calendar,
    DollarSign, Zap, ShieldCheck, Printer,
    Clock, Phone, Info, Activity
} from 'lucide-react';
import { format, isPast } from 'date-fns';
import { fr } from 'date-fns/locale';

import { useDebtDetails } from '../hooks/useData';
import { useCurrency } from '../contexts/CurrencyContext';
import { LoadingSpinner, EmptyState, StatusBadge } from '../components/ui';

export default function DebtDetailPage() {
    const { debtId } = useParams();
    const navigate = useNavigate();
    const { data: debt, isLoading } = useDebtDetails(debtId || null);
    const { formatAmount, formatNumber } = useCurrency();

    if (isLoading) {
        return (
            <div className="min-h-[60vh] flex flex-col items-center justify-center gap-4">
                <LoadingSpinner />
                <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest animate-pulse font-mono">Extraction du dossier de créance...</p>
            </div>
        );
    }

    if (!debt) {
        return (
            <EmptyState
                icon={Printer}
                title="Dossier Introuvable"
                description="Cet index de créance n'existe pas ou n'est plus accessible."
            />
        );
    }

    const isOverdue = debt.due_date ? isPast(new Date(debt.due_date)) && debt.status !== 'paid' : false;
    const progress = (debt.paid_amount / debt.total_amount) * 100;

    return (
        <div className="space-y-10 pb-20 animate-fade-in">
            {/* Header */}
            <div className="flex items-center gap-4">
                <button
                    onClick={() => navigate('/debts')}
                    className="p-3 rounded-2xl bg-[var(--bg-card)] border border-[var(--border-subtle)] text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-all shadow-sm hover:scale-105 active:scale-95"
                >
                    <ArrowLeft size={20} />
                </button>
                <div className="h-10 w-px bg-[var(--border-subtle)] mx-2" />
                <div>
                    <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest font-mono">Risk Management / Ledger</p>
                    <h1 className="text-2xl font-black text-[var(--text-primary)] uppercase tracking-tighter">Détails du Dossier Débiteur</h1>
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">

                {/* Left Column - Entity Card */}
                <div className="lg:col-span-1 space-y-6">
                    <div className="card-dashboard p-8 relative overflow-hidden group border-zinc-800/50">
                        <div className="absolute top-0 right-0 p-6 opacity-[0.03] group-hover:opacity-[0.08] transition-opacity">
                            <Clock size={150} className="-rotate-12 translate-x-10 translate-y-[-20px]" />
                        </div>

                        <div className="mb-0 relative z-10">
                            <div className="flex items-center justify-between mb-6">
                                <StatusBadge
                                    status={debt.status === 'paid' ? 'success' : isOverdue ? 'error' : 'warning'}
                                    label={debt.status === 'paid' ? 'SOLDE PAYÉ' : isOverdue ? 'EN RETARD' : 'EN COURS'}
                                />
                                <span className="text-[11px] font-black text-[var(--text-muted)] uppercase tracking-[0.2em] font-mono italic">
                                    {debt.type === 'credit' ? 'CLIENT DOI' : 'VOUS DEVEZ'}
                                </span>
                            </div>

                            <div className="space-y-1">
                                <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-[0.3em]">Encours Réel</p>
                                <h2
                                    className={`font-black text-[var(--text-primary)] tracking-tighter font-mono italic flex items-baseline gap-2 truncate
                                        ${formatAmount(debt.remaining_amount).length > 15 ? 'text-2xl sm:text-3xl' : 'text-3xl sm:text-4xl'}`}
                                    title={formatAmount(debt.remaining_amount)}
                                >
                                    {formatAmount(debt.remaining_amount)}
                                </h2>
                            </div>

                            {/* Progress Indicator */}
                            <div className="mt-8 space-y-3">
                                <div className="flex justify-between items-end">
                                    <span className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest">Liquidation</span>
                                    <span className="text-xs font-black text-[var(--success)] tracking-tighter">{Math.round(progress)}% Archivé</span>
                                </div>
                                <div className="h-1.5 w-full bg-[var(--bg-app)]/50 rounded-full overflow-hidden border border-[var(--border-subtle)]">
                                    <div
                                        className={`h-full rounded-full transition-all duration-1000 ${debt.status === 'paid' ? 'bg-[var(--success)] shadow-[0_0_10px_var(--success)]/30' : isOverdue ? 'bg-[var(--error)] shadow-[0_0_10px_var(--error)]/30' : 'bg-[var(--warning)]'}`}
                                        style={{ width: `${progress}%` }}
                                    />
                                </div>
                            </div>

                            <div className="pt-8 mt-8 border-t border-[var(--border-subtle)] space-y-6">
                                <div className="flex items-center gap-4 group/item">
                                    <div className="w-10 h-10 rounded-xl bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center text-[var(--text-muted)] shrink-0 group-hover/item:text-rose-400 transition-colors">
                                        <UserIcon size={18} />
                                    </div>
                                    <div className="min-w-0">
                                        <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest">Débiteur Principal</p>
                                        <p className="text-sm font-bold text-[var(--text-secondary)] truncate">{debt.customer_name || 'Anonyme'}</p>
                                        <p className="text-[10px] font-black text-[var(--text-muted)] mt-0.5">{debt.customer_phone || 'Pas de numéro'}</p>
                                    </div>
                                </div>

                                <div className="flex items-center gap-4 group/item">
                                    <div className="w-10 h-10 rounded-xl bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center text-[var(--text-muted)] shrink-0 group-hover/item:text-amber-400 transition-colors">
                                        <Store size={18} />
                                    </div>
                                    <div className="min-w-0">
                                        <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest">Boutique Créancière</p>
                                        <p className="text-sm font-bold text-[var(--text-secondary)] truncate">{debt.shops?.name}</p>
                                        <p className="text-[10px] font-black text-[var(--text-muted)] mt-0.5">{debt.shops?.velmo_id}</p>
                                    </div>
                                </div>

                                <div className="flex items-center gap-4 group/item pb-2">
                                    <div className="w-10 h-10 rounded-xl bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center text-[var(--text-muted)] shrink-0 group-hover/item:text-[var(--primary)] transition-colors">
                                        <Phone size={18} />
                                    </div>
                                    <div className="min-w-0">
                                        <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest">Agent en Charge</p>
                                        <p className="text-sm font-bold text-[var(--text-secondary)] truncate">{debt.users?.first_name} {debt.users?.last_name}</p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Quick Stats Sidebar */}
                    <div className="grid grid-cols-2 gap-4">
                        <div className="card-dashboard p-4 bg-[var(--bg-app)]/10 border-[var(--border-subtle)] flex flex-col items-center justify-center text-center">
                            <p className="text-[8px] font-black text-[var(--text-muted)] uppercase tracking-widest mb-1">Total Crédit</p>
                            <p className="text-sm font-black text-[var(--text-muted)] font-mono tracking-tighter">{formatAmount(debt.total_amount)}</p>
                        </div>
                        <div className="card-dashboard p-4 bg-[var(--bg-app)]/10 border-[var(--border-subtle)] flex flex-col items-center justify-center text-center">
                            <p className="text-[8px] font-black text-[var(--text-muted)] uppercase tracking-widest mb-1">Remboursé</p>
                            <p className="text-sm font-black text-[var(--success)] font-mono tracking-tighter">{formatAmount(debt.paid_amount)}</p>
                        </div>
                    </div>
                </div>

                {/* Main Content Area */}
                <div className="lg:col-span-2 space-y-8">

                    {/* Urgency & Timeline Cards */}
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                        <div className="card-dashboard p-6 border-[var(--border-subtle)] bg-[var(--bg-card)]/50 relative overflow-hidden flex flex-col justify-between min-h-[120px]">
                            <div>
                                <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest mb-2 flex items-center gap-2">
                                    <Calendar size={12} className="text-[var(--warning)]" /> Échéance
                                </p>
                                <p className={`text-xl font-black italic tracking-tighter ${isOverdue ? 'text-[var(--error)]' : 'text-[var(--text-secondary)]'}`}>
                                    {debt.due_date ? format(new Date(debt.due_date), 'dd MMM yyyy', { locale: fr }) : 'Non fixée'}
                                </p>
                            </div>
                            {isOverdue && (
                                <p className="text-[8px] font-black text-[var(--error)]/50 uppercase tracking-widest mt-2 animate-pulse">Retard Critique</p>
                            )}
                        </div>

                        <div className="card-dashboard p-6 border-[var(--border-subtle)] bg-[var(--bg-card)]/50 flex flex-col justify-between min-h-[120px]">
                            <div>
                                <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest mb-2 flex items-center gap-2">
                                    <ShieldCheck size={12} className="text-[var(--success)]" /> Fiabilité
                                </p>
                                <div className="flex items-center gap-2">
                                    <p className="text-xl font-black text-[var(--text-secondary)] tracking-tighter">{formatNumber(debt.reliability_score || 0)}/100</p>
                                    <div className="flex gap-0.5">
                                        {[1, 2, 3, 4, 5].map(i => (
                                            <div key={i} className={`h-1.5 w-1.5 rounded-full ${i <= (debt.reliability_score || 0) / 20 ? 'bg-[var(--success)]' : 'bg-[var(--border-subtle)]'}`} />
                                        ))}
                                    </div>
                                </div>
                            </div>
                            <p className="text-[8px] font-black text-[var(--text-muted)] uppercase tracking-widest mt-2 italic">{debt.trust_level || 'Non classé'}</p>
                        </div>

                        <div className="card-dashboard p-6 border-[var(--border-subtle)] bg-[var(--bg-card)]/50 flex flex-col justify-between min-h-[120px]">
                            <div>
                                <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest mb-2 flex items-center gap-2">
                                    <Activity size={12} className="text-[var(--primary)]" /> On-Time
                                </p>
                                <p className="text-xl font-black text-[var(--text-secondary)] tracking-tighter">{formatNumber(debt.on_time_payment_count || 0)} / {formatNumber(debt.payment_count || 0)}</p>
                            </div>
                            <p className="text-[8px] font-black text-[var(--text-muted)] uppercase tracking-widest mt-2">Ponctualité Ledger</p>
                        </div>
                    </div>

                    {/* Timeline of Payments */}
                    <div className="card-dashboard p-8">
                        <div className="flex items-center justify-between mb-10 pb-4 border-b border-[var(--border-subtle)]">
                            <h3 className="text-lg font-black text-[var(--text-primary)] uppercase tracking-tighter flex items-center gap-3">
                                <Zap size={18} className="text-[var(--warning)]" /> Journal d'Apurement
                            </h3>
                            <div className="flex items-center gap-2">
                                <span className="text-[9px] font-black text-[var(--text-muted)] uppercase">{debt.debt_payments?.length || 0} Éclats de paiement</span>
                            </div>
                        </div>

                        {debt.debt_payments && debt.debt_payments.length > 0 ? (
                            <div className="space-y-6 relative before:absolute before:left-[19px] before:top-4 before:bottom-4 before:w-[2px] before:bg-[var(--border-subtle)]">
                                {debt.debt_payments.map((payment: any) => (
                                    <div key={payment.id} className="relative pl-12 group">
                                        <div className="absolute left-0 top-1 w-10 h-10 rounded-xl bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center text-[var(--success)] z-10 group-hover:scale-110 group-hover:bg-[var(--success)] group-hover:text-white transition-all duration-300">
                                            <DollarSign size={18} />
                                        </div>
                                        <div className="card-dashboard p-5 bg-[var(--bg-app)]/30 hover:bg-[var(--bg-app)]/50 border-[var(--border-subtle)] flex items-center justify-between transition-all cursor-crosshair">
                                            <div>
                                                <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest mb-1 font-mono">
                                                    Transaction_ID: {payment.id.split('-')[0]}
                                                </p>
                                                <p className="text-xs font-bold text-[var(--text-secondary)] uppercase italic tracking-tighter">Versement au compte central</p>
                                                <div className="flex items-center gap-4 mt-2">
                                                    <span className="text-[9px] font-black text-[var(--text-muted)]/40 uppercase tracking-widest">{format(new Date(payment.created_at), 'PPP', { locale: fr })}</span>
                                                    <span className="text-[9px] font-black text-[var(--text-muted)]/20 uppercase tracking-widest">{payment.payment_method}</span>
                                                </div>
                                            </div>
                                            <div className="text-right">
                                                <p className="text-2xl font-black text-[var(--success)] font-mono tracking-tighter">+{formatAmount(payment.amount)}</p>
                                                <p className="text-[9px] font-black text-[var(--success)] uppercase tracking-widest mt-1">Status: Conclut</p>
                                            </div>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        ) : (
                            <div className="py-20 flex flex-col items-center text-center grayscale opacity-20 border-2 border-dashed border-[var(--border-subtle)] rounded-3xl">
                                <ShieldCheck size={64} className="mb-6 text-[var(--text-muted)]" />
                                <h4 className="text-lg font-black text-[var(--text-muted)] uppercase tracking-widest">Aucun versement indexé</h4>
                                <p className="text-[10px] font-bold text-[var(--text-muted)] mt-2 max-w-[300px] mx-auto leading-relaxed uppercase italic">
                                    Le sujet n'a effectué aucune opération d'apurement. Risque de capital non sécurisé maximal.
                                </p>
                            </div>
                        )}

                        {/* Final Balance Projection */}
                        <div className="mt-12 pt-10 border-t border-[var(--border-subtle)] flex flex-col items-end gap-2 pr-6">
                            <div className="flex gap-16 text-right">
                                <span className="text-[11px] font-black text-[var(--text-muted)] uppercase tracking-widest">Capital de départ</span>
                                <span className="text-sm font-bold text-[var(--text-muted)]">{formatAmount(debt.total_amount)}</span>
                            </div>
                            <div className="flex gap-16 text-right mt-1">
                                <span className="text-[11px] font-black text-[var(--text-muted)] uppercase tracking-widest">Total amortis</span>
                                <span className="text-sm font-bold text-[var(--success)]/80">-{formatAmount(debt.paid_amount)}</span>
                            </div>
                            <div className="flex gap-12 items-center mt-6 p-6 px-10 rounded-[2.5rem] bg-[var(--error)]/[0.02] border border-[var(--error)]/5 shadow-2xl shadow-[var(--error)]/5">
                                <div className="text-right">
                                    <span className="text-[11px] font-black text-[var(--text-primary)] uppercase tracking-[0.3em] block mb-1">Encours Débiteur Brut</span>
                                    <span className="text-4xl font-black text-[var(--error)] font-mono tracking-tighter italic">{formatAmount(debt.remaining_amount)}</span>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Meta Data & Intelligence */}
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        <div className="card-dashboard p-6 border-[var(--border-subtle)] bg-[var(--bg-app)]/20">
                            <div className="flex items-center gap-3 mb-6">
                                <Info size={16} className="text-[var(--info)]" />
                                <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-[0.2em]">Notes Opérationnelles</p>
                            </div>
                            <p className="text-sm text-[var(--text-muted)] italic leading-relaxed">
                                {debt.notes ? `"${debt.notes}"` : "Aucune note additionnelle n'a été indexée pour ce dossier."}
                            </p>
                        </div>
                        <div className="card-dashboard p-6 border-[var(--border-subtle)] bg-[var(--bg-app)]/20 flex flex-col justify-between">
                            <div className="flex items-center gap-3 mb-4">
                                <Activity size={16} className="text-[var(--error)]" />
                                <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-[0.2em]">Actions Immédiates</p>
                            </div>
                            <div className="flex flex-col gap-3">
                                <button className="w-full py-3 rounded-xl bg-[var(--bg-app)]/50 border border-[var(--border-subtle)] text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest hover:text-[var(--text-primary)] hover:bg-[var(--bg-app)]/80 transition-all">
                                    Simuler un plan d'apurement
                                </button>
                                <button className="w-full py-3 rounded-xl bg-[var(--error)]/10 border border-[var(--error)]/20 text-[9px] font-black text-[var(--error)] uppercase tracking-widest hover:bg-[var(--error)] hover:text-white transition-all shadow-lg active:scale-95">
                                    Notifier le créancier
                                </button>
                            </div>
                        </div>
                    </div>
                </div>

            </div>
        </div>
    );
}
