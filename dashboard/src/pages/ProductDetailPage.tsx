import { useParams, useNavigate } from 'react-router-dom';
import {
    ArrowLeft, Package, Store, Activity,
    BarChart3, RefreshCw, AlertTriangle,
    Layers, Tag, Info, Cpu, MousePointer2
} from 'lucide-react';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

import { useProductDetails } from '../hooks/useData';
import { useCurrency } from '../contexts/CurrencyContext';
import { LoadingSpinner, EmptyState, StatusBadge } from '../components/ui';

export default function ProductDetailPage() {
    const { productId } = useParams();
    const navigate = useNavigate();
    const { data: product, isLoading } = useProductDetails(productId || null);
    const { formatAmount } = useCurrency();

    if (isLoading) {
        return (
            <div className="min-h-[60vh] flex flex-col items-center justify-center gap-4">
                <LoadingSpinner />
                <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest animate-pulse">Audit de l'inventaire Node...</p>
            </div>
        );
    }

    if (!product) {
        return (
            <EmptyState
                icon={Package}
                title="Produit Introuvable"
                description="Cet index produit n'existe pas ou a été purgé de la base de données."
            />
        );
    }

    const isLowStock = product.stock_alert !== null && product.quantity <= product.stock_alert;

    return (
        <div className="space-y-10 pb-20 animate-fade-in">
            {/* Header */}
            <div className="flex items-center gap-4">
                <button
                    onClick={() => navigate('/products')}
                    className="p-3 rounded-2xl bg-[var(--bg-app)]/50 border border-[var(--border-subtle)] text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-all shadow-sm"
                >
                    <ArrowLeft size={20} />
                </button>
                <div className="h-10 w-px bg-[var(--border-subtle)] mx-2" />
                <div>
                    <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest">Base de Données Assets</p>
                    <h1 className="text-2xl font-black text-[var(--text-primary)] uppercase tracking-tighter">Fiche Technique</h1>
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">

                {/* Product Bio */}
                <div className="lg:col-span-1 space-y-6">
                    <div className="relative w-full aspect-square rounded-3xl bg-[var(--bg-app)] border border-[var(--border-subtle)] overflow-hidden mb-8 flex items-center justify-center">
                        {(product.photo_url || product.photo) ? (
                            <img src={(product.photo_url || product.photo) || undefined} alt={product.name} className="w-full h-full object-cover" />
                        ) : (
                            <Package size={64} className="text-[var(--border-subtle)]" />
                        )}
                        <div className="absolute top-0 right-0 p-4 opacity-5 pointer-events-none">
                            <Package size={120} />
                        </div>
                    </div>

                    <div className="mb-8">
                        <div className="flex items-center justify-between mb-4">
                            <StatusBadge
                                status={product.is_active ? 'active' : 'inactive'}
                                label={product.is_active ? 'INDEXÉ' : 'DÉSACTIVÉ'}
                            />
                            <span className="text-[10px] font-mono text-[var(--text-muted)]">#{product.id.split('-')[0].toUpperCase()}</span>
                        </div>
                        <h2 className="text-3xl font-black text-[var(--text-primary)] leading-tight uppercase tracking-tight">{product.name}</h2>
                        <p className="text-xs text-[var(--text-muted)] font-bold uppercase tracking-widest mt-2">{product.velmo_id || 'SKU Core Alpha'}</p>
                    </div>

                    <div className="space-y-4">
                        <div className="p-4 rounded-2xl bg-[var(--bg-app)]/50 border border-[var(--border-subtle)]">
                            <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest mb-1">Prix de Vente Unitaire</p>
                            <p className="text-2xl font-black text-[var(--primary)] font-mono tracking-tighter">{formatAmount(product.price_sale)}</p>
                        </div>
                        <div className="p-4 rounded-2xl bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-between">
                            <div>
                                <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest mb-1">Prix d'Achat (Estimated Profit)</p>
                                <p className="text-sm font-bold text-[var(--text-secondary)]">{formatAmount(product.price_buy || 0)}</p>
                            </div>
                            <div className="w-10 h-10 rounded-xl bg-[var(--success)]/10 flex items-center justify-center text-[var(--success)]">
                                <BarChart3 size={16} />
                            </div>
                        </div>
                    </div>
                </div>

                {/* Stock Alert Visualizer */}
                <div className={`card-dashboard p-6 border-l-4 ${isLowStock ? 'border-l-[var(--error)] bg-[var(--error)]/[0.02]' : 'border-l-[var(--primary)]'}`}>
                    <div className="flex items-center justify-between mb-4">
                        <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-[0.2em]">Quantité Critique</p>
                        {isLowStock && <AlertTriangle size={14} className="text-[var(--error)] animate-pulse" />}
                    </div>
                    <div className="flex items-end gap-3 mb-4">
                        <span className={`text-4xl font-black ${isLowStock ? 'text-[var(--error)]' : 'text-[var(--text-primary)]'}`}>{product.quantity}</span>
                        <span className="text-xs font-bold text-[var(--text-muted)] mb-1.5 uppercase tracking-tighter">Unités disponibles</span>
                    </div>
                    <div className="h-1.5 w-full bg-[var(--bg-app)] rounded-full overflow-hidden">
                        <div
                            className={`h-full rounded-full transition-all duration-1000 ${isLowStock ? 'bg-[var(--error)] shadow-[0_0_10px_var(--error)]' : 'bg-[var(--primary)] shadow-[var(--primary-glow)]'}`}
                            style={{ width: `${Math.min(100, (product.quantity / (product.stock_alert || 10) * 100))}%` }}
                        />
                    </div>
                    <p className="text-[9px] text-[var(--text-muted)]/50 font-black uppercase tracking-tighter mt-3 text-right">Seuil d'alerte : {product.stock_alert || '0'}</p>
                </div>
            </div>

            {/* Logistics Traceability */}
            <div className="lg:col-span-2 space-y-8">

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                    <div className="card-dashboard p-6 flex flex-col justify-between border-[var(--border-subtle)] hover:border-[var(--primary)]/20 transition-all cursor-crosshair">
                        <div>
                            <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest mb-1.5">Localisation Stock</p>
                            <h4 className="text-lg font-black text-[var(--text-primary)] uppercase tracking-tight">{product.shops?.name || 'Central'}</h4>
                            <p className="text-[10px] font-mono text-[var(--text-muted)] mt-1">Terminal ID: {product.shops?.velmo_id || 'SYS-ALPHA'}</p>
                        </div>
                        <div className="flex items-center gap-2 mt-6 text-[var(--primary)] group">
                            <Store size={14} />
                            <span className="text-[10px] font-black uppercase tracking-widest cursor-pointer hover:underline">Accéder à la boutique</span>
                        </div>
                    </div>

                    <div className="card-dashboard p-6 flex items-center gap-6 border-[var(--border-subtle)]">
                        <div className="w-16 h-16 rounded-[1.5rem] bg-[var(--primary)]/10 flex items-center justify-center text-[var(--primary)] border border-[var(--primary)]/20 shrink-0 shadow-2xl">
                            <Cpu size={28} />
                        </div>
                        <div>
                            <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest">Metadata Sync</p>
                            <h4 className="text-sm font-black text-[var(--text-secondary)]">Synchronisation active</h4>
                            <p className="text-[10px] text-[var(--text-muted)] mt-1 uppercase tracking-tighter">Dernière MAJ: {format(new Date(product.updated_at), 'dd/MM HH:mm', { locale: fr })}</p>
                        </div>
                    </div>
                </div>

                {/* Data Points */}
                <div className="card-dashboard p-8 border-[var(--border-subtle)]">
                    <div className="flex items-center justify-between mb-8 pb-4 border-b border-[var(--border-subtle)]">
                        <h3 className="text-lg font-black text-[var(--text-primary)] uppercase tracking-tighter flex items-center gap-3">
                            <Layers size={18} className="text-[var(--primary)]" /> Attributs Systèmes
                        </h3>
                        <div className="flex gap-2">
                            <div className="w-2.5 h-2.5 rounded-full bg-[var(--success)] shadow-[0_0_8px_var(--success)]" title="Data integrity 100%" />
                        </div>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-y-6 gap-x-12">
                        {[
                            { label: 'Identifiant UUID', val: product.id, icon: Info },
                            { label: 'Catégorie Code', val: product.category || 'Standard', icon: Tag },
                            { label: 'Statut Logistique', val: product.is_active ? 'Délivré' : 'Retenu', icon: Activity },
                            { label: 'Barcode', val: product.barcode || 'N/A', icon: MousePointer2 },
                        ].map((item, idx) => (
                            <div key={idx} className="flex flex-col gap-1.5 group">
                                <div className="flex items-center gap-2">
                                    <item.icon size={12} className="text-[var(--text-muted)] group-hover:text-[var(--primary)] transition-colors" />
                                    <span className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest">{item.label}</span>
                                </div>
                                <p className="text-sm font-bold text-[var(--text-secondary)] truncate font-mono">{item.val}</p>
                            </div>
                        ))}
                    </div>
                </div>

                {/* Quick Tools */}
                <div className="flex flex-wrap gap-4">
                    <button className="flex-1 min-w-[150px] flex items-center justify-center gap-3 bg-[var(--primary)] hover:brightness-110 py-4 rounded-2xl text-[10px] font-black text-white uppercase tracking-widest transition-all active:scale-95 shadow-xl shadow-[var(--primary-glow)]">
                        <RefreshCw size={16} /> Ajuster Inventaire
                    </button>
                    <button className="flex-1 min-w-[150px] flex items-center justify-center gap-3 bg-[var(--bg-app)] border border-[var(--border-subtle)] hover:bg-[var(--primary)]/5 py-4 rounded-2xl text-[10px] font-black text-[var(--text-muted)] hover:text-[var(--text-primary)] uppercase tracking-widest transition-all active:scale-95 shadow-xl">
                        <Activity size={16} /> Rapport d'Analyse
                    </button>
                </div>
            </div>

        </div>
    );
}
