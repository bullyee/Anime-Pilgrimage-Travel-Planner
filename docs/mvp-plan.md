# MVP plan

Status: in progress. Drafted 2026-10-31. Updated on the morning of 2026-11-03:
- #81, #82, #83 and #87 have merged.
- ck approved #88 (the library, place pages and Anitabi import) and #92 (the trip list's filters and sections, and sorting stops).
- #91 (camera and editor on library places) is stacked on #88. It goes up for review once #88 merges.
- #93 does what's left of stage 3 (#89) and adds the trip note. It's in review.

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
- [ ] Stop page, built on the place page's design, with the shared per-stop trip note (`stops.note`, in #93).
  - Cap the note at 2000 by Dart's `String.length` (UTF-16 code units), which is what the rules' `size()` counts. TextField's `maxLength` counts characters as people see them, so a note of emoji could pass it and fail the rules. A note the rules refuse fails the whole trip's upload.
- [x] Anitabi import: a checkbox list with "select all". Picked spots go into the library, and optionally into a new or existing trip. A rework of `bangumi_search_screen` (#88).
- [x] Labels: create, rename and merge anime, tag and region labels (#88). Unused labels are deleted. Replaces the anime and tag edit screens.
- [x] Camera and editor on library places (#91, stacked on #88):
  - photos are saved into `photos`, with `kind`, `derived_from_id`, `reference_image_id` and `trip_id`. The trip is the one with a stop at the place on the day the photo was taken;
  - the pickers choose a library place, then one of its frames. Today's trip places come first;
  - fixes two bugs from #84:
    - The photo-edit routes decoded `path` and `ref` a second time, so a file name containing `%` threw. `PhotoEditArgs` now builds and reads the query.
    - Leaving the isnet cutout panel mid-cutout released the ONNX session while `runAsync` could still be using it. `dispose()` now waits for it.
- [ ] Cache reference image thumbnails for offline use, with `ThumbnailCacheService` (merged in #83).
- [ ] Remove the old screens, routes, models and repositories as each is replaced. Remove the v8 sync engine together with the old tables. (both)
  - Re-run `migrateData()` before the old tables go.
  - `persistMediaAsset` writes each new photo to `media_assets` and `photos` under the same id until then (#88), so the re-run doesn't copy it twice.

**Milestone A:** the whole app runs on the new model on one device. Internal builds only, since sync is off until stage 3.

## Stage 3: sync on the new model (ck)

The engine and rules merged in #82 on 2026-11-02. #93 does the rest of #89, except deploying the rules and the cutover.

- [x] Firestore layout and rules for trips, days, stops, stop labels and schedule items (#82):
  - each document is last-write-wins on `updated_at`;
  - deletes are `deleted_at` tombstones.
- [x] Sync engine (#82):
  - upload dirty rows;
  - listen for remote changes per trip and apply them;
  - work offline, and never await a Firestore write inside a Drift transaction (#65 round 3, fixed in #79).
- [ ] Run the engine in the app for signed-in users (#93, in review). Two review findings:
  - fixed: the rules refused the query for the user's trips, so nothing synced down. `tripsV2` now has an `allow list` rule;
  - open: the new lost-access check also catches another account's trips. After switching accounts on one phone, it turns them private, and the first account's next edit unshares the trip in the cloud and hands it to the other account.
- [x] Labels sync by natural key. A label that's missing locally is created (#82).
- [x] Turning a private trip into a shared one uploads its stops, days and schedule. Photos are not uploaded (#82).
- [ ] One sync status icon per trip: synced, pending, or offline. The engine side is `tripSyncStatusProvider` (#82). The icon is bullyee's, after #93 merges: it goes next to the title on trip cards, and only when a shared trip isn't synced.
- [x] Tests:
  - [x] reuse the fake Firestore harness from #65 (#82);
  - [x] add rules tests on the Firebase emulator: `test/rules_v2_emulator_test.py`;
  - [x] run them in CI, with `firebase emulators:exec` (#93). The #65 rule hole showed that untested rules slip through;
  - [x] steady `sync_engine_v2_test`: it polls instead of waiting fixed times (#93).
- [ ] Deploy the `tripsV2` rules from master when v0.2.0 ships (#89).
- [ ] Make the old `trips/` collection read-only after the cutover (#89).
- [x] The trip note: `stops.note`, a v12 migration, sync, and a 2000-character limit in the rules (#93).

**Release v0.2.0:** the new model, plus sync across your own devices. Sharing with other people is still not possible, the same as in v0.1.x.

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
  - valid for 7 days, usable by any number of people. Invites have an `isRevoked` flag, but there's no call to revoke one yet;
  - an email allowlist;
  - joining is validated in rules, since the free plan has no Cloud Functions.
- [x] Invite preview data on the invite doc: title, dates, stop count, and the inviter's name and avatar.
- [x] Leaving, removing a member, changing a role, transferring ownership.
- [ ] When the owner stops sharing or deletes the trip, every other member keeps a private, unsynced copy. The engine side is in #93, with an open review finding (see stage 3).
- [x] Member profiles: Google display name and avatar, never the email.
- [x] Guest → signed in: `claimGuestTrips` claims the local trips by setting the owner and author to the uid. No screen calls it yet.
- [x] Download page on Firebase Hosting, plus Android App Links (`assetlinks.json`), with the release keystore's SHA-256 (`30:71:A9:32:…`). The live site serves it since #83 merged.
  - The download button opens `/releases/latest`. While every release is a pre-release, that redirects to the release list.

**Screens (bullyee)**
- [ ] Share sheet: create an invite with a role; show the link, QR code and short code; revoke.
- [ ] Join flow: open a link, scan a QR code, or enter a code → invite preview → join.
  - The login redirect still checks `/cloud-share`, which matches no route. Make it check the join route instead (#84).
  - Add a `/join` route: #83's App Links open `/join` links in the app, which has no such route yet.
- [ ] Member list: roles, remove, leave, transfer ownership.
- [ ] Member avatars on shared trip cards, and a read-only mode for viewers. The trip list's Shared filter and "Shared" line are in #92 (#44).
- [ ] A "Join a trip" entry in My Trips' app bar and in the empty Shared filter.

**Release v0.3.0, the MVP.**

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

- Phases 2–4 of `docs/trip-sharing.md`: the safety net, photos, templates.
- Personal layer backup, "save updates to my place", template attribution, closed-day warnings, trip cover, split tracks within a day.
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
