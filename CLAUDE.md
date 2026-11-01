# Anime Pilgrimage Travel App - Trip Planner

## Project Overview
A local-first, cross-platform travel planning app for anime pilgrimage trips.
Built with Flutter (Dart). SQLite via Drift for local storage. Riverpod for state management.

## Architecture
- **Mobile App (Flutter)**: Primary execution environment. Offline-first, GPS, camera, AR.
- **PC Web (Next.js/React)**: Deep planning environment (future phase).
- **Sync Model**: two-way Firestore sync for shared trips (`lib/features/sync/`, #65, #79): dirty POIs and time chunks are pushed after a 2 s debounce, and a trip is pulled when its `cloudVersion` rises. A trip's only member is its creator (there are no invites yet), so sync runs between one user's devices; photos and reference images don't sync. Manual JSON export/import was removed from the UI in v0.1.1.
- **Data model status**: frozen, bug fixes only. #72 proposes the replacement (a personal `places` library plus shared `trips` with day blocks), planned for v0.2.0.

## Core Modules
1. **ROI (Region of Interest)**: Macro-container (e.g., "Kyoto City", "Akihabara") for grouping POIs
2. **POI (Point of Interest)**: Core location node with spatial data, metadata, media, scheduling
3. **Trip Calendar**: Time chunks for scheduling POIs with drag-and-drop
4. **Anime Camera**: shoot against an anime reference, then a photo editor (filters, rotate, crop) with a Compose/cutout flow. Android opens the phone's own camera app with the reference in a small draggable floating window (`ReferenceOverlay.kt`, `SYSTEM_ALERT_WINDOW`); iOS uses the in-app camera (`camera_screen.dart`); desktop/web have none. Entry point: `openAnimeCamera`. Why: `docs/anime-camera-decision.md`
5. **Anime & Tag**: first-class entities linked to POIs many-to-many; anime can be imported from Bangumi + Anitabi
6. **Ticket Organizer**: removed in v0.1.1 (the `ticket_qr` media type remains)
7. **VLM Pipeline**: planned, not implemented — Gemini API for parsing screenshots into POI data via share extension

## Database Schema (SQLite via Drift, schemaVersion 9)
Source of truth: `lib/core/database/tables.dart`; migrations live in `lib/core/database/database.dart`. Rows carry `author_id` (and `is_shared` on shareable tables) for cloud sync.
- `rois`: id, name, description, is_offline_cached, created_at, cloud_version, sync_lock_expires_at
- `pois`: id, roi_id (nullable), name, description, address, lat, lng, business_hours, contact_info, local_cover_image_path, remote_cover_image_url, sort_order, created_at, sync_status, is_deleted, has_ever_synced, last_modified_at
- `animes`: id, name, description, bangumi_id (unique), created_at
- `tags`: id, name, description, created_at
- `poi_animes`, `poi_tags`: many-to-many junctions, cascade on delete
- `time_chunks`: id, poi_id, date, start_time, end_time, status (backlog/scheduled/skipped/completed), sort_order, duration, transit_duration, is_fixed_time, sync_status, is_deleted, has_ever_synced, original_start_time, original_end_time, last_modified_at
- `reference_images`: id, poi_id, local_path, remote_url, metadata, created_at
- `media_assets`: id, poi_id, type (reference_frame/user_photo/ticket_qr/audio_bgm), local_path, remote_url, metadata, reference_image_id, created_at

## Tech Stack
- Flutter / Dart
- State Management: Riverpod
- Local DB: Drift (SQLite)
- AI Integration: Gemini API (VLM) — planned
- On-device ML: ONNX Runtime (isnet-anime cutout; model fetched at runtime, ~176 MB), ML Kit subject segmentation
- Cloud: Firebase Auth (Google Sign-In), Firestore, Storage
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
- Tests: `flutter test` (unit tests under `test/`). CI (`.github/workflows/ci.yml`) runs them on every PR and on `master`.
- Run and drive the app on Android: `.claude/skills/run-app/SKILL.md`.
- Releases: `.claude/skills/release/SKILL.md` (Antigravity reaches it through `.agents/skills/release/`). GitHub pre-releases tagged `vX.Y.Z` with an APK; the `pubspec.yaml` version matches the tag; history in `CHANGELOG.md`. Pushing the tag runs `.github/workflows/release.yml`, which builds and signs the APK (keystore from the `ANDROID_DEBUG_KEYSTORE_B64` secret) and attaches it to a draft pre-release.
