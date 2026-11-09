# Google Play listing for Orbix (own listing, own content)

Use your own screenshots, icon (`mobile/store/play_icon_512.png`) and text. Do not reuse another app's name, icon, screenshots or text.

## Store listing

- **App name:** Orbix: Cloud & Channels
- **Short description (80 chars):** Private cloud storage and creator channels, made for India.
- **Full description:**
  Orbix gives you a private place for your photos, videos and files, and a feed of creator channels you can follow.

  - 15 GB free cloud storage when you create an account
  - Premium plans with 2 TB storage, full-length premium videos and downloads
  - Join channels, share your own, report or block anything in one tap
  - Your files stay private and open through short-lived secure links
  - Delete your account any time from the app or the website

  Orbix is for people aged 18 and over.
- **Category:** Tools (or Productivity)
- **Contact email:** help.orbix@gmail.com
- **Website:** https://orbix-gray.vercel.app
- **Privacy policy URL:** https://orbix-gray.vercel.app/privacy
- **Account deletion URL (required by Google):** https://orbix-gray.vercel.app/delete-account

## App content / policy answers

- **Ads:** No ads. (The Play build has no advertising SDK and no advertising ID.)
- **User-generated content:** Yes. Declare it, and point to the in-app Report and Block and to https://orbix-gray.vercel.app/community-guidelines.
- **Target audience:** 18 and over.
- **In-app purchases:** Leave the Play build with purchases OFF until Google approves User Choice Billing (see play-billing.md). The Play build never sells plans with UPI.
- **Data safety (accurate for this app):**
  - Collected: Email address, User IDs, Photos and videos, Files and docs (all for app functionality and account management); Purchase history is not collected in the Play build while purchases are off; Device or other IDs (a random install ID, for account management and fraud prevention).
  - Shared with third parties: No. Supabase and Vercel are processors acting for us. (If you use the website or ads builds, anonymised purchase events may go to Meta; this is not part of the Play build.)
  - Encrypted in transit: Yes.
  - Users can request deletion: Yes (in-app and web link above).
  - Does not collect: location, contacts, messages, advertising ID.
- **Permissions:** Internet, Notifications.

## Before you upload

1. Package `com.orbix.play` is a different app from the direct APK (`com.orbix.app`). Confirm with the owner before the first upload.
2. Sign the AAB with the key from the GitHub secrets (CI does this).
3. Complete the Play Integrity setup described in play-billing.md if you want the free-cloud verification.
