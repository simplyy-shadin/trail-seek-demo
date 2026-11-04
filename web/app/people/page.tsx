'use client';
import { useEffect, useState } from 'react';
import { sb } from '@/lib/supabase';
import { Card } from '@/lib/social';
import { NeedLogin } from '@/components/need';
import { useAuth } from '@/components/auth';
import { PersonRow } from '@/components/person';

function People() {
  const { user } = useAuth();
  const [q, setQ] = useState('');
  const [list, setList] = useState<Card[] | null>(null);
  useEffect(() => {
    const t = setTimeout(async () => {
      let query = sb().from('profile_cards').select().neq('id', user!.id).order('followers', { ascending: false }).limit(100);
      if (q.trim()) query = query.or(`display_name.ilike.%${q.trim()}%,username.ilike.%${q.trim()}%,home_town.ilike.%${q.trim()}%`);
      const { data } = await query;
      setList((data as Card[]) ?? []);
    }, 250);
    return () => clearTimeout(t);
  }, [q, user]);
  return (
    <>
      <input placeholder="Search by name, @handle or town" value={q} onChange={(e) => setQ(e.target.value)} style={{ margin: '10px 0 14px' }} />
      {list === null ? <p className="muted">Loading…</p> : <div style={{ display: 'grid', gap: 10, maxWidth: 680 }}>{list.map((c) => <PersonRow key={c.id} c={c} />)}</div>}
    </>
  );
}
export default function PeoplePage() { return <><h1>Find explorers</h1><NeedLogin what="find explorers"><People /></NeedLogin></>; }
