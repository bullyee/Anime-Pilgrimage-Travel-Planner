---
name: release
description: Cut a trip_planner Android release (GitHub pre-release with a debug-signed APK) — survey what ships, choose the version, bump pubspec, update the static docs (CHANGELOG, README, CLAUDE.md, docs/), run tests, build and smoke-test the APK, then post a release checklist and wait for the user to confirm before any commit, push, PR, tag, or publish. After the tag is pushed, GitHub Actions builds the published APK into a draft release. Use when asked to release, ship, cut a version, or publish an APK.
---

# Release trip_planner

Releases are GitHub **pre-releases** tagged `vX.Y.Z` on `master`, each with two assets: `app-release.apk` (debug-signed, sideload only — not a Play Store build) and `app-release.apk.sha1`. History lives in `CHANGELOG.md`.

Two GitHub Actions workflows take the mechanical parts:
- `.github/workflows/ci.yml` runs `flutter test` on every PR and on `master`.
- `.github/workflows/release.yml` runs when a `vX.Y.Z` tag is pushed. It builds the APK, checks it, and attaches it to a **draft** pre-release. Publishing the draft stays a manual step (step 9). It can also be run by hand from the Actions tab to build an APK artifact from any branch.

This file is shared by every coding agent working on the repo. Claude Code reads it from `.claude/skills/release/`, and Antigravity reads `.agents/skills/release/SKILL.md`, which points here. Where a step names an agent-specific tool, use your agent's equivalent.

## Rules that override everything below

- **Nothing outward-facing without the user's explicit yes at the gate (step 7)** — that covers commit, push, PR, tag, `gh release`, and issue comments. Approval given earlier in the conversation, or for a previous release, does not carry over.
- Changes reach `master` only through a PR with at least one external reviewer. The user doesn't self-merge, and neither do you.
- Never run `flutter analyze` — it freezes the dev PC. `flutter test` is fine.
- Commit subjects are imperative ("Release v0.1.2", "Fix …"), no Conventional-Commit prefixes. End every commit with the co-author trailer your agent's instructions require (Claude Code: the one in its attribution reminder), and PR bodies with your agent's generated-by line, if it has one.
- Commands below are POSIX shell (Git Bash on Windows): no PowerShell here-strings. Pass long text with `git commit -F`, `--body-file`, `--notes-file` pointing at files in a temp folder outside the repo (Claude Code: the session scratchpad). `$OUT` below is that folder.

## 1. Survey what ships

```bash
git fetch --tags origin
git status --short                               # clean, or only this release's changes
LAST=$(git describe --tags --abbrev=0 origin/master)
SINCE=$(git log -1 --format=%cI "$LAST")
git log --oneline "$LAST"..origin/master
gh pr list --state merged --search "merged:>=$SINCE" --json number,title
gh issue list --state closed --search "closed:>=$SINCE" --json number,title
gh release view "$LAST"                          # tone and format of the last notes
```

GitHub's `merged:`/`closed:` search is day-granular, so it also lists items from the last release's own day — `git log "$LAST"..origin/master` is the authority on what ships. Fixes that belong in this release but aren't merged yet go on the release branch (step 2) and ride in the release PR. If nothing user-visible changed, tell the user and stop.

## 2. Branch and version

```bash
git switch -c release/vX.Y.Z origin/master       # local only until the gate
```

- Pre-1.0 semver: PATCH for fixes only, MINOR for new user-visible features.
- `pubspec.yaml` → `version: X.Y.Z+N`. The name matches the tag. `N` is Android's versionCode: previous `N` + 1, never lower, or the APK won't install over the last one. (v0.1.0 and v0.1.1 shipped as `1.0.0+1`; v0.1.2 aligned it to `0.1.2+3`.)

## 3. Update the static docs

Every doc a user or contributor reads must describe the release being shipped:

| File | Update |
|---|---|
| `CHANGELOG.md` | New `## [X.Y.Z] - YYYY-MM-DD` section on top (Keep a Changelog: Added / Changed / Fixed / Removed / Known issues, with issue refs), plus the compare link at the bottom. Only claim what was verified — a fix you couldn't exercise end-to-end is described by what changed, not as "works again". |
| `README.md` | The end-user manual: every section whose steps, messages, limits, or requirements changed; "What you can do"; "Good to know" (offline vs. online needs, platform table); the developer block. Plain language, no internal jargon. |
| `CLAUDE.md` | Architecture facts the release changed: modules, tables and schema version (`schemaVersion` in `lib/core/database/database.dart`), external APIs and their rules, workflows. |
| `docs/*.md` | Mark resolved items; fix statements the release made false. |
| `THIRD_PARTY_NOTICES.md` | Add the license notice of any project whose code or approach the release adapted (MIT and similar require it), and credit it in README's Acknowledgements. |

Then sweep for drift: grep the docs for the previous version, removed features, and renamed paths. Every file path or command a doc names must exist.

## 4. Verify

```bash
flutter test                                     # everything passes
git diff --stat -- linux macos windows           # pub get churn: line endings only?
git restore -- linux macos windows               # then drop it
```

Run `dart run build_runner build --delete-conflicting-outputs` first if any Riverpod, Drift, or freezed annotation changed. Add or update tests for every fix that ships.

## 5. Build the APK

This local build is for the smoke test and the size check. The APK that gets published is built by `release.yml` from the tag (step 9). Both are signed with the same key: CI restores this PC's `~/.android/debug.keystore` from the `ANDROID_DEBUG_KEYSTORE_B64` secret.

