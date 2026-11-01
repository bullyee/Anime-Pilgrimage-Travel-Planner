# MVP plan

Status: draft, 2026-10-31, updated 2026-11-01 after #74 and #75 merged. It builds on `docs/data-model.md` and `docs/trip-sharing.md`, which were proposed in #72.

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
  - ck: the data layer, the migration, sync, and the sharing backend.
  - bullyee: the screens, the camera and the photo flow, and screen design.

## Stage 0: prepare (both)

- [x] Merge #65, then its round 3 fixes in #79.
- [x] Merge #73 (#24 cleanup).
- [x] Merge #75 (#76 file cleanup and thumbnails).
- [x] Finish #74 (desktop) with the crash guards only. Windows packaging waits until after the MVP; see the review on #74.
- [ ] Cut **v0.1.3** from master once #74 and #75 are in. It is the last release on the old model, and ships the camera floating window, the photo editor tools, two-way sync and the fixes above. (bullyee)
- [ ] Fold the #72 feedback into the docs:
  - Schedule times are minutes from the block's start and may pass 24:00, e.g. 25:30. They move with the block when blocks swap.
  - An invite preview screen comes before joining. Its fields live on the invite doc, since non-members can't read the trip.
  - The place / stop page keeps `access_tips` (shared) and `private_note` (yours) visibly separate.
  - Reference image thumbnails are cached for offline use.
  - Later: "Save updates to my place" on a stop, and template attribution.
- [ ] Freeze the old model: no new features, bug fixes only. Close #55, #77 and #78 for now and reopen them after the MVP, since the code they touch gets replaced. (ck)
- [ ] Settle before writing code (ck + bullyee):
  - **Firestore layout for the new sync.** Use a new top-level collection, e.g. `tripsV2/{tripId}/…`, so v0.1.x clients still writing to `trips/` can't corrupt new data. Make `trips/` read-only after the cutover.
  - **Fractional index for `sort_key`.** Use a package or write our own.
  - **IDs.** UUIDs everywhere except `place_key`. Labels are matched across people by natural key.

## Stage 1: data layer (ck)

**1a. Contract first**, so the screens can be built in parallel:
- [ ] Drift tables:
  - personal layer: `places`, `labels`, `place_labels`, `photos`, `place_visits`, `reference_images`;
  - shared layer: `trips`, `trip_days`, `stops`, `stop_labels`, `schedule_items`;
  - sync bookkeeping on the shared tables: `updated_at`, `updated_by`, `deleted_at` and a local sync status.
- [ ] Repository interfaces and Riverpod providers for the operations the screens need, for example:
  - list and filter places by label;
  - add a place to a trip (copy it into a stop, including its reference images);
  - create a `trip_only` place;
  - schedule a stop, reorder items, swap blocks, pin a date.
- [ ] Pure logic, with unit tests:
  - day block dates: position, pins, backup blocks, and the rule that pins must increase;
  - the fractional index;
  - schedule times: order, stay, transit, fixed times, past 24:00. Port what applies from `lib/core/utils/schedule_engine.dart`;
  - trip status and the backlog, which are derived rather than stored.

**1b. Migration**
- [ ] v9 → v10, as described in `docs/data-model.md`:
  - rois → region labels;
  - pois → `saved` places (Anitabi ones keep `anitabi:<id>`);
  - animes / tags → labels;
  - reference images and `reference_frame` media → reference images, with the metadata parsed into episode / timestamp;
  - `user_photo` → photos;
  - drop `ticket_qr`, `audio_bgm`, `time_chunks` and the old tables.
- [ ] Migration tests, starting from a v8 and a v9 database.

## Stage 2: screens (bullyee)

**Design first.** These are the "Still to design" items, worked through with Claude:
- [ ] Place page and stop page: which shared and personal fields each shows, and the layout.
- [ ] Day planner on a phone:
  - a zoomed-out mode for reordering blocks;
  - auto-scroll while dragging;
  - how backlog and backup blocks are shown.
