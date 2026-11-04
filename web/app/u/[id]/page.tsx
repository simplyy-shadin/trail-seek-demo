'use client';
import { use, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { sb } from '@/lib/supabase';
import { Card, feed, FeedPost } from '@/lib/social';
import { NeedLogin } from '@/components/need';
import { initials, useAuth } from '@/components/auth';
import { FollowBtn, PersonRow } from '@/components/person';
import { PostCard } from '@/components/post';

function Profile({ id }: { id: string }) {
  const { user, refresh } = useAuth();
  const router = useRouter();
  const [c, setC] = useState<Card | null | undefined>(undefined);
  const [posts, setPosts] = useState<FeedPost[]>([]);
  const [tab, setTab] = useState<'posts' | 'followers' | 'following'>('posts');
  const [people, setPeople] = useState<Card[]>([]);
  const [editing, setEditing] = useState(false);
  const [bio, setBio] = useState('');
  const [town, setTown] = useState('');
  const load = async () => {
    const { data } = await sb().from('profile_cards').select().eq('id', id).maybeSingle();
    setC((data as Card) ?? null);
    setBio((data as Card)?.bio ?? ''); setTown((data as Card)?.home_town ?? '');
    setPosts(await feed('user', user!.id, id));
  };
  useEffect(() => { load(); }, [id]);
  useEffect(() => {
    if (tab === 'posts') return;
    (async () => {
      const [want, by] = tab === 'followers' ? ['follower_id', 'followee_id'] : ['followee_id', 'follower_id'];
      const { data } = await sb().from('follows').select('follower_id, followee_id').eq(by, id);
      const ids = ((data ?? []) as Record<string, string>[]).map((r) => r[want]);
      const { data: cards } = ids.length ? await sb().from('profile_cards').select().in('id', ids) : { data: [] };
      setPeople((cards as Card[]) ?? []);
    })();
  }, [tab, id]);
  if (c === undefined) return <p className="muted">Loading…</p>;
  if (c === null) return <p>Explorer not found.</p>;
  const mine = user?.id === id;
  return (
    <div style={{ maxWidth: 680 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginTop: 20 }}>
        <div className="avatar big">{initials(c.display_name)}</div>
        <div style={{ flex: 1 }}><h1 style={{ margin: 0 }}>{c.display_name}</h1><div className="tag">@{c.username}</div>{c.home_town && <div className="caption">{c.home_town}</div>}</div>
        <FollowBtn id={c.id} initial={c.followed_by_me} onChange={() => load()} />
      </div>
      {editing ? (
        <div className="card" style={{ padding: 14, marginTop: 12 }}>
          <label>Bio</label><textarea rows={2} value={bio} onChange={(e) => setBio(e.target.value)} />
          <label>Home town</label><input value={town} onChange={(e) => setTown(e.target.value)} />
          <div style={{ display: 'flex', gap: 8, marginTop: 10 }}><button className="btn small" onClick={async () => { await sb().from('profiles').update({ bio, home_town: town }).eq('id', id); setEditing(false); load(); refresh(); }}>Save</button><button className="btn small ghost" onClick={() => setEditing(false)}>Cancel</button></div>
        </div>
      ) : c.bio && <p>{c.bio}</p>}
      {mine && !editing && <div style={{ display: 'flex', gap: 8 }}><button className="btn small ghost" onClick={() => setEditing(true)}>Edit profile</button><button className="btn small ghost" onClick={async () => { await sb().auth.signOut(); router.push('/'); }}>Log out</button></div>}
      <div className="stats" style={{ marginTop: 14 }}>
        <button className={`card stat ${tab === 'posts' ? 'on' : ''}`} onClick={() => setTab('posts')} style={{ color: 'inherit', cursor: 'pointer' }}><b>{c.posts}</b><span className="caption">Posts</span></button>
        <button className="card stat" onClick={() => setTab('followers')} style={{ color: 'inherit', cursor: 'pointer', borderColor: tab === 'followers' ? 'var(--neon)' : undefined }}><b>{c.followers}</b><span className="caption">Followers</span></button>
        <button className="card stat" onClick={() => setTab('following')} style={{ color: 'inherit', cursor: 'pointer', borderColor: tab === 'following' ? 'var(--neon)' : undefined }}><b>{c.following}</b><span className="caption">Following</span></button>
      </div>
      <div style={{ display: 'grid', gap: 12, marginTop: 14 }}>
        {tab === 'posts' ? (posts.length ? posts.map((p) => <PostCard key={p.id} p={p} onChange={load} />) : <p className="muted">No posts yet.</p>)
          : people.length ? people.map((p) => <PersonRow key={p.id} c={p} />) : <p className="muted">Nobody yet.</p>}
      </div>
    </div>
  );
}
export default function UserPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  return <NeedLogin what="see explorers"><Profile id={id} /></NeedLogin>;
}
