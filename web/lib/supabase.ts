'use client';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

const url = process.env.NEXT_PUBLIC_SUPABASE_URL ?? '';
const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? '';
let client: SupabaseClient | null = null;
export const configured = Boolean(url && key);
export function sb(): SupabaseClient {
  if (!configured) throw new Error('Supabase is not configured for this deployment.');
  client ??= createClient(url, key, { auth: { persistSession: true, autoRefreshToken: true } });
  return client;
}
