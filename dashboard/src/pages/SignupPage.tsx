import React, { useState, useRef } from 'react';
import { Link } from 'react-router-dom';
import { Mail, Lock, UserPlus, AlertCircle, CheckCircle, ShieldCheck, Globe, Zap, Cpu } from 'lucide-react';
import { supabase } from '../lib/supabase';

export default function SignupPage() {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');

    // États UI
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [success, setSuccess] = useState(false);

    // 🔒 GUARD
    const isSubmittingRef = useRef(false);

    const handleSignup = async (e: React.FormEvent) => {
        e.preventDefault();

        if (isSubmittingRef.current) return;

        isSubmittingRef.current = true;
        setIsLoading(true);
        setError(null);

        try {
            if (password !== confirmPassword) {
                throw new Error("Les mots de passe ne correspondent pas");
            }
            if (password.length < 6) {
                throw new Error("Le mot de passe doit contenir au moins 6 caractères");
            }

            const { data, error: signUpError } = await supabase.auth.signUp({
                email,
                password,
                options: {
                    emailRedirectTo: `${window.location.origin}/auth/callback`,
                },
            });

            if (signUpError) {
                if (signUpError.status === 429) {
                    throw new Error("Trop de tentatives. Veuillez attendre quelques minutes.");
                }
                throw signUpError;
            }

            if (data.user) {
                setSuccess(true);
            }

        } catch (err: any) {
            setError(err.message || "Une erreur est survenue");
            isSubmittingRef.current = false;
            setIsLoading(false);
        }
    };

    if (success) {
        return (
            <div className="min-h-screen bg-[var(--bg-app)] flex items-center justify-center p-6 relative overflow-hidden font-sans">
                <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-[var(--success)]/10 blur-[120px] rounded-full animate-pulse" />

                <div className="w-full max-w-[440px] relative z-10">
                    <div className="card-dashboard p-1.5 bg-[var(--border-subtle)] border-[var(--border-subtle)]">
                        <div className="bg-[var(--bg-card)] rounded-[1.4rem] p-10 border border-[var(--border-subtle)] text-center flex flex-col items-center">
                            <div className="w-20 h-20 bg-[var(--success)]/10 rounded-[2rem] flex items-center justify-center mb-8 border border-[var(--success)]/20 shadow-[0_0_30px_var(--success-glow)]">
                                <CheckCircle size={40} className="text-[var(--success)] animate-pulse" />
                            </div>
                            <h2 className="text-2xl font-black text-[var(--text-primary)] uppercase tracking-tighter mb-4">Requête Approuvée</h2>
                            <p className="text-[var(--text-muted)] text-sm font-medium leading-relaxed mb-10">
                                Votre profil agent a été enregistré dans le registre Velmo Central.
                                <br /><br />
                                Si la validation par email est active, un jeton d'accès a été envoyé à votre adresse.
                            </p>
                            <Link
                                to="/login"
                                className="w-full bg-[var(--bg-app)] border border-[var(--border-subtle)] py-4 rounded-2xl text-[var(--text-primary)] text-[11px] font-black uppercase tracking-[0.2em] hover:bg-[var(--primary)]/5 transition-all shadow-xl active:scale-95 text-center"
                            >
                                Revenir au Terminal
                            </Link>
                        </div>
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-[var(--bg-app)] flex items-center justify-center p-6 relative overflow-hidden font-sans">

            {/* Ambient Effects */}
            <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-[var(--primary)]/10 blur-[120px] rounded-full animate-pulse" />
            <div className="absolute bottom-[-10%] right-[-10%] w-[40%] h-[40%] bg-[var(--primary)]/5 blur-[120px] rounded-full animate-pulse" />

            <div className="w-full max-w-[480px] relative z-10">

                {/* HEADER */}
                <div className="text-center mb-10">
                    <div className="relative inline-flex mb-6">
                        <div className="absolute inset-0 bg-[var(--primary)] blur-2xl opacity-20 animate-pulse" />
                        <div className="relative w-16 h-16 bg-gradient-to-br from-[var(--primary)] to-violet-700 rounded-2xl flex items-center justify-center shadow-2xl border border-white/10">
                            <UserPlus size={28} className="text-white" />
                        </div>
                    </div>
                    <h1 className="text-3xl font-black text-[var(--text-primary)] uppercase tracking-tighter">Nouvel <span className="text-[var(--primary)]">Agent</span></h1>
                    <p className="text-[var(--text-muted)] text-[10px] font-black uppercase tracking-[0.3em] mt-2">Enrôlement Système • Velmo HQ</p>
                </div>

                {/* FORM MATRIX */}
                <div className="card-dashboard p-1.5 bg-[var(--border-subtle)] border-[var(--border-subtle)]">
                    <div className="bg-[var(--bg-card)] rounded-[1.4rem] p-8 border border-[var(--border-subtle)]">
                        <form onSubmit={handleSignup} className="space-y-6">

                            {error && (
                                <div className="flex items-center gap-4 p-4 bg-[var(--error)]/10 border border-[var(--error)]/20 rounded-2xl animate-slide-in-up">
                                    <AlertCircle size={20} className="text-[var(--error)] shrink-0" />
                                    <p className="text-[var(--error)] text-xs font-bold leading-tight uppercase tracking-tighter opacity-90">{error}</p>
                                </div>
                            )}

                            {/* Email */}
                            <div className="space-y-2">
                                <label className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest px-1">Identifiant Email</label>
                                <div className="relative group">
                                    <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-[var(--text-muted)] group-focus-within:text-[var(--primary)]/50 transition-colors" size={18} />
                                    <input
                                        type="email"
                                        required
                                        disabled={isLoading}
                                        value={email}
                                        onChange={(e) => setEmail(e.target.value)}
                                        className="w-full bg-[var(--bg-app)]/50 border border-[var(--border-subtle)] rounded-2xl pl-12 pr-5 py-4 text-sm text-[var(--text-primary)] focus:border-[var(--primary)]/50 focus:ring-1 focus:ring-[var(--primary)]/20 transition-all font-bold placeholder:text-[var(--text-muted)]"
                                        placeholder="agent@velmo.cloud"
                                    />
                                </div>
                            </div>

                            {/* Passwords Grid */}
                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                                <div className="space-y-2">
                                    <label className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest px-1">Mot de passe</label>
                                    <div className="relative group">
                                        <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-[var(--text-muted)] group-focus-within:text-[var(--primary)]/50 transition-colors" size={16} />
                                        <input
                                            type="password"
                                            required
                                            disabled={isLoading}
                                            value={password}
                                            onChange={(e) => setPassword(e.target.value)}
                                            className="w-full bg-[var(--bg-app)]/50 border border-[var(--border-subtle)] rounded-2xl pl-11 pr-5 py-3.5 text-xs text-[var(--text-primary)] focus:border-[var(--primary)]/50 focus:ring-1 focus:ring-[var(--primary)]/20 transition-all font-bold placeholder:text-[var(--text-muted)]"
                                            placeholder="••••••••"
                                        />
                                    </div>
                                </div>
                                <div className="space-y-2">
                                    <label className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest px-1">Confirmation</label>
                                    <div className="relative group">
                                        <ShieldCheck className="absolute left-4 top-1/2 -translate-y-1/2 text-[var(--text-muted)] group-focus-within:text-[var(--primary)]/50 transition-colors" size={16} />
                                        <input
                                            type="password"
                                            required
                                            disabled={isLoading}
                                            value={confirmPassword}
                                            onChange={(e) => setConfirmPassword(e.target.value)}
                                            className="w-full bg-[var(--bg-app)]/50 border border-[var(--border-subtle)] rounded-2xl pl-11 pr-5 py-3.5 text-xs text-[var(--text-primary)] focus:border-[var(--primary)]/50 focus:ring-1 focus:ring-[var(--primary)]/20 transition-all font-bold placeholder:text-[var(--text-muted)]"
                                            placeholder="••••••••"
                                        />
                                    </div>
                                </div>
                            </div>

                            <button
                                type="submit"
                                disabled={isLoading}
                                className={`
                                    w-full relative group overflow-hidden bg-[var(--primary)] py-4 rounded-2xl text-white text-[11px] font-black uppercase tracking-[0.2em] transition-all active:scale-[0.98] shadow-2xl shadow-[var(--primary)]/20
                                    ${isLoading ? 'opacity-80 cursor-wait' : 'hover:bg-[var(--primary-hover)] hover:shadow-[var(--primary)]/40'}
                                `}
                            >
                                <div className="absolute inset-0 bg-gradient-to-r from-white/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity -skew-x-[45deg] scale-150 translate-x-full group-hover:-translate-x-full duration-1000" />
                                {isLoading ? (
                                    <div className="flex items-center justify-center gap-3">
                                        <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                                        <span>Cryptage...</span>
                                    </div>
                                ) : (
                                    <div className="flex items-center justify-center gap-2">
                                        <UserPlus size={16} /> Initier l'Enregistrement
                                    </div>
                                )}
                            </button>
                        </form>

                        <div className="mt-8 pt-8 border-t border-[var(--border-subtle)] text-center">
                            <p className="text-[var(--text-muted)] text-[10px] font-bold uppercase tracking-widest">
                                Déjà indexé dans la base ?{' '}
                                <Link to="/login" className="text-[var(--primary)] hover:text-[var(--text-primary)] transition-colors underline underline-offset-4 ml-1">
                                    Connexion Terminal
                                </Link>
                            </p>
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
                    <div className="flex items-center justify-around w-full max-w-[300px]">
                        <div className="flex flex-col items-center gap-1.5">
                            <Zap size={12} className="text-[var(--warning)]" />
                            <span className="text-[8px] font-black text-[var(--text-muted)] uppercase">Auto-Auth</span>
                        </div>
                        <div className="flex flex-col items-center gap-1.5">
                            <Globe size={12} className="text-[var(--primary)]" />
                            <span className="text-[8px] font-black text-[var(--text-muted)] uppercase">Global Node</span>
                        </div>
                        <div className="flex flex-col items-center gap-1.5">
                            <Cpu size={12} className="text-[var(--success)]" />
                            <span className="text-[8px] font-black text-[var(--text-muted)] uppercase">High Sec</span>
                        </div>
                    </div>
                </div>
            </div>

            {/* Glossy Scanning Line Effect */}
            <div className="absolute top-0 left-0 w-full h-[2px] bg-[var(--primary)]/20 blur-sm shadow-[0_0_15px_var(--primary)] animate-[scan_8s_linear_infinite] pointer-events-none" />
        </div>
    );
}
