# Brainstorm log — trip sharing and data model (2026-10-30)

The question-and-answer rounds behind `docs/trip-sharing.md` and `docs/data-model.md`, kept so reviewers, human or agent, can see why each decision was made, which options were turned down, and where an answer changed later.

- **Format:** each row is one question. The options are the ones that were offered; "(rec)" marks the option recommended at the time. **Answer** is what was chosen. Free-text answers are quoted (translated from Chinese, original in parentheses).
- **Later rounds win.** Rows marked *→ changed* were reversed later; the later round has the final answer.

## Part 1 — Trip sharing

Context: no sharing existed at the time. `members` couldn't change, and there was no invite UI.

### Round 1
| Question | Options | Answer |
|---|---|---|
| In what situations do people share a trip? (multi) | plan together before the trip / live sync during the trip / read-only reference for others / share memories afterwards | **All four** |
| Who can edit? | everyone (rec) / one person plans, others view / roles | **Roles** (owner / editor / viewer) |
| What is the unit of sharing? | whole trip (rec) / trip plus single places / decide after Route | Trip plus single places *→ changed in round 2* |
| Are photos shared? | not in v1 (rec) / only reference-image URLs / include your own photos | "Provide the function; the user chooses for each photo whether to share it" |

### Round 2
| Question | Options | Answer |
|---|---|---|
| Sharing a single place gives the friend…? | a copy (rec) / a live link / both | "Share by trip instead" (改成以行程為單位分享). **Single-place sharing dropped.** |
| How does a read-only viewer open a trip? | install the app and sign in / web page without sign-in / app first, web later | **Install the app and sign in** |
| Invite methods (multi) | link / QR code / Google email / short code | **All four** |
| Who sees shared photos? | trip members only / everyone who can view the trip / per photo | **Trip members only** (viewers included) |

### Round 3
| Question | Options | Answer |
|---|---|---|
| Who can invite? | owner only / owner and editors (rec) / editors invite viewers only | **Owner and editors** |
| What can an editor delete? | anything / anything, but restorable (rec) / only their own | **Anything, restorable** (trash) |
| Owner deletes the trip → other members? | keep a private copy (rec) / it disappears / read-only archive | **Keep a private copy** |
| A member leaves or is removed → their phone? | keep a private copy (rec) / keep if they left, delete if removed / delete | **Keep a private copy** |

### Round 4
| Question | Options | Answer |
|---|---|---|
| Live features during the trip (multi) | per-person check-in status / live location / none | "Media assets too — members should see what the others shot. That's enough for now, more later." Check-ins and location: not now. |
| How do members learn about changes? (multi) | activity log / in-app red dot / push / none | "The activity log is there for reverting." **Activity log + red dot**, no push |
| Two people edit the same place | last write wins, restorable (rec) / per-field merge / ask the user | **Last write wins, restorable** from the activity log |
| Sync status display | trip-level icon (rec) / per item / none | **Trip-level icon** |

