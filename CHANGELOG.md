# Changelog

Notable changes to Trip Planner. Builds are published as Android pre-releases on [GitHub Releases](https://github.com/bullyee/trip_planner/releases). Versions follow [Semantic Versioning](https://semver.org); before 1.0, minor versions may change behavior.

## [0.4.0] - 2026-11-25

Planning a trip together now keeps track: see who changed what, bring back what was deleted, and compare a place with Anitabi and your library. Frames you add yourself reach everyone in a shared trip through your own Google Drive, and uploads and downloads run in the background. The app gets a bottom bar with a Photos tab, Settings with a language choice, maps that group and cluster, optional dates and times in the plan, and a route export. And it runs in a browser at [trip-planner-2775c.web.app](https://trip-planner-2775c.web.app), where invite links now open. v0.3.1 was never released; its changes are part of this version.

### Added
- **What changed** ([#177](https://github.com/bullyee/trip_planner/pull/177)). The clock at the top of a shared trip lists who changed what in the last 30 days, newest first ("Mika moved Uji Bridge to Day 3"); tap an entry about a stop to open it. A dot on the trip's card and on the clock means someone else changed the trip since you last looked.
- **Recently deleted** ([#177](https://github.com/bullyee/trip_planner/pull/177)). A trip's **⋮** menu keeps deleted days and stops for 30 days, with who deleted them and when; **Restore** puts one back where it was, with its schedule. A deleted trip waits under **My Trips → Recently deleted** for 30 days; only its owner can restore it, and a shared trip comes back for everyone.
- **Compare a place** ([#178](https://github.com/bullyee/trip_planner/pull/178)). When Anitabi changed a spot since you imported it, or your library has a trip's stop differently, a line on the page says so ("Anitabi moved this spot 120 m SE"). Tap it to see both side by side and pick **Use this** or **Keep mine**, field by field. A joined trip's spots that aren't in your library offer **Save to my library** and **Save all**.
- **The web app is online** at [trip-planner-2775c.web.app](https://trip-planner-2775c.web.app) ([#154](https://github.com/bullyee/trip_planner/pull/154), [#156](https://github.com/bullyee/trip_planner/pull/156), [#179](https://github.com/bullyee/trip_planner/pull/179), [#180](https://github.com/bullyee/trip_planner/pull/180)): the same app in a browser. Invite links open it, so friends can join a trip without installing anything. On an Android browser the join page offers **Open in the app** and **Get the APK**; in LINE's or Instagram's own browser it says to open the link in Chrome or Safari, where Google sign-in works, with **Copy link**. The library and trips are kept in the browser's own storage, and the camera works where the browser has one.
- **Language** ([#185](https://github.com/bullyee/trip_planner/pull/185)): **Settings → Language** picks English, Traditional Chinese or Japanese, or follows the phone (the default). Only part of the app is translated so far; see Known issues.
- **A joined trip says it's still coming down** ([#182](https://github.com/bullyee/trip_planner/pull/182)): "Getting this trip's days and stops…" until they've all arrived, then, on Android, an offer to download the frames others shared on Google Drive. On the web, closing the tab while a trip is still coming down asks first.
- **Share your own frames with the trip** ([#158](https://github.com/bullyee/trip_planner/pull/158), [#162](https://github.com/bullyee/trip_planner/pull/162), [#152](https://github.com/bullyee/trip_planner/issues/152)). On a shared trip, **Members → Sync via my Google Drive** uploads the frames you added yourself to a folder of their own inside "Trip Planner Shared Frames" in your Drive and shares it by link, so everyone else in the trip sees them. Google asks once for access to the files the app creates; it can't see the rest of your Drive. **Anyone with the link can view these files.** Only people who can edit the trip can upload, and private trips never upload.
  - **Frame upload quality** is your choice: **Original** (the default; up to 1920 px, sent as the original file when it already fits), **Smaller** or **Smallest** (1280 px). Measured on 40 real 1920 × 1080 frames: about 283, 195 and 141 KB per frame.
  - **Taking them back:** deleting, unsharing or leaving a trip, or removing a stop or frame, deletes the Drive files nothing else needs; removals made offline wait and are retried. **Members → Remove my frames from Google Drive** does it for one trip, and **Settings → Remove shared frames from my Google Drive** for all of them.
  - A frame whose Drive file was deleted by hand goes back to local-only and is uploaded again by the next **Sync via my Google Drive**.
  - A stop's **⋮** menu can also upload one photo from your gallery, or add a frame from an image link. **Share local frames** and **Import local frames** pass frames as a file instead, with no Google account.
- **Uploads and downloads run in the background** ([#161](https://github.com/bullyee/trip_planner/pull/161)). A notification shows the progress ("Uploading frames to Google Drive · 120 of 405") with **Cancel**, and the upload keeps going with the screen off, in another app, or after you swipe the app away. A slim bar at the bottom of every screen shows it too, and the app stays usable. If an upload stops, the next start offers **Resume** for the frames left.
  - **Download frames for offline** (in Members) fetches every frame of a trip. Frames your friends shared download by themselves on Wi-Fi.
- **A bottom bar on every main screen: Home, Trips, Shoot, Library, Photos** ([#160](https://github.com/bullyee/trip_planner/pull/160)). Each tab keeps where you were. Pages opened from a tab open full screen, and back returns to the tab.
- **The Photos tab** ([#160](https://github.com/bullyee/trip_planner/pull/160)): every photo, newest first, by day (with the trip) or by place. Tap one to see it next to its frame, with **Edit** and **Open the place**. **To edit** is a filter there; Home's "N photos to edit" card opens it.
- **Settings** ([#163](https://github.com/bullyee/trip_planner/pull/163)), from the gear on Home or the account button in My Trips: your account and **Sign out**, the frame upload quality, **Back up to a file** / **Restore from a file** (moved from the Library's ⋮ menu), how much space the app takes with **Clear map tiles** and **Delete** for the cutout model, and About (version, credits, privacy policy, licences).
- **Export a trip's route** ([#171](https://github.com/bullyee/trip_planner/pull/171), [#78](https://github.com/bullyee/trip_planner/issues/78)): the trip's **⋮** menu → **Export route (GPX)** or **(GeoJSON)**, for apps such as OsmAnd, Organic Maps or Google My Maps. Each day is a route in visiting order, with the planned time in the stop's description; backup days and the backlog come along, marked as such. Stops without coordinates are left out.

### Changed
- **Dates and times are optional** ([#189](https://github.com/bullyee/trip_planner/pull/189)). A day without times shows its stops numbered in order instead of made-up times, and a trip without dates shows "Day 1", "Day 2" and how many days it has. A stop's start, stay and travel wait under **Add time (optional)**. An empty day offers **Add stops to this day** without the pencil, adding from the library can put places straight onto a day (**Add to:** Backlog, Day 1, …), and a stop's sheet has **Move up** and **Move down** while editing.
- **On a computer** ([#188](https://github.com/bullyee/trip_planner/pull/188), [#190](https://github.com/bullyee/trip_planner/pull/190)): the plan has a day switcher (**‹ ›**, a button per day, the ← and → keys, and dragging with the mouse), and a place's frames switch with arrows, the dots or the mouse.
- **Joining a trip on the web is faster** ([#188](https://github.com/bullyee/trip_planner/pull/188)): its days, stops and schedule come down in batches instead of one row at a time.
- **The maps** ([#159](https://github.com/bullyee/trip_planner/pull/159)): the day map, the library's, a place's, Home's and the new spot picker now share one map.
  - **A group of stops is one pin** with a badge saying how many; its card steps through them. Pins are numbered in the day's order and turn grey with a check once visited.
  - **Crowded pins merge into a bubble** labelled with their numbers ("1–4") or a count. Tapping it zooms in; stops on the very same spot open as a list.
  - **The library's pins are coloured by anime.** Tapping one shows a small card instead of leaving the map.
  - **Map tiles you've looked at stay on your phone** for two weeks (up to 300 MB), so they show without a connection on the day. Nothing is downloaded ahead.
  - Pins no longer leave a trail behind while the map moves.
- **Home's ⋮ menu is gone** ([#160](https://github.com/bullyee/trip_planner/pull/160)). **Edit a photo from the gallery** is a button on the Photos tab, and **Float a frame over any app** *(Android)* a button at the top of Home. The Library's ⋮ menu moved into Settings ([#163](https://github.com/bullyee/trip_planner/pull/163)).
- **Uploading a trip's frames to Drive is faster** ([#162](https://github.com/bullyee/trip_planner/pull/162)): one request per frame instead of two, three at a time. On the 關西 trip's 405 frames: 403 Drive requests instead of 811, and no frame re-encoded.
- **Wide and landscape screens** ([#172](https://github.com/bullyee/trip_planner/pull/172)): a place's and a stop's page keep the frame at 16:9 and at most 840 px wide, scrolling anywhere in the window. The floating frame starts top-left over the camera and top-right when floating over other apps.
- Reopening the app after swiping it away returns to where you were, instead of starting over ([#161](https://github.com/bullyee/trip_planner/pull/161)).

### Fixed
- **One refused change no longer stops a shared trip from syncing** ([#181](https://github.com/bullyee/trip_planner/pull/181)). "Couldn't sync" kept coming back when the cloud refused one entry; the other changes now go up, and the refused one stays on that phone.
- **Joining from a link while signed out** no longer hangs on "Finding the trip…" after you sign in ([#187](https://github.com/bullyee/trip_planner/pull/187)).
- **A shared trip on a signed-out phone** says to sign in, instead of saying you're already in when you open its invite again and the Members tab failing ([#186](https://github.com/bullyee/trip_planner/pull/186)).
- **A trip opened on its own**, after joining from a link or reloading the web page, has a back arrow ([#183](https://github.com/bullyee/trip_planner/pull/183)).
- **The in-app camera** (iPhone, web) shows a stop's frames over the camera; frames that came with a shared trip showed none ([#190](https://github.com/bullyee/trip_planner/pull/190)).
- **Cancel during a Drive upload** no longer hangs on "Cancelling…": it stops the uploads in flight, and on a slow connection each file gets time in proportion to its size ([#162](https://github.com/bullyee/trip_planner/pull/162)).
- **Signing in** from Settings, the invite sheet or Join keeps the screen you were on, with its back button ([#163](https://github.com/bullyee/trip_planner/pull/163)).
- The "N frames to download" count updates after **Download frames for offline** finishes ([#165](https://github.com/bullyee/trip_planner/issues/165)).
- **Compose** shows "Google ML Kit is downloading the segmentation model…" instead of a stack trace while the model downloads ([#166](https://github.com/bullyee/trip_planner/issues/166)).
- **Shoot without it** (no overlay permission) says what it actually does ([#169](https://github.com/bullyee/trip_planner/issues/169)).
- Home no longer shows the first-time **Plan a pilgrimage** card when all your trips are in the past ([#170](https://github.com/bullyee/trip_planner/issues/170)).
- Settings' space used no longer counts the app's own files as your data ([#164](https://github.com/bullyee/trip_planner/issues/164), [#173](https://github.com/bullyee/trip_planner/pull/173)).

### Known issues
- **Only part of the app is translated.** In Chinese or Japanese, the bottom bar and Settings are translated and most other screens are still in English.
- **The web app keeps its data in the browser.** In a private window nothing stays after the tab closes (it warns when you leave), and Safari may delete a website's data after 7 days without a visit unless it's on the home screen.
- **Deleted days, stops and What changed entries stay in the cloud** after their 30 days. The app hides them, but they aren't purged from Firestore yet, which needs a paid plan.
- The other known issues of v0.3.0 still apply, except the one about your own frames.

### Developer
- Schema 15 ([#177](https://github.com/bullyee/trip_planner/pull/177)): `trip_activities` (What changed, 30 days) and `trip_views` (the unread dot, local only). `TripActivityLog` writes an entry in the same transaction as each change, pushed in the same batch to `tripsV2/{id}/activity` (append-only). Tombstones carry `expireAt`; a device that missed a purged one hides the row once a server snapshot no longer has it (`_markRowsGoneFromServer`).
- Place comparison: field diffs between Anitabi, the library and a stop, ignoring moves under 15 m ([#178](https://github.com/bullyee/trip_planner/pull/178)).
- Sync: a snapshot lands in one transaction and marks a joined trip as arriving (`tripArrivingProvider`) ([#182](https://github.com/bullyee/trip_planner/pull/182)); downstream rows are preloaded and written in batches, and last-write-wins compares milliseconds ([#188](https://github.com/bullyee/trip_planner/pull/188)); a refused activity entry is isolated and retried alone ([#181](https://github.com/bullyee/trip_planner/pull/181)).
- Localization ([#185](https://github.com/bullyee/trip_planner/pull/185)): `flutter_localizations` with `flutter gen-l10n` from `lib/l10n/app_{en,zh_Hant,zh,ja}.arb`; `context.l10n`, `AppLocaleOption` and the remembered choice in `lib/core/l10n/`.
- Hosting serves `build/web` (`flutter build web --wasm --release`), and `public/` is gone: `web/` holds `assetlinks.json`, the privacy policy and the terms ([#179](https://github.com/bullyee/trip_planner/pull/179)).
- `lib/shared/map/` (`AppMap`, `MapPin`, `clusterPins`) and `features/trip/widgets/day_map_pins.dart`; flutter_map 7.0.2 → 8.3.2 with its built-in tile cache set up in `main()` ([#159](https://github.com/bullyee/trip_planner/pull/159)).
- `MainActivity` keeps one cached `FlutterEngine` that outlives the Activity; `TransferService.kt` is a `dataSync` foreground service driven over the `trip_planner/transfers` channel; `frame_transfer_queue.dart` runs the jobs ([#161](https://github.com/bullyee/trip_planner/pull/161)).
- go_router `StatefulShellRoute` with four branches in `AppFrame` ([#160](https://github.com/bullyee/trip_planner/pull/160)); the router lives as long as the app and auth changes only re-run its redirect ([#163](https://github.com/bullyee/trip_planner/pull/163)).
- `GoogleDriveFrameService` (`drive.file`), `DriveFrameCleanup`, `OnlineFrameMatcher`, `TripFramesPackService` and `archive_isolate.dart` ([#158](https://github.com/bullyee/trip_planner/pull/158), [#162](https://github.com/bullyee/trip_planner/pull/162)).
- `lib/core/app_version.dart` holds the version shown in Settings; a test checks it against `pubspec.yaml` ([#163](https://github.com/bullyee/trip_planner/pull/163)).
- Web: drift's `WasmDatabase` (`connection/web.dart`, files resolved against `document.baseURI`), `usePathUrlStrategy()`, `lib/core/utils/platform_media.dart` for `blob:` / `data:` / file paths, `package:web` + `dart:js_interop` only, and conditional exports on `dart.library.js_interop` so `--wasm` builds pick them ([#156](https://github.com/bullyee/trip_planner/pull/156), [#174](https://github.com/bullyee/trip_planner/issues/174)).
- `TripRouteExportService` (GPX 1.1 and GeoJSON) ([#171](https://github.com/bullyee/trip_planner/pull/171)).

## [0.3.0] - 2026-11-12

Pilgrimage mode: the app is now built for the day you're out at the spots. Home follows the date, **Shoot** finds the places around you, and the camera takes several shots against a spot's frames and keeps the ones you pick.

### Upgrading from v0.2.0
- **Your data moves over by itself** the first time you open this version ([#135](https://github.com/bullyee/trip_planner/pull/135)). The photos you already have count as kept as they are, so **Photos to edit** starts empty.

### Added
- **A new home screen** ([#139](https://github.com/bullyee/trip_planner/pull/139), [#140](https://github.com/bullyee/trip_planner/pull/140), [#142](https://github.com/bullyee/trip_planner/pull/142)): a column of cards where only the top one follows the date.
  - **On a day of a trip, it's today:** "Day 2 of 3", how many of the day's stops are visited, a small map of them that opens the day map, and the next stop with its frame, **Take photo** and **Mark done** (with Undo). View-only members don't get Mark done.
  - **On other days, it's the next trip:** when it starts, its stops on a small map, how many days and stops it has, which days aren't planned yet, and **Continue planning**. With no trip, **Plan a pilgrimage**.
  - **Near you** lists up to 3 of your library places within 3 km, each with a camera button. It asks for your location only when you tap it, and offers **Try again** when it can't find where you are.
  - **"3 photos to edit"** shows while there are any.
  - **Shoot** is the big button in the middle of the bottom bar, between **Trips** and **Library**.
- **Shoot here** ([#135](https://github.com/bullyee/trip_planner/pull/135), [#142](https://github.com/bullyee/trip_planner/pull/142)): Shoot finds where you are and offers the frames of the places within about 150 m, nearest first. On a trip day the day's stops come first; the trip's other stops and your library places wait under **Other places nearby**. With one place nearby that has one frame or none, the camera opens for it after 2 seconds unless you tap **Not this place**. It works without a trip, and you can always shoot with another place's frames, a picture from the gallery, or no frame at all.
- **Several shots, then pick** (Android, [#137](https://github.com/bullyee/trip_planner/pull/137), [#142](https://github.com/bullyee/trip_planner/pull/142)): after each shot the camera opens again with the frame where you left it; press back in the camera when you're done. Your shots then show beside the frame: tap the ones to keep, then **Keep N**. They're saved as shot to the place's photos, under the trip, and to the **Trip Planner** album on your phone, and the day's visit is logged; the rest are deleted. **Take more** opens the camera again. If Android closes the app while the camera is open, your shots and picks come back the next time you open it.
  - **The plan is your call.** A shot never marks a stop done. If you can edit the trip, the pick screen offers **Mark Uji Bridge done** (already ticked when every frame of the stop has a shot), or **Add Uji Bridge to Day 2** for a place that isn't on a day. Each stop shows its progress, such as "2 of 5 frames".
- **Switch frames while shooting** ([#143](https://github.com/bullyee/trip_planner/pull/143)): when a spot has several frames, the floating window's bar gets **‹ 3/14 ›** (on iOS, over the camera's controls). Each shot keeps the frame it was taken with, and the pick screen shows each shot beside its own frame. A stop that keeps fewer frames than its place counts only its own.
- **Photos to edit** ([#142](https://github.com/bullyee/trip_planner/pull/142)): the photos you kept as shot and haven't edited yet, by day. Tap one to edit it; **Keep as it is** takes it off the list (with Undo). Hold one to pick several.
- **The day map** ([#136](https://github.com/bullyee/trip_planner/pull/136), [#138](https://github.com/bullyee/trip_planner/pull/138)), from the map button at the top of a trip or Home's small map: a day's stops on a map with your location and the route between them, which ones are visited and how many are left. Switch days along the top. Tap a stop for its frame, how far it is and which way, the photos you took there, **Take photo**, **Mark visited** and the stop's page.
- **Groups of stops** ([#146](https://github.com/bullyee/trip_planner/pull/146)): Anitabi has one spot per scene, so one café can come in as seven stops. On a trip's **Stops** tab, hold to pick several, then:
  - **Group** stops that are close together. The name is suggested from what their names start with. A group opens to its stops, and can be renamed or ungrouped.
  - **Merge** stops that are the same spot. Pick the one to keep; it takes on the others' notes, labels, frames and days.
  - **In the plan**, a group is one block on its day ("11:00–13:00 Café Rose · 3 stops · 1 visited") that opens to its stops, each marked visited on its own. In edit mode it drags as one, to another day or to the backlog, where it's also one entry. **Take out of the group** moves a stop on its own.
- **Remove from the trip** on a stop's sheet in the planner's edit mode ([#144](https://github.com/bullyee/trip_planner/pull/144)), so a stop in the backlog can go without opening its page.
- **A trip description** ([#148](https://github.com/bullyee/trip_planner/pull/148)), up to 500 characters, set when you make the trip or with **Edit trip** (was "Edit name and dates"). It shows in two lines under the trip's name in My Trips.
- **Back up to a file** ([#155](https://github.com/bullyee/trip_planner/pull/155), [#78](https://github.com/bullyee/trip_planner/issues/78)): the Library's **⋮** menu saves everything that isn't in the cloud as one `.pilgrimage` file, then opens the share sheet so you can keep it in Drive or send it to yourself. The file holds your library (places, labels, visits, photos and frames), your private trips in full, and the frames you added yourself to shared trips. Shared trips aren't in it: they come back when you sign in.
  - **Restore from a file** (also on an empty library) adds what this phone is missing and leaves the rest as it is, so an old backup never overwrites newer edits.
  - Both show their progress and can be cancelled, and a big library doesn't freeze the app.

### Changed
- **Home's cards are gone**: Library and My Trips are in the bottom bar, and **Float a frame over any app** and **Edit a photo from the gallery** are in the **⋮** menu ([#139](https://github.com/bullyee/trip_planner/pull/139)).
- **Sign in only when a trip needs it** ([#142](https://github.com/bullyee/trip_planner/pull/142)): Home no longer has Sign in. Sharing, inviting and joining ask for it, and **Sign out** is in My Trips' account menu, shown while you're signed in.
- **On Android, the editor no longer opens after a shot** ([#137](https://github.com/bullyee/trip_planner/pull/137)). Edit later from **Photos to edit**. On iOS each shot still opens the editor.
- **The floating window's bar** ([#137](https://github.com/bullyee/trip_planner/pull/137), [#143](https://github.com/bullyee/trip_planner/pull/143)): tap the frame for opacity − / +, ✕ and the frame switcher; the bar fades out 1.5 seconds after you last touch it. A double-tap shrinks the window to a small dot out of the way; tap the dot to bring it back. A closed window opens again where it was.
- **A trip opens on Plan, next to Stops and Members** ([#148](https://github.com/bullyee/trip_planner/pull/148)). During the trip, Plan opens on today.
- **Merging places in the library leaves your trips alone** ([#145](https://github.com/bullyee/trip_planner/pull/145)). Before, it changed every trip's stops at those places, for everyone in a shared trip. A merged-away place stays hidden behind the trip stops that use it.

### Removed
- **The trip page's Overview tab** ([#148](https://github.com/bullyee/trip_planner/pull/148)). Its dates are in the top bar, its description on the trip's card in My Trips, its days in Plan's grid, and today's card on Home.

### Fixed
- **Rejoining a trip you left syncs again** ([#110](https://github.com/bullyee/trip_planner/pull/110)). If you changed your copy while you were away, your changes are kept as a separate private trip, such as "Kyoto (your copy)".
- **A stop marked visited while offline stays visited** in a shared trip when someone else edits it before you're back online ([#114](https://github.com/bullyee/trip_planner/pull/114)).
- **Undo messages go away by themselves** ([#144](https://github.com/bullyee/trip_planner/pull/144)). One left over the backlog bar no longer stops you dropping more stops there.
- **The floating window on an APK you downloaded** ([#147](https://github.com/bullyee/trip_planner/pull/147)): from Android 13, Android only says "App access denied". The app now explains that you need **Allow restricted settings** in its App info (**⋮** menu) first, with a button to open that page.

### Known issues
- **The maps** can leave ghost pins behind when you move them, are slow to load, and pile many pins into one blob. Their tiles need a connection; the day's stops and the camera work offline.
- **Nothing backs up by itself.** Shared trips are in the cloud; your library, private trips and photos are only on your phone until you use **Back up to a file**.
- **Photos you take stay on your phone.** Others in a shared trip don't see them.
- **Frames you add yourself don't reach the others in a shared trip** ([#152](https://github.com/bullyee/trip_planner/issues/152)). Only Anitabi's frames do. A backup file carries them to your next phone.
- **Merging stops has no Undo yet.**
- **Links in some in-app browsers** (LINE, Discord) may not open the app. Copy the 6-letter code from the page and enter it under **Join a trip**.
- **Searching an anime in Traditional Chinese or English finds little.** The search uses Bangumi, which knows Japanese and Simplified Chinese titles; search with one of those.
- **Spot names are as Anitabi's contributors wrote them**, often in Japanese or Simplified Chinese. Rename a place if you like.

### Developer
- Database schema v14 ([#135](https://github.com/bullyee/trip_planner/pull/135)): `places.chinese_name`, filled from Anitabi's data on import but not shown yet, and `photos.keep_as_is`, set for every photo that was already there.
- `PilgrimageShootingService` ([#135](https://github.com/bullyee/trip_planner/pull/135), [#136](https://github.com/bullyee/trip_planner/pull/136)): nearby places, today's trip, `recordShot` (the photo, its trip and one visit per place per day, marking nothing done), Photos to edit, the day's feed with compass bearings, and a check-in without a photo (no screen uses it yet).
- `LibraryBackupService` ([#135](https://github.com/bullyee/trip_planner/pull/135), [#155](https://github.com/bullyee/trip_planner/pull/155)) exports and imports a `.pilgrimage` zip, one file at a time in a background isolate. Import checks the manifest and only adds rows the phone doesn't have.
- `TripRepository` can restore deleted stops, days and trips with their schedule items ([#103](https://github.com/bullyee/trip_planner/pull/103)). No screen uses it yet, and there's no TTL or purge.
- `firestore.rules` and `storage.rules` drop the unused `users/{userId}` paths ([#135](https://github.com/bullyee/trip_planner/pull/135)); only trips go to the cloud.
- `tool/verify.ps1` runs the unit tests with compact output, and the rules tests with `-WithEmulator` or `-RulesOnly` ([#119](https://github.com/bullyee/trip_planner/pull/119)).
- The web build compiles: the Compose cutout's ONNX Runtime is behind a platform import ([#154](https://github.com/bullyee/trip_planner/pull/154)).
- `release.yml` restores the keystore where AGP looks for it (`ANDROID_USER_HOME`) and checks its certificate before building, so CI signs with the release key ([#112](https://github.com/bullyee/trip_planner/pull/112)).

## [0.2.0] - 2026-11-06

A new app on a new data model ([#72](https://github.com/bullyee/trip_planner/issues/72)): a library of places you keep, trips planned day by day, and trips you can now share with friends. Every screen is new.

### Upgrading from v0.1.x
Your data moves over the first time you open this version ([#81](https://github.com/bullyee/trip_planner/pull/81), [#95](https://github.com/bullyee/trip_planner/issues/95)):
- **Places (POIs) become library places**, with their notes, reference images, photos and visits. Deleted places are left out.
- **Regions, anime and tags become labels** on those places. Two with the same name become one.
- **Not carried over:** the Trip Calendar's schedule, and regions as trips. Make a trip in **My Trips** and add your places to it.
- **Cloud sync of v0.1.x regions stops.** Their copies in the cloud can still be read, but nothing writes to them any more; shared trips use a new place in the cloud.

### Added
- **Library** ([#88](https://github.com/bullyee/trip_planner/pull/88)), first on the home screen: your saved places as a list or on a map, with search and filters by anime, tag and region.
  - Hold a place to pick several, then label them, add them to a trip, merge them or remove them.
  - Adding a place warns when it looks like one you saved already, and offers to use that one.
  - Find a spot on the map by name (OpenStreetMap), by pasting a Google Maps link, or by typing coordinates.
  - **Labels** has its own screen to create, rename, merge and delete anime, tag and region labels.
- **Place pages** ([#88](https://github.com/bullyee/trip_planner/pull/88), [#94](https://github.com/bullyee/trip_planner/pull/94)) lead with the anime frames, with **Take photo**, **Float frame** and **Directions**. Below: labels, your visits, the spot's facts, the trips it's in, **My note** and **My photos** (grouped by trip). The pencil turns the page into a form.
- **Import from Anitabi** ([#88](https://github.com/bullyee/trip_planner/pull/88)): search an anime, see each spot with its frame, tick the ones you want, and save them to your library, and to a trip if you like. The frames download after you save; if the app closes before they finish, importing the same anime again fetches the ones it missed ([#109](https://github.com/bullyee/trip_planner/pull/109)).
- **My Trips** ([#87](https://github.com/bullyee/trip_planner/pull/87), [#92](https://github.com/bullyee/trip_planner/pull/92)): trips under Ongoing, Coming up, No dates yet and Finished, filtered by All, Shared or Private. A trip opens in four tabs: Overview, Plan, Stops and Members.
- **The day planner** ([#87](https://github.com/bullyee/trip_planner/pull/87), [#88](https://github.com/bullyee/trip_planner/pull/88), [#94](https://github.com/bullyee/trip_planner/pull/94)): one day at a time, or every day in a grid. In edit mode:
  - drag stops within a day or to another one, or back to the backlog;
  - swap days, add and remove them, and keep backup days for rain;
  - pin a day to a date;
  - set a stop's start time, its stay and the travel to the next stop. Times past midnight read 25:30 and so on;
  - name a day, such as "Uji" or "Rainy day".
- **Stop pages** ([#94](https://github.com/bullyee/trip_planner/pull/94)): a stop's plan, a **trip note** everyone in the trip sees, and the trip's own copy of the facts. Your own note, visits and photos come from your library place. **Mark visited** marks it for the trip and adds a visit to your history.
- **Share a trip** ([#83](https://github.com/bullyee/trip_planner/pull/83), [#100](https://github.com/bullyee/trip_planner/pull/100)), signed in with Google:
  - **Invite** from a trip's person-plus button or Members tab, as **Edit** or **View only**. You get a link, a QR code and a 6-letter code, valid for 7 days.
  - **Join** by opening the link, scanning the code with your phone's camera, or entering it under **Join a trip** in My Trips. You see the trip and who invited you before you join.
  - **The Members tab** shows who's in the trip. The owner can make someone view only, make them the owner, remove them, stop an invite, or stop sharing.
  - **Everyone's changes sync** both ways: days, stops, times, trip notes and facts. Your library, your notes and your photos stay on your phone.
  - **Leave trip** for members who aren't the owner ([#107](https://github.com/bullyee/trip_planner/pull/107)). Whoever leaves, is removed, or sees the owner stop sharing keeps their own copy of the trip, which just stops syncing. Only the owner can delete a shared trip.
  - **View only** members see the trip but can't change it; their own note and photos still work ([#107](https://github.com/bullyee/trip_planner/pull/107)).
  - **Shared trip cards** show the others' avatars and "You and Aki" or "You and 3 others" ([#107](https://github.com/bullyee/trip_planner/pull/107)).
  - **A small cloud** next to a shared trip's name means it isn't in sync yet, you're offline, or a change was refused ([#101](https://github.com/bullyee/trip_planner/pull/101)). Tap it to see which.
- **Photos are filed by trip** ([#91](https://github.com/bullyee/trip_planner/pull/91)): the camera and the editor save to a library place, and a photo goes under the trip you were on that day.
- **On desktop, sign-in can be cancelled** and gives up after 5 minutes ([#99](https://github.com/bullyee/trip_planner/pull/99)), instead of waiting forever after the browser is closed.
- **A web page for invites** at `trip-planner-2775c.web.app` ([#83](https://github.com/bullyee/trip_planner/pull/83), [#98](https://github.com/bullyee/trip_planner/pull/98)): it previews the trip, opens the app, and links to the download. The site also has the privacy policy and terms of service.

### Changed
- **The home screen** leads with Library and My Trips. The Anime Camera, Floating Reference and Edit Photo stay.
- **The camera and the editor pick from your library** ([#91](https://github.com/bullyee/trip_planner/pull/91)): a place, then one of its frames. Places on today's trip come first.
- **New colors**: tea green, with wisteria for people and vermilion for pins ([#87](https://github.com/bullyee/trip_planner/pull/87)).

### Removed
- View POIs, the POI map, regions and the Trip Calendar ([#96](https://github.com/bullyee/trip_planner/pull/96), [#97](https://github.com/bullyee/trip_planner/pull/97)). The Library, My Trips and the day planner replace them.
- The v0.1.x cloud sync of regions ([#97](https://github.com/bullyee/trip_planner/pull/97)).

### Fixed
- **A file name with `%` in it no longer breaks the photo editor** ([#84](https://github.com/bullyee/trip_planner/issues/84)).
- **Leaving the Compose cutout mid-cutout no longer releases its model while it's still in use** ([#84](https://github.com/bullyee/trip_planner/issues/84)).

### Known issues
- **Rejoining a trip you left doesn't sync yet.** Joining again works, but your old copy stays private and the trip's changes don't reach it.
- **Links in some in-app browsers** (LINE, Discord) may not open the app. Copy the 6-letter code from the page and enter it under **Join a trip**.
- **Searching an anime in Traditional Chinese or English finds little.** The search uses Bangumi, which knows Japanese and Simplified Chinese titles; search with one of those.
- **Spot names are as Anitabi's contributors wrote them**, often in Japanese or Simplified Chinese. Rename a place if you like.
- **Your library lives only on your phone.** Shared trips are in the cloud, but your places, notes and photos aren't backed up anywhere.

### Developer
- Database schema v13 ([#81](https://github.com/bullyee/trip_planner/pull/81), [#93](https://github.com/bullyee/trip_planner/pull/93), [#97](https://github.com/bullyee/trip_planner/pull/97)): `places`, `labels`, `place_labels`, `photos`, `place_visits`, `v10_reference_images`, `trips`, `trip_days`, `stops`, `stop_labels` and `schedule_items`. The v9 tables are dropped after their data is copied.
- Sync v2 ([#82](https://github.com/bullyee/trip_planner/pull/82), [#93](https://github.com/bullyee/trip_planner/pull/93), [#102](https://github.com/bullyee/trip_planner/pull/102), [#106](https://github.com/bullyee/trip_planner/pull/106)): `tripsV2/{tripId}` with `days`, `stops`, `schedule_items`, `members` and `invites`, last-write-wins on `updated_at`, with `deleted_at` tombstones. The rules enforce the owner, editor and viewer roles, refuse anonymous sign-ins, cap invite fields, and require a document's `id` to match its path. `trips/` is read-only.
- `test/rules_v2_emulator_test.py` runs the rules on the Firestore emulator in CI ([#93](https://github.com/bullyee/trip_planner/pull/93)), and multi-user sync tests run two engines on one fake cloud ([#105](https://github.com/bullyee/trip_planner/pull/105)).
- Firebase Hosting serves `public/`: the invite page, `assetlinks.json` for Android App Links on `/join`, the privacy policy and the terms ([#83](https://github.com/bullyee/trip_planner/pull/83), [#98](https://github.com/bullyee/trip_planner/pull/98)).
- `release.yml`'s signer check reads apksigner's output with a looser pattern ([#97](https://github.com/bullyee/trip_planner/pull/97)).

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

[0.4.0]: https://github.com/bullyee/trip_planner/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/bullyee/trip_planner/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/bullyee/trip_planner/compare/v0.1.3...v0.2.0
[0.1.3]: https://github.com/bullyee/trip_planner/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/bullyee/trip_planner/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/bullyee/trip_planner/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/bullyee/trip_planner/releases/tag/v0.1.0
