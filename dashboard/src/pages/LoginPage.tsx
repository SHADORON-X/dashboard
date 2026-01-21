import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { Eye, EyeOff, AlertCircle, Lock, ShieldCheck, Zap, Globe, Cpu } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';

export default function LoginPage() {
    const navigate = useNavigate();
    const { signInWithPassword, isLoading, error } = useAuth();

    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [localError, setLocalError] = useState<string | null>(null);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setLocalError(null);

        if (!email || !password) {
            setLocalError('Veuillez remplir tous les champs');
            return;
        }

        try {
            await signInWithPassword(email, password);
            navigate('/');
        } catch (err) {
            // Error is handled by auth context
        }
    };

    const displayError = localError || error;

    return (
        <div className="min-h-screen bg-[var(--bg-app)] flex items-center justify-center p-6 relative overflow-hidden font-sans">

            {/* Ambient Background Elements */}
            <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-[var(--primary)]/10 blur-[120px] rounded-full animate-pulse" />
            <div className="absolute bottom-[-10%] right-[-10%] w-[40%] h-[40%] bg-[var(--primary)]/5 blur-[120px] rounded-full animate-pulse opacity-20" />
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-full h-full bg-[url('https://www.transparenttextures.com/patterns/carbon-fibre.png')] opacity-[0.03] pointer-events-none" />

            <div className="w-full max-w-[440px] relative z-10">

                {/* LOGO & TERMINAL HEADER */}
                <div className="text-center mb-10 group">
                    <div className="relative inline-flex mb-6">
                        <div className="absolute inset-0 bg-[var(--primary)] blur-2xl opacity-20 group-hover:opacity-40 transition-opacity duration-700 animate-pulse" />
                        <div className="relative w-20 h-20 bg-gradient-to-br from-[var(--primary)] to-violet-700 rounded-[2rem] flex items-center justify-center shadow-2xl border border-white/10 group-hover:scale-105 transition-transform duration-500">
                            <div className="text-4xl font-black text-white italic tracking-tighter">V</div>
                            <div className="absolute -bottom-1 -right-1 w-6 h-6 bg-[var(--success)] rounded-full border-4 border-[var(--bg-app)] shadow-[0_0_15px_var(--success)]" />
                        </div>
                    </div>
                    <h1 className="text-3xl font-black text-[var(--text-primary)] uppercase tracking-tighter flex items-center justify-center gap-3">
                        Velmo <span className="text-[var(--primary)]">Sentinel</span>
                    </h1>
                    <p className="text-[var(--text-muted)] text-[10px] font-black uppercase tracking-[0.3em] mt-2">Accès Sécurisé • Node Alpha-01</p>
                </div>

                {/* LOGIN MATRIX */}
                <div className="card-dashboard p-1.5 bg-[var(--border-subtle)] border-[var(--border-subtle)] shadow-[0_0_50px_-12px_rgba(0,0,0,0.5)]">
                    <div className="bg-[var(--bg-card)] rounded-[1.4rem] p-8 border border-[var(--border-subtle)] relative overflow-hidden">

                        <div className="flex items-center gap-3 mb-8 p-3.5 bg-[var(--primary)]/5 rounded-2xl border border-[var(--primary)]/10 group">
                            <Lock size={16} className="text-[var(--primary)] group-hover:animate-swing transition-all" />
                            <span className="text-[var(--text-secondary)] text-[10px] font-bold uppercase tracking-widest">Protocol d'Analyse requis</span>
                            <div className="ml-auto flex gap-1">
                                <div className="w-1 h-1 rounded-full bg-[var(--primary)]" />
                                <div className="w-1 h-1 rounded-full bg-[var(--primary)]/50" />
                                <div className="w-1 h-1 rounded-full bg-[var(--primary)]/20" />
                            </div>
                        </div>

                        <form onSubmit={handleSubmit} className="space-y-6">
                            {/* Error Notification */}
                            {displayError && (
                                <div className="flex items-center gap-4 p-4 bg-[var(--error)]/10 border border-[var(--error)]/20 rounded-2xl group animate-slide-in-up">
                                    <AlertCircle size={20} className="text-[var(--error)] shrink-0 animate-pulse" />
                                    <p className="text-[var(--error)] text-xs font-bold leading-tight uppercase tracking-tighter opacity-90">{displayError}</p>
                                </div>
                            )}

                            {/* Email Input */}
                            <div className="space-y-2">
                                <label className="flex items-center justify-between px-1">
                                    <span className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest">System Identity</span>
                                    <span className="text-[9px] text-[var(--text-muted)] italic opacity-50">User @ Velmo.hq</span>
                                </label>
                                <div className="relative group">
                                    <input
                                        type="email"
                                        value={email}
                                        onChange={(e) => setEmail(e.target.value)}
                                        placeholder="NOM_UTILISATEUR"
                                        className="w-full bg-[var(--bg-app)] border border-[var(--border-subtle)] rounded-2xl px-5 py-4 text-sm text-[var(--text-primary)] focus:border-[var(--primary)]/50 focus:ring-1 focus:ring-[var(--primary)]/20 transition-all font-bold placeholder:text-[var(--text-secondary)] caret-[var(--primary)]"
                                        disabled={isLoading}
                                        autoComplete="email"
                                    />
                                    <Globe size={16} className="absolute right-4 top-1/2 -translate-y-1/2 text-[var(--text-muted)] group-focus-within:text-[var(--primary)]/50 transition-colors" />
                                </div>
                            </div>

                            {/* Password Input */}
                            <div className="space-y-2">
                                <label className="flex items-center justify-between px-1">
                                    <span className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest">Passcode Cipher</span>
                                    <button type="button" className="text-[9px] text-[var(--text-muted)] hover:text-[var(--primary)] transition-colors uppercase font-black">Oublié ?</button>
                                </label>
                                <div className="relative group">
                                    <input
                                        type={showPassword ? 'text' : 'password'}
                                        value={password}
                                        onChange={(e) => setPassword(e.target.value)}
                                        placeholder="••••••••"
                                        className="w-full bg-[var(--bg-app)] border border-[var(--border-subtle)] rounded-2xl px-5 py-4 text-sm text-[var(--text-primary)] focus:border-[var(--primary)]/50 focus:ring-1 focus:ring-[var(--primary)]/20 transition-all font-bold placeholder:text-[var(--text-secondary)] tracking-[0.2em] caret-[var(--primary)]"
                                        disabled={isLoading}
                                        autoComplete="current-password"
                                    />
                                    <button
                                        type="button"
                                        onClick={() => setShowPassword(!showPassword)}
                                        className="absolute right-4 top-1/2 -translate-y-1/2 text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-colors"
                                    >
                                        {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                                    </button>
                                </div>
                            </div>

                            {/* Submit Terminal Access */}
                            <button
                                type="submit"
                                disabled={isLoading}
                                className={`
                                    w-full relative group overflow-hidden bg-[var(--primary)] py-4 rounded-2xl text-white text-[11px] font-black uppercase tracking-[0.2em] transition-all active:scale-[0.98] shadow-2xl shadow-[var(--primary)]/20
                                    ${isLoading ? 'opacity-80 cursor-wait shadow-inner' : 'hover:bg-[var(--primary-hover)] hover:shadow-[var(--primary)]/40'}
                                `}
                            >
                                <div className="absolute inset-0 bg-gradient-to-r from-white/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity -skew-x-[45deg] scale-150 translate-x-full group-hover:-translate-x-full duration-1000" />
                                {isLoading ? (
                                    <div className="flex items-center justify-center gap-3">
                                        <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                                        <span>Initialisation...</span>
                                    </div>
                                ) : (
                                    <div className="flex items-center justify-center gap-2">
                                        <ShieldCheck size={16} /> Établir la Connexion
                                    </div>
                                )}
                            </button>
                        </form>

                        {/* ACCESS FOOTER */}
                        <div className="mt-10 pt-8 border-t border-[var(--border-subtle)] flex flex-col gap-4">
                            <div className="flex items-center justify-around gap-2 px-2">
                                <div className="flex flex-col items-center gap-1.5 opacity-40 hover:opacity-100 transition-opacity cursor-help">
                                    <Zap size={14} className="text-[var(--warning)]" />
                                    <span className="text-[8px] font-black text-[var(--text-muted)] uppercase tracking-widest">Fast Sync</span>
                                </div>
                                <div className="flex flex-col items-center gap-1.5 opacity-40 hover:opacity-100 transition-opacity cursor-help">
                                    <ShieldCheck size={14} className="text-[var(--success)]" />
                                    <span className="text-[8px] font-black text-[var(--text-muted)] uppercase tracking-widest">SSL-256</span>
                                </div>
                                <div className="flex flex-col items-center gap-1.5 opacity-40 hover:opacity-100 transition-opacity cursor-help">
                                    <Cpu size={14} className="text-[var(--primary)]" />
                                    <span className="text-[8px] font-black text-[var(--text-muted)] uppercase tracking-widest">Live Ops</span>
                                </div>
                            </div>

                            <div className="text-center">
                                <p className="text-[var(--text-muted)] text-[10px] font-bold uppercase tracking-widest">
                                    Agent non identifié ?{' '}
                                    <Link to="/signup" className="text-[var(--primary)] hover:text-[var(--text-primary)] transition-colors underline underline-offset-4 ml-1">
                                        S'enregistrer ici
                                    </Link>
                                </p>
                            </div>
                        </div>
                    </div>
                </div>

                {/* SYSTEM METADATA */}
                <div className="mt-10 flex flex-col items-center gap-4 opacity-30 select-none">
                    <div className="flex items-center gap-3">
                        <div className="w-8 h-px bg-[var(--border-subtle)]" />
                        <span className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-[0.4em]">Velmo Cloud OS v4.2.0</span>
                        <div className="w-8 h-px bg-[var(--border-subtle)]" />
                    </div>
                    <p className="text-[8px] text-[var(--text-muted)] font-bold uppercase tracking-tighter">
                        Propriété de Velmo Logistique © 2024 • Build_Sentinel.Alpha
                    </p>
                </div>
            </div>

            {/* Glossy Scanning Line Effect */}
            <div className="absolute top-0 left-0 w-full h-[2px] bg-[var(--primary)]/20 blur-sm shadow-[0_0_15px_var(--primary)] animate-[scan_8s_linear_infinite] pointer-events-none" />
        </div>
    );
}