### Round 5
| Question | Options | Answer |
|---|---|---|
| Home screen: shared vs private trips (#44) | one list with badges (rec) / two sections / tabs | "One list + tabs + a shared badge — I expect lots of trips, so filtering keeps it tidy" |
| Show who added each item? | avatar on every item / activity log only (rec) / detail page only | **Activity log only** |
| Member identity | Google name and avatar (rec) / in-app nickname / Google profile plus email | **Google name and avatar**, never email |
| Trash and version retention | 30 days (rec) / forever / 7 days | **30 days** |

### Round 6 — invites
| Question | Options | Answer |
|---|---|---|
| Role of an invited member | chosen when the invite is created (rec) / always viewer, promote later | **Chosen when created** |
| Invite validity | 7 days, multi-use, revocable (rec) / until revoked / single use | **7 days, multi-use, revocable** |
| Approval | join right away (rec) / owner or editor approves / email joins directly, links need approval | **Join right away** |
| Opening a link without the app | simple download page on Firebase Hosting (rec) / nothing / redirect to GitHub releases | **Download page** |

### Round 7 — what is shared
| Question | Options | Answer |
|---|---|---|
| Anime and tag links on places | sync them (rec) / anime only / neither | **Sync them.** Direction change: "anime and tags will just be labels on a place, used to search places — no longer a high-impact field" |
| Making a private trip shared uploads… | everything except photos (rec) / the user picks | **Everything except photos** |
| Shared photo quality | compressed (rec) / original / user's choice | **Compressed** (~2048 px, JPEG 85%) |
| Reference images | URL if there is one, otherwise upload (rec) / URL only / per image | **URL if there is one, otherwise upload** |

### Round 8 — lifecycle
| Question | Options | Answer |
|---|---|---|
| Can the owner leave? | transfer ownership first (rec) / auto-transfer to the earliest editor / can't leave | **Transfer first** |
| Can the owner turn a shared trip back into a private one? | yes, others keep copies (rec) / no | **Yes** |
| Member limit | 20 (rec) / 10 / unlimited | "A trip can be shared in different ways: publicly, you share only the template and people fetch an offline copy; in a group there's no member limit." **→ two sharing modes: group and public template** |
| Archive after the trip | not in v1 (rec) / owner can archive | **Not in v1** |

### Round 9 — public templates
| Question | Options | Answer |
|---|---|---|
| How are templates found? | link / QR / code only (rec) / in-app gallery / link first, gallery later | **Link / QR / code only** |
| Template contents (multi) | places with labels / schedule as "day N" / reference images / the author's shared photos | **The first three**, no photos |
| Updates after publishing | snapshot, republish by hand (rec) / always the latest | **Snapshot** |
| Sign-in needed to fetch? | no (rec) / yes | **No** |

After round 9 the user asked: "Are the contents of an ROI (trip) and POI even settled? If not, sharing is premature." That started Part 2.

## Part 2 — Data model

The opening proposal: a personal Library of places, plus Trips that copy places into Stops; anime, tags and regions as labels; Route merged into Trip.

### Round 1
| Question | Options | Answer |
|---|---|---|
| Where does a place live? | library, copied into a trip when added (rec) / global place referenced by trips / trips only, no library | **Library + copy** |
| ROI (e.g. "Kyoto") | becomes a label (rec) / derived from coordinates / stays an entity | **Label** (`kind = region`) |
| Route | merged into trips (rec) / several routes per trip / separate top level | **Merged into trips** |
| Schedule dates | day index + trip start date (rec) / absolute dates | Day index + start date *→ replaced by day blocks* |

### Round 2
| Question | Options | Answer |
|---|---|---|
| A library place changes later → its stops? | fully independent (rec) / "update available" prompt / auto-merge untouched fields | **Fully independent** |
| Can a place go straight into a trip? | yes, trip-only (rec) / always saved to the library too / must come from the library | Yes *→ changed: no, see the two-layer discussion* |
| Same stop scheduled twice? | yes, several schedule items (rec) / once only | **Yes** |
| Non-pilgrimage places (hotels, stations, restaurants) | stop type field (rec) / no type / pilgrimage spots only | "Only pilgrimage spots. We are not a general trip planner; we should set that boundary." |

### Round 3
| Question | Options | Answer |
|---|---|---|
| Photos belong to… | the trip's stop (rec) / the library place | The stop *→ changed: the personal place* |
| Reference images | on both, copied along (rec) / library only | **On both, copied along** |
| Label scope | per user, matched by name / Bangumi id (rec) / per trip | **Per user, matched by key** |
| Private notes per member | not in v1 (rec) / yes, local only | Not in v1 *→ changed: yes, in v1* |

### The two-layer discussion
The user reconsidered round 2: adding a place straight into a trip "would be strange". Maybe a library place could have states: local only, trip only, and so on. Then:

> "Round 3 raises several questions: if the trip is synced, how do we get per-user private photos for a stop? Private notes on a stop are a super good-to-have. These would be strange if a stop only lives in a trip."

The answer was to split shared data from personal data:
- **Personal layer:** `places`, keyed by `place_key`. They hold notes, all of your photos, visits, and `visibility = saved | trip_only`.
- **Shared layer:** `stops`, which always carry a `place_key`.

The user accepted it: "This is the right way, but what a POI shows still needs design. `trip_only` hidden by default is a workable solution."

### Round 4
Interrupted by the discussion above. Its question about photos taken outside a trip was answered by the two-layer model: photos attach to the personal place, so a trip is optional.

### Round 5
| Question | Options | Answer |
|---|---|---|
| "I visited this spot" | shared schedule status + personal visit log (rec) / schedule status only / per-person schedule status | **Shared status + personal visit log** |
| Private notes in v1? | yes (rec) / model only, UI later | **Yes** |
| Trip length | store a day count (rec) / end date / derived from the schedule | "Or a trip is a collection of stops and days. We don't enforce its length; the user can tag a day with a specific date, and that tag isn't shared publicly." |
| Trip status | derived from dates (rec) / manual / derived with manual override | **Derived from dates** |

### Round 6 — days
| Question | Options | Answer |
|---|---|---|
| Who sees date tags in a group? | shared in the group, stripped from templates (rec) / each person's own / shared with personal override | **Shared in the group, stripped from templates** |
| Is a day its own record? | yes, reorderable with a title (rec) / just a number | **Yes** |
| Non-consecutive dates? | allowed, with a "fill consecutive" helper (rec) / always consecutive / fully manual | **Allowed, with the helper** |
| Two days on the same date? | no (rec) / yes | "No. For that, create a day with no date named e.g. 'rainy-day plan' and swap it in when needed." |

### The day-block discussion
The user asked whether undated backup days would be cumbersome compared with today's date-based scheduling. The reply: the common path is unaffected if the UI is date-first, but whole-day backups are coarse.

The user then proposed day blocks:

> "Only public sharing uses days as the unit. In the planner, the calendar is day blocks side by side; you can drag a whole block or single stops, so it still feels like arranging consecutive dates. Backup days come after the consecutive dates as blocks without a date tag."

Problems raised with that design:
- Date-bound plans (events, reservations) moving with a block.
- Swap vs insert when dragging a block.
- Non-consecutive trips.
- Backlog vs backup blocks.
- Phone width.
- Recomputing times when a stop moves.
- Concurrent reordering in groups.
- Closed-day checks.

Answers:
- "Support non-consecutive dates through pin + manually entered dates. 'Two days can't share a date' then holds naturally."
- Dragging a block: "**swap** by default. If that's not what you want, enter the date by hand, and finalized days can be pinned."
- Backup blocks in public templates: **no**.

### Round 7 — fields
| Question | Options | Answer |
|---|---|---|
| Shared facts on a spot (multi) | description and address / business hours and contact / access and shooting tips / external links | **All four** |
| Anime scene info on reference images | structured columns (rec) / keep the JSON metadata | **Structured** (`episode`, `timestamp_s`, anime label, attribution) |
| Do stops have their own order? | no, order comes from the schedule (rec) / a separate sort order | "No stored order, but they should be easy to sort and search, just like today's POI page." |
| Does a personal place keep its own copy of the facts? | yes, full data (rec) / no, read from the stop | **Yes** |

### Round 8 — migration, import, media
| Question | Options | Answer |
|---|---|---|
| Existing ROIs become… | trips plus a region label (rec) / region labels only / trips only | "Region labels only — after all it's a *region of interest*." |
| Where do Anitabi imports land? | library as saved (rec) / straight into a chosen trip / pick which spots | "Into the library. While importing you can tick which ones, with a select-all option, and optionally tick a trip (or none, or create one). Probably after fetching it first shows a list page." |
| Unused media types `ticket_qr`, `audio_bgm` | drop them (rec) / keep them | **Drop them** |
| Original / edited / comparison / composite photos | link them with `derived_from` (rec) / independent | **`derived_from`** |

### Round 9
| Question | Options | Answer |
|---|---|---|
| Existing scheduled items (`time_chunks`) | an extra trip for each ROI that has a schedule (rec) / one "old schedule" trip / drop them | **Drop them** (pre-1.0, few users) |
| Backing up the personal layer across your devices | yes, in a later phase (rec) / yes, in v1 / never, local only | **Later phase** (leave room in the model) |
| Backlog | stops with no schedule item, derived (rec) / a special block | **Derived** |
| A stop's time after dragging it to another day | recompute from order, fixed-time items stay (rec) / keep the time / clear it | **Recompute; fixed-time items stay** |

## Still open
- What the place / stop page shows, and its layout.
- Day planner UI on phones.
- Closed-day warnings.
- Moving data from guest mode to a signed-in account.
- Trip cover image.
- Whether to finish PR #65 against schema v8.

See the "Still to design" section of `docs/data-model.md`.
