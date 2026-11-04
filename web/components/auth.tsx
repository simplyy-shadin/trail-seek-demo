'use client';
import { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { configured, sb } from '@/lib/supabase';

export type Profile = { id: string; display_name: string; username: string; avatar_id: string | null; bio: string; home_town: string };
type Ctx = { user: Profile | null; ready: boolean; refresh: () => Promise<void> };
const AuthCtx = createContext<Ctx>({ user: null, ready: false, refresh: async () => {} });

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<Profile | null>(null);
  const [ready, setReady] = useState(!configured);
  async function load() {
    if (!configured) return;
    const { data } = await sb().auth.getSession();
    const uid = data.session?.user.id;
    if (!uid) { setUser(null); setReady(true); return; }
    const { data: p } = await sb().from('profiles').select('id, display_name, username, avatar_id, bio, home_town').eq('id', uid).maybeSingle();
    setUser((p as Profile) ?? null);
    setReady(true);
  }
  useEffect(() => {
    load();
    if (!configured) return;
    const { data } = sb().auth.onAuthStateChange(() => { load(); });
    return () => data.subscription.unsubscribe();
  }, []);
  return <AuthCtx.Provider value={{ user, ready, refresh: load }}>{children}</AuthCtx.Provider>;
}
export const useAuth = () => useContext(AuthCtx);
export const initials = (name: string) => {
  const p = name.trim().split(/\s+/).filter(Boolean);
  return !p.length ? '?' : p.length === 1 ? p[0][0].toUpperCase() : (p[0][0] + p[p.length - 1][0]).toUpperCase();
};
