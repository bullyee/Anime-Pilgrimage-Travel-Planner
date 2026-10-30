# Trip sharing — requirements

Status: brainstorm result, 2026-10-30. Not built yet. This file records requirements. The schema they need is proposed in `docs/data-model.md`. The questions, options and answers behind each decision are in `docs/brainstorm-2026-10-30.md`.

## Where we are

- There is no way to share a trip today. A cloud trip's `members` holds only its creator, `firestore.rules` forbids changing `members`, and the app has no invite or member UI.
- The trip edit screen says "Real-time collaboration is active" (`roi_edit_screen.dart`). That is misleading and should go.
- Two-way sync (#45, PR #65) is a prerequisite.

## Use cases

All four are in scope:
1. Planning together before the trip.
2. Live sync during the trip, including seeing the photos the others take.
3. Letting other people use a trip as a reference.
4. Sharing memories (photos) afterwards.

## Two ways to share

The unit of sharing is always a whole trip. Sharing a single place on its own was considered and dropped.

### 1. Group: live collaboration

**Roles**
- Owner, editor and viewer. Viewers install the app and sign in like everyone else.
- The owner and editors can invite. Viewers can't.
- No member limit.

**Invites**
- A link, a QR code or a short code. All three are the same invite token: the QR code encodes the link, and the code is a short form of it.
  - The role is chosen when the invite is created.
  - An invite is valid for 7 days, can be used by any number of people, and can be revoked.
  - Opening a valid invite joins the trip right away, with no approval step.
- Invite by Google email: an allowlist checked against the signed-in account.
- Someone who opens the link without the app gets a simple download page (Firebase Hosting): the trip name, an APK download button, and "open the link again or enter the code after installing".

**Editing, conflicts and recovery**
- Editors can delete anything. Deleted items go to a trash and stay restorable by any member for 30 days.
- When two people edit the same place, the last write wins. The overwritten version stays in the activity log for 30 days and can be restored.
- Each trip has an activity log ("who did what"). It is mainly there so changes can be reverted.
- An in-app red dot marks trips with changes you haven't seen. No push notifications.

**Identity and status**
- Members see each other's Google display name and avatar. Email addresses are never shown to other members.
- Who added what is visible only in the activity log, not on list items.
- Each trip shows one sync status icon: synced, pending upload, or offline.

**Leaving and deleting**
- The owner has to transfer ownership before leaving. Otherwise they can only delete the trip or stop sharing it.
- When the owner deletes the trip or stops sharing it, every other member keeps a private, unsynced copy.
- When a member leaves or is removed, they keep a private copy.
- No archive or read-only mode in the first version.

**What is shared**
- Places, the schedule, and their anime and tag labels. Anime are matched across devices by Bangumi id.
- Turning a private trip into a shared one uploads all of its places and the schedule. Photos are not uploaded.
- Photos live in each member's personal layer (see the data model). Sharing one publishes a copy to the trip. Photos are shared one at a time, by choice, and only members can see them.
  - They are uploaded compressed (about 2048 px on the long edge, JPEG 85%) to Firebase Storage.
  - They sync live during the trip.
- Reference images that already have a URL (Anitabi imports) share the URL only. Screenshots the user added are uploaded to Storage.

### 2. Public template: snapshot

- Found only through a link, QR code or code. There is no gallery in the first version.
- Contains:
  - The places, with their anime and tag labels.
  - The dated day blocks as "day 1, day 2…", with their schedule. Dates, pinned dates and backup blocks are left out; the person picks a start date when applying the template.
  - The reference images.
- User photos are not included.
- A template is a snapshot. The author republishes it by hand, and copies people already made are never affected.
- Fetching a template doesn't need sign-in, so it works in guest mode.

## Home screen (#44)

- One trip list with filter tabs (for example All, Shared, Private) and a badge on shared trips.
- Expect many trips per user, so filtering matters.

## Related direction change

Anime and tags become plain labels on places, used to search and filter. They stop being heavyweight, first-class fields.

## Proposed phases

| Phase | Scope |
|---|---|
| 0. Prerequisites | Data model settled; two-way sync working (#65) |
| 1. Group sharing MVP | Roles and members; link / QR / code invites; member list; remove, leave, transfer ownership; stop sharing (others keep copies); sync status icon; home tabs (#44); remove the misleading text; sync anime/tag labels; download page |
| 2. Safety net | Activity log, red dot, 30-day trash, restoring overwritten versions, email invites |
| 3. Photos | Per-photo sharing, compressed upload, reference image sync, live photos during the trip |
| 4. Public templates | Publish a snapshot, relative-day schedule, link / QR / code, fetch without sign-in |
| Later | Template gallery, per-person check-in status, live location, archive, push notifications |

## Open questions

- **Purging the trash after 30 days.** The free Firebase plan has no Cloud Functions. Options are a Firestore TTL policy (not yet checked: is it available on the free plan?) or clients purging expired items when they open the trip.
- **Invite validation.** It has to be done in Firestore security rules, since there are no Cloud Functions. For example, a member may add themselves only with a valid, unexpired, unrevoked invite.
- **Opening links in the app.** Deep links need Android App Links: `assetlinks.json` on the Hosting domain.