- [ ] Home: one trip list with All / Shared / Private tabs and a shared badge (#44), and where the library lives.

**Build**, on the stage 1a repositories:
- [ ] Home screen and routes.
- [ ] Library:
  - places as a list and a map, with label filters (anime / tag / region) and search;
  - `saved` vs `trip_only` places.
  - Replaces `poi_browse_screen`, `pois_by_filter_screen`, `poi_map_screen` and the ROI list / detail screens.
- [ ] Place page: facts, private note, labels, reference images, my photos, visits. Replaces `poi_detail_screen` and `poi_create_screen`.
- [ ] Trip page:
  - the stop list, sortable and searchable;
  - the backlog;
  - adding a stop from the library, or creating a new spot (a `trip_only` place);
  - trip settings (title, start date, day count).
  - Replaces `roi_detail_screen` and `roi_edit_screen`, and drops the "Real-time collaboration is active" text.
- [ ] Day planner: blocks, dragging stops and blocks, pins, backup blocks, times. Replaces `calendar_screen` and the time-chunk widgets.
- [ ] Stop page.
- [ ] Anitabi import: a checkbox list with "select all". Picked spots go into the library, and optionally into a new or existing trip. A rework of `bangumi_search_screen`.
- [ ] Labels: create, rename and merge anime, tag and region labels. Replaces the anime and tag edit screens.
- [ ] Camera and editor:
  - save into `photos`, with `kind`, `derived_from_id`, `reference_image_id` and `trip_id`;
  - the reference picker reads the place's or stop's reference images;
  - touches `background_photo_save`, `media_asset_service`, `media_repository`, `photo_edit_screen` and `anime_camera_launcher`.
- [ ] Cache reference image thumbnails for offline use.
- [ ] Remove the old screens, routes, models and repositories as each is replaced. Remove the v8 sync engine together with the old tables. (both)

**Milestone A:** the whole app runs on the new model on one device. Internal builds only, since sync is off until stage 3.

## Stage 3: sync on the new model (ck)

- [ ] Firestore layout and rules for trips, days, stops, stop labels and schedule items:
  - each document is last-write-wins on `updated_at`;
  - deletes are `deleted_at` tombstones.
- [ ] Sync engine:
  - upload dirty rows;
  - listen for remote changes per trip and apply them;
  - work offline, and never await a Firestore write inside a Drift transaction (#65 round 3, fixed in #79).
- [ ] Labels sync by natural key. A label that's missing locally is created.
- [ ] Turning a private trip into a shared one uploads its stops, days and schedule. Photos are not uploaded.
- [ ] One sync status icon per trip: synced, pending, or offline. (UI: bullyee)
- [ ] Tests:
  - reuse the fake Firestore harness from #65;
  - add rules tests on the Firebase emulator, in CI if feasible. The #65 rule hole showed that untested rules slip through.
- [ ] Make the old `trips/` collection read-only after the cutover.

**Release v0.2.0:** the new model, plus sync across your own devices. Sharing with other people is still not possible, the same as in v0.1.x.

## Stage 4: group sharing

**Backend (ck)**
- [ ] `members` with the roles owner, editor and viewer, enforced in rules. Viewers are read-only. Only owners and editors can invite.
- [ ] Invites:
  - a token plus a short code;
  - the role is chosen when the invite is created;
  - valid for 7 days, usable by any number of people, revocable;
  - an email allowlist;
  - joining is validated in rules, since the free plan has no Cloud Functions.
- [ ] Invite preview data on the invite doc: title, dates, stop count, and the inviter's name and avatar.
- [ ] Leaving, removing a member, transferring ownership.
- [ ] When the owner stops sharing or deletes the trip, every other member keeps a private, unsynced copy.
- [ ] Member profiles: Google display name and avatar, never the email.
- [ ] Guest → signed in: before the first share, claim the local trips by setting the owner and author to the uid.
- [ ] Download page on Firebase Hosting, plus Android App Links (`assetlinks.json`).

**Screens (bullyee)**
- [ ] Share sheet: create an invite with a role; show the link, QR code and short code; revoke.
- [ ] Join flow: open a link, scan a QR code, or enter a code → invite preview → join.
- [ ] Member list: roles, remove, leave, transfer ownership.
- [ ] The shared badge and tabs on home, and a read-only mode for viewers.

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

## Existing issues

| Issue | Where it goes |
|---|---|
| #24 cleanup backlog | #73 (merged) did the items worth doing. Items on old screens become moot after stage 2. Still open: `applicationId` is `com.example.trip_planner`. Change it before any store release, together with the map's `userAgentPackageName`, which sends the same name. |
| #40 `isShared` no-ops | Solved by stage 1 (`trips.sharing`, `photos.is_shared`). |
| #44 "My Trips" opens Regions | Stage 2 home. |
| #45 two-way sync | Closed by #65 and #79; stage 3 replaces it. |
| #55 desktop | #74 added the crash guards. Close for now; Windows packaging and desktop layouts come after the MVP. |
| #72 data model proposal | This plan. |
| #76 sync FK / storage leaks | Closed by #75. |
| #77 offline map tiles | Close for now; reopen after the MVP. It needs a different tile source. The [OpenStreetMap tile policy](https://operations.osmfoundation.org/policies/tiles/) forbids offline use of `tile.openstreetmap.org`, including any "download for offline" feature, and requires a User-Agent that identifies the app. |
| #78 export / backup | Close for now; reopen after the MVP. The export format should follow the new model, and it overlaps with the personal layer backup. |
