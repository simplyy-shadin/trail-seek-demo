import raw from '@/data/thrissur.json';

export type Pricing = {
  packageAmount?: number; packageCovers?: number; additionalPerPerson?: number; perPerson?: number;
  perPersonIndian?: number; perPersonForeign?: number; minimumAmount?: number;
  entryFees: Record<string, number>; vehicleFees: Record<string, number>; cameraFees: Record<string, number>;
};
export type Programme = {
  id: string; name: string; destinationId: string; destinationName: string; programType: 'trekking' | 'hiking' | 'coracle' | 'cycling' | 'stay' | 'entry';
  summary: string; description: string; difficulty: 'easy' | 'moderate' | 'hard'; distanceKm: number; durationHours: number[];
  images: string[]; pricing: Pricing; timing: { open?: string | null; close?: string | null; startTime?: string | null; note?: string | null };
  minPersons?: number | null; maxPersons?: number | null; inclusions: string[]; highlights: string[]; howToReach: string; parking: string;
  terrain: string; bestSeason: string; risks: string[]; precautions: string[]; wildlife: string; checklist: string[];
  emergencyContacts: { label: string; phone: string }[]; gear: Record<string, string>; lat: number; lng: number;
  booking: { availability: 'open' | 'onRequest' | 'soon' | 'closed'; bookingWindowDays: number; capacityPerDay?: number | null };
};
export type Destination = {
  id: string; name: string; tagline: string; description: string; images: string[]; howToReach: string; timings: string;
  entryFees: Record<string, number>; highlights: string[]; nearby: { name: string; distanceKm: number; note: string }[]; bestSeason: string; programCount: number; lat: number; lng: number;
};

const data = raw as unknown as { destinations: Destination[]; programs: Programme[] };
export const destinations = data.destinations;
export const programmes = data.programs;
export const programmeById = (id: string) => programmes.find((p) => p.id === id);
export const destinationById = (id: string) => destinations.find((d) => d.id === id);

export const img = (asset?: string) => (asset ? '/' + asset.replace(/^assets\//, '') : '/logo.jpeg');
export const rupees = (n: number) => '₹' + n.toLocaleString('en-IN');
export const typeLabel: Record<Programme['programType'], string> = { trekking: 'Trekking', hiking: 'Hiking', coracle: 'Coracle ride', cycling: 'Cycling', stay: 'Stay', entry: 'Entry & sightseeing' };
export const difficultyLabel = { easy: 'Easy', moderate: 'Moderate', hard: 'Very Difficult' } as const;

export function fromAmount(p: Pricing): number | undefined {
  if (p.packageAmount != null) return p.packageAmount;
  if (p.perPersonIndian != null) return p.perPersonIndian;
  if (p.perPerson != null) return p.perPerson;
  const v = Object.values(p.entryFees);
  return v.length ? Math.min(...v) : undefined;
}
export function priceLabel(p: Pricing): string {
  if (p.packageAmount != null) return `${rupees(p.packageAmount)} · up to ${p.packageCovers ?? '-'}`;
  if (p.perPersonIndian != null) return `${rupees(p.perPersonIndian)} / person`;
  if (p.perPerson != null) return `${rupees(p.perPerson)} / person`;
  const f = fromAmount(p);
  return f == null ? 'On request' : `From ${rupees(f)}`;
}
export function durationLabel(h: number[]) {
  const [a, b] = [h[0], h[h.length - 1]];
  if (b >= 12) return `${Math.ceil(b / 8)} day${Math.ceil(b / 8) > 1 ? 's' : ''}`;
  if (b < 1) return `${Math.round(b * 60)} min`;
  return a === b ? `${a} hrs` : `${a}-${b} hrs`;
}
export function statusLabel(p: Programme): string | null {
  return { open: null, onRequest: 'On request', soon: 'Opening soon', closed: 'Not available now' }[p.booking.availability];
}
