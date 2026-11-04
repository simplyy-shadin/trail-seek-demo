import Link from 'next/link';
import { Programme, img, priceLabel, durationLabel, typeLabel, difficultyLabel, statusLabel } from '@/lib/data';

export function ProgrammeCard({ p }: { p: Programme }) {
  const status = statusLabel(p);
  return (
    <Link href={`/programme/${p.id}`} className="card prog">
      <div className="thumb">
        <img src={img(p.images[0])} alt={p.name} loading="lazy" />
        <span className="type">{typeLabel[p.programType].split(' ')[0]}</span>
      </div>
      <div style={{ minWidth: 0 }}>
        <h3>{p.name}</h3>
        <div className="caption">{p.destinationName}</div>
        <p className="caption" style={{ color: '#cfd8cf', margin: '6px 0', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{p.summary}</p>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
          <span className="price">{priceLabel(p.pricing)}</span>
          {p.programType !== 'coracle' && p.programType !== 'entry' && <span className={`badge ${p.difficulty}`}>{difficultyLabel[p.difficulty]}</span>}
          <span className="caption">{durationLabel(p.durationHours)}</span>
          {status && <span className="caption" style={{ color: p.booking.availability === 'closed' ? 'var(--danger)' : 'var(--amber)', fontWeight: 700 }}>{status}</span>}
        </div>
      </div>
    </Link>
  );
}
