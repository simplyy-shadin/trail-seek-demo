'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { sb } from '@/lib/supabase';
import { img, rupees } from '@/lib/data';
import { NeedLogin } from '@/components/need';
import { useAuth } from '@/components/auth';

export type BookingRow = { id: string; code: string; program_id: string; program_name: string; destination_name: string; cover_image: string | null; visit_date: string; slot: string; party: Record<string, number>; lines: { label: string; amount: number }[]; total: number; status: string; payment_method: string; payment_ref: string; created_at: string; user_name: string; vehicle: string | null; camera: boolean };

function List() {
  const { user } = useAuth();
  const [rows, setRows] = useState<BookingRow[] | null>(null);
  useEffect(() => { sb().from('bookings').select().eq('user_id', user!.id).order('visit_date').then(({ data }) => setRows((data as BookingRow[]) ?? [])); }, [user]);
  if (!rows) return <p className="muted">Loading…</p>;
  const today = new Date().toISOString().slice(0, 10);
  const up = rows.filter((r) => r.status === 'confirmed' && r.visit_date >= today);
  const past = rows.filter((r) => !(r.status === 'confirmed' && r.visit_date >= today));
  if (!rows.length) return <div className="card" style={{ padding: 20, marginTop: 16 }}><h3>No bookings yet</h3><p className="muted">Pick a programme and tap Book.</p><Link className="btn" href="/">Browse programmes</Link></div>;
  const card = (b: BookingRow) => (
    <Link key={b.id} href={`/booking/${b.id}`} className="card prog" style={{ marginBottom: 10 }}>
      <div className="thumb" style={{ width: 80, height: 80 }}><img src={img(b.cover_image ?? undefined)} alt="" /></div>
      <div><h3>{b.program_name}</h3><div className="caption">{new Date(b.visit_date).toDateString()} · {b.slot}</div><b style={{ letterSpacing: 2 }}>{b.code}</b> <span className="tag">{b.status === 'cancelled' ? 'Cancelled' : rupees(b.total)}</span></div>
    </Link>);
  return (<>{up.length > 0 && <h2>Upcoming</h2>}{up.map(card)}{past.length > 0 && <h2>Past & cancelled</h2>}{past.map(card)}</>);
}
export default function Bookings() { return <><h1>My bookings</h1><NeedLogin what="see your bookings"><List /></NeedLogin></>; }
