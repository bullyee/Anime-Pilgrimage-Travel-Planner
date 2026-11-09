# Roadmap

Status: draft for bullyee and ck, 2026-11-06, updated 2026-11-10. What comes after the MVP (`docs/mvp-plan.md`), by version. Each version runs two code tracks side by side, since the screens (bullyee) and the backend and sync (ck) are mostly separate, plus a launch track that isn't code.

The hard part from here isn't the code: it's getting the app into stores and in front of people. So the launch track starts now, alongside v0.3.0, not after it.

## v0.2.0: the MVP (published 2026-11-07)

- [x] Merge #105, #106, #107, #108 (first invite's Members tab error), #109 (frames missing after the app closes mid-import).
- [x] Deploy #106's `firestore.rules` from `master` (Console or `firebase deploy --only firestore:rules`).
- [x] The rejoin fix, #110 (ck), moves to after the release; v0.2.0 ships with the known issue in its CHANGELOG. Agreed on 2026-11-06: the shared trip comes down clean from the cloud, and a leftover private copy with changes made while away stays as a separate private trip with a new id ("Kyoto (your copy)"), so nothing is pushed into everyone's trip and nothing is lost. A copy without changes just reconnects.
- [x] Release: PR #111 "Release v0.2.0", then the tag. The workflow couldn't sign with the release key until #112 (AGP read `$XDG_CONFIG_HOME/.android` on the runner), so the tag was moved onto #112 and the workflow built the draft pre-release.
- [x] Publish the draft (2026-11-07).

## What the app is for

The moment that matters is standing at the spot and getting the shot. Planning, sharing and importing exist so that, on the day, the right frame is in your hand. So the next version is about that moment, and planning together comes after it.

**The app is local; signing in is only for trips.** The library (places, notes, visits, photos and frames) lives on the device and never goes to the cloud. A Google account is the identity for sharing trips (sharing, inviting, joining), not a login for the whole app, and everything else works without one. Only shared trips go to Firebase, plus, later, the photos someone chooses to upload to a shared trip and the templates they publish. Moving to a new phone or to the Play app goes through a file the user exports and imports (see Google Play below), not a cloud backup. Agreed on 2026-11-08, which is why #104's personal cloud backup isn't going in.

## v0.3.0: pilgrimage mode

The goal: planning a trip gets simpler, and the day itself gets better looking and easier to use. Two tracks in parallel. They meet only where a screen needs a backend call.

