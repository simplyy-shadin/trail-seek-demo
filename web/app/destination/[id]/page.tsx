import { notFound } from 'next/navigation';
import { destinations, destinationById, programmes, img, rupees } from '@/lib/data';
import { Gallery } from '@/components/gallery';
import { ProgrammeCard } from '@/components/cards';

export function generateStaticParams() { return destinations.map((d) => ({ id: d.id })); }

export default async function DestinationPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const d = destinationById(id);
  if (!d) notFound();
  const list = programmes.filter((p) => p.destinationId === d.id);
  return (
    <>
      <Gallery images={d.images.map(img)} title={d.name} subtitle={d.tagline} />
      <p style={{ marginTop: 16 }}>{d.description}</p>
      <h2>Programmes here</h2>
      <div className="grid">{list.map((p) => <ProgrammeCard key={p.id} p={p} />)}</div>
      <h2>Entry fees</h2>
      <div className="card" style={{ padding: '6px 16px' }}>{Object.entries(d.entryFees).map(([k, v]) => <div className="row" key={k}><span>{k}</span><b>{rupees(v)}</b></div>)}<div className="caption" style={{ padding: '6px 0' }}>{d.timings}</div></div>
      <h2>How to reach</h2>
      <p>{d.howToReach}</p>
      <a className="btn ghost" target="_blank" rel="noreferrer" href={`https://www.google.com/maps/dir/?api=1&destination=${d.lat},${d.lng}`}>Directions</a>
      {d.nearby.length > 0 && (<><h2>Nearby</h2><ul className="bul">{d.nearby.map((n) => <li key={n.name}><b>{n.name}</b> {n.distanceKm ? `(${n.distanceKm} km)` : ''} — {n.note}</li>)}</ul></>)}
      <h2>Best season</h2><p>{d.bestSeason}</p>
    </>
  );
}
