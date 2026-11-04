'use client';
import { Suspense, use, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import Link from 'next/link';
import QRCode from 'qrcode';
import { sb } from '@/lib/supabase';
import { img, rupees } from '@/lib/data';
import { NeedLogin } from '@/components/need';
import type { BookingRow } from '../../bookings/page';

function Ticket({ id }: { id: string }) {
  const isNew = useSearchParams().get('new') === '1';
  const [b, setB] = useState<BookingRow | null | undefined>(undefined);
  const [qr, setQr] = useState<string>('');
  async function load() {
    const { data } = await sb().from('bookings').select().eq('id', id).maybeSingle();
    setB((data as BookingRow) ?? null);
    if (data) setQr(await QRCode.toDataURL(`TRAILSEEK|${data.code}|${data.program_id}|${data.visit_date}`, { width: 220, margin: 1 }));
  }
  useEffect(() => { load(); }, [id]);
  if (b === undefined) return <p className="muted">Loading…</p>;
  if (b === null) return <p>Booking not found.</p>;
  const cancelled = b.status === 'cancelled';
  const hours = (new Date(b.visit_date).getTime() - Date.now()) / 36e5;
  async function cancel() {
    if (!confirm(hours >= 48 ? `Cancel and refund ${rupees(b!.total)}?` : 'Less than 48 hours to go: this booking is not refundable. Cancel anyway?')) return;
    await sb().from('bookings').update({ status: 'cancelled' }).eq('id', id);
    load();
  }
  const party = Object.entries(b.party).filter(([, v]) => v > 0).map(([k, v]) => `${v} ${k}`).join(', ');
  return (
    <div style={{ maxWidth: 560, margin: '0 auto' }}>
      {isNew && <h1>Booked! Show this QR at the gate.</h1>}
      <div className="card" style={{ overflow: 'hidden', marginTop: 16 }}>
        <img src={img(b.cover_image ?? undefined)} alt="" style={{ height: 170, width: '100%', objectFit: 'cover' }} />
        <div className="ticket">
          <h2 style={{ margin: 0 }}>{b.program_name}</h2>
          <div className="caption">{b.destination_name}</div>
          {qr && <img className="qr" src={qr} alt="ticket QR" style={{ opacity: cancelled ? 0.3 : 1 }} />}
          <div className="code">{b.code}</div>
          <div className="caption" style={{ color: cancelled ? 'var(--danger)' : undefined, fontWeight: 700 }}>{cancelled ? 'CANCELLED' : 'Booking code'}</div>
          <div style={{ textAlign: 'left', marginTop: 16 }}>
            <div className="row"><span className="muted">Date</span><b>{new Date(b.visit_date).toDateString()}</b></div>
            <div className="row"><span className="muted">Time</span><b>{b.slot}</b></div>
            <div className="row"><span className="muted">People</span><b>{party}</b></div>
            {b.vehicle && <div className="row"><span className="muted">Parking</span><b>{b.vehicle}</b></div>}
            <div className="row"><span className="muted">Name</span><b>{b.user_name}</b></div>
          </div>
        </div>
      </div>
      <h2>Payment</h2>
      <div className="card" style={{ padding: '8px 16px' }}>
        {b.lines.map((l) => <div className="row" key={l.label}><span className="caption" style={{ color: 'var(--text)' }}>{l.label}</span><span>{rupees(l.amount)}</span></div>)}
        <div className="row"><b>Paid</b><b className="tag">{rupees(b.total)}</b></div>
        <div className="caption" style={{ paddingBottom: 6 }}>{b.payment_method} · ref {b.payment_ref}</div>
      </div>
      <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
        <Link className="btn ghost" href={`/programme/${b.program_id}`}>Programme</Link>
        {!cancelled && hours > 0 && <button className="btn danger" onClick={cancel}>Cancel booking</button>}
      </div>
    </div>
  );
}
export default function TicketPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  return <NeedLogin what="see this ticket"><Suspense><Ticket id={id} /></Suspense></NeedLogin>;
}
