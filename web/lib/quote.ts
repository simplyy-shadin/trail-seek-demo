import { Programme, rupees } from './data';

export type Party = { adults: number; children: number; students: number; foreigners: number };
export type Line = { label: string; amount: number };
export const partyTotal = (p: Party) => p.adults + p.children + p.students + p.foreigners;
export const partyLabel = (p: Party) =>
  [p.adults && `${p.adults} adult${p.adults > 1 ? 's' : ''}`, p.children && `${p.children} child${p.children > 1 ? 'ren' : ''}`, p.students && `${p.students} student${p.students > 1 ? 's' : ''}`, p.foreigners && `${p.foreigners} foreign`]
    .filter(Boolean).join(', ') || 'Nobody';

/** Same rules as the app (lib/features/booking/booking_models.dart Quote.compute). */
export function quote(a: Programme, party: Party, vehicle?: string | null, camera = false): { lines: Line[]; total: number } {
  const p = a.pricing;
  const lines: Line[] = [];
  const n = Math.max(1, partyTotal(party));
  const indians = party.adults + party.children + party.students;
  if (p.packageAmount != null) {
    const covers = p.packageCovers ?? n;
    if (p.additionalPerPerson != null || n <= covers) {
      lines.push({ label: `Ticket (up to ${covers} people)`, amount: p.packageAmount });
      const extra = n - covers;
      if (extra > 0) lines.push({ label: `${extra} extra ${extra === 1 ? 'person' : 'people'} × ${rupees(p.additionalPerPerson ?? 0)}`, amount: extra * (p.additionalPerPerson ?? 0) });
    } else {
      const tickets = Math.ceil(n / covers);
      lines.push({ label: `${tickets} tickets × ${rupees(p.packageAmount)} (up to ${covers} each)`, amount: tickets * p.packageAmount });
    }
  } else if (p.perPersonIndian != null) {
    if (indians > 0) lines.push({ label: `${indians} × ${rupees(p.perPersonIndian)}`, amount: indians * p.perPersonIndian });
    if (party.foreigners > 0 && p.perPersonForeign != null) lines.push({ label: `${party.foreigners} foreign × ${rupees(p.perPersonForeign)}`, amount: party.foreigners * p.perPersonForeign });
    const sub = lines.reduce((s, l) => s + l.amount, 0);
    if (p.minimumAmount != null && sub < p.minimumAmount) lines.push({ label: 'Minimum booking top-up', amount: p.minimumAmount - sub });
  } else if (p.perPerson != null) {
    lines.push({ label: `${n} × ${rupees(p.perPerson)}`, amount: n * p.perPerson });
  }
  const fees = Object.entries(p.entryFees);
  if (fees.length) {
    const find = (m: (k: string) => boolean) => fees.find(([k]) => m(k.toLowerCase()))?.[1];
    const child = find((k) => k.includes('child'));
    const student = find((k) => k.includes('student'));
    const foreign = find((k) => k.includes('foreign'));
    const adult = find((k) => k.includes('indian') && !k.includes('child')) ?? find((k) => !k.includes('foreign') && !k.includes('student') && !k.includes('child') && !k.includes('camera'));
    const prefix = a.programType === 'entry' ? 'Entry' : 'Sanctuary entry';
    const add = (who: string, count: number, fee?: number, fallback?: number) => {
      const f = fee ?? fallback;
      if (count > 0 && f != null) lines.push({ label: `${prefix} · ${count} ${who} × ${rupees(f)}`, amount: count * f });
    };
    add(party.adults === 1 ? 'adult' : 'adults', party.adults, adult);
    add(party.children === 1 ? 'child' : 'children', party.children, child, adult);
    add(party.students === 1 ? 'student' : 'students', party.students, student, adult);
    add('foreign', party.foreigners, foreign, adult);
  }
  if (vehicle && p.vehicleFees[vehicle] != null) lines.push({ label: `Parking · ${vehicle}`, amount: p.vehicleFees[vehicle] });
  const cams = Object.entries(p.cameraFees);
  if (camera && cams.length) lines.push({ label: 'Camera permit', amount: (cams.find(([k]) => !k.toLowerCase().includes('video')) ?? cams[0])[1] });
  return { lines, total: lines.reduce((s, l) => s + l.amount, 0) };
}

function parse(s: string): number | null {
  const m = /^(\d{1,2}):(\d{2})\s*(AM|PM)$/i.exec(s.trim());
  if (!m) return null;
  let h = +m[1] % 12;
  if (m[3].toUpperCase() === 'PM') h += 12;
  return h * 60 + +m[2];
}
const fmt = (m: number) => {
  const h24 = Math.floor(m / 60), mm = m % 60, h = h24 % 12 === 0 ? 12 : h24 % 12;
  return `${String(h).padStart(2, '0')}:${String(mm).padStart(2, '0')} ${h24 < 12 ? 'AM' : 'PM'}`;
};
export function slotsFor(a: Programme): string[] {
  const t = a.timing;
  if (a.programType === 'stay') return ['Check-in 2:00 PM'];
  if (t.startTime) return [t.startTime];
  if (!t.open || !t.close) return ['Morning'];
  if (t.open === t.close) return [t.open];
  const o = parse(t.open), c = parse(t.close);
  if (o == null || c == null) return [t.open];
  const step = a.programType === 'coracle' ? 30 : 60;
  const last = a.programType === 'coracle' ? c - 30 : c;
  const out: string[] = [];
  for (let m = o; m <= last; m += step) out.push(fmt(m));
  return out.length ? out : [t.open];
}
