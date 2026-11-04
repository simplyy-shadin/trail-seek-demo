'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { ReactNode } from 'react';
import { configured } from '@/lib/supabase';
import { useAuth } from './auth';

/** Renders children only for a signed-in user; otherwise a sign-in prompt. */
export function NeedLogin({ children, what = 'continue' }: { children: ReactNode; what?: string }) {
  const { user, ready } = useAuth();
  const path = usePathname();
  if (!configured) return <div className="notice">Accounts are not switched on for this deployment yet.</div>;
  if (!ready) return <p className="muted">Loading…</p>;
  if (!user) return (
    <div className="card" style={{ padding: 20, marginTop: 20 }}>
      <h3>Log in to {what}</h3>
      <p className="muted">Your account works on the app and the website.</p>
      <Link className="btn" href={`/login?next=${encodeURIComponent(path)}`}>Log in or sign up</Link>
    </div>
  );
  return <>{children}</>;
}
