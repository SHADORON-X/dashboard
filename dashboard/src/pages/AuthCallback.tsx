import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { XCircle, ShieldCheck, Cpu } from 'lucide-react';

export default function AuthCallback() {
    const navigate = useNavigate();
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        supabase.auth.getSession().then(({ data: { session }, error }) => {
            if (error) {
                setError(error.message);
            } else if (session) {
                setTimeout(() => navigate('/'), 2000);
            } else {
                navigate('/login');
            }
        });
    }, [navigate]);

    return (
        <div className="min-h-screen bg-[var(--bg-app)] flex items-center justify-center p-6 relative overflow-hidden font-sans transition-colors duration-300">

            {/* Ambient Background */}
            <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-[var(--primary)]/10 blur-[120px] rounded-full animate-pulse" />
            <div className="absolute bottom-[-10%] right-[-10%] w-[40%] h-[40%] bg-[var(--primary)]/5 blur-[120px] rounded-full animate-pulse opacity-20" />

            <div className="w-full max-w-[440px] relative z-10">
                <div className="card-dashboard p-1.5 bg-[var(--bg-app)]/50 border-[var(--border-subtle)]">
                    <div className="bg-[var(--bg-card)] rounded-[1.4rem] p-10 border border-[var(--border-subtle)] text-center flex flex-col items-center">

                        {error ? (
                            <>
                                <div className="w-20 h-20 bg-[var(--error)]/10 rounded-[2rem] flex items-center justify-center mb-8 border border-[var(--error)]/20 shadow-[0_0_30px_var(--error-glow)]">
                                    <XCircle size={40} className="text-[var(--error)]" />
                                </div>
                                <h2 className="text-2xl font-black text-[var(--error)] uppercase tracking-tighter mb-4">Échec de Validation</h2>
                                <p className="text-[var(--text-muted)] text-sm font-medium leading-relaxed mb-10">
                                    Le protocole de vérification a rencontré une anomalie :
                                    <br /><br />
                                    <span className="text-[var(--error)]/80 font-mono text-xs">{error}</span>
                                </p>
                                <button
                                    onClick={() => navigate('/login')}
                                    className="w-full bg-[var(--bg-app)] border border-[var(--border-subtle)] py-4 rounded-2xl text-[var(--text-primary)] text-[11px] font-black uppercase tracking-[0.2em] hover:bg-[var(--primary)]/10 transition-all shadow-xl"
                                >
                                    Retour au Terminal
                                </button>
                            </>
                        ) : (
                            <>
                                <div className="relative mb-10">
                                    <div className="absolute inset-0 bg-[var(--primary)] blur-2xl opacity-20 animate-pulse" />
                                    <div className="relative w-24 h-24 bg-gradient-to-br from-[var(--primary)] to-violet-700 rounded-[2.5rem] flex items-center justify-center shadow-2xl border border-white/10">
                                        <ShieldCheck size={48} className="text-[var(--text-primary)] animate-[pulse_2s_infinite]" />
                                    </div>
                                    <div className="absolute -bottom-2 -right-2 w-8 h-8 bg-[var(--bg-card)] border-4 border-[var(--bg-card)] rounded-full flex items-center justify-center">
                                        <div className="w-full h-full bg-[var(--success)] rounded-full animate-pulse shadow-[0_0_10px_var(--success)]" />
                                    </div>
                                </div>

                                <h2 className="text-2xl font-black text-[var(--text-primary)] uppercase tracking-tighter mb-4">Certificat Validé</h2>
                                <p className="text-[var(--text-muted)] text-xs font-black uppercase tracking-[0.3em] mb-12">Synchronisation avec Velmo Sentinel Alpha...</p>

                                <div className="w-full flex flex-col gap-3">
                                    <div className="flex items-center gap-4 p-4 bg-[var(--bg-app)] border border-[var(--border-subtle)] rounded-2xl">
                                        <div className="w-2 h-2 rounded-full bg-[var(--primary)] shadow-[0_0_8px_var(--primary)] animate-pulse" />
                                        <div className="flex-1 text-left">
                                            <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-[0.2em]">Flux d'entrée</p>
                                            <p className="text-[11px] font-bold text-[var(--text-secondary)]">Identity Secure Node_101</p>
                                        </div>
                                        <Cpu size={14} className="text-[var(--text-muted)]" />
                                    </div>
                                </div>

                                <div className="mt-10 w-12 h-1 bg-[var(--border-subtle)] rounded-full overflow-hidden">
                                    <div className="h-full bg-[var(--primary)] w-1/2 animate-[loading_2s_ease-in-out_infinite]" />
                                </div>
                            </>
                        )}
                    </div>
                </div>
            </div>

            {/* Bottom Metadata */}
            <div className="absolute bottom-10 left-1/2 -translate-x-1/2 opacity-20">
                <p className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-[0.4em]">Velmo Cloud OS v4.2.0 • Build_Auth_Redirect</p>
            </div>
        </div>
    );
}
