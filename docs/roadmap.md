# Roadmap

Status: draft for bullyee and ck, 2026-11-06, updated 2026-11-09. What comes after the MVP (`docs/mvp-plan.md`), by version. Each version runs two code tracks side by side, since the screens (bullyee) and the backend and sync (ck) are mostly separate, plus a launch track that isn't code.

The hard part from here isn't the code: it's getting the app into stores and in front of people. So the launch track starts now, alongside v0.3.0, not after it.

## v0.2.0: the MVP (now)

- [x] Merge #105, #106, #107, #108 (first invite's Members tab error), #109 (frames missing after the app closes mid-import).
- [ ] Deploy #106's `firestore.rules` from `master` (Console or `firebase deploy --only firestore:rules`).
- [x] The rejoin fix, #110 (ck), moves to after the release; v0.2.0 ships with the known issue in its CHANGELOG. Agreed on 2026-11-06: the shared trip comes down clean from the cloud, and a leftover private copy with changes made while away stays as a separate private trip with a new id ("Kyoto (your copy)"), so nothing is pushed into everyone's trip and nothing is lost. A copy without changes just reconnects.
- [x] Release: PR #111 "Release v0.2.0", then the tag. The workflow couldn't sign with the release key until #112 (AGP read `$XDG_CONFIG_HOME/.android` on the runner), so the tag was moved onto #112 and the workflow built the draft pre-release.
- [x] Publish the draft (2026-11-07).

## What the app is for

The moment that matters is standing at the spot and getting the shot. Planning, sharing and importing exist so that, on the day, the right frame is in your hand. So the next version is about that moment, and planning together comes after it.

**The app is local; signing in is only for trips.** The library (places, notes, visits, photos and frames) lives on the device and never goes to the cloud. A Google account is the identity for sharing trips (sharing, inviting, joining), not a login for the whole app, and everything else works without one. Only shared trips go to Firebase, plus, later, the photos someone chooses to upload to a shared trip and the templates they publish. Moving to a new phone or to the Play app goes through a file the user exports and imports (see Google Play below), not a cloud backup. Agreed on 2026-11-08, which is why #104's personal cloud backup isn't going in.

## v0.3.0: pilgrimage mode

The goal: planning a trip gets simpler, and the day itself gets better looking and easier to use. Two tracks in parallel. They meet only where a screen needs a backend call.

**Who it's for.** Some people plan every stop and enjoy seeing the day go to plan; others walk around and shoot whatever turns up. Both go on pilgrimages, often in the same group trip (one person plans, the rest wander), and the same person can be both: a planner at home, a wanderer on the street. So the app doesn't ask which kind you are. Shooting works without a plan, the plan shows progress for those who want it, and a detour lands in the plan with one tap, so the plan stays true. **The plan follows the user** (2026-11-09): the day decides what's offered first, never what's allowed, and nothing changes the plan unless the user asks for it.

**Screens (bullyee), in two steps**

