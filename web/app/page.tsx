'use client';
import { useMemo, useState } from 'react';
import { destinations, programmes, img, typeLabel, Programme, fromAmount } from '@/lib/data';
import { ProgrammeCard } from '@/components/cards';
import Link from 'next/link';

const types = Object.keys(typeLabel) as Programme['programType'][];

export default function Home() {
  const [dest, setDest] = useState<string | null>(null);
  const [type, setType] = useState<Programme['programType'] | null>(null);
  const [q, setQ] = useState('');
  const [sort, setSort] = useState<'recommended' | 'cheapest' | 'shortest'>('recommended');
  const list = useMemo(() => {
    const t = q.trim().toLowerCase();
    let l = programmes.filter((p) => (!dest || p.destinationId === dest) && (!type || p.programType === type) && (!t || `${p.name} ${p.destinationName} ${typeLabel[p.programType]} ${p.summary}`.toLowerCase().includes(t)));
    if (sort === 'cheapest') l = [...l].sort((a, b) => (fromAmount(a.pricing) ?? 1e9) - (fromAmount(b.pricing) ?? 1e9));
    if (sort === 'shortest') l = [...l].sort((a, b) => a.distanceKm - b.distanceKm);
    return l;
  }, [dest, type, q, sort]);
  return (
    <>
      <h1>Thrissur forest treks, coracle rides and waterfalls</h1>
      <p className="muted">{programmes.length} programmes across Athirappilly–Vazhachal, Peechi–Vazhani, Chimmony and Chulannur. Book a slot, pay, get your QR ticket.</p>
      <input placeholder="Search treks, coracle rides, Athirappilly…" value={q} onChange={(e) => setQ(e.target.value)} style={{ margin: '10px 0 16px' }} />
      <div className="dests">
        {destinations.map((d) => (
          <div key={d.id} className={`dest ${dest === d.id ? 'on' : ''}`} onClick={() => setDest(dest === d.id ? null : d.id)}>
            <img src={img(d.images[0])} alt={d.name} />
            <div className="over">
              <b style={{ fontSize: 17 }}>{d.name.split(/ – | Wildlife| Peafowl/)[0]}</b>
              <span className="caption" style={{ color: dest === d.id ? 'var(--neon)' : '#ddd' }}>{d.programCount} programmes · <Link href={`/destination/${d.id}`} onClick={(e) => e.stopPropagation()} style={{ textDecoration: 'underline' }}>about</Link></span>
            </div>
          </div>
        ))}
      </div>
      <div className="chips" style={{ margin: '16px 0' }}>
        <button className={`chip ${!type ? 'on' : ''}`} onClick={() => setType(null)}>All</button>
        {types.filter((t) => programmes.some((p) => p.programType === t)).map((t) => (
          <button key={t} className={`chip ${type === t ? 'on' : ''}`} onClick={() => setType(type === t ? null : t)}>{typeLabel[t]}</button>
        ))}
        <select value={sort} onChange={(e) => setSort(e.target.value as typeof sort)} style={{ width: 'auto', padding: '6px 10px', borderRadius: 999 }}>
          <option value="recommended">Recommended</option><option value="cheapest">Cheapest first</option><option value="shortest">Shortest first</option>
        </select>
      </div>
      {list.length === 0 ? <p className="muted">No programmes match.</p> : <div className="grid">{list.map((p) => <ProgrammeCard key={p.id} p={p} />)}</div>}
    </>
  );
}
