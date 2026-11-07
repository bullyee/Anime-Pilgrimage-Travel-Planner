# Roadmap

Status: draft for bullyee and ck, 2026-11-06, updated 2026-11-08. What comes after the MVP (`docs/mvp-plan.md`), by version. Each version runs two code tracks side by side, since the screens (bullyee) and the backend and sync (ck) are mostly separate, plus a launch track that isn't code.

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

Two tracks in parallel. They meet only where a screen needs a backend call.

**Who it's for.** Some people plan every stop and enjoy seeing the day go to plan; others walk around and shoot whatever turns up. Both go on pilgrimages, often in the same group trip (one person plans, the rest wander), and the same person can be both: a planner at home, a wanderer on the street. So the app doesn't ask which kind you are. Shooting works without a plan, the plan shows progress for those who want it, and a detour still lands in the plan, so the plan stays true.

**Screens (bullyee), in two steps**

*Step 1: the shooting core.* It goes into today's app behind the existing camera entries, so it can be tried on a real outing before the home screen changes. It is the same in every home-screen version on the design canvas.
- **Shoot here.** One button that uses GPS to find where you are: the places within about 150 m, nearest first, from your library, so it works **without a trip**; when a trip has today's date, its stops for today come first. With one place the camera opens with its frame; with several close together, as in Uji, a row of their frames to pick from. GPS is off by tens of metres in town, so it suggests and never decides alone.
- **From a stop to the camera in one tap,** with its frame already in the floating window. When a spot has more than one frame, switch frames without leaving the camera.
- **Several shots, then pick.** The Android camera returns one photo per opening, so after each shot the camera opens again with the same frame still in the floating window; pressing back in the camera ends the series. Then the shots appear next to the frame, you keep the ones you want, and the rest are deleted. Each extra shot costs the camera app's own confirm tap and about a second to reopen. If that turns out too slow on the day, the fallback is the camera app's normal mode (`INTENT_ACTION_STILL_IMAGE_CAMERA`: as many shots as you like, burst included) and, back in the app, picking the new shots with the system Photo Picker, which needs no `READ_MEDIA_IMAGES`; the cost is copies left in the phone's gallery.
- **No editing on the spot.** The kept photo is saved as shot, attached to its place (and to the stop, in a trip), the place is marked visited, and you're back where you were. Editing, compose and cutout wait for later: a **Photos to edit** list holds the photos not yet edited, to edit at home. It replaces Home's Edit Photo card.
- **Shots off the plan.** A shot at a place that isn't in today's plan, while a trip has today's date, adds the place to that day and marks it visited.

*Step 2: Home and the trip's two modes, after a real outing with step 1.* The design canvas has four versions of Home (A: a card for today's trip; B: the whole app switches between Plan and Pilgrimage; C: start and end a pilgrimage, with a banner while it runs; D: camera first, a "Here" screen). The current lean is C, with a Shoot button on Home that works without a trip. Decide after trying step 1, then:
- **Two modes for a trip: Plan and Pilgrimage.** Plan is today's trip screen (days, stops, times, members). Pilgrimage is for the day itself: the day's stops, the map, the camera, and nothing to edit. How you switch between them depends on the Home version chosen.
- **The day's map is Pilgrimage's main screen.** The day's stops on a map with your own location, visited ones marked, and how many are left. Tapping one opens a small card with its frame, name, **Take photo** and **Mark visited**. Everything it needs exists: the library's map (flutter_map), the location from the new spot screen, and the stop page's Take photo; no new data. Map tiles stay online-only (see Offline maps under Later); the list of stops and the camera work without a connection, since the frames are on the device.
- Home's camera cards (Anime Camera, Floating Reference) become one Shoot entry.

**Backend and sync (ck)**
- #110, rejoining a trip after leaving it (see v0.2.0). Later, once the comparison screens exist, rejoining could ask "You changed 3 things while away; bring them into the shared trip?" instead of keeping a separate copy.
- #103's phase 2, split into PRs: the trash (#103: restore deleted stops, days and trips), the activity log (#115), the unread badge. Rules changes come with emulator tests, as now. Their screens come in v0.4.0. The trash and the log set `expireAt` for Firestore to delete them after 30 days, which needs a TTL policy on that field in the Firebase Console.
- Marking a stop visited while offline in a shared trip must sync cleanly once back online: the day of a pilgrimage is where connections drop (#114). Photos stay on the device, so they don't sync here (trip photos are v0.5.0).
- Remove the unused `users/{userId}` paths from `firestore.rules` and `storage.rules` (left from the sign-in work in May; nothing writes there), so the rules say what the app does: only trips go to the cloud.

## v0.4.0: planning together, smoother

**Screens (bullyee)**
- Different versions of a place: compare Anitabi with the library, the library with a trip's stop, and a joined trip with the library ("Save all to my library", which also gives joined stops a My note). Design in `docs/mvp-plan.md`, "After the MVP".
- Screens for ck's safety net: the trash, the activity list, unread badges on trip cards.

**Backend and sync (ck)**
- Whatever those screens need beyond phase 2.

## v0.5.0: sharing outward

What other people see is what brings new users, so this is the growth version.

- **Public trip templates** (#103 phase 4): a finished trip becomes a public route, such as "Uji in one day, Hibike! Euphonium". It needs a **web page on Firebase Hosting** that anyone can open without the app, with a button to copy it into the app. This page is the main thing people would share in posts.
- Template attribution: who made it, and the Anitabi credit (CC BY-NC-SA) for its spots and frames.
- Opt-in trip photos (#103 phase 3): photos uploaded to a shared trip, which needs `storage.rules`.

## Launch track (not code, starts now)

### Before the store
- [ ] **Simplify the screens first.** The app has grown a lot of entry points, and every string will need translating, so tidy up before the languages:
  - Home's five cards: Anime Camera, Floating Reference and Edit Photo are all the camera, and could be one.
  - A trip has two modes, Plan and Pilgrimage (see v0.3.0), so neither screen has to hold everything.
  - Comparing versions of a place stays a hint where it's relevant, with no new tab or entry.
  - Use the closed test below as a usability test too: ask the testers where they got stuck.
- [ ] **Several languages: Traditional Chinese, Japanese and English.** The app is English only today (no `flutter_localizations`), while the people who go on pilgrimages mostly read Chinese or Japanese, so this comes before the store, not after. The screens are stable since v0.2.0, so the strings can move into ARB files (`flutter gen-l10n`) any time, one feature folder per PR. The store listing, the invite and template web pages, and `privacy.html` need the same languages. Anime and spot names are data, not UI strings: see the next two items.
- [ ] **Finding an anime in any language.** The import searches Bangumi, which only matches Simplified Chinese and Japanese titles, so a Traditional Chinese or English search finds little. Anitabi's index (`g.json`, already downloaded for every import) lists every work that has spots with its Chinese, English and Japanese titles (Oct 30 copy: 1,564 works; 1,431 with a Chinese title, 304 English, 1,561 Japanese). Proposed: search that list on the device, converting Traditional Chinese to Simplified before matching, with Bangumi as a fallback. It also only shows works that have spots, which is what the import needs, and it works offline once the index is cached.
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
- Usage analytics (#113, Firebase Analytics): it reports how the whole app is used, not only shared trips, so it sits awkwardly with a local app. Off until people opt in from Settings, or not at all? Either way the privacy policy and Play's Data safety form must list it.
