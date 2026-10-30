# Data model — proposal

Status: brainstorm result, 2026-10-30. This is a proposal for review, not built. It replaces the schema v8 model (`rois` / `pois` / `time_chunks` …) and is the base for trip sharing (`docs/trip-sharing.md`). The questions, options and answers behind each decision are in `docs/brainstorm-2026-10-30.md`.

## Principles

1. **Pilgrimage spots only.** Hotels, stations and restaurants are out of scope; this is not a general trip planner.
2. **Two layers: personal and shared.**
   - The **personal layer** is yours alone: your library of places, private notes, your photos, the places you've visited. It is never synced to a group.
   - The **shared layer** is a trip: its stops, days and schedule. A trip syncs to every member of the group.
   - Leaving a trip, deleting it or unsharing it never touches anyone's personal layer.
3. **A trip is self-contained.** Adding a place to a trip copies it into a stop. Sharing, templates and "keep a private copy" are all just copies of one trip.
4. **Anime, tags and regions are labels.** They exist to search and filter places, not to drive the app.

## Overview

```
PERSONAL (on your device; backed up to your own cloud space later)
  labels           kind = anime | tag | region
  places           your page for a spot, keyed by place_key
   ├ place_labels
   ├ reference_images   (owner = place)
   ├ photos             every photo you took here; each records its trip, if any
   └ place_visits       "visited 3 times, last 2027-04"

SHARED (one trip, synced with its group)
  trips            start_date?, day_count
   ├ trip_days     ordered day blocks; optional pinned date
   ├ stops         copy of a place's facts + place_key
   │  ├ stop_labels
   │  ├ reference_images (owner = stop)
   │  └ shared photos     published from members' personal photos
   └ schedule_items  stop → day block, in order

CLOUD ONLY
  members, invites, activity log, templates
```

## Personal layer

### `places`
Your page for one real-world spot.

| Column | Notes |
|---|---|
| `place_key` (PK) | The spot's identity, shared by every person's copy of it: `anitabi:<pointId>` for Anitabi imports, a UUID for places users create. |
| `name`, `lat`, `lng` | Required. |
| `description`, `address`, `business_hours`, `contact_info` | Shared facts (your own editable copy). |
| `access_tips` | How to get there, and when to shoot. A shared fact, unlike the private note. |
| `links` | External links (Google Maps, the Anitabi page…). |
| `cover_local_path`, `cover_remote_url` | |
| `source`, `source_url` | Attribution. Anitabi data is CC BY-NC-SA 4.0, so keep `origin` / `originURL`. |
| `private_note` | Ships in v1. |
| `visibility` | `saved` (shown in the library) or `trip_only` (exists because a trip uses it; hidden by default). "Save" turns `trip_only` into `saved`. |
| `created_at`, `updated_at` | |

