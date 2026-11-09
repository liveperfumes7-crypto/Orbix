# Orbix — setup (what only you can do)

Live now: website + admin https://orbix-gray.vercel.app · Supabase project `wppultvjscruthsuddae`.

## 1. Your owner account
Supabase dashboard → Authentication → Users → *Add user* → `liveperfumes7@gmail.com` + a password, tick **Auto Confirm**.
That email is the owner automatically. Then sign in at `/admin/login`.

## 2. Secrets (type them yourself — never paste in chat)
Vercel → project **orbix** → Settings → Environment Variables
- `SUPABASE_SECRET_KEY` (Supabase → Settings → API keys → secret) — enables rich `/p/<id>` link previews
- `ANDROID_SIGNING_SHA256` — the SHA-256 of your release keystore (see §4)
- `NEXT_PUBLIC_SUPPORT_EMAIL` — your support address
- `NEXT_PUBLIC_APK_URL` — where the APK file is hosted (GitHub Release link works)

Supabase → Edge Functions → Secrets (only the ones you use)
- `META_CRON_KEY` (Meta events), `UPI_WEBHOOK_SECRET` / `PROVIDER_WEBHOOK_SECRET` (bank/webhook),
  `GOOGLE_SERVICE_ACCOUNT_JSON` + `PLAY_CRON_KEY` (Google Play, later), `SITE_URL`.

GitHub → repo → Settings → Secrets and variables → Actions
- `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`,
  `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`; variable `SUPABASE_PUBLISHABLE_KEY`.

## 3. Push this folder to GitHub
Install the Claude GitHub App on `liveperfumes7-crypto/Orbix`, or: `git init && git remote add origin … && git push`.
Export the live database as migration files: `supabase link --project-ref wppultvjscruthsuddae && supabase db pull`.
Export the functions: `supabase functions download <name>` for each of the 11 functions.

## 4. Android keystore (on your computer, never in git)
`keytool -genkeypair -v -keystore orbix.jks -alias orbix -keyalg RSA -keysize 2048 -validity 10000`
`base64 -w0 orbix.jks` → paste into the `ANDROID_KEYSTORE_BASE64` GitHub secret.
`keytool -list -v -keystore orbix.jks` → copy SHA256 into `ANDROID_SIGNING_SHA256` on Vercel.
Back up the keystore: losing it means you can never update the app.

## 5. Build the app
Push to GitHub; the **mobile** workflow runs analyze + tests and uploads `Orbix.apk`, `Orbix-ads.apk`, `Orbix-play.aab`.
Locally: `cd mobile && flutter create --platforms=android --org com.orbix --project-name orbix . && flutter pub get && flutter test`.

## 6. Phone test plan
1. Install `Orbix.apk`, open as guest, browse. 2. Sign up. 3. Premium → buy Trial (₹49) with GPay.
4. Cancel once and confirm "Payment failed or cancelled". 5. Start a payment, force-close the app mid-way,
reopen: the result is retried from the queue. 6. In `/admin/payments` verify the credit in your bank app, press **Mark paid** with the UTR.