**Where it stands (2026-11-10).** Merged: several shots then pick (#137), the shooting backend and schema 14 (#135), the day's feed and check-in (#136), the day map (#138) and the new Home (#139). Built overnight on 2026-11-10, tested and tried on the emulator, not yet pushed: `feat/shoot-flow` (Shoot here, Mark done and Add to Day N after the shots, Photos to edit, sign-in only where needed), `feat/frame-switch` on top of it (switching frames in the camera), `feat/plan-screen` (one Plan screen, no Edit switch, Undo) and `fix/near-you-retry`. Still open on the backend: #103 (the trash).

**Who it's for.** Some people plan every stop and enjoy seeing the day go to plan; others walk around and shoot whatever turns up. Both go on pilgrimages, often in the same group trip (one person plans, the rest wander), and the same person can be both: a planner at home, a wanderer on the street. So the app doesn't ask which kind you are. Shooting works without a plan, the plan shows progress for those who want it, and a detour lands in the plan with one tap, so the plan stays true. **The plan follows the user** (2026-11-09): the day decides what's offered first, never what's allowed, and nothing changes the plan unless the user asks for it.

**Screens (bullyee), in two steps**

*Step 1: the shooting core.* It goes into today's app behind the existing camera entries, so it can be tried on a real outing before the home screen changes. How it behaves on a trip day was settled with step 2's Home (2026-11-09).
- [ ] **Shoot here.** (Backend in #135; the screen is on `feat/shoot-flow`.) One button that uses GPS to find the places within about 150 m, nearest first. On a trip day it shows that day's stops; the trip's other stops (labelled with their day) and the library places nearby wait behind an "Other places nearby" row, which opens by itself when none of the day's stops is nearby. On other days it shows the library places, so it works **without a trip**. With one place the camera opens with its frame; with several close together, as in Uji, a row of their frames to pick from. GPS is off by tens of metres in town, so it suggests and never decides alone.
- [x] **From a stop to the camera in one tap,** with its frame already in the floating window: Take photo on the day map's card (#138) and on Home's next stop (#139).
- [ ] When a spot has more than one frame, switch frames without leaving the camera (on `feat/frame-switch`).
- [x] **Several shots, then pick** (#137, 2026-11-09). The Android camera returns one photo per opening, so after each shot the camera opens again with the same frame still in the floating window; pressing back in the camera ends the series. Then the shots appear next to the frame, you keep the ones you want, and the rest are deleted. Each extra shot costs the camera app's own confirm tap and about a second to reopen. If that turns out too slow on the day, the fallback is the camera app's normal mode (`INTENT_ACTION_STILL_IMAGE_CAMERA`: as many shots as you like, burst included) and, back in the app, picking the new shots with the system Photo Picker, which needs no `READ_MEDIA_IMAGES`; the cost is copies left in the phone's gallery.
- [ ] **No editing on the spot.** (The editor no longer opens after a shot since #137, and the list's backend is in #135; the Photos to edit screen is on `feat/shoot-flow`.) The kept photo is saved as shot, attached to its place (and filed under the trip, in one), the day's visit is logged, and you're back where you were. Editing, compose and cutout wait for later: a **Photos to edit** list holds the photos not yet edited, to edit at home. It replaces Home's Edit Photo card.
- [ ] **Done is the user's call, not the shot's.** (A shot marks nothing done since #135; Mark done is on Home (#139) and Mark visited on the day map (#138); the tick after the shots is on `feat/shoot-flow`.) A big spot can take many shots across several frames, so a shot never marks a stop done. The screen after the shots has a "Mark Uji Bridge done" tick (the same as the day map's Mark visited), already ticked when every frame of the spot now has a shot, so a one-frame spot needs no extra tap. Each stop shows its progress ("2 of 5 frames").
- [ ] **Shots off the plan leave the plan alone.** (The backend leaves the plan alone since #135; "Add to Day 2" is on `feat/shoot-flow`.) A shot at a stop planned for another day stays on that day; ticking done marks that day's item, so it shows done when the day comes. A shot at a place that isn't in the trip is filed under the trip but not added to the plan; the screen after the shots offers "Add to Day 2" for those who want the plan to match the route walked.

*Step 2: Plan, Pilgrimage and Home.* These go on one design canvas before any code, since splitting the trip screen into Plan and Pilgrimage is one design. The canvas has four versions of Home (A: a card for today's trip; B: the whole app switches between Plan and Pilgrimage; C: start and end a pilgrimage, with a banner while it runs; D: camera first, a "Here" screen). **Decided on 2026-11-09, before step 1 was tried, since it settles how Shoot here and recording a shot behave: A, and no session.** C turned out to be B's switch with a trip day attached, and a session to start and end would tie the user to the plan, which the rule above avoids. A first try made Home the day's map on a trip day, which made trip days and other days look like two different apps, so Home went back to A's column of cards with a small map in the trip card (2026-11-10); switching between days lives on the day map. Then:
- [x] **Two modes for a trip: Plan and Pilgrimage.** Plan is for arranging the trip. Pilgrimage is for the day itself: the day's stops, the map, the camera, and nothing to edit. There's no switch: Pilgrimage is the day's map (#138), which Home's trip card opens and each day in Plan opens too, and Plan is the trip's page.
- [ ] **Plan, simpler** (on `feat/plan-screen`; backup days kept for now). Today a trip has four tabs (Overview, Plan, Stops, Members) and an Edit switch, and a stop can sit in three places (a dated day, a backup day, the backlog). Proposed:
  - **One Plan screen instead of four tabs:** the days, with the stops not on a day yet at the end. Overview's "3 of 5 visited" belongs to the day itself and moves to Pilgrimage. The Stops tab's search moves to Plan's top bar. Members becomes the avatars in the top bar, which open the member list and the invite.
  - **No Edit switch:** Plan is always editable for owners and editors, and looking without changing is Pilgrimage's job. Deleting a stop, a day or a trip shows **Undo**, through #103's restore.
  - **Backup days fold into the backlog** (open: see Open questions). The data stays, so they can come back; only the "Add a backup day" entry goes.
- [x] **The day's map is Pilgrimage's main screen** (#138, 2026-11-10; route `/trips/:tripId/map?day=`). The day's stops on a map with your own location, visited ones marked, and how many are left; ‹ › go to the trip's other days, and Shoot looks at the day shown. Tapping one opens a small card with its frame, name, **Take photo** and **Mark visited**. The frame is the main thing on these cards, and after a series the shots sit next to it. Everything it needs exists: the library's map (flutter_map), the location from the new spot screen, and the stop page's Take photo; no new data. Map tiles stay online-only (see Offline maps under Later); the list of stops and the camera work without a connection, since the frames are on the device.
- [x] **Home, a column of cards with no session** (#139, 2026-11-10). Only the top card follows the date. On a trip day it's today: "Day 2 of 3", how many stops are visited, a small map of the day's stops that opens the day map, and the next stop with its frame, **Take photo** and **Mark done** (with Undo; editors only). On other days it's the next trip ("in 8 days", a small map of its stops, "Day 3 not planned", Continue planning), or Plan a trip. Below it, **Near you** is the same every day: up to three library places within 3 km, asking for location only when tapped. Shoot sits in the middle of the bottom bar, between Trips and Library. There's nothing to start or end: the trip day is over at midnight, and scouting before the trip is Plan, then that day's map. Floating Reference, Edit a photo and Sign in moved to the ⋮ menu.
  - [ ] Still to come on Home: Photos to edit, once its screen exists; Sign in leaves the menu, so it only comes up when sharing, inviting or joining a trip. Both are on `feat/shoot-flow` (sign-out moved to My Trips' Account menu).

**Backend (ck)**

From the open PRs, v0.3.0 takes three:
- [x] #110, rejoining a trip after leaving it (see v0.2.0; merged 2026-11-08). Later, once the comparison screens exist, rejoining could ask "You changed 3 things while away; bring them into the shared trip?" instead of keeping a separate copy.
- [x] #114, marking a stop visited while offline in a shared trip so it syncs cleanly once back online (merged 2026-11-08): the day of a pilgrimage is where connections drop.
- [ ] #103, the trash: its `restoreStop`, `restoreDayBlock` and `restoreTrip` give Plan its Undo, and deleted rows are purged after 30 days. It needs a rules publish and a TTL policy on `expireAt` in the Firebase Console. Review on 2026-11-09 found problems to fix first: any editor can set `expireAt` on someone else's document, which turns the TTL into a way around the no-delete rule; a member away for more than 30 days never hears about a deletion; and restoring a stop or a day doesn't bring its schedule back. Proposed: take the restore half in v0.3.0, and hold its rules until those are fixed.

New, for the screens above. All of it is local (Drift). Items 1 to 5 and the library file merged in #135 (2026-11-10, schema 14), and #136 added the day's feed, check-in without a photo and the compass bearing for the day map:
1. [x] **Nearby places** (Shoot here): the places within about 150 m of a position, nearest first. On a trip day, the trip's stops from `stops` itself, each with its day (a stop has its own name and coordinates, while its place may be trip-only, or missing in a joined trip), with their frames by `placeKey` or `stopId`; then the library places not among them. With no trip, the library places. It takes the day rather than always today, so the day map's Shoot can look at the day shown. `places` has coordinates and `geolocator` is already in use. A library holds a few thousand places at most, so working out every distance is enough, with no spatial index.
2. [x] **Today's trip:** which trip and day today is, with that day's stops and their status. `schedule_logic` already works out today's day; this wraps it in a provider.
3. [x] **Record a shot,** the main piece: one call that copies the photo into the app and adds its `photos` row (place, trip, frame) and one `place_visits` row per place per day. It marks nothing done and changes no plan: marking a stop done and adding an off-plan place to a day are their own calls, from the screen after the shots, and work offline in a shared trip (#114). A stop whose place isn't in the library (a joined trip's) first gets a trip-only place, since `photos` and `place_visits` reference `places`. `addPhoto`, `addVisit`, `tripForPhoto` and the planner's status change exist; this joins them into one step.
4. [x] **Photos to edit:** the originals with no edited version yet (`photos.kind`, `derivedFromId`), and a way to say "keep it as it is", which needs a new column. That is schema 14, together with the place's Chinese name from the launch track, so the schema changes once.
5. [x] Remove the unused `users/{userId}` paths from `firestore.rules` and `storage.rules` (left from the sign-in work in May; nothing writes there), so the rules say what the app does: only trips go to the cloud.
   - [ ] Publish the new rules from `master` (Console or `firebase deploy --only firestore:rules,storage`).

- [ ] The library export and import (#78), which the move to Play needs (launch track). The `.pilgrimage` file's export and import (`LibraryBackupService`) merged with #135; the screen to export and import is still to do. Photos stay on the device, so they don't sync in v0.3.0 (trip photos are v0.5.0).

**The other open PRs** are drafts until their version comes (2026-11-08):
- v0.4.0, with their screens: #115 the activity log, #118 the unread badge, #121 comparing versions of a place.
- v0.5.0: #116 trip photos, #117 templates, #124 template links.
- Before the store: #122 searching anime in any language, #120 the privacy policy, #113 analytics (opt-in, see the launch track).
- Not planned yet: #123 route order and clusters, #127 opening hours, #133 walking times. These are planning helpers, to look at again once Plan is simpler.
- To close, or keep as issues: #104 (declined, see above), #125 (background location, which Play restricts; Shoot here only needs a distance check), #126 (bulk tile downloads, which the OSM tile policy forbids), #128, #129, #130, #131, #132, #134.
- #119, a test runner, isn't tied to a version (review comments posted 2026-11-09).

## v0.4.0: planning together, smoother

The goal: in a group trip, everyone can see what changed and who changed it, a mistake can be undone, and each person's version of a place stays their own. Nothing here is needed on the day of a pilgrimage, so it comes after v0.3.0.

**Screens (bullyee)**
- [ ] **Trash.** Per trip, what was deleted in the last 30 days (stops, days, and the trip itself from the trip list), with who deleted it, when, and **Restore**. Opened from the trip's ⋮ menu. v0.3.0's Undo covers the seconds after a delete; this covers the rest.
- [ ] **What changed.** The trip's activity, newest first and grouped by day: "Mika moved Uji Bridge to Day 3", "Ken deleted Day 5". Tapping an entry opens the stop or day. Opened from the avatars in the trip's top bar, next to the member list.
- [ ] **Unread dot** on a trip's card and in its top bar when someone else changed it since you last looked; opening What changed clears it.
- [ ] **Comparing versions of a place.** When two versions differ, the place or stop page shows a one-line hint ("Anitabi moved this spot 120 m SE", "Your library has a different note"), which opens a side-by-side where each field gets **Keep mine** or **Use this**. No new tab or entry. Design in `docs/mvp-plan.md`, "After the MVP". Three pairs:
  - Anitabi and the library (the spot was edited on Anitabi after the import);
  - the library and a trip's stop (the stop was edited in the trip);
  - a joined trip and the library: **Save all to my library**, which also gives joined stops a My note.

**Backend and sync (ck)**
- [ ] **#103's other half: the trash in the cloud.** Deleted rows kept 30 days, then purged by a Firestore TTL policy on `expireAt`. Before it ships: `expireAt` only alongside `deletedAt` and only by the person deleting, so it can't be used to delete someone else's data; a member away longer than 30 days does a full refresh instead of missing deletions; restoring a stop or day brings its schedule back.
- [ ] **#115, the activity log**, rebased on #103: append-only, one entry per change, written in the same batch as the change so the log can't drift from the trip. Entries expire after 30 days like the trash.
- [ ] **#118, the unread dot:** the time you last opened each trip, kept on the device, against the newest entry by someone else.
- [ ] **#121, comparing places:** the field-by-field diff of Anitabi, library and stop, ignoring moves under 15 m (GPS noise).
- [ ] Rules and rules tests for the trash and the log, published with the release.

## v0.5.0: sharing outward

What other people see is what brings new users, so this is the growth version. A **template** is a finished trip turned into a public route, such as "Uji in one day, Hibike! Euphonium": the days and stops in order with their frames, but no dates, members, photos or private notes.

**Templates**
- [ ] **Publish a trip as a template.** From the trip's ⋮ menu: pick a title, a cover and a short description, check a preview, publish. It gets a 6-letter code and a link (`trip-planner-2775c.web.app/t/K7MN2P`). The author can republish after changing the trip, or unpublish at any time; an unpublished link says the template is gone. Publishing needs sign-in, and shows the author's display name, never an email. (#117 has the snapshot and codes, but its authors can't delete their templates yet, which must change.)
- [ ] **The template's web page** on Firebase Hosting, readable without the app: the route day by day on a map, each stop with its frame, the Anitabi credit, and buttons to open it in the app or get the app. Posts on Threads, X or PTT show a preview card (OpenGraph, #124). This page is the main thing people share.
- [ ] **Copy a template** into a new private trip: its days and stops come over, the user picks the dates, and the places arrive as trip-only until saved to the library.
- [ ] **Browse templates in the app** (decided 2026-11-10: a list as well as links). A Templates section, searchable by anime and by area, newest or most copied first; each shows its anime, area, days, stops and author. A list anyone can see needs:
  - a **Report** button, and a way for us to hide a template (a `hidden` flag only we can set);
  - rules so that only the author writes a template and anyone reads the published ones;
  - a copy count kept by the server, not by the app, so it can't be inflated.
- [ ] **Attribution** on every template, in the app and on the web page: who made it, and the Anitabi credit for its spots and frames. Templates carry Anitabi's data, so they're CC BY-NC-SA too: free to copy, never sold.

**Trip photos** (#116)
- [ ] Opt-in, one photo at a time: from a photo's page, **Share to the trip**. Uploaded as a 2048 px JPEG to Cloud Storage under the trip; members see them per stop and per day; the person who shared one can remove it; they go when the trip is deleted. `storage.rules` let only the trip's members read and only the uploader write.
- [ ] **Firebase's Blaze plan** (decided 2026-11-10: switch when we get here). Cloud Storage for Firebase is only on the pay-as-you-go Blaze plan since February 2026; the free quota still applies there. Set a budget alert (a few US dollars) before the switch.
- [ ] The privacy policy and Play's Data safety form list shared photos and templates (#120 has a draft).

## Launch track (not code, starts now)

### Before the store
- [ ] **Simplify the screens first.** The app has grown a lot of entry points, and every string will need translating, so tidy up before the languages. Most of it is v0.3.0: one Shoot entry instead of three camera cards, Plan and Pilgrimage, and one Plan screen instead of four tabs. Also:
  - Comparing versions of a place stays a hint where it's relevant, with no new tab or entry.
  - Use the closed test below as a usability test too: ask the testers where they got stuck.
- [ ] **Several languages: Traditional Chinese, Japanese and English.** The app is English only today (no `flutter_localizations`), while the people who go on pilgrimages mostly read Chinese or Japanese, so this comes before the store, not after. The screens are stable since v0.2.0, so the strings can move into ARB files (`flutter gen-l10n`) any time, one feature folder per PR. The store listing, the invite and template web pages, and `privacy.html` need the same languages. Anime and spot names are data, not UI strings: see the next two items.
- [ ] **Finding an anime in any language.** The import searches Bangumi, which only matches Simplified Chinese and Japanese titles, so a Traditional Chinese or English search finds little. Anitabi's index (`g.json`, already downloaded for every import) lists every work that has spots with its Chinese, English and Japanese titles (Oct 30 copy: 1,564 works; 1,431 with a Chinese title, 304 English, 1,561 Japanese). Proposed: search that list on the device, converting Traditional Chinese to Simplified before matching, with Bangumi as a fallback (ck's #122 has a start; #136 briefly bundled it and dropped it again). It also only shows works that have spots, which is what the import needs, and it works offline once the index is cached.
- [ ] **Spot names in the reader's language.** The import keeps a spot's name as Anitabi's contributors wrote it, which is a mix: of 52,959 spots, about 22,100 names have kana (Japanese), 26,700 are kanji or hanzi only (Japanese, or Chinese, often Simplified) and 3,300 are Latin. A separate Chinese name exists for only about 1 in 5 spots (10,490). Proposed: keep both names on the place (a new column, schema 14), show the Chinese one in Traditional characters when the app is in Chinese, search both, and let people rename a place as now. Converting Simplified to Traditional must leave Japanese names alone, so it applies to the Chinese name, not the original. Machine translation for the rest is a later option. (The column is in schema 14 and the import fills it since #136; showing and searching it is still to do.)
- [ ] **A Settings page.** Today the app has no settings; the ⋮ menu holds a few actions. The store version needs one place for: the language (following the phone by default), the analytics switch, export and import of the library, sign-in and sign-out, and About (the version, open-source licences, the Anitabi credit, the privacy policy).
- [ ] **Usage analytics, opt-in** (decided 2026-11-10). #113 adds Firebase Analytics with the advertising ID off. Change it so collection is off until the user turns it on in Settings (`firebase_analytics_collection_enabled` false in the manifest, enabled from the switch), and ask once, after the first trip, rather than at the first launch. Anonymous events only (screens, imports, trips made, shots), never place names or coordinates.
- [ ] **The privacy policy** (`public/privacy.html`, #120's draft) says exactly what ships: Google sign-in for trips, shared trips in Firestore, opt-in analytics, and that the library and photos stay on the phone. v0.5.0 adds shared photos and templates. In the same three languages as the app.

### Google Play
- [ ] **The app's name, then `applicationId`.** Settle the name first (see Open questions), since the ID usually follows it, then change `applicationId` from `com.example.trip_planner`. Play refuses `com.example`, and the ID can't change after the first upload. Change the map's `userAgentPackageName` and the Anitabi User-Agent with it (#24).
- [ ] **16 KB memory pages.** Since November 2025, Play only takes new apps and updates for Android 15 and later if their native libraries are aligned to 16 KB pages. Our debug builds warn that `libonnxruntime.so` (the anime cutout) isn't; update ONNX Runtime to a release built for 16 KB, or load the cutout as an optional download. Check every other `.so` with the APK Analyzer.
- [ ] **Permissions, as Play reviews them:** location only while the app is open (Shoot here, Near you, the day map), never in the background; the floating frame's "display over other apps" (`SYSTEM_ALERT_WINDOW`), explained in the listing and asked for only when first used; no advertising ID.
- [ ] **Release signing.** Today's APKs are signed with the debug key, which Play refuses. Use Play App Signing with a new upload key, kept outside the repo (both of us need a copy).
- [ ] **Moving people from the GitHub APK: export and import the library.** A new ID and key make the Play app a separate app, and the library only lives on the device. So before asking anyone to switch, the app exports the library, photos and frames included, into one file that the user saves or sends wherever they like (the system share sheet: the phone, Google Drive, a chat), and the new app imports it. It needs no account, no cloud and no change to the privacy policy, and the same file covers changing phones. This is #78: the `.pilgrimage` file's export and import merged with #135; the screens (in Settings) are still to do, and the GitHub build needs them one release before the Play app appears.
- [ ] **Play Console account** (one-time fee; personal or organization is still open, see Open questions). A new **personal** account must run a closed test with at least 12 testers, opted in for 14 days in a row, before it can publish to everyone; an organization account skips that but needs a D-U-N-S number.
- [ ] **The closed test**, if personal: recruit 15 or more testers (a few always drop out) from the communities below, through a Google Group; ship at least one update during the 14 days; ask each tester where they got stuck. It doubles as our first usability test.
- [ ] **Store listing** in the three languages: name, short and full description, the Data safety form (Google sign-in, Firestore for shared trips, opt-in analytics, photos stay on the device), content rating, privacy policy URL (`public/privacy.html`, #98).
- [ ] **Store screenshots without anime frames.** Frames belong to the studios; use our own photos and the app's screens with our own spots, so the listing isn't refused for IP.

### Licences that limit what we can do
- Anitabi's data is **CC BY-NC-SA 4.0: non-commercial.** No ads or paid features built on it while we use it. Keep the app free, and keep the attribution (already in the import and on frames).

### iOS (later, once Android has users)
- The iOS camera path exists. It needs the Apple Developer Program (yearly fee) and the Mac for builds. Apple asks apps with Google sign-in to also offer a privacy-focused login such as Sign in with Apple (guideline 4.8).

### Promotion
- **Show a real trip.** Plan our own pilgrimage in the app and post the trip report with its public template link. One good route does more than a description of features.
- **Where pilgrims are:** PTT (C_Chat, Japan_Travel), Bahamut, Dcard, Threads and X under 聖地巡禮; Bilibili and Xiaohongshu for Simplified Chinese readers. Read each board's rules on self-promotion first.
- **Anitabi.** Tell them what we built on their data, with the attribution; a link from them would reach exactly our users.
- The invite page and template pages on `trip-planner-2775c.web.app` are where people land, so they should explain the app and link to the store once it's there.

## Later

- Desktop (#55): Windows packaging and desktop layouts.
- Offline maps (#77): needs a tile source that allows offline use; `tile.openstreetmap.org` doesn't.
- Screenshots to spots with Gemini (VLM), and the PC web planner, from `CLAUDE.md`.
- From the MVP plan: closed-day warnings, trip cover, split tracks within a day, areas in the day planner.

## Open questions

- Who owns the launch track? Play account owner, store listing, the closed test's testers.
- Personal or organization Play account? An organization account skips the closed-test rule but needs a D-U-N-S number. Left for later (2026-11-10).
- Is a name change due before the store? "trip_planner" is generic and hard to search for. It must be settled before the first upload, since `applicationId` usually follows it.
- Backup days in v0.3.0's simpler Plan: fold them into the backlog, or keep them? A backup day groups a whole rainy-day plan so it can be dragged in at once; the backlog is a flat list. Folding them in reverses part of the 2026-11-02 planner design.
- v0.4.0's trash: can anyone who edits the trip restore anything, or only the owner and the person who deleted it?
- v0.5.0's template list: who answers reports, and how fast? With two of us, hiding first and looking later may be the only workable rule.
- Crash reports (Firebase Crashlytics): opt-in together with analytics, or not at all?

**Decided** (moved out of this list): usage analytics is opt-in (2026-11-10); templates have a browse list as well as links (2026-11-10); trip photos switch the project to Blaze when v0.5.0 starts (2026-11-10).
