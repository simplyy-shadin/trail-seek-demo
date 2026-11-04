import { notFound } from 'next/navigation';
import Link from 'next/link';
import { programmes, programmeById, img, rupees, durationLabel, typeLabel, difficultyLabel, statusLabel, fromAmount } from '@/lib/data';
import { Gallery } from '@/components/gallery';

export function generateStaticParams() { return programmes.map((p) => ({ id: p.id })); }

export default async function ProgrammePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const p = programmeById(id);
  if (!p) notFound();
  const pr = p.pricing;
  const status = statusLabel(p);
  const bookable = p.booking.availability === 'open' || p.booking.availability === 'onRequest';
  return (
    <>
      <Gallery images={p.images.map(img)} title={p.name} subtitle={p.destinationName} />
      <div className="two" style={{ marginTop: 18 }}>
        <div>
          <div className="stats">
            <div className="card stat"><b>{p.programType === 'coracle' ? durationLabel(p.durationHours) : `${p.distanceKm} km`}</b><span className="caption">{p.programType === 'coracle' ? 'On water' : 'Distance'}</span></div>
            <div className="card stat"><b>{durationLabel(p.durationHours)}</b><span className="caption">Duration</span></div>
            <div className="card stat"><b>{p.programType === 'coracle' || p.programType === 'entry' ? typeLabel[p.programType].split(' ')[0] : difficultyLabel[p.difficulty]}</b><span className="caption">{p.programType === 'coracle' || p.programType === 'entry' ? 'Type' : 'Difficulty'}</span></div>
          </div>
          {status && <div className="notice">{status}. {p.booking.availability === 'onRequest' ? 'Pick your dates; we confirm within two working days or refund in full.' : 'Booking opens here as soon as dates are released.'}</div>}
          <h2>About</h2>
          <p>{p.description || p.summary}</p>
          {p.inclusions.length > 0 && (<><h2>Included</h2><ul className="bul">{p.inclusions.map((x) => <li key={x}>{x}</li>)}</ul></>)}
          <h2>Getting there</h2>
          <p>{p.howToReach}</p>
          <p className="caption">{p.parking}</p>
          <h2>Safety</h2>
          <ul className="bul">{p.risks.map((x) => <li key={x}>{x}</li>)}</ul>
          <p className="caption">{p.wildlife}</p>
          <h3 style={{ marginTop: 12 }}>Precautions</h3>
          <ul className="bul">{p.precautions.map((x) => <li key={x}>{x}</li>)}</ul>
          <h3 style={{ marginTop: 12 }}>Emergency</h3>
          <ul className="bul">{p.emergencyContacts.map((c) => <li key={c.label}>{c.label}: <a href={`tel:${c.phone}`} className="tag">{c.phone}</a></li>)}</ul>
          <h2>Things to carry</h2>
          <ul className="bul">{Object.entries(p.gear).map(([k, v]) => <li key={k}><b style={{ textTransform: 'capitalize' }}>{k.replace('firstAid', 'first aid')}:</b> {v}</li>)}</ul>
          <h3 style={{ marginTop: 12 }}>Before you go</h3>
          <ul className="bul">{p.checklist.map((x) => <li key={x}>{x}</li>)}</ul>
        </div>
        <aside className="card" style={{ padding: 16, position: 'sticky', top: 76 }}>
          <h3>Price</h3>
          <div className="caption" style={{ marginBottom: 6 }}>GST included</div>
          {pr.packageAmount != null && <div className="row"><span>Ticket (up to {pr.packageCovers ?? '-'})</span><b className="tag">{rupees(pr.packageAmount)}</b></div>}
          {pr.additionalPerPerson != null && <div className="row"><span>Each extra person</span><b>{rupees(pr.additionalPerPerson)}</b></div>}
          {pr.perPersonIndian != null && <div className="row"><span>Per person, Indian</span><b className="tag">{rupees(pr.perPersonIndian)}</b></div>}
          {pr.perPersonForeign != null && <div className="row"><span>Per person, foreign</span><b>{rupees(pr.perPersonForeign)}</b></div>}
          {pr.perPerson != null && <div className="row"><span>Per person</span><b className="tag">{rupees(pr.perPerson)}</b></div>}
          {pr.minimumAmount != null && <div className="row"><span>Minimum booking</span><b>{rupees(pr.minimumAmount)}</b></div>}
          {Object.keys(pr.entryFees).length > 0 && <div className="caption" style={{ marginTop: 8 }}>{p.programType === 'entry' ? 'Entry' : 'Plus sanctuary entry'}: {Object.entries(pr.entryFees).map(([k, v]) => `${k} ${rupees(v)}`).join(' · ')}</div>}
          <h3 style={{ marginTop: 16 }}>Timings</h3>
          <div className="caption">{p.timing.startTime ? `Starts ${p.timing.startTime}` : p.timing.open ? `${p.timing.open} – ${p.timing.close}` : 'By arrangement'}{p.timing.note ? ` · ${p.timing.note}` : ''}</div>
          {p.maxPersons && <div className="caption">{pr.additionalPerPerson != null ? `Ticket covers up to ${p.maxPersons}; more people added per head` : `Up to ${p.maxPersons} people per ticket`}</div>}
          <div style={{ marginTop: 16 }}>
            {bookable ? <Link className="btn" style={{ width: '100%' }} href={`/book/${p.id}`}>Book{fromAmount(pr) != null ? ` · ${rupees(fromAmount(pr)!)}` : ''}</Link> : <button className="btn" style={{ width: '100%' }} disabled>{status}</button>}
          </div>
          <div className="caption" style={{ marginTop: 8 }}>Instant QR ticket · free cancellation up to 48 h before</div>
        </aside>
      </div>
    </>
  );
}
