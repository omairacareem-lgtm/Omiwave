# OmiWave 🌊

OmiWave is a social experience platform: discover activities, join challenges, create shared experiences and find communities.

## Run locally
1. Install Node.js 20 or later.
2. Run `npm install`.
3. Run `npm run dev`.
4. Open the local URL printed by Vite.

## Deploy
Import this repository into Vercel. The framework preset is **Vite** and the build command is `npm run build`; output directory is `dist`.

## Current status
This first version is an interactive frontend prototype with sample activity data. Creating and joining Waves works locally in the current browser session. Accounts, persistent data, uploads, real-time chat, notifications and cross-device sync are not connected yet.

## Next step: Supabase
The next development stage will add Supabase Auth, Postgres, Realtime and Storage. Never commit secret service-role keys. Browser apps should only use the Supabase project URL and anon/publishable key, protected by Row Level Security policies.
