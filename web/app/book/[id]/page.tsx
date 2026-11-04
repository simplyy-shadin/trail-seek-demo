'use client';
import { use, useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { programmeById, rupees, img } from '@/lib/data';
import { quote, slotsFor, Party, partyTotal, partyLabel } from '@/lib/quote';
import { sb } from '@/lib/supabase';
import { NeedLogin } from '@/components/need';
import { useAuth } from '@/components/auth';

const ymd = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const code = () => Array.from({ length: 6 }, () => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[Math.floor(Math.random() * 32)]).join('');

function Book({ id }: { id: string }) {
  const p = programmeById(id)!;
  const router = useRouter();
  const { user } = useAuth();
  const days = useMemo(() => Array.from({ length: Math.min(90, Math.max(7, p.booking.bookingWindowDays)) }, (_, i) => { const d = new Date(); d.setHours(0, 0, 0, 0); d.setDate(d.getDate() + 1 + i); return d; }), [p]);
  const slots = slotsFor(p);
  const [date, setDate] = useState(days[0]);
  const [slot, setSlot] = useState(slots[0]);
  const [party, setParty] = useState<Party>({ adults: 1, children: 0, students: 0, foreigners: 0 });
  const [vehicle, setVehicle] = useState<string | null>(null);
  const [camera, setCamera] = useState(false);
  const [step, setStep] = useState<'form' | 'pay'>('form');
  const [method, setMethod] = useState('UPI');
  const [busy, setBusy] = useState(false);
  const [taken, setTaken] = useState(0);
  const [err, setErr] = useState<string | null>(null);
  const q = quote(p, party, vehicle, camera);
  const n = partyTotal(party);
  const cap = p.booking.capacityPerDay ?? null;
  const left = cap == null ? null : Math.max(0, cap - taken);
  const maxParty = p.maxPersons == null ? 20 : p.pricing.additionalPerPerson != null ? 20 : p.maxPersons;
  const problem = n === 0 ? 'Add at least one person.' : n > maxParty ? `This programme takes up to ${maxParty} people per booking.` : p.minPersons && n < p.minPersons ? `This programme needs at least ${p.minPersons} people.` : left != null && n > left ? 'Not enough seats left on this slot.' : null;

  useEffect(() => {
    sb().rpc('booked_seats', { p_program_id: p.id, p_date: ymd(date), p_slot: slot }).then(({ data }) => setTaken(Number(data ?? 0)));
  }, [p.id, date, slot]);

  async function pay() {
    setBusy(true); setErr(null);
    await new Promise((r) => setTimeout(r, 1200));
    const row = {
      code: code(), user_id: user!.id, user_name: user!.display_name, program_id: p.id, program_name: p.name, destination_id: p.destinationId,
      destination_name: p.destinationName, cover_image: p.images[0] ?? null, visit_date: ymd(date), slot, party, lines: q.lines, total: q.total,
      status: 'confirmed', payment_method: method, payment_ref: 'TSW' + Date.now().toString(36).toUpperCase(), vehicle, camera,
    };
    const { data, error } = await sb().from('bookings').insert(row).select('id').single();
    setBusy(false);
    if (error) { setErr(error.message); return; }
    router.push(`/booking/${data.id}?new=1`);
  }

  const step1 = (
    <>
      <h2>Date</h2>
      <div className="dates">{days.map((d) => (
        <div key={+d} className={`date ${+d === +date ? 'on' : ''}`} onClick={() => setDate(d)}>
          <span className="caption" style={{ color: 'inherit' }}>{d.toLocaleDateString('en-IN', { weekday: 'short' })}</span><b>{d.getDate()}</b><span className="caption" style={{ color: 'inherit' }}>{d.toLocaleDateString('en-IN', { month: 'short' })}</span>
        </div>))}</div>
      <h2>Time</h2>
      <div className="chips" style={{ flexWrap: 'wrap' }}>{slots.map((s) => <button key={s} className={`chip ${s === slot ? 'on' : ''}`} onClick={() => setSlot(s)}>{s}</button>)}</div>
      {p.timing.note && <p className="caption">{p.timing.note}</p>}
      {left != null && <p className="caption" style={{ color: left === 0 ? 'var(--danger)' : 'var(--neon)' }}>{left} of {cap} seats left</p>}
      <h2>Who is coming</h2>
      {([['adults', 'Adults'], ['children', 'Children (under 15)'], ['students', 'Students (with ID)'], ['foreigners', 'Foreign nationals']] as const).map(([k, label]) => (
        <div className="stepper" key={k}><span>{label}</span><span style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <button onClick={() => setParty({ ...party, [k]: Math.max(0, party[k] - 1) })}>−</button><b style={{ width: 20, textAlign: 'center' }}>{party[k]}</b><button onClick={() => setParty({ ...party, [k]: party[k] + 1 })}>+</button>
        </span></div>
      ))}
      {Object.keys(p.pricing.vehicleFees).length > 0 && (<><h2>Parking</h2><div className="chips" style={{ flexWrap: 'wrap' }}>
        <button className={`chip ${!vehicle ? 'on' : ''}`} onClick={() => setVehicle(null)}>No vehicle</button>
        {Object.entries(p.pricing.vehicleFees).map(([k, v]) => <button key={k} className={`chip ${vehicle === k ? 'on' : ''}`} onClick={() => setVehicle(k)}>{k} · {rupees(v)}</button>)}
      </div></>)}
      {Object.keys(p.pricing.cameraFees).length > 0 && <label style={{ display: 'flex', gap: 8, alignItems: 'center', color: 'var(--text)' }}><input type="checkbox" checked={camera} onChange={(e) => setCamera(e.target.checked)} style={{ width: 'auto' }} /> Camera permit</label>}
    </>
  );

  const payStep = (
    <>
      <h2>Pay with</h2>
      {[['UPI', 'Google Pay, PhonePe, Paytm or any UPI app'], ['Card', 'Debit or credit card'], ['Net banking', 'All major banks']].map(([m, sub]) => (
        <div key={m} className="card" onClick={() => setMethod(m)} style={{ padding: 14, marginBottom: 8, cursor: 'pointer', borderColor: method === m ? 'var(--neon)' : undefined }}>
          <b>{m}</b><div className="caption">{sub}</div>
        </div>))}
      <p className="caption">Beta: payments are simulated. No money moves until the payment gateway goes live; your booking is recorded and your ticket is issued.</p>
      {err && <div className="err">{err}</div>}
    </>
  );

  return (
    <div className="two" style={{ marginTop: 10 }}>
      <div>
        <div style={{ display: 'flex', gap: 12, alignItems: 'center', marginTop: 16 }}>
          <img src={img(p.images[0])} alt="" style={{ width: 72, height: 72, objectFit: 'cover', borderRadius: 12 }} />
          <div><h3>{p.name}</h3><div className="caption">{p.destinationName}</div></div>
        </div>
        {step === 'form' ? step1 : payStep}
      </div>
      <aside className="card" style={{ padding: 16, position: 'sticky', top: 76, marginTop: 16 }}>
        <h3>{step === 'pay' ? 'To pay' : 'Price'}</h3>
        <div className="caption">{date.toDateString()} · {slot} · {partyLabel(party)}</div>
        {q.lines.map((l) => <div className="row" key={l.label}><span className="caption" style={{ color: 'var(--text)' }}>{l.label}</span><span>{rupees(l.amount)}</span></div>)}
        <div className="row" style={{ borderTop: '1px solid var(--line)', marginTop: 6, paddingTop: 10 }}><b>Total</b><b className="tag" style={{ fontSize: 22 }}>{rupees(q.total)}</b></div>
        {problem && step === 'form' && <div className="notice">{problem}</div>}
        {step === 'form'
          ? <button className="btn" style={{ width: '100%', marginTop: 10 }} disabled={!!problem} onClick={() => setStep('pay')}>Continue · {rupees(q.total)}</button>
          : <><button className="btn" style={{ width: '100%', marginTop: 10 }} disabled={busy} onClick={pay}>{busy ? 'Processing…' : `Pay ${rupees(q.total)}`}</button><button className="btn ghost" style={{ width: '100%', marginTop: 8 }} onClick={() => setStep('form')}>Back</button></>}
        <div className="caption" style={{ marginTop: 8 }}>Free cancellation up to 48 h before the start.</div>
      </aside>
    </div>
  );
}

export default function BookPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  if (!programmeById(id)) return <p>Programme not found.</p>;
  return <NeedLogin what="book"><Book id={id} /></NeedLogin>;
}
