'use client';
import Link from 'next/link';
import { useState } from 'react';
import { Card, follow } from '@/lib/social';
import { initials, useAuth } from './auth';

export function FollowBtn({ id, initial, onChange }: { id: string; initial: boolean; onChange?: (on: boolean) => void }) {
  const { user } = useAuth();
  const [on, setOn] = useState(initial);
  if (!user || user.id === id) return null;
  return <button className={`btn small ${on ? 'ghost' : ''}`} onClick={async () => { const n = !on; setOn(n); await follow(user.id, id, n); onChange?.(n); }}>{on ? 'Following' : 'Follow'}</button>;
}

export function PersonRow({ c }: { c: Card }) {
  return (
    <div className="card" style={{ display: 'flex', alignItems: 'center', gap: 12, padding: 12 }}>
      <Link href={`/u/${c.id}`} className="avatar">{initials(c.display_name)}</Link>
      <Link href={`/u/${c.id}`} style={{ flex: 1, minWidth: 0 }}><b>{c.display_name}</b><div className="caption">@{c.username}{c.home_town ? ` · ${c.home_town}` : ''} · {c.followers} followers</div></Link>
      <FollowBtn id={c.id} initial={c.followed_by_me} />
    </div>
  );
}