```bash
flutter build apk --release                      # a few minutes; run it in the background if you can
OUT="<temp folder>/release-vX.Y.Z"; mkdir -p "$OUT"
cp build/app/outputs/flutter-apk/app-release.apk "$OUT/"
(cd "$OUT" && sha1sum app-release.apk | cut -d' ' -f1 > app-release.apk.sha1)
ls -la "$OUT"
gh release view "$LAST" --json assets --jq '.assets[] | "\(.name) \(.size)"'
```

Compare the size with the last release. Baseline: a fat APK (arm64-v8a, armeabi-v7a, x86_64) of ~93 MB, almost all native libraries — libflutter, libapp, libonnxruntime, libsqlite3 (v0.1.1: 92.5 MB, v0.1.2: 92.6 MB, v0.1.3: 93.2 MB). A large unexplained jump means something got bundled by accident; the 176 MB cutout model is fetched at runtime and must stay out (`unzip -l` the APK and grep for `.onnx`). Don't claim a size change in the CHANGELOG without this comparison.

## 6. Smoke test

Follow the `run-app` skill with the **release** APK on Pixel_Test or a phone: cold start → home → every screen this release touched → each shipped fix. Take screenshots and check logcat for exceptions. Write down anything you couldn't verify and why — for example, an external API refusing this network.

## 7. Confirmation gate: post the check, then stop

Post the checklist to the user in their language, filled in:

```
Release vX.Y.Z — please confirm
- Version: pubspec X.Y.Z+N (was …); tag vX.Y.Z on master after the PR merges
- Ships: <commits / PRs since LAST>; fixes #…
- Docs updated: CHANGELOG.md, README.md (§…), CLAUDE.md (§…), …
- Tests: flutter test — N passed, 0 failed
- APK: <size> MB, sha1 <hash> (LAST was <size> MB)
- Smoke test: <device> — <what was exercised>; screenshots: <paths>
- Not verified: <what, and why>
- On approval I will: commit on release/vX.Y.Z → push → open PR "Release vX.Y.Z" (needs an external reviewer) → after it merges, ask once more, then push the tag, let CI build the draft pre-release, check it, and publish it
```

Then ask the user and wait for the answer (Claude Code: AskUserQuestion) — "Ship vX.Y.Z?" with options *Approve: commit, push, open PR* / *Change something first* / *Cancel*. Run no git or `gh` write command until the answer is approve. On *Change something first*, make the changes and post the check again.

## 8. After approval: commit, push, PR

Commit in reviewable units — each fix with its tests, tooling or skill changes, then the version-and-docs commit — so a reviewer can read them one at a time:

```bash
git add <fix files + tests> && git commit -F "$OUT/msg-fix.txt"     # "Fix …" / "Call …" + trailer
git add <tooling files>     && git commit -F "$OUT/msg-tools.txt"   # if any
git add -A && git status --short                                    # only intended files left
git commit -F "$OUT/msg-release.txt"                                # "Release vX.Y.Z": version, CHANGELOG, docs
git push -u origin release/vX.Y.Z
gh pr create --base master --title "Release vX.Y.Z" --body-file "$OUT/pr-body.md"
```

PR body: the checklist from step 7 as a GitHub task list (`- [x]` for what's done, `- [ ]` for the user's and reviewer's checks), the CHANGELOG section, and "Merging needs an external reviewer." Give the user the PR link, then stop until the PR is merged.

## 9. After merge: tag and publish (confirm again)

Ask once more: "PR #n is merged — tag and publish vX.Y.Z now?" On yes, push the tag and wait for `release.yml`:

```bash
git fetch origin && git switch master && git pull --ff-only
git log --oneline -3                             # release commit on top?
git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin vX.Y.Z
RUN=$(gh run list --workflow release.yml --branch vX.Y.Z --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN" --exit-status                # ~15 min
gh release view vX.Y.Z --json isDraft,assets --jq '.isDraft, (.assets[] | "\(.name) \(.size)")'
```

The workflow fails instead of releasing when:
- `pubspec.yaml`'s version doesn't match the tag.
- `flutter test` fails.
- The APK is signed with a key other than the one every release used. The key's SHA-256 is pinned in the workflow as `EXPECTED_CERT_SHA256`.
- The APK bundles an `.onnx` model.

On success it attaches `app-release.apk` and `app-release.apk.sha1` to a **draft** pre-release, with this version's CHANGELOG section as placeholder notes. Check the draft's APK size against step 5. It differs slightly from the local build, but not by megabytes.

If the run fails:
- A fix that needs no code change, such as a missing secret: fix it, then `gh run rerun "$RUN"`.
- A fix that needs code goes through a PR. Then ask the user before moving the tag: `git push origin :refs/tags/vX.Y.Z`, tag again on the new `master` head, and push the tag.

Then write the notes and publish the draft:

```bash
gh release edit vX.Y.Z --title "vX.Y.Z — <headline>" --notes-file "$OUT/notes.md" --draft=false
```

If Actions is unavailable, fall back to uploading the step 5 build, provided nothing besides the release PR merged after it was built. Run `gh release create vX.Y.Z --prerelease --verify-tag --title … --notes-file … "$OUT/app-release.apk" "$OUT/app-release.apk.sha1"`.

The `ANDROID_DEBUG_KEYSTORE_B64` secret is the base64 of the keystore that signed every release. If it's ever lost, existing users have to uninstall the app, and lose its local data, before a new APK will install.

Release notes match the previous ones: a one-paragraph summary, then `### :sparkles: New`, `### :wrench: Changes`, `### :bug: Fixes`, `### :warning: Notes` (debug-signed / sideload only, known issues, anything unverified), and an install line ("download app-release.apk, allow unknown sources, tap").

## 10. Wrap up

- With the user's OK, comment on the fixed issues with the release link; close those the release fully resolves.
- `git switch master`, delete the merged local release branch.
- Record anything about the process that changed in this file.
