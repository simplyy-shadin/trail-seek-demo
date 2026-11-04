'use client';
import Link from 'next/link';
import { useState } from 'react';
import { FeedPost, ago, like, placePhoto } from '@/lib/social';
import { sb } from '@/lib/supabase';
import { initials, useAuth } from './auth';

type C = { id: string; author_id: string; text: string; created_at: string; profiles: { display_name: string } | null };

export function PostCard({ p, onChange }: { p: FeedPost; onChange: () => void }) {
  const { user } = useAuth();
  const [liked, setLiked] = useState(p.liked_by_me);
  const [likes, setLikes] = useState(p.like_count);
  const [open, setOpen] = useState(false);
  const [comments, setComments] = useState<C[] | null>(null);
  const [text, setText] = useState('');
  const photo = placePhoto(p);
  const mine = user?.id === p.author_id;

  async function toggle() {
    if (!user) return;
    const on = !liked;
    setLiked(on); setLikes((n) => n + (on ? 1 : -1));
    await like(user.id, p.id, on);
  }
  async function loadComments() {
    setOpen(!open);
    const { data } = await sb().from('comments').select('id, author_id, text, created_at, profiles(display_name)').eq('post_id', p.id).order('created_at');
    setComments((data as unknown as C[]) ?? []);
  }
  async function send() {
    if (!user || !text.trim()) return;
    await sb().from('comments').insert({ post_id: p.id, author_id: user.id, text: text.trim() });
    setText('');
    const { data } = await sb().from('comments').select('id, author_id, text, created_at, profiles(display_name)').eq('post_id', p.id).order('created_at');
    setComments((data as unknown as C[]) ?? []);
  }
  async function remove() {
    if (!confirm('Delete this post?')) return;
    await sb().from('posts').delete().eq('id', p.id);
    onChange();
  }
  async function report() {
    if (!user) return;
    await sb().from('reports').upsert({ post_id: p.id, user_id: user.id, reason: 'Reported from web' }, { ignoreDuplicates: true });
    alert('Thanks. Reports are reviewed; content is hidden after three.');
  }
  const parts = p.text.split(/(#[A-Za-z0-9_]+)/g);
  return (
    <div className="card post">
      <div className="head">
        <Link href={`/u/${p.author_id}`} className="avatar">{initials(p.author_name)}</Link>
        <div style={{ flex: 1, minWidth: 0 }}>
          <Link href={`/u/${p.author_id}`}><b>{p.author_name}</b></Link> <span className="caption">@{p.author_username}</span>
          <div className="caption">{ago(p.created_at)}{p.place_name ? ` · ${p.place_name}` : ''}</div>
        </div>
        {mine ? <button className="btn small ghost" onClick={remove}>Delete</button> : user && <button className="btn small ghost" onClick={report}>Report</button>}
      </div>
      <p style={{ margin: '10px 0 0' }}>{parts.map((s, i) => (s.startsWith('#') ? <span key={i} className="tag">{s}</span> : s))}</p>
      {photo && <div className="photo"><img src={photo} alt="" loading="lazy" /></div>}
      <div className="actions">
        <button className={liked ? 'liked' : ''} onClick={toggle} disabled={!user}>{liked ? '♥' : '♡'} {likes}</button>
        <button onClick={loadComments}>💬 {comments ? comments.length : p.comment_count}</button>
      </div>
      {open && (
        <div style={{ marginTop: 10, borderTop: '1px solid var(--line)', paddingTop: 10 }}>
          {comments === null ? <p className="caption">Loading…</p> : comments.length === 0 ? <p className="caption">No comments yet</p> :
            comments.map((c) => <div key={c.id} style={{ marginBottom: 8 }}><Link href={`/u/${c.author_id}`}><b>{c.profiles?.display_name ?? 'Explorer'}</b></Link> <span className="caption">{ago(c.created_at)}</span><div>{c.text}</div></div>)}
          {user && <div style={{ display: 'flex', gap: 8, marginTop: 6 }}><input placeholder="Add a comment…" value={text} onChange={(e) => setText(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && send()} /><button className="btn small" onClick={send}>Send</button></div>}
        </div>
      )}
    </div>
  );
}
