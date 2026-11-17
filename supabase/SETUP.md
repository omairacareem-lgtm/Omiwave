# Connect OmiWave to Supabase

1. Create a Supabase project at https://supabase.com/dashboard.
2. Open **SQL Editor**, create a new query, paste all of `schema.sql`, and run it.
3. In **Project Settings → API**, copy the Project URL and anon/publishable key.
4. In the OmiWave repository, create a file named `.env.local` in the project root:
   ```env
   VITE_SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
   VITE_SUPABASE_ANON_KEY=YOUR_ANON_OR_PUBLISHABLE_KEY
   ```
5. Do not commit `.env.local`. It is intended to stay on your computer. The anon/publishable key is designed for browser use only when Row Level Security is enabled. Never use or expose the service_role/secret key in the frontend.
6. For Vercel, add those same two variables under **Project → Settings → Environment Variables**, then redeploy.
7. In Supabase **Authentication → URL Configuration**, add your Vercel deployment URL to Site URL and Redirect URLs.
8. Enable Realtime for `waves` and `messages` if you want live updates.

The current UI is still a frontend prototype. This setup creates the database and client foundation; the next code pass will connect the screens to these tables and add sign-in/sign-up UI.
