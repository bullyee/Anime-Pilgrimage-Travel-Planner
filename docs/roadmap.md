# Roadmap

Status: draft for bullyee and ck, 2026-11-06. What comes after the MVP (`docs/mvp-plan.md`), by version. Each version runs two code tracks side by side, since the screens (bullyee) and the backend and sync (ck) are mostly separate, plus a launch track that isn't code.

The hard part from here isn't the code: it's getting the app into stores and in front of people. So the launch track starts now, alongside v0.3.0, not after it.

## v0.2.0: the MVP (now)

- [ ] Merge #105, #106, #107, #108 (first invite's Members tab error), #109 (frames missing after the app closes mid-import).
- [ ] Deploy #106's `firestore.rules` from `master` (Console or `firebase deploy --only firestore:rules`).
- [ ] The rejoin fix, #110 (ck). Agreed on 2026-11-06: the shared trip comes down clean from the cloud, and a leftover private copy with changes made while away stays as a separate private trip with a new id ("Kyoto (your copy)"), so nothing is pushed into everyone's trip and nothing is lost. A copy without changes just reconnects. If it doesn't fit v0.2.0, v0.2.0 ships with the known issue already in its CHANGELOG.
- [ ] Release: `release/v0.2.0` from `master` with the docs already prepared, then the tag.

## v0.3.0: planning together, smoother

Two tracks in parallel. They meet only where a screen needs a backend call.

**Screens (bullyee)**
- Different versions of a place: compare Anitabi with the library, the library with a trip's stop, and a joined trip with the library ("Save all to my library", which also gives joined stops a My note). Design in `docs/mvp-plan.md`, "After the MVP".
- Screens for ck's safety net below: the trash, the activity list, unread badges on trip cards.
- **A map for the day of the pilgrimage.** The day's stops on a map with your own location, so the nearest one is easy to see. Tapping one opens a small card with its frame, name, **Take photo** (the anime camera with that frame) and **Mark visited**; after the photo you're back on the map. On a trip day, the trip opens straight to this map. Everything it needs exists: the library's map (flutter_map), the location from the new spot screen, and the stop page's Take photo; it's one screen, no new data. Map tiles stay online-only (see Offline maps under Later).

**Backend and sync (ck)**
- #103's phase 2, split into PRs: the trash (restore deleted stops and days), the activity log, the unread badge. Rules changes come with emulator tests, as now.
- Rejoining a trip after leaving it, as a follow-up if it doesn't make v0.2.0 (#110): see v0.2.0. Later, once the comparison screens exist, rejoining could ask "You changed 3 things while away; bring them into the shared trip?" instead of keeping a separate copy.

## v0.4.0: sharing outward

What other people see is what brings new users, so this is the growth version.

- **Public trip templates** (#103 phase 4): a finished trip becomes a public route, such as "Uji in one day, Hibike! Euphonium". It needs a **web page on Firebase Hosting** that anyone can open without the app, with a button to copy it into the app. This page is the main thing people would share in posts.
- Template attribution: who made it, and the Anitabi credit (CC BY-NC-SA) for its spots and frames.
- Opt-in trip photos (#103 phase 3): photos uploaded to a shared trip, which needs `storage.rules`.

## Launch track (not code, starts now)

### Before the store
- [ ] **Simplify the screens first.** The app has grown a lot of entry points, and every string will need translating, so tidy up before the languages:
  - Home's five cards: Anime Camera, Floating Reference and Edit Photo are all the camera, and could be one.
  - A trip opens to its plan before the trip and to the day's map during it (see v0.3.0).
  - Comparing versions of a place stays a hint where it's relevant, with no new tab or entry.
  - Use the closed test below as a usability test too: ask the testers where they got stuck.
- [ ] **Several languages: Traditional Chinese, Japanese and English.** The app is English only today (no `flutter_localizations`), while the people who go on pilgrimages mostly read Chinese or Japanese, so this comes before the store, not after. The screens are stable since v0.2.0, so the strings can move into ARB files (`flutter gen-l10n`) any time, one feature folder per PR. The store listing, the invite and template web pages, and `privacy.html` need the same languages. Anime and spot names are data, not UI strings: see the next two items.
- [ ] **Finding an anime in any language.** The import searches Bangumi, which only matches Simplified Chinese and Japanese titles, so a Traditional Chinese or English search finds little. Anitabi's index (`g.json`, already downloaded for every import) lists every work that has spots with its Chinese, English and Japanese titles (Oct 30 copy: 1,564 works; 1,431 with a Chinese title, 304 English, 1,561 Japanese). Proposed: search that list on the device, converting Traditional Chinese to Simplified before matching, with Bangumi as a fallback. It also only shows works that have spots, which is what the import needs, and it works offline once the index is cached.
- [ ] **Spot names in the reader's language.** The import keeps a spot's original name, which is Japanese for most works and matches the signs on site. Anitabi has a Chinese name for only about 1 in 5 spots (10,490 of 52,959). Proposed: keep both names on the place (a new column, schema 14), show the Chinese one (converted to Traditional) under or instead of the Japanese one when the app is in Chinese, search both, and let people rename a place as now. Machine translation for the rest is a later option.

### Google Play
- [ ] **Change `applicationId`** from `com.example.trip_planner`. Play refuses `com.example`, and it can't change after the first upload. Change the map's `userAgentPackageName` with it (#24).
- [ ] **Release signing.** Today's APKs are signed with the debug key, which Play refuses. Use Play App Signing with a new upload key, kept outside the repo (both of us need a copy).
- [ ] **Moving people from the GitHub APK.** A new ID and key make the Play app a separate app, and the library only lives on the device. Either a library export and import, or #104's backup (opt-in, with a privacy policy update), before asking anyone to switch.
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
