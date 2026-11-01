# Changelog

Notable changes to Trip Planner. Builds are published as Android pre-releases on [GitHub Releases](https://github.com/bullyee/trip_planner/releases). Versions follow [Semantic Versioning](https://semver.org); before 1.0, minor versions may change behavior.

## [0.1.3] - 2026-11-01

The last release on the current data model. The next one, v0.2.0, moves places, trips and schedules to a new model ([#72](https://github.com/bullyee/trip_planner/issues/72)); until then this version only gets bug fixes.

### Added
- **On Android, the Anime Camera opens your phone's own camera app** ([#69](https://github.com/bullyee/trip_planner/pull/69)), so you keep its HDR, night mode and white balance. The anime screenshot floats over it in a small window: drag it to move it, pinch to resize it, tap it for opacity and close, or double-tap to close it. The camera's own controls work everywhere else on the screen. The first time, Android asks you to let Trip Planner display over other apps; without that you can still shoot, and the screenshot still goes to the editor. iOS keeps the in-app camera.
- **Floating Reference** (Android, on the home screen and a place's page) floats a screenshot over every app until you close it, so you can shoot with any camera app.
- **Edit Photo** on the home screen opens a photo from your gallery in the editor.
- **Photo editor tools** ([#68](https://github.com/bullyee/trip_planner/pull/68)) in a strip along the bottom: Reference, Match Color, Brightness, Sharpness, Rotate, Crop and Compose.
  - **Reference:** add or swap the screenshot, from this place, any other place, or your gallery.
  - **Rotate:** 90° turns, left–right and top–bottom flips, and straightening from −45° to 45° over a grid.
  - **Crop:** Free, Match ref (the screenshot's shape), Original, 1:1, 4:3, 3:4, 16:9 and 9:16. The screenshot floats inside the crop box with its own opacity slider.
- **Choose the place a photo belongs to** with the button at the top of the editor, or create a new place from there. A photo taken without a place opens straight in the editor instead of asking for one first.
- **Cloud sync now works both ways** ([#45](https://github.com/bullyee/trip_planner/issues/45), [#65](https://github.com/bullyee/trip_planner/pull/65)). A region with **Cloud Collaborative Workspace** turned on now also downloads changes, so it stays the same on every device where you sign in with the same Google account. New, edited and deleted places and schedule changes sync about two seconds after you make them, whenever you're online. Before, sync only uploaded. It is still experimental.
- **Overlapping visits show a "Conflict: N min" marker** in the Trip Calendar ([#51](https://github.com/bullyee/trip_planner/issues/51)).

### Changed
- **Saving an edited photo is much faster and happens in the background** ([#67](https://github.com/bullyee/trip_planner/pull/67), [#68](https://github.com/bullyee/trip_planner/pull/68)). All edits are applied in one pass instead of one after another. The editor closes as soon as you save, and the place's page shows "Saving N photos…" until they're done.
- **New photos are also saved to a "Trip Planner" album** on your phone ([#68](https://github.com/bullyee/trip_planner/pull/68)), and a fresh capture keeps its untouched original there too. On desktop, photos go to the Pictures folder ([#74](https://github.com/bullyee/trip_planner/pull/74)).
- **Deleting a place, photo or reference image also deletes its files** from the device, freeing the space ([#76](https://github.com/bullyee/trip_planner/issues/76)).
- **Thumbnails keep the photo's shape** instead of being squashed ([#76](https://github.com/bullyee/trip_planner/issues/76)).
- **Bangumi search leaves out adult titles** ([#24](https://github.com/bullyee/trip_planner/issues/24)).
- **On desktop** ([#55](https://github.com/bullyee/trip_planner/issues/55), [#74](https://github.com/bullyee/trip_planner/pull/74)), the camera and the Compose cutout say they need a phone instead of crashing, a build without Google Sign-In set up says so when you sign in, and the home and sign-in screens no longer stretch across wide windows.

### Fixed
- **Deleting a place no longer fails with a database error** when it has imported reference images, photos or visits ([#61](https://github.com/bullyee/trip_planner/issues/61)).
- **Adding places to a region in bulk no longer erases their cover images and order** ([#61](https://github.com/bullyee/trip_planner/issues/61)).
- **Visits keep their duration, transit time and fixed time** when you change their status ([#61](https://github.com/bullyee/trip_planner/issues/61)) or edit them ([#50](https://github.com/bullyee/trip_planner/issues/50)). Removing a visit, or sending it back to the backlog, re-flows the rest of the day.
- **Later visits no longer jump backwards** when a fixed-time visit starts before the previous visit ends ([#51](https://github.com/bullyee/trip_planner/issues/51)).
- **The calendar numbers next month's days correctly** ([#20](https://github.com/bullyee/trip_planner/issues/20)).
- **The map shows new, imported and deleted places right away** ([#62](https://github.com/bullyee/trip_planner/issues/62)), and its pins are colored by region again instead of all blue; places without a region are gray ([#24](https://github.com/bullyee/trip_planner/issues/24)).
- **The Sign In button is visible in the light theme** ([#62](https://github.com/bullyee/trip_planner/issues/62)).
- **Crashes fixed** ([#62](https://github.com/bullyee/trip_planner/issues/62)): opening the duration dialog of a visit longer than 5 hours, adding to the backlog after the last-used region was deleted, and renaming a photo whose file is missing. A visit marked scheduled without a date, which then showed up nowhere, can no longer be created.
- **The in-app camera (iOS) no longer crashes** when the app goes to the background and back ([#16](https://github.com/bullyee/trip_planner/issues/16)).
- **Saving an edit never overwrites the photo it started from** ([#17](https://github.com/bullyee/trip_planner/issues/17)).
- **A place's page shows a message when the place is deleted** while it's open, instead of an error ([#23](https://github.com/bullyee/trip_planner/issues/23)).
- **The map's add-place button and the regions' offline icons are back** ([#47](https://github.com/bullyee/trip_planner/issues/47)).
- **The app starts even if Firebase fails to initialize** ([#18](https://github.com/bullyee/trip_planner/issues/18)).

### Known issues
- **Cloud sync only syncs between your own devices.** There is no way yet to share a region with other people, although the switch is called "Cloud Collaborative Workspace". Photos and reference images aren't synced, and cloud sync can't be turned off for a region once it's on.
- **The map's + button covers its my-location button** in the bottom-right corner.

### Developer
- GitHub Actions ([#70](https://github.com/bullyee/trip_planner/pull/70)): `ci.yml` runs `flutter test` on every pull request and on `master`. `release.yml` builds and checks the APK for a `vX.Y.Z` tag, signs it with the release key, and attaches it to a draft pre-release.
- Database schema v9: `pois` gains `sync_status`, `is_deleted`, `has_ever_synced` and `last_modified_at` ([#65](https://github.com/bullyee/trip_planner/pull/65)).
- Firestore rules: a trip member can only remove themselves from `members` ([#79](https://github.com/bullyee/trip_planner/pull/79)).
- The Anitabi import writes through `PoiRepository` and `MediaRepository` instead of the database ([#38](https://github.com/bullyee/trip_planner/issues/38)).
- Audit cleanups ([#24](https://github.com/bullyee/trip_planner/issues/24), [#33](https://github.com/bullyee/trip_planner/issues/33)): shared row-to-model mappers, sync fields on `RoiModel`, and dead sync code removed.
- `docs/anime-camera-decision.md` records why Android uses the phone's camera app.
- `TODO.md` and the brainstorm map are no longer tracked ([#71](https://github.com/bullyee/trip_planner/pull/71)).

## [0.1.2] - 2026-10-29

### Fixed
- **Import from Bangumi works again** ([#57](https://github.com/bullyee/trip_planner/issues/57)). Two things had broken it:
  - The app requested paths outside Anitabi's documented open API (a connection "pre-warm" of `/` and a title lookup at `/bangumi/{id}`). Anitabi's Cloudflare front blocks any network that does that for a while, so every import then failed with "Couldn't reach Anitabi".
  - Anitabi's open API stopped returning spot coordinates and lists only part of each anime's spots, so even an unblocked import produced nothing.

  Imports now read Anitabi's static map data — the same files its website and iOS app draw the map from — which has every spot with coordinates (214 spots for K-On!, where the open API returned 51 without coordinates). The open API is no longer used.

### Changed
- The map index (~2 MB) is downloaded at most once a day and kept on the device; spot details are re-downloaded only when Anitabi publishes new data. If one Anitabi host is down, the app tries its mirrors.
- Cover images that Anitabi's image host refuses are fetched from its mirror.
- When Anitabi refuses requests (HTTP 403/429), the import stops at once and says the block is temporary, instead of retrying and blaming your connection.
- Imported places are named in their original language (usually Japanese, as on the signs on site); the Chinese translation is used only when there is no original name. Places imported earlier keep their names.
- Spots that Anitabi lists without map coordinates are skipped and counted in the import message. If no spot has coordinates, nothing is imported and the app says so, instead of reporting "Imported 0 POIs" and opening an empty list.
- The Compose cutout downloads its AI model (~176 MB) the first time you tap **Download AI model**, instead of expecting it inside the app package ([#56](https://github.com/bullyee/trip_planner/pull/56)). The APK size is unchanged (~93 MB).
- The app's version number now matches the release (0.1.2, build 3). Earlier builds all reported 1.0.0.

### Known issues
- The static map data isn't part of Anitabi's documented API. Its address already changed once (Aug 2026); if it moves again, importing fails until an app update follows it.
- If your network was blocked by an older build, cover images may be missing until Anitabi lifts the block and its mirror also refuses; switching networks (Wi-Fi ↔ mobile data) works around it.

### Developer
- Claude Code project skills: `.claude/skills/run-app` (run and drive the app on the Android emulator) and `.claude/skills/release` (this release process).
- `THIRD_PARTY_NOTICES.md` credits MiriaGo (MIT), whose handling of Anitabi's map data the import follows, and the Anitabi data license.

## [0.1.1] - 2026-06-11

### Added
- **Trip Calendar scheduling**: drag POIs into a day with auto-cascading start/end times, per-stop duration, travel time between stops, fixed-time locking, and "free time" gaps; drag to reorder stops.
- **Cloud sync (experimental)**: back up and share a trip across devices via Firestore (sign-in required).
- **Batch region assignment**: add many POIs to a region at once.

### Removed
- The placeholder Tickets organizer and manual JSON export/import (superseded by cloud sync).

### Changed
- The README is now an end-user guide.

### Known issues
- Cloud sync only uploads/backs up so far; two-way pull is still in progress.
- The Anime Camera background cutout runs on arm64 devices only.

## [0.1.0] - 2026-06-06

First Android demo build.

### Added
- Regions (ROI) and places (POI), calendar scheduling, organization by anime and tag.
- Import spots from Anitabi via Bangumi search.
- Anime cutout (ISNet ONNX / ML Kit) and a photo editor for recreating anime shots.
- Google sign-in and JSON cloud backup.

### Changed
- Clean-architecture pass: UI decoupled from the database behind repositories, Riverpod code generation, unified save-error handling.

### Fixed
- Editing no longer wipes `createdAt` or the offline-cache flag; saving a new anime or tag navigates back; the app boots even if Firebase init fails; the database closes on dispose.

### Known issues
- Photo re-edit overwrites the source (#17), camera crash on background/resume (#16), wrong trailing days in the calendar (#20), leaked dialog controllers (#19).

[0.1.3]: https://github.com/bullyee/trip_planner/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/bullyee/trip_planner/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/bullyee/trip_planner/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/bullyee/trip_planner/releases/tag/v0.1.0
