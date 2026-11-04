'use client';
import { useEffect, useState } from 'react';
import { feed, FeedPost } from '@/lib/social';
import { sb } from '@/lib/supabase';
import { NeedLogin } from '@/components/need';
import { useAuth } from '@/components/auth';
import { PostCard } from '@/components/post';

function Feed() {
  const { user } = useAuth();
  const [scope, setScope] = useState<'all' | 'following'>('all');
  const [posts, setPosts] = useState<FeedPost[] | null>(null);
  const [text, setText] = useState('');
  const [place, setPlace] = useState('');
  const load = () => feed(scope, user!.id).then(setPosts);
  useEffect(() => { setPosts(null); load(); }, [scope, user]);
  useEffect(() => {
    const ch = sb().channel('web-feed').on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'posts' }, () => load()).subscribe();
    return () => { sb().removeChannel(ch); };
  }, [scope, user]);
  async function post() {
    if (!text.trim()) return;
    await sb().from('posts').insert({ author_id: user!.id, text: text.trim(), place_name: place.trim() || null });
    setText(''); setPlace(''); load();
  }
  return (
    <>
      <div className="card" style={{ padding: 14, marginTop: 10 }}>
        <textarea rows={3} maxLength={500} placeholder="What did the trail give you today? Use #hashtags." value={text} onChange={(e) => setText(e.target.value)} />
        <div style={{ display: 'flex', gap: 8, marginTop: 8 }}><input placeholder="Place (optional)" value={place} onChange={(e) => setPlace(e.target.value)} /><button className="btn" onClick={post} disabled={!text.trim()}>Post</button></div>
      </div>
      <div className="chips" style={{ margin: '14px 0' }}>
        <button className={`chip ${scope === 'all' ? 'on' : ''}`} onClick={() => setScope('all')}>All</button>
        <button className={`chip ${scope === 'following' ? 'on' : ''}`} onClick={() => setScope('following')}>Following</button>
      </div>
      {posts === null ? <p className="muted">Loading…</p> : posts.length === 0 ? <p className="muted">{scope === 'following' ? 'Follow some explorers to see their posts here.' : 'No posts yet.'}</p> :
        <div style={{ display: 'grid', gap: 12, maxWidth: 680 }}>{posts.map((p) => <PostCard key={p.id} p={p} onChange={load} />)}</div>}
    </>
  );
}
export default function Community() { return <><h1>Community</h1><NeedLogin what="see the community"><Feed /></NeedLogin></>; }