*Step 1: the shooting core.* It goes into today's app behind the existing camera entries, so it can be tried on a real outing before the home screen changes. How it behaves on a trip day was settled with step 2's Home (2026-11-09).
- **Shoot here.** One button that uses GPS to find the places within about 150 m, nearest first. On a trip day it shows that day's stops; the trip's other stops (labelled with their day) and the library places nearby wait behind an "Other places nearby" row, which opens by itself when none of the day's stops is nearby. On other days it shows the library places, so it works **without a trip**. With one place the camera opens with its frame; with several close together, as in Uji, a row of their frames to pick from. GPS is off by tens of metres in town, so it suggests and never decides alone.
- **From a stop to the camera in one tap,** with its frame already in the floating window. When a spot has more than one frame, switch frames without leaving the camera.
- **Several shots, then pick.** The Android camera returns one photo per opening, so after each shot the camera opens again with the same frame still in the floating window; pressing back in the camera ends the series. Then the shots appear next to the frame, you keep the ones you want, and the rest are deleted. Each extra shot costs the camera app's own confirm tap and about a second to reopen. If that turns out too slow on the day, the fallback is the camera app's normal mode (`INTENT_ACTION_STILL_IMAGE_CAMERA`: as many shots as you like, burst included) and, back in the app, picking the new shots with the system Photo Picker, which needs no `READ_MEDIA_IMAGES`; the cost is copies left in the phone's gallery.
- **No editing on the spot.** The kept photo is saved as shot, attached to its place (and filed under the trip, in one), the day's visit is logged, and you're back where you were. Editing, compose and cutout wait for later: a **Photos to edit** list holds the photos not yet edited, to edit at home. It replaces Home's Edit Photo card.
- **Done is the user's call, not the shot's.** A big spot can take many shots across several frames, so a shot never marks a stop done. The screen after the shots has a "Mark Uji Bridge done" tick (the same as the day map's Mark visited), already ticked when every frame of the spot now has a shot, so a one-frame spot needs no extra tap. Each stop shows its progress ("2 of 5 frames").
- **Shots off the plan leave the plan alone.** A shot at a stop planned for another day stays on that day; ticking done marks that day's item, so it shows done when the day comes. A shot at a place that isn't in the trip is filed under the trip but not added to the plan; the screen after the shots offers "Add to Day 2" for those who want the plan to match the route walked.

*Step 2: Plan, Pilgrimage and Home.* These go on one design canvas before any code, since splitting the trip screen into Plan and Pilgrimage is one design. The canvas has four versions of Home (A: a card for today's trip; B: the whole app switches between Plan and Pilgrimage; C: start and end a pilgrimage, with a banner while it runs; D: camera first, a "Here" screen). **Decided on 2026-11-09, before step 1 was tried, since it settles how Shoot here and recording a shot behave: A, with free switching between days, and no session.** C turned out to be B's switch with a trip day attached, and a session to start and end would tie the user to the plan, which the rule above avoids. Then:
- **Two modes for a trip: Plan and Pilgrimage.** Plan is for arranging the trip. Pilgrimage is for the day itself: the day's stops, the map, the camera, and nothing to edit. There's no switch: Pilgrimage is the day's map, which Home opens on during a trip and each day in Plan opens too, and Plan is the trip's page.
- **Plan, simpler.** Today a trip has four tabs (Overview, Plan, Stops, Members) and an Edit switch, and a stop can sit in three places (a dated day, a backup day, the backlog). Proposed:
  - **One Plan screen instead of four tabs:** the days, with the stops not on a day yet at the end. Overview's "3 of 5 visited" belongs to the day itself and moves to Pilgrimage. The Stops tab's search moves to Plan's top bar. Members becomes the avatars in the top bar, which open the member list and the invite.
  - **No Edit switch:** Plan is always editable for owners and editors, and looking without changing is Pilgrimage's job. Deleting a stop, a day or a trip shows **Undo**, through #103's restore.
  - **Backup days fold into the backlog** (open: see Open questions). The data stays, so they can come back; only the "Add a backup day" entry goes.
- **The day's map is Pilgrimage's main screen.** The day's stops on a map with your own location, visited ones marked, and how many are left; ‹ › go to the trip's other days, and Shoot looks at the day shown. Tapping one opens a small card with its frame, name, **Take photo** and **Mark visited**. The frame is the main thing on these cards, and after a series the shots sit next to it. Everything it needs exists: the library's map (flutter_map), the location from the new spot screen, and the stop page's Take photo; no new data. Map tiles stay online-only (see Offline maps under Later); the list of stops and the camera work without a connection, since the frames are on the device.
- **Home, with no session.** On a trip day it's that day's map, starting on today ("Kyoto · Day 2 · today"), with Shoot, Photos to edit and a way into Plan. On other days it's the next trip ("Kyoto · in 8 days · Day 3 not planned", or Plan a trip), Shoot (looking in the library) and Photos to edit. Library and Trips are always one tap away. There's nothing to start or end: the trip day is over at midnight, and scouting before the trip is Plan, then that day's map. The camera cards (Anime Camera, Floating Reference, Edit Photo) become the Shoot button and the Photos to edit list. The Sign In button goes: signing in comes up only when sharing, inviting or joining a trip.

**Backend (ck)**

From the open PRs, v0.3.0 takes three:
- #110, rejoining a trip after leaving it (see v0.2.0; approved). Later, once the comparison screens exist, rejoining could ask "You changed 3 things while away; bring them into the shared trip?" instead of keeping a separate copy.
- #114, marking a stop visited while offline in a shared trip so it syncs cleanly once back online (approved): the day of a pilgrimage is where connections drop.
- #103, the trash: its `restoreStop`, `restoreDayBlock` and `restoreTrip` give Plan its Undo, and deleted rows are purged after 30 days. It needs a rules publish and a TTL policy on `expireAt` in the Firebase Console.

New, for the screens above (#135 has 1 to 4; the 2026-11-09 changes are in its comments). All of it is local (Drift), and most of the pieces are already on master:
1. **Nearby places** (Shoot here): the places within about 150 m of a position, nearest first. On a trip day, the trip's stops from `stops` itself, each with its day (a stop has its own name and coordinates, while its place may be trip-only, or missing in a joined trip), with their frames by `placeKey` or `stopId`; then the library places not among them. With no trip, the library places. It takes the day rather than always today, so the day map's Shoot can look at the day shown. `places` has coordinates and `geolocator` is already in use. A library holds a few thousand places at most, so working out every distance is enough, with no spatial index.
2. **Today's trip:** which trip and day today is, with that day's stops and their status. `schedule_logic` already works out today's day; this wraps it in a provider.
3. **Record a shot,** the main piece: one call that copies the photo into the app and adds its `photos` row (place, trip, frame) and one `place_visits` row per place per day. It marks nothing done and changes no plan: marking a stop done and adding an off-plan place to a day are their own calls, from the screen after the shots, and work offline in a shared trip (#114). A stop whose place isn't in the library (a joined trip's) first gets a trip-only place, since `photos` and `place_visits` reference `places`. `addPhoto`, `addVisit`, `tripForPhoto` and the planner's status change exist; this joins them into one step.
4. **Photos to edit:** the originals with no edited version yet (`photos.kind`, `derivedFromId`), and a way to say "keep it as it is", which needs a new column. That is schema 14, together with the place's Chinese name from the launch track, so the schema changes once.
5. Remove the unused `users/{userId}` paths from `firestore.rules` and `storage.rules` (left from the sign-in work in May; nothing writes there), so the rules say what the app does: only trips go to the cloud.

Then the library export and import (#78), which the move to Play needs (launch track). Photos stay on the device, so they don't sync in v0.3.0 (trip photos are v0.5.0).

**The other open PRs** are drafts until their version comes (2026-11-08):
- v0.4.0, with their screens: #115 the activity log, #118 the unread badge, #121 comparing versions of a place.
- v0.5.0: #116 trip photos, #117 templates, #124 template links.
- Before the store: #122 searching anime in any language, #120 the privacy policy, #113 analytics (see Open questions).
- Not planned yet: #123 route order and clusters, #127 opening hours, #133 walking times. These are planning helpers, to look at again once Plan is simpler.
- To close, or keep as issues: #104 (declined, see above), #125 (background location, which Play restricts; Shoot here only needs a distance check), #126 (bulk tile downloads, which the OSM tile policy forbids), #128, #129, #130, #131, #132, #134.
- #119, a test runner, isn't tied to a version.

## v0.4.0: planning together, smoother

**Screens (bullyee)**
- Different versions of a place: compare Anitabi with the library, the library with a trip's stop, and a joined trip with the library ("Save all to my library", which also gives joined stops a My note). Design in `docs/mvp-plan.md`, "After the MVP".
- Screens for ck's safety net: the trash (a list of what was deleted, beyond v0.3.0's Undo), the activity list, unread badges on trip cards.

**Backend and sync (ck)**
- #115 the activity log (rebased on #103) and #118 the unread badge, merged with those screens; #121 for comparing versions. The log also sets `expireAt`.
- Whatever else those screens need.

## v0.5.0: sharing outward

What other people see is what brings new users, so this is the growth version.

- **Public trip templates** (#103 phase 4; #117, #124): a finished trip becomes a public route, such as "Uji in one day, Hibike! Euphonium". It needs a **web page on Firebase Hosting** that anyone can open without the app, with a button to copy it into the app. This page is the main thing people would share in posts.
- Template attribution: who made it, and the Anitabi credit (CC BY-NC-SA) for its spots and frames.
- Opt-in trip photos (#103 phase 3; #116): photos uploaded to a shared trip, which needs `storage.rules`.

## Launch track (not code, starts now)

### Before the store
- [ ] **Simplify the screens first.** The app has grown a lot of entry points, and every string will need translating, so tidy up before the languages. Most of it is v0.3.0: one Shoot entry instead of three camera cards, Plan and Pilgrimage, and one Plan screen instead of four tabs. Also:
  - Comparing versions of a place stays a hint where it's relevant, with no new tab or entry.
  - Use the closed test below as a usability test too: ask the testers where they got stuck.
- [ ] **Several languages: Traditional Chinese, Japanese and English.** The app is English only today (no `flutter_localizations`), while the people who go on pilgrimages mostly read Chinese or Japanese, so this comes before the store, not after. The screens are stable since v0.2.0, so the strings can move into ARB files (`flutter gen-l10n`) any time, one feature folder per PR. The store listing, the invite and template web pages, and `privacy.html` need the same languages. Anime and spot names are data, not UI strings: see the next two items.
- [ ] **Finding an anime in any language.** The import searches Bangumi, which only matches Simplified Chinese and Japanese titles, so a Traditional Chinese or English search finds little. Anitabi's index (`g.json`, already downloaded for every import) lists every work that has spots with its Chinese, English and Japanese titles (Oct 30 copy: 1,564 works; 1,431 with a Chinese title, 304 English, 1,561 Japanese). Proposed: search that list on the device, converting Traditional Chinese to Simplified before matching, with Bangumi as a fallback (ck's #122 has a start). It also only shows works that have spots, which is what the import needs, and it works offline once the index is cached.
- [ ] **Spot names in the reader's language.** The import keeps a spot's name as Anitabi's contributors wrote it, which is a mix: of 52,959 spots, about 22,100 names have kana (Japanese), 26,700 are kanji or hanzi only (Japanese, or Chinese, often Simplified) and 3,300 are Latin. A separate Chinese name exists for only about 1 in 5 spots (10,490). Proposed: keep both names on the place (a new column, schema 14), show the Chinese one in Traditional characters when the app is in Chinese, search both, and let people rename a place as now. Converting Simplified to Traditional must leave Japanese names alone, so it applies to the Chinese name, not the original. Machine translation for the rest is a later option.

### Google Play
- [ ] **Change `applicationId`** from `com.example.trip_planner`. Play refuses `com.example`, and it can't change after the first upload. Change the map's `userAgentPackageName` with it (#24).
- [ ] **Release signing.** Today's APKs are signed with the debug key, which Play refuses. Use Play App Signing with a new upload key, kept outside the repo (both of us need a copy).
- [ ] **Moving people from the GitHub APK: export and import the library.** A new ID and key make the Play app a separate app, and the library only lives on the device. So before asking anyone to switch, the app exports the library, photos and frames included, into one file that the user saves or sends wherever they like (the system share sheet: the phone, Google Drive, a chat), and the new app imports it. It needs no account, no cloud and no change to the privacy policy, and the same file covers changing phones. This is #78 (closed until after the MVP), on the new model.
- [ ] Play Console account (one-time fee). A new **personal** account must run a closed test with at least 12 testers for 14 days before it can publish (Google's help page has said 20; check the Console when we apply). The closed test is also our first group of real users, so recruit them from the communities below.
- [ ] Store listing: Data safety form (Google sign-in, Firestore for shared trips, photos stay on the device), content rating, privacy policy URL (`public/privacy.html`, #98).
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
- Personal or organization Play account? An organization account skips the closed-test rule but needs a D-U-N-S number.
- Is a name change due before the store? "trip_planner" is generic and hard to search for.
- Backup days in v0.3.0's simpler Plan: fold them into the backlog, or keep them? A backup day groups a whole rainy-day plan so it can be dragged in at once; the backlog is a flat list. Folding them in reverses part of the 2026-11-02 planner design.
- Usage analytics (#113, Firebase Analytics): it reports how the whole app is used, not only shared trips, so it sits awkwardly with a local app. Off until people opt in from Settings, or not at all? Either way the privacy policy and Play's Data safety form must list it.