How places come to exist:
- **Anitabi import:** fetch → a list page with checkboxes and "select all" → optionally add the picked spots to an existing trip, or a new one. Picked spots land in the library as `saved` with the anime label.
- **Created inside a trip:** a place can't be added straight into a trip. A new spot added from a trip creates a `trip_only` place first, then the stop.
- **Someone else's stop:** when you write a note or take a photo on another member's stop (or a template's), a `trip_only` place with the same `place_key` is created for you.

### `labels`, `place_labels`
- `labels`: `id`, `kind` (`anime` | `tag` | `region`), `name`, `bangumi_id?`.
- Matched across people by natural key: anime by `bangumi_id`; tags and regions by `kind` + `name`. A missing label is created when you join a shared trip or apply a template.

### `photos`
| Column | Notes |
|---|---|
| `id`, `place_key`, `trip_id?` | Photos belong to your place. `trip_id` records the trip you took it on. Photos taken outside a trip simply have no trip. |
| `kind` | `original`, `edited`, `comparison` or `composite`. |
| `derived_from_id?`, `reference_image_id?` | Link an edit or comparison to its original and to the reference frame it matched. |
| `local_path`, `remote_url?` | |
| `is_shared` | Opt-in per photo. When true, the photo is uploaded compressed (~2048 px, JPEG 85%) and published to the trip. |
| `taken_at` | |

### `place_visits`
`id`, `place_key`, `date`, `trip_id?`. "I visited" is personal and accumulates across trips. Whether a schedule item is done, by contrast, is shared.

### `reference_images`
Anime frames for the camera overlay. A row is owned by either a place or a stop (exactly one of `place_key` / `stop_id`). Adding a place to a trip copies its reference images to the stop; afterwards the two are independent.

| Column | Notes |
|---|---|
| `local_path?`, `remote_url?` | Images that have a URL (Anitabi) copy and sync only the URL. User screenshots are uploaded when shared. |
| `anime_label_id?`, `episode?`, `timestamp_s?` | Structured scene info, replacing today's JSON `metadata`. |
| `source`, `source_url` | Attribution. |

## Shared layer

### `trips`
`id`, `title`, `description?`, `owner_id`, `sharing` (`private` | `group`), `start_date?`, `day_count`, `created_at`, `updated_at`.

The status (planning / ongoing / finished) is derived from the dated blocks and not stored.

### `trip_days`: day blocks
`id`, `trip_id`, `sort_key`, `title?`, `pinned_date?`.

The planner shows the blocks side by side. You drag whole blocks or single stops, so it feels like arranging consecutive dates.
- **Dated blocks:** the first `day_count` blocks. Block *i* is dated by position, `start_date + i`. A **pinned** block keeps a manually entered date and stays in place; the blocks after it continue from that date. Pins are how non-consecutive trips work, and how date-bound plans such as events or reservations are protected.
- **Backup blocks:** blocks after the divider (index ≥ `day_count`) have no date, e.g. "rainy-day plan". You drag one into the dated range when you need it.
- **Rules:**
  - Dragging a block onto another swaps them.
  - Pinned dates must increase along the order. A pin on or before the previous block's date is rejected, so two blocks never share a date.
- `sort_key` is a fractional index, so concurrent reordering in a group doesn't corrupt the order.

### `stops`
`id`, `trip_id`, `place_key` (not null), the shared facts copied from the place (`name`, `lat`, `lng`, `description`, `address`, `business_hours`, `contact_info`, `access_tips`, `links`, cover, `source`, `source_url`), `added_by`, `created_at`, `updated_at`, `deleted_at?`.

- A stop is independent of the place it came from. To get newer data, add the place again.
- Stops have no stored order. Lists sort and search like today's POI page.
- `stop_labels (stop_id, label_id)` holds the stop's labels; they sync with the trip.

### `schedule_items`
`id`, `trip_id`, `stop_id`, `day_id`, `sort_key`, `stay_minutes`, `transit_minutes`, `fixed_time?`, `status` (`planned` | `done` | `skipped`), `updated_at`, `deleted_at?`.

- One stop can have several schedule items, for example the same spot on two days.
- The **backlog** is the trip's stops that have no schedule item. It is derived, not stored.
- Times within a day are computed from order, stay and transit. Items with `fixed_time` keep their time. Dragging a stop to another day recomputes its time.

### Sync bookkeeping
Shared tables carry `updated_at`, `updated_by` and `deleted_at`. `deleted_at` is the 30-day trash. Local rows also keep a sync status (`synced` / `dirty`).

## Cloud only

- `members (trip_id, user_id, role, display_name, avatar_url)`, with `role` = `owner` | `editor` | `viewer`.
- `invites`: token, code, role, expiry, revocation; plus email invites.
- `activity`: who changed what, with the previous value, kept 30 days for revert.
- `trip_photos`: shared photos published by members.
- `templates`: published snapshots. A snapshot holds the stops, their labels and reference images, the dated blocks as "day 1, day 2…" and the schedule. It has no `start_date`, no pins and no backup blocks.

## Migration from schema v8

Pre-1.0 with few users, so the migration keeps places and photos and drops schedules.

| v8 | New |
|---|---|
| `animes`, `tags` | `labels` (`anime`, `tag`) |
| `rois` | `labels` (`region`). ROIs really are regions of interest. No trips are created. |
| `pois` | `places` (`saved`). The ROI, anime and tag links become labels. Anitabi POIs keep `anitabi:<id>` as their `place_key`. |
| `reference_images`, `media_assets.reference_frame` | `reference_images` owned by the place. The JSON metadata is parsed into `episode` / `timestamp_s`. |
| `media_assets.user_photo` | `photos` on the place. |
| `media_assets.ticket_qr`, `audio_bgm` | Dropped. |
| `time_chunks` | Dropped. |

## Effect on current work

- **#65 (two-way sync):** it is built on the v8 tables, so trip sync gets rewritten against `trips` / `trip_days` / `stops` / `schedule_items`. The team needs to decide whether to finish and merge #65 as an interim step, or to stop investing in it.
- **Route plan:** merged into trips. A day block's ordered schedule items are the route.
- **#44 ("My Trips" just opens Regions):** solved by the design. Trips and regions are different things now.
- **#40 (`isShared` no-ops):** replaced by `trips.sharing` and `photos.is_shared`.

## Still to design

- The place / stop page: which shared and personal fields it shows, and the layout.
- The day planner UI:
  - a zoomed-out mode for reordering blocks on a phone;
  - auto-scroll while dragging across blocks;
  - how backlog and backup blocks are presented.
- Closed-day warnings when a block moves (business hours are free text today).
- Moving the personal layer from guest mode to a signed-in account, and the later private cloud backup.
- Trip cover image.
