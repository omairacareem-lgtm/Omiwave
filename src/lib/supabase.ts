import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

export const isSupabaseConfigured = Boolean(url && anonKey)

export const supabase = isSupabaseConfigured
  ? createClient(url, anonKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    })
  : null

export type Profile = {
  id: string
  username: string
  display_name: string
  avatar_url: string | null
  bio: string
}

export type Wave = {
  id: string
  creator_id: string
  title: string
  description: string
  category: string
  created_at: string
  profiles?: Pick<Profile, 'username' | 'display_name' | 'avatar_url'>
}

export async function getCurrentProfile(userId: string) {
  if (!supabase) return null
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .maybeSingle()
  if (error) throw error
  return data as Profile | null
}
