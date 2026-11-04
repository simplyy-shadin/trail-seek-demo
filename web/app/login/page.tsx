'use client';
import { Suspense, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { configured, sb } from '@/lib/supabase';

function LoginForm() {
  const router = useRouter();
  const next = useSearchParams().get('next') || '/';
  const [mode, setMode] = useState<'login' | 'signup' | 'reset' | 'code'>('login');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [code, setCode] = useState('');
  const [msg, setMsg] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  if (!configured) return <div className="notice">Accounts are not switched on for this deployment yet.</div>;

  async function go(e: React.FormEvent) {
    e.preventDefault();
    setErr(null); setMsg(null); setBusy(true);
    try {
      const auth = sb().auth;
      if (mode === 'signup') {
        const { data, error } = await auth.signUp({ email: email.trim().toLowerCase(), password, options: { data: { display_name: name.trim() } } });
        if (error) throw error;
        if (!data.session) { setMsg('Check your email to confirm the address, then log in.'); setMode('login'); return; }
        router.push(next);
      } else if (mode === 'login') {
        const { error } = await auth.signInWithPassword({ email: email.trim().toLowerCase(), password });
        if (error) throw error;
        router.push(next);
      } else if (mode === 'reset') {
        const { error } = await auth.resetPasswordForEmail(email.trim().toLowerCase());
        if (error) throw error;
        setMsg('We emailed you a 6-digit code.'); setMode('code');
      } else {
        const { error } = await auth.verifyOtp({ email: email.trim().toLowerCase(), token: code.trim(), type: 'recovery' });
        if (error) throw error;
        const { error: e2 } = await auth.updateUser({ password });
        if (e2) throw e2;
        router.push(next);
      }
    } catch (e: unknown) {
      const m = e instanceof Error ? e.message : String(e);
      setErr(/invalid login/i.test(m) ? 'Email or password is wrong.' : /already registered/i.test(m) ? 'An account with this email already exists. Log in instead.' : m);
    } finally { setBusy(false); }
  }

  return (
    <div style={{ maxWidth: 420, margin: '30px auto' }}>
      <h1>{mode === 'signup' ? 'Create your account' : mode === 'login' ? 'Log in' : 'Reset password'}</h1>
      <form onSubmit={go} className="card" style={{ padding: 18 }}>
        {mode === 'signup' && (<><label>Full name</label><input required value={name} onChange={(e) => setName(e.target.value)} /></>)}
        <label>Email</label><input required type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
        {mode === 'code' && (<><label>6-digit code</label><input required value={code} onChange={(e) => setCode(e.target.value)} /></>)}
        {mode !== 'reset' && (<><label>{mode === 'code' ? 'New password' : 'Password'}</label><input required minLength={6} type="password" value={password} onChange={(e) => setPassword(e.target.value)} /></>)}
        {err && <div className="err">{err}</div>}
        {msg && <div className="caption" style={{ color: 'var(--neon)', marginTop: 8 }}>{msg}</div>}
        <button className="btn" style={{ width: '100%', marginTop: 16 }} disabled={busy}>{busy ? 'Please wait…' : mode === 'signup' ? 'Create account' : mode === 'login' ? 'Log in' : mode === 'reset' ? 'Send code' : 'Set password'}</button>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 12 }} className="caption">
          {mode === 'login' ? <a onClick={() => setMode('signup')} style={{ cursor: 'pointer' }}>New here? Sign up</a> : <a onClick={() => setMode('login')} style={{ cursor: 'pointer' }}>Have an account? Log in</a>}
          {mode === 'login' && <a onClick={() => setMode('reset')} style={{ cursor: 'pointer' }}>Forgot password?</a>}
        </div>
      </form>
      <p className="caption" style={{ marginTop: 12 }}>Demo explorers for testing: riya@demo.trailseek.in, arjun@demo.trailseek.in (password <b>trailseek</b>).</p>
    </div>
  );
}
export default function Login() { return <Suspense><LoginForm /></Suspense>; }
