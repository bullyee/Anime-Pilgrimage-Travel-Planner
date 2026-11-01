# Anime Pilgrimage Travel Planner

**Plan the trip, then stand where your favorite scene happened.**

Anime Pilgrimage Travel Planner helps you organize *seichi junrei* — real-world visits to the places that inspired the scenes in your favorite anime. Collect locations, group them into trips, build a day-by-day schedule, and when you arrive, line your camera up with the original screenshot to recreate the shot frame-for-frame.

Everything lives on your phone. **No account is required and you can use it fully offline** — handy when you're standing on a rural train platform with one bar of signal.

---

## How it works

1. **Collect places.** Add the locations you want to visit — by hand, or by importing a whole anime's pilgrimage spots in one tap.
2. **Organize them.** Group places into trips by region, and tag them by anime so you can find everything at a glance.
3. **Plan your days.** Drop places onto a calendar, set how long you'll stay, and reorder your route until it flows.
4. **Recreate the scene.** At each spot, float the anime screenshot over your camera, match the framing, and capture your own version.

---

## What you can do

- 📍 **Save anime locations** with address, map coordinates, business hours, notes, and the anime they're from.
- 🗂️ **Organize by region, anime, and tag** so a sprawling trip stays manageable.
- ⬇️ **Import locations automatically** by searching an anime in the built-in Bangumi search — the spots come pre-filled with coordinates from the community-run [Anitabi](https://www.anitabi.cn) pilgrimage map.
- 🗺️ **See everything on a map**, color-coded by region.
- 🗓️ **Build a day-by-day itinerary** with drag-and-drop scheduling, visit durations, travel time between stops, and progress tracking.
- 📸 **Recreate scenes with the Anime Camera**, floating the original screenshot over your camera so you can match the angle exactly. On Android it opens your phone's own camera app, so you keep its HDR and night mode.
- 🎨 **Touch up your shots** in the photo editor: match the colors to the screenshot, adjust brightness and sharpness, rotate, straighten and crop, or paste a character from the screenshot into your photo.
- ☁️ **Keep a trip in step across your devices** with optional cloud sync *(experimental)*.

---

## Getting around

When you open the app you land on the **home screen**, your hub for everything. Tap a card to go to that feature:

| Card | What it's for |
|------|---------------|
| **View POIs** | Browse and manage all your places, regions, anime, and tags |
| **Map** | See your places plotted on a map |
| **My Trips** | Your regions — each one is a trip area like "Kyoto" or "Hakone" |
| **Trip Calendar** | Schedule visits and plan each day |
| **Anime Camera** | Recreate scenes with a screenshot overlay *(Android and iOS)* |
| **Floating Reference** | Float a screenshot over any app and shoot with any camera *(Android)* |
| **Edit Photo** | Open a photo from your gallery in the photo editor |

> **A quick word on names:** every place you save is called a **POI** (point of interest), and a **Region** is a trip area that groups POIs together. The **My Trips** card opens your list of Regions.

---

# User Manual

## 1. Add a place

A "place" (POI) is any location you want to visit.

1. From the home screen, tap **View POIs**.
2. Tap the **+** button and choose **New POI**.
3. Fill in the details:
   - **Name** *(required)* — e.g. *Toyosato Elementary School*
   - **Region** — the trip this place belongs to (optional; you can assign it later)
   - **Anime Series** — link one or more anime this location appears in
   - **Description, Address, Business Hours, Contact Info** — all optional
   - **Latitude / Longitude** *(required)* — the map coordinates, as decimal numbers
   - **Tags** — your own labels, like *rain-safe* or *must-eat*
4. Tap **Create Location**.

> 💡 You don't have to type coordinates by hand. The fastest way to add places is to **import them from Bangumi** (see below) — they arrive with coordinates already filled in.

To **edit or delete** a place later, open it and use the menu (**⋮**) in the top-right corner.

## 2. Organize your trip

Open **View POIs** and use the tabs along the top — **Region · Anime · Tag · All** — to slice your places however you like. Tap any item to see the places inside it; long-press to edit it.

**Create new groupings** from the **+** button:

- **New Region** — a trip area (e.g. "Kamakura"). Give it a name and an optional description.
- **New Anime** — an anime series you can link places to.
- **New Tag** — a custom label.

**Add many places to a region at once:** open a region, tap **Add Places**, tick the places you want from the list of unassigned ones, and confirm.

## 3. Import locations from Bangumi

Skip the manual entry and pull in a whole anime's pilgrimage spots:

1. In **View POIs**, tap **+** → **Import from Bangumi**.
2. Type an anime's name in the search box.
3. Tap the series you want, then confirm **Import**.
4. The anime and its real-world locations are added to your library, ready to be sorted into a region.

> 🌐 Importing needs an internet connection. The locations come from [Anitabi](https://www.anitabi.cn), a community-maintained pilgrimage map shared under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/); each imported place keeps its source and link in its description. The first import of the day downloads Anitabi's map index (about 2 MB); later imports reuse it.

**If the import message mentions a problem:**

- *"Skipped N without map coordinates"* — Anitabi lists some spots without coordinates, and a place needs coordinates to be saved. Everything else was imported.
- *"…none have map coordinates, so nothing was imported"* — Anitabi has no usable coordinates for that anime yet.
- *"Anitabi is temporarily refusing requests from this network"* — Anitabi's servers have paused requests from your network. Wait a while before trying again (repeated tries keep the pause going), or switch between Wi-Fi and mobile data.
- *"Couldn't reach Anitabi"* — check your connection and tap **Import** again.

## 4. See your places on the map

Tap **Map** from the home screen to see every place as a pin, color-coded by region. Use the filter at the top to focus on a single region, and tap any pin to preview that place and jump to its full details.

## 5. Plan your days (Trip Calendar)

The **Trip Calendar** turns your list of places into an hour-by-hour plan.

- **Pick a day** using the week strip across the top, the arrows to jump a week, or the date picker. Tap **Today** to snap back.
- **The Backlog** (lower section) holds visits you've added but not yet scheduled. Tap **+** there to add places to the backlog, then **drag** a backlog item up into the day to schedule it.
- **Set the details** on each scheduled visit:
  - **Duration** — how long you'll stay
  - **Transit** — travel time to your next stop (the schedule shifts to account for it)
  - **Status** — mark visits **Scheduled**, **Completed**, or **Skipped** as your day unfolds
- **Reorder your route** by dragging visits up and down — the times re-flow automatically so your day stays consistent.
- **Overlaps are flagged:** when a visit with a fixed time starts before you can get there from the previous one, a **Conflict: N min** marker shows between them.

> You can also schedule a place directly from its detail screen: open a POI, find the **Schedule** section, and tap **+** to add it to the backlog or pin it to a specific date and time.

## 6. Recreate the scene (Anime Camera)

This is the heart of the app. *Available on Android and iOS.*

**First, give the place a reference image:**

1. Open the place (POI) you're visiting.
2. In the **Reference Images** section, tap **Add** and pick the anime screenshot you want to match.

**Then line up your shot:**

1. Open **Anime Camera** from the home screen, or tap **Take photo** on the place's page.
2. Choose the screenshot to match: one of this place's reference images, another place's, one from your gallery, or none.
3. Line it up:
   - **On Android**, your phone's own camera app opens, with the screenshot floating in a small window. **Drag** the window to move it and **pinch** to resize it. **Tap** it for opacity **−** / **+** and **✕**, or **double-tap** to close it. The camera's shutter, focus and zoom work everywhere else on the screen.

     The first time, Android asks you to allow Trip Planner to **display over other apps**. If you'd rather not, you can still shoot without the window.
   - **On iOS**, the screenshot floats over the in-app camera. Drag it, pinch to resize it, use the **opacity slider**, and switch **flash**, the **native or fill** framing, **zoom** or the **front camera** as needed.
4. Take the shot. It opens in the photo editor with the screenshot attached.

> 💡 **Floating Reference** *(Android)*, on the home screen or a place's page, floats a screenshot over every app until you close it, so you can take as many shots as you like with any camera app.

## 7. Edit your photos

The editor opens after every shot. To edit a photo you already have, tap **Edit Photo** on the home screen and pick it from your gallery.

- **Tools** run along the bottom; swipe the strip to see them all:
  - **Reference** — add or swap the screenshot you're matching.
  - **Match Color** — shift your photo's colors toward the screenshot's.
  - **Brightness** and **Sharpness**.
  - **Rotate** — turn 90°, flip, or straighten up to 45° either way over a grid.
  - **Crop** — free, the screenshot's shape (**Match ref**), the original shape, or 1:1, 4:3, 3:4, 16:9 and 9:16. The screenshot floats inside the crop box with its own opacity slider.
  - **Compose** — cut a character out of the screenshot and paste it into your photo. It downloads its AI model (~176 MB) the first time you tap **Download AI model**.
- **The place button** at the top shows which place the photo is saved to. Tap it to choose another place or create a new one; **No POI** saves the photo only to your phone's gallery.
- **Save** closes the editor right away and finishes in the background; the place's page shows *Saving N photos…* until it's done. Photos are kept with the place and in a **Trip Planner** album on your phone. Your edits never overwrite the original.

## 8. Sign in & cloud sync *(experimental)*

- **Sign In** (top-right of the home screen) signs you in with Google. It's **completely optional** — every feature above works without it.
- Signed in, you can keep a region **backed up and in step across your devices**:
  1. Open the region from **My Trips**, choose **Edit** from the **⋮** menu, turn on **Cloud Collaborative Workspace**, and save. *Once on, it can't be turned off for that region.*
  2. The region's places and schedule upload. Sign in with the same Google account on another device and the region appears there too.
  3. From then on, changes on either device — new, edited or deleted places, and schedule changes — sync both ways about two seconds after you make them, whenever you're online. **Sync to Cloud now** on the same screen sends them right away.
- **What doesn't sync:** photos and reference images stay on the device you added them on, and regions without cloud sync stay only on this device.
- **Sharing with other people isn't available yet.** Despite the switch's name, it only syncs between your own devices.

---

## Good to know

- **It's yours and it's offline.** Your trips, photos, and notes are stored on your device. No account, no connection needed.
- **A few things go online:** importing from Bangumi, signing in and cloud sync, and the photo editor's **Compose** cutout, which downloads its AI model (~176 MB) the first time you tap **Download AI model** — use Wi-Fi for that one.
- **Mostly one copy.** Only regions with cloud sync are kept anywhere else, and photos never are. Everything else lives only on this device — keep that in mind before switching phones or clearing app data.
- **Where features work:**

  | Feature | Android | iOS | Desktop |
  |---------|:-------:|:---:|:-------:|
  | Plan, organize, map, schedule | ✅ | ✅ | ✅ |
  | Anime Camera (screenshot overlay) | ✅ | ✅ | — |
  | Floating Reference | ✅ | — | — |
  | Photo editor | ✅ | ✅ | ✅ (no Compose) |

  On Android, the camera asks once for permission to display over other apps, which the floating screenshot needs.

---

<details>
<summary><b>For developers</b> — building from source</summary>

This is a [Flutter](https://flutter.dev) app using Drift (SQLite) for local storage, Riverpod for state management, and GoRouter for navigation.

```bash
# Install dependencies
flutter pub get

# Generate the database & provider code
dart run build_runner build --delete-conflicting-outputs

# Run on a connected device (Android / iOS)
flutter run

# Run on Windows Desktop
flutter run -d windows --dart-define-from-file=env.json

# Run the unit tests
flutter test
```

Source is organized feature-first under `lib/features/` (`anime`, `auth`, `calendar`, `camera`, `home`, `poi`, `roi`, `sync`, `tag`), with shared infrastructure under `lib/core/` (`database`, `router`, `providers`). See `CLAUDE.md` for the full architecture and conventions, and `CHANGELOG.md` for release history. GitHub Actions runs the tests on every pull request and builds the APK when a version tag is pushed.

Contributors using Claude Code get two project skills: `run-app` (build, launch, and drive the app on the Android emulator) and `release` (version, docs, build, smoke test, and a confirmation checklist before anything is published).

</details>

## Acknowledgements

- Pilgrimage locations and screenshots come from [Anitabi](https://www.anitabi.cn) and its contributors ([CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/)).
- Reading Anitabi's map data follows [MiriaGo](https://github.com/BilyHurington/MiriaGo) (MIT). See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## License

MIT
