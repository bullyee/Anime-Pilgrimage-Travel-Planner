# MVP plan

Status: almost done. Drafted 2026-10-31. Updated 2026-11-06:
- **Stages 0–3 are done**, apart from the release. Every screen runs on the new model (#87, #88, #91, #92, #94), the old screens, tables and v8 sync are gone (#96, #97), and sync runs in the app (#93). The `tripsV2` rules are live.
- **Stage 4:** the backend (#83), the invite and join screens (#100), the security hardening (#102) and the sync icon (#101) have merged. Two phones invited, joined and synced in a hand test.
- **Left for the MVP:** the viewer read-only mode, Leave trip and member avatars on trip cards (bullyee, in progress), then the release.
- **In review:** #106 (document ID checks in the rules, and a sync chain that survives a bad snapshot) and #105 (multi-user sync tests).
- **After the MVP:** #103 (the phase 2–4 backend: trash, activity log, unread badge, photo upload, templates) and #104 (personal cloud backup) wait until the release. #103's first commit fixes rejoining a trip after leaving it, which is an MVP bug, so it should land on its own.

It builds on `docs/data-model.md` and `docs/trip-sharing.md`, which were proposed in #72.

## Goal

The MVP is the new data model plus group sharing, which is phase 1 of `docs/trip-sharing.md`. It covers:
- a personal library of places, with private notes, labels and photos;
- trips planned with day blocks;
- sync rebuilt on the new tables;
- sharing a trip with a group: roles, link / QR / code invites, and member management.

Not in the MVP: the activity log and trash, photo sharing, public templates, and the personal cloud backup. These are phases 2–4 and later.

## Decisions

- **No fixed deadline.**
- **Direct replacement.** The new schema replaces v9 in a single migration, and the old screens are rewritten on top of it. There is no feature flag and no period where old and new tables run side by side.
  - Master keeps compiling and its tests stay green.
  - Features are missing until their new screens land, so there is no release until v0.2.0.
  - Until then the old code gets bug fixes only.
- **Ownership.**
  - ck: the data layer (tables, repositories, pure logic), the migration, sync, the sharing backend, and services such as the thumbnail cache.
  - bullyee: screen design, the screens and their controllers, the camera and the photo flow. A controller's shape follows its screen, so the two are built together.

## Working rules

These apply to people and coding agents alike.
- **One stage at a time in review.** Open the next stacked PR only after the one below it is approved. Fix a PR's review items before adding new work to it.
- **Stay in your area.** Before writing code in the other person's area, agree on it first, on #72 or on the PR. The stage 2 screens and controllers, for example, are bullyee's.
- **Deploy from master only.** Never deploy an unmerged branch to the live Firebase project (`trip-planner-2775c`).
  - Deploy only what changed, e.g. `firebase deploy --only hosting`.
  - Rules that change `trips/` go live with v0.2.0, since v0.1.x clients still write there.
- **Check agent output before posting it.** Issue reports and "fixed" replies written by an agent must match the branch: every file, function and line they cite must exist.
- **Reviews.** Every PR needs an approving review from the other person before it merges.

## Stage 0: prepare (both)

- [x] Merge #65, then its round 3 fixes in #79.
- [x] Merge #73 (#24 cleanup).
- [x] Merge #75 (#76 file cleanup and thumbnails).
- [x] Finish #74 (desktop) with the crash guards only. Windows packaging waits until after the MVP; see the review on #74.
- [x] Cut **v0.1.3**, the last release on the old model (2026-11-01). It ships the camera floating window, the photo editor tools, two-way sync and the fixes above. (bullyee)
- [ ] Fold the #72 feedback into the docs:
  - Schedule times are minutes from the block's start and may pass 24:00, e.g. 25:30. They move with the block when blocks swap.
  - An invite preview screen comes before joining. Its fields live on the invite doc, since non-members can't read the trip.
  - The place / stop page keeps `access_tips` (shared) and `private_note` (yours) visibly separate.
  - Reference image thumbnails are cached for offline use.
  - Later: "Save updates to my place" on a stop, and template attribution.
- [x] Freeze the old model: no new features, bug fixes only. #55, #77 and #78 are closed until after the MVP, since the code they touch gets replaced. (ck)
- [x] Settled on #72 (ck + bullyee):
  - **Firestore layout for the new sync.** `tripsV2/{tripId}`, with `days`, `stops`, `schedule_items`, `members` and `invites` subcollections. A new top-level collection means v0.1.x clients still writing to `trips/` can't corrupt new data. `trips/` becomes read-only after the cutover.
  - **Fractional index for `sort_key`.** The `fractional_indexing_dart` package (#81).
  - **IDs.** UUIDs everywhere. `place_key` is `anitabi:<id>` for Anitabi spots and a bare UUID for places users create, with no `custom:` prefix (decided 2026-11-02). Migrated places keep their v9 IDs. Labels are matched across people by kind + name, and anime by Bangumi ID.

## Stage 1: data layer (ck)

Merged in #81 on 2026-11-02.

**1a. Contract first**, so the screens can be built in parallel:
- [x] Drift tables:
  - personal layer: `places`, `labels`, `place_labels`, `photos`, `place_visits`, `reference_images`;
  - shared layer: `trips`, `trip_days`, `stops`, `stop_labels`, `schedule_items`;
  - sync bookkeeping on the shared tables: `updated_at`, `updated_by`, `deleted_at` and a local sync status.
- [x] Repository interfaces and Riverpod providers for the operations the screens need, for example:
  - list and filter places by label;
  - add a place to a trip (copy it into a stop, including its reference images);
  - create a `trip_only` place;
  - schedule a stop, reorder items, swap blocks, pin a date.
- [x] Pure logic, with unit tests:
  - day block dates: position, pins, backup blocks, and the rule that pins must increase;
  - the fractional index;
  - schedule times: order, stay, transit, fixed times, past 24:00. Port what applies from `lib/core/utils/schedule_engine.dart`;
  - trip status and the backlog, which are derived rather than stored.

**1b. Migration**
- [x] v9 → v10, as described in `docs/data-model.md`:
  - rois → region labels;
  - pois → `saved` places (Anitabi ones keep `anitabi:<id>`). Deleted POIs are skipped;
  - animes / tags → labels, with duplicates merged;
  - reference images and `reference_frame` media → reference images, with the metadata parsed into episode / timestamp;
  - `user_photo` and `uploaded_image` → `original` photos, and `comparison_image` → `comparison` photos;
  - drop `ticket_qr`, `audio_bgm`, `time_chunks` and the old tables.
  - The upgrade copies the data and keeps the old tables, because the old screens still use them. At the stage 2 cutover, run `migrateData()` again, then drop the old tables.
- [x] Migration tests, starting from a v8 and a v9 database.

## Stage 2: screens (bullyee)

**Design first.** These are the "Still to design" items, worked through with Claude:
- [x] Place page and stop page: which shared and personal fields each shows, and the layout. One design serves both. The anime frames lead, and the personal parts (note, photos by trip, visits) are kept apart from the shared facts. A stop adds a plan card.
- [x] Day planner on a phone:
  - a zoomed-out mode for reordering blocks;
  - auto-scroll while dragging;
  - how backlog and backup blocks are shown.
- [x] Home and My Trips (#44). The library leads Home, followed by My Trips (#88). My Trips (#92) has:
  - All / Shared / Private filters, with counts;
  - sections that carry each trip's status: ongoing, coming up, no dates yet, finished;
  - lean cards: the date badge, the title, and a "Shared" line on shared trips. Member avatars and "You and 3 others" come with the stage 4 member list.

**Build**, on the stage 1a repositories:
- [x] Screen controllers, as Riverpod `Notifier`s, written together with each screen. The day planner's is `DayPlannerController` (#87). #83 dropped its draft `TripListController` and `TripPlannerController` (e02e045) and keeps `JoinTripController`.
- [x] Home screen and routes. The library and trips lead Home, and the old screens sit under "Old screens", marked deprecated (#88). The trip list's filters are in #92.
- [x] Library (#88):
  - places as a list and a map, with label filters (anime / tag / region) and search;
  - `saved` vs `trip_only` places;
  - picking several to label, add to a trip, merge or remove;
  - a warning when a new place looks like a saved one, and merging places;
  - map search with Nominatim and Google Maps links, on the new place, new spot and move pin screens.
  - Replaces `poi_browse_screen`, `pois_by_filter_screen`, `poi_map_screen` and the ROI list / detail screens, once they're removed.
- [x] Place page: facts, private note, labels, reference images, my photos, visits (#88). Replaces `poi_detail_screen` and `poi_create_screen`.
- [x] Trip page (#87):
  - [x] the stop list: searchable, and sorted by plan order, name or most recently added (#92);
  - [x] the header and the overview show only the dates, without day or stop counts (#92);
  - [x] the backlog;
  - [x] adding a stop from the library, or creating a new spot (a `trip_only` place). A place can be added more than once, and each stop gets its own name, e.g. "Uji Bridge (2)" (#88);
  - [x] trip settings (title, start date, day count).
  - Replaces `roi_detail_screen` and `roi_edit_screen`, and drops the "Real-time collaboration is active" text.
- [x] Day planner: blocks, dragging stops and blocks, pins, backup blocks (#87), and times (#88). Replaces `calendar_screen` and the time-chunk widgets.
- [x] Stop page, built on the place page's design, with the shared per-stop trip note (`stops.note` from #93; the page in #94).
  - Cap the note at 2000 by Dart's `String.length` (UTF-16 code units), which is what the rules' `size()` counts. TextField's `maxLength` counts characters as people see them, so a note of emoji could pass it and fail the rules. A note the rules refuse fails the whole trip's upload.
- [x] Anitabi import: a checkbox list with "select all". Picked spots go into the library, and optionally into a new or existing trip. A rework of `bangumi_search_screen` (#88).
- [x] Labels: create, rename and merge anime, tag and region labels (#88). Unused labels are deleted. Replaces the anime and tag edit screens.
- [x] Camera and editor on library places (#91, stacked on #88):
  - photos are saved into `photos`, with `kind`, `derived_from_id`, `reference_image_id` and `trip_id`. The trip is the one with a stop at the place on the day the photo was taken;
  - the pickers choose a library place, then one of its frames. Today's trip places come first;
  - fixes two bugs from #84:
    - The photo-edit routes decoded `path` and `ref` a second time, so a file name containing `%` threw. `PhotoEditArgs` now builds and reads the query.
    - Leaving the isnet cutout panel mid-cutout released the ONNX session while `runAsync` could still be using it. `dispose()` now waits for it.
- [x] Cache reference image thumbnails for offline use, with `ThumbnailCacheService` (merged in #83). The place and stop pages use it for frames that only have a link.
- [x] Remove the old screens, routes, models and repositories, the v8 sync engine and the old tables (#96, #97). `migrateData()` runs once more before the old tables go, and still upgrades v0.1.0–v0.1.2 databases (#95).

**Milestone A:** reached on 2026-11-03 with #97. The whole app runs on the new model.

## Stage 3: sync on the new model (ck)

The engine and rules merged in #82 on 2026-11-02, and #93 did the rest of #89. Done apart from the release.

- [x] Firestore layout and rules for trips, days, stops, stop labels and schedule items (#82):
  - each document is last-write-wins on `updated_at`;
  - deletes are `deleted_at` tombstones.
- [x] Sync engine (#82):
  - upload dirty rows;
  - listen for remote changes per trip and apply them;
  - work offline, and never await a Firestore write inside a Drift transaction (#65 round 3, fixed in #79).
- [x] Run the engine in the app for signed-in users (#93). Two review findings:
  - fixed: the rules refused the query for the user's trips, so nothing synced down. `tripsV2` now has an `allow list` rule;
  - the lost-access check could catch another account's trips after switching accounts on one phone. #102 made the engine upload only the signed-in account's own and shared trips. Switching accounts on one phone hasn't been re-tested since.
- [ ] Hardening from ck's audit (#106, in review): the rules require a document's `id` to match its path, the engine keys on the path ID, and one bad snapshot no longer stops a trip's sync until restart.
- [x] Labels sync by natural key. A label that's missing locally is created (#82).
- [x] Turning a private trip into a shared one uploads its stops, days and schedule. Photos are not uploaded (#82).
- [x] One sync status icon per trip (#101): a cloud next to the title on trip cards and the trip page, only when a shared trip isn't synced. The engine side is `tripSyncStatusProvider` (#82).
- [x] Tests:
  - [x] reuse the fake Firestore harness from #65 (#82);
  - [x] add rules tests on the Firebase emulator: `test/rules_v2_emulator_test.py`;
  - [x] run them in CI, with `firebase emulators:exec` (#93). The #65 rule hole showed that untested rules slip through;
  - [x] steady `sync_engine_v2_test`: it polls instead of waiting fixed times (#93).
  - [ ] multi-user sync tests: two engines on one fake cloud, covering concurrent adds, last-write-wins, offline edits and soft deletes (#105, in review).
- [x] Deploy the `tripsV2` rules from master. They went live on 2026-11-04, before any release rather than with v0.2.0. The live rules equal master after #100 (checked against the console on 2026-11-05).
- [x] Make the old `trips/` collection read-only: members can still read it, and nobody can write.
- [x] The trip note: `stops.note`, a v12 migration, sync, and a 2000-character limit in the rules (#93).

**Release v0.2.0:** not cut. With stage 4 nearly done, the plan is one release for both, the MVP.

## Stage 4: group sharing

**Backend (ck)**: merged in #83 on 2026-11-02, after three review rounds. Each round ran the rules on the Firestore emulator ([first review](https://github.com/bullyee/trip_planner/pull/83#pullrequestreview-5738700283)). The fixes covered:
- joining, the first share, and the owner's member doc;
- unsharing, which now removes the other members' access;
- short codes, which other users can no longer delete or retarget;
- the 7-day invite cap, and removed editors rejoining;
- an editor making themselves the owner.

- [x] `members` with the roles owner, editor and viewer, enforced in rules. Viewers are read-only. Only owners and editors can invite.
- [x] Invites:
  - a token plus a short code;
  - the role is chosen when the invite is created;
  - valid for 7 days, usable by any number of people, and can be stopped (`isRevoked`, from the Members tab since #100);
  - an email allowlist;
  - joining is validated in rules, since the free plan has no Cloud Functions.
- [x] Invite preview data on the invite doc: title, dates, stop count, and the inviter's name and avatar.
- [x] Leaving, removing a member, changing a role, transferring ownership.
- [x] When the owner stops sharing or deletes the trip, every other member keeps a private, unsynced copy (#93).
  - Known gap: after leaving, rejoining the same trip doesn't sync, because the engine skips the leftover private copy. The fix is the first commit of #103 (86dbdbf) and should land on its own before the release.
- [x] Member profiles: Google display name and avatar, never the email.
- [x] Guest → signed in: `claimGuestTrips` claims the local trips by setting the owner and author to the uid. The invite sheet calls it before the first share (#100).
- [x] Security hardening (#102): anonymous sign-ins are refused, the invite fields have size caps, a short code's `createdBy` must be the caller, and the engine only uploads the signed-in account's trips. Emulator tests cover each rule.
- [x] Download page on Firebase Hosting, plus Android App Links (`assetlinks.json`), with the release keystore's SHA-256 (`30:71:A9:32:…`). The live site serves it since #83 merged.
  - The download button opens `/releases/latest`. While every release is a pre-release, that redirects to the release list.

**Screens (bullyee)**
- [x] Share sheet (#100): pick Edit or View only, then share the link, QR code and 6-letter code; stop an invite.
- [x] Join flow (#100): open a link, or type a code or paste a link under **Join a trip** → invite preview → join. A QR code opens the link with the phone's camera. `/join` is a route, and signing in from it returns to the invite.
- [x] Members tab (#100): avatars and roles; the owner can make a member view only, make them owner, or remove them; open invites; Stop sharing.
- [x] A "Join a trip" entry in My Trips (#100).
- [x] Hand test on two phones: invite, join and sync (2026-11-05).
- [ ] Leave trip for members who aren't the owner. (in progress)
- [ ] Read-only mode for viewers: the trip, day planner and stop pages hide or disable editing. The rules already refuse a viewer's writes, so without this a viewer's edits stay local and never upload. (in progress)
- [ ] Member avatars on shared trip cards. The trip list's Shared filter and "Shared" line are in #92 (#44). (in progress)

**Release: the MVP.** One release with the new model and group sharing. Bump `pubspec.yaml` past 0.1.3 and update the download page's APK, since v0.1.3 can't open invite links.

## Order

```
Stage 0 ──► 1a ──┬──► 1b (migration) ──┐
                 ├──► 2 build ─────────┼──► v0.2.0 ──► 4 ──► v0.3.0 (MVP)
                 └──► 3 sync ──────────┘
2 design (can start now) ──► 2 build
```

- Stage 2 design can start right away.
- Stage 2 build and stage 3 both need the 1a tables and repositories. After that they run in parallel.
- v0.2.0 needs all three: the migration, the screens and sync.

## After the MVP

- Phases 2–4 of `docs/trip-sharing.md`: the safety net, photos, templates. ck's #103 has the backend for all three (the trash, activity log, unread badge, photo upload and templates), with no screens yet. It touches `firestore.rules` and adds `storage.rules`.
- Personal layer backup: ck's #104 has the service, with no screen yet. It sends the personal library to Firestore, which the privacy policy (#98) says stays on the device, so it needs an opt-in and a policy update.
- **Different versions of a place** (agreed 2026-11-06). A place has up to three versions: Anitabi's, the one in my library, and each trip's stop, which is the trip's own copy. They may differ and stay different: nothing changes another version by itself, and a difference is only pointed out, never asked about in the middle of something. Each case uses the same comparison: one at a time, only the fields that differ (name, location as "moved 120 m", description, source link), with "Use theirs", "Keep mine", "Use theirs for all" and "Keep mine for all".
  - **Anitabi → my library:** the import keeps my version as it does now, and its result says "5 spots differ from Anitabi · Review". A place's page shows "Anitabi has different details · Compare".
  - **My library → a trip's stop:** the stop page shows "Your library has different details · Compare", and only the owner and editors can update the stop, since that syncs to every member. The Stops tab can review them all.
  - **A trip → my library, on joining:** after joining, "5 places in this trip differ from your library · Review", plus "Save all to my library" for the trip's places I don't have. Today a stop whose place isn't in my library has no My note (the stop page shows it only when the place exists), so saving them also fixes that.
- Template attribution, closed-day warnings, trip cover, split tracks within a day.
- Areas in the day planner: grouping stops by area by hand. Postponed on 2026-11-02, so `stops.area` stays unused until then.

## Existing issues

| Issue | Where it goes |
|---|---|
| #24 cleanup backlog | #73 (merged) did the items worth doing. Items on old screens become moot after stage 2. Still open: `applicationId` is `com.example.trip_planner`. Change it before any store release, together with the map's `userAgentPackageName`, which sends the same name. |
| #40 `isShared` no-ops | Solved by stage 1 (`trips.sharing`, `photos.is_shared`). |
| #44 "My Trips" opens Regions | My Trips opens the new trip list (#87, #88), and #92 adds the All / Shared / Private filters. Close it once #92 merges. |
| #45 two-way sync | Closed by #65 and #79; stage 3 replaces it. |
| #55 desktop | #74 added the crash guards. Close for now; Windows packaging and desktop layouts come after the MVP. |
| #72 data model proposal | This plan. |
| #76 sync FK / storage leaks | Closed by #75. |
| #77 offline map tiles | Close for now; reopen after the MVP. It needs a different tile source. The [OpenStreetMap tile policy](https://operations.osmfoundation.org/policies/tiles/) forbids offline use of `tile.openstreetmap.org`, including any "download for offline" feature, and requires a User-Agent that identifies the app. |
| #78 export / backup | Close for now; reopen after the MVP. The export format should follow the new model, and it overlaps with the personal layer backup. |
| #84 camera, editor and router notes | #91 fixes the two camera and editor bugs. The `/cloud-share` redirect goes with the join flow. The other items cite code that isn't in the repo or in #81–#83, or old-model screens that stage 2 replaces. |
| #89 stage 3, what's left after #82 | #93 closes it. Deploying the rules and making `trips/` read-only stay in stage 3's list. |
