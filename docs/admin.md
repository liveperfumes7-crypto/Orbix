# Orbix admin panel

URL: `/admin` on the website (sign in at `/admin/login`). Only users in the `admins` table can enter.
Every permission is enforced in the database (RLS policies and owner-checked functions); the pages only show what the database allows.

## Roles
- **Owner**: everything.
- **Content admin**: Dashboard, Channels and Posts, only for channels assigned on the Admins page.

## Pages and what each action does in the app
| Page | Actions | Effect in the app |
|---|---|---|
| Dashboard | — | Alerts link to work waiting for you; tiles and the campaign table are read-only. |
| Channels | Approve (choose audience) / Reject a request; New / Edit channel; picture upload; Hide / Unhide | Approved channels appear for the chosen audience (Everyone, Organic only, Ads only). Hidden or draft channels and their posts disappear. |
| Posts | New post; edit details; add video/image, trailer, thumbnail; Premium toggle; reorder; remove; Hide; Delete | Published posts appear in Home, Explore and the channel. Premium items need a plan; others see the trailer if one exists. Delete also removes the files. |
| Approvals | Approve / Reject / Revoke | Organic users with approved access see the same content as ads users. |
| Payments | UPI ID, payee, enable, activation mode, Clear UPI ID; Bank verified; Mark paid (UTR); Reject; Revoke | New payments go to the saved UPI ID. Mark paid starts the plan; Revoke ends it. |
| Meta Pixel | Pixel ID, token (write-only), test code, enable; Send test event; Send waiting events; upload ads APK | Server-side events to Meta. The token is never sent back to the browser. |
| Users | Approve / Reject / Revoke access; Grant premium | Grant premium gives the chosen plan for free and extends an existing plan. |
| Requests | Close; Delete account; Hide content | Delete account removes the user and their files. |
| Plans | Free mode; Free plans; Show plans in app; edit / add plans (days or hours) | The app picks up changes within a minute. Existing subscribers keep their plan until it ends. |
| Admins | Invite / update; Remove | New people get an invite email. The last owner cannot be removed. |

## Deploying
The Vercel project builds from the public GitHub repo: its install command clones `main` and copies `/admin`.
Environment variables: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `NEXT_PUBLIC_SITE_URL`, `NEXT_PUBLIC_APK_URL`.
No secret key is used: server actions run with the signed-in admin's session.
