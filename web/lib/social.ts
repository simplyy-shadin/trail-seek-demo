'use client';
import { sb } from './supabase';

export type FeedPost = { id: string; author_id: string; author_name: string; author_username: string; text: string; photos: string[]; place_name: string | null; created_at: string; like_count: number; comment_count: number; report_count: number; liked_by_me: boolean };
export type Card = { id: string; display_name: string; username: string; bio: string; home_town: string; followers: number; following: number; posts: number; followed_by_me: boolean };

export async function feed(scope: 'all' | 'following' | 'user', uid: string, authorId?: string): Promise<FeedPost[]> {
  let q = sb().from('feed_posts').select().order('created_at', { ascending: false }).limit(150);
  if (scope === 'user' && authorId) q = q.eq('author_id', authorId);
  if (scope === 'following') {
    const { data: f } = await sb().from('follows').select('followee_id').eq('follower_id', uid);
    const ids = [uid, ...(f ?? []).map((r) => r.followee_id as string)];
    q = q.in('author_id', ids);
  }
  const [{ data }, { data: blocks }] = await Promise.all([q, sb().from('blocks').select('blocked_id').eq('blocker_id', uid)]);
  const blocked = new Set((blocks ?? []).map((b) => b.blocked_id as string));
  return ((data as FeedPost[]) ?? []).filter((p) => p.report_count < 3 && !blocked.has(p.author_id));
}
export const like = (uid: string, postId: string, on: boolean) =>
  on ? sb().from('likes').upsert({ user_id: uid, post_id: postId }, { ignoreDuplicates: true }) : sb().from('likes').delete().eq('user_id', uid).eq('post_id', postId);
export const follow = (uid: string, other: string, on: boolean) =>
  on ? sb().from('follows').upsert({ follower_id: uid, followee_id: other }, { ignoreDuplicates: true }) : sb().from('follows').delete().eq('follower_id', uid).eq('followee_id', other);
export const ago = (iso: string) => {
  const s = (Date.now() - new Date(iso).getTime()) / 1000;
  if (s < 60) return 'just now'; if (s < 3600) return `${Math.floor(s / 60)}m ago`; if (s < 86400) return `${Math.floor(s / 3600)}h ago`; if (s < 604800) return `${Math.floor(s / 86400)}d ago`;
  return new Date(iso).toLocaleDateString('en-IN');
};
export function placePhoto(p: FeedPost): string | null {
  if (p.photos?.length) return p.photos[0];
  const t = `${p.place_name ?? ''} ${p.text}`.toLowerCase();
  const b = '/images/thrissur/';
  const m: [string, string][] = [['coracle', 'peechi-coracle-jackets'], ['dam valley', 'peechi-dhole'], ['digital rope', 'peechi-dhole'], ['elephant saga', 'peechi-trail'], ['guide', 'peechi-trail'], ['moodal', 'peechi-stream-2'], ['peechi', 'peechi-sunset'], ['choorathala', 'chimmony-waterfall'], ['amphi', 'chimmony-coracle-2'], ['climate walk', 'chimmony-elephant-2'], ['chimmony', 'chimmony-reservoir'], ['ayakurisi', 'chulannur-rest'], ['chilambathodi', 'chulannur-walk'], ['chulannur', 'chulannur-peacocks'], ['vazhachal', 'vazhachal-rapids'], ['charpa', 'commons-charpa'], ['thumboormuzhi', 'commons-thumboormuzhi-bridge'], ['athirappilly', 'athirappilly-top']];
  const hit = m.find(([k]) => t.includes(k));
  return hit ? `${b}${hit[1]}.jpg` : null;
}
