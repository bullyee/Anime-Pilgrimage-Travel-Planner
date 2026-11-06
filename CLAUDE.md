# Anime Pilgrimage Travel App - Trip Planner

## Project Overview
A local-first, cross-platform travel planning app for anime pilgrimage trips.
Built with Flutter (Dart). SQLite via Drift for local storage. Riverpod for state management.

## Architecture
- **Mobile App (Flutter)**: Primary execution environment. Offline-first, GPS, camera, AR.
- **PC Web (Next.js/React)**: Deep planning environment (future phase).
- **Sync Model**: two-way Firestore sync for shared trips (`lib/features/sync/`): personal library (`places`, `labels`, `photos`) remains private on device; shared trips (`tripsV2`) with day blocks, stops, and schedule items sync across group members (`lib/features/sharing/`): people join through an invite link, QR code or 6-letter code, and the owner, editor and viewer roles are enforced in `firestore.rules` and the screens.
- **Data model**: unified `places` library and `trips` planner (schemaVersion 13).

## Core Modules
1. **Library (`places`, `labels`, `photos`)**: Personal library of pilgrimage spots, anime & region labels, user photos and comparison frames.
2. **Trip Planner (`trips`, `trip_days`, `stops`, `schedule_items`)**: Multi-day trip itineraries, day blocks, sequenced stops, and schedule items.
3. **Anime Camera**: shoot against an anime reference, then a photo editor (filters, rotate, crop) with a Compose/cutout flow. Android opens the phone's own camera app with the reference in a small draggable floating window (`ReferenceOverlay.kt`, `SYSTEM_ALERT_WINDOW`); iOS uses the in-app camera (`camera_screen.dart`); desktop/web have none. Entry point: `openAnimeCamera`. Why: `docs/anime-camera-decision.md`
4. **Labels**: Anime, tag, and region labels (`labels` table with kind `anime`/`tag`/`region`) linked to places and stops via `place_labels` and `stop_labels`; anime can be imported from Bangumi + Anitabi.
5. **VLM Pipeline**: planned, not implemented — Gemini API for parsing screenshots into POI data via share extension.

## Database Schema (SQLite via Drift, schemaVersion 13)
Source of truth: `lib/core/database/tables_v10.dart`; migrations live in `lib/core/database/database.dart`, and the one-time copy from the v9 model (v0.1.x) in `lib/core/database/migrations/migration_v9_to_v10.dart`.
- `places`: personal pilgrimage spot library (anitabi imports & custom user spots)
- `labels`: unified tags, regions, and animes
- `place_labels`: many-to-many junction between places and labels
- `photos`: user-taken photos and edits
- `place_visits`: visit history for places
- `v10_reference_images`: scene reference frames and metadata
- `trips`: multi-day travel plans (private or group-shared)
- `trip_days`: day blocks within trips
- `stops`: spots added to trips
- `stop_labels`: label associations for trip stops
- `schedule_items`: scheduled visits within day blocks

## Tech Stack
- Flutter / Dart
- State Management: Riverpod
- Local DB: Drift (SQLite)
- AI Integration: Gemini API (VLM) — planned
- On-device ML: ONNX Runtime (isnet-anime cutout; model fetched at runtime, ~176 MB), ML Kit subject segmentation
- Cloud: Firebase Auth (Google Sign-In), Firestore (`firestore.rules`), Hosting (`public/`: the invite page, App Links for `/join`, privacy policy, terms). `firebase_storage` is a dependency but unused so far.
- Camera: the phone's camera app via `image_picker` + a native floating reference window (Android); Flutter camera package (iOS)
- Navigation: Go Router

## Conventions
- Feature-first folder structure under lib/
- Use Riverpod providers for state
- Drift for all database operations
- UUID for all primary keys

## External APIs
- **Bangumi** (`api.bgm.tv`): anime search in `BangumiSearchService`.
- **Anitabi**: pilgrimage spots for a Bangumi subject in `AnitabiApiService`, read from Anitabi's static map data by `AnitabiStaticData` — `/d/g.json` (every work and spot coordinate, ~2 MB, cached ≤ 1 download/day) and `/d/g{n}.json` (spot details, cached per data version), from `w.junreimap.com` → `ww.anitabi.cn` → `www.anitabi.cn`. Covers come from `image.anitabi.cn`, falling back to the mirror `img-tc.anitabi.cn`. The format follows MiriaGo (MIT) and Anitabi's iOS app.
  - Don't use the open API (`api.anitabi.cn`, [api.md](https://github.com/anitabi/anitabi.cn-document/blob/main/api.md)): since 2026 it returns no spot coordinates and a partial spot list, and any undocumented path there (even `/`) gets the caller's IP Cloudflare-blocked for a while (#57).
  - Always send `AnitabiApiService.userAgent`, never retry on 403/429, and keep downloads rare. The data is CC BY-NC-SA 4.0, so keep the `origin`/`originURL` attribution.

## Workflows
- Tests: `flutter test` (unit tests under `test/`), and the Firestore rules on the emulator: `firebase emulators:exec "python test/rules_v2_emulator_test.py" --only firestore --project trip-planner-2775c` (needs Java 21, e.g. Android Studio's `jbr`, as `JAVA_HOME`). CI (`.github/workflows/ci.yml`) runs both on every PR and on `master`.
- Firebase deploys: from `master` only, and only what changed (`firebase deploy --only firestore:rules`, `--only hosting`).
- Run and drive the app on Android: `.claude/skills/run-app/SKILL.md`.
- Releases: `.claude/skills/release/SKILL.md` (Antigravity reaches it through `.agents/skills/release/`). GitHub pre-releases tagged `vX.Y.Z` with an APK; the `pubspec.yaml` version matches the tag; history in `CHANGELOG.md`. Pushing the tag runs `.github/workflows/release.yml`, which builds and signs the APK (keystore from the `ANDROID_DEBUG_KEYSTORE_B64` secret) and attaches it to a draft pre-release.
