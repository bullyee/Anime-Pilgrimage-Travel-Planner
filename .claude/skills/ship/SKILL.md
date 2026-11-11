---
name: ship
description: Take finished work on a trip_planner branch to a reviewed, green PR — verify, clean the platform churn, commit in the repo's style, push, open the PR with a test plan, watch CI, get an independent review, and fix what it finds. Use when the user says ship it, open a PR, push this, or the work on a branch is done.
---

# Ship a branch as a PR

The repo is **public**: a push publishes. Ship only work the user asked for, from a feature branch (never `master`), and stop to ask whenever a step below says so.

## 1. Preflight

```bash
git branch --show-current       # must not be master; if it is, create a branch first (feat/…, fix/…, chore/…, docs/…)
git fetch origin && git status --short
git log --oneline origin/master..HEAD
```

- Work in the branch's own worktree. The main checkout often has local-only files (`docs/roadmap.md`, `docs/mvp-plan.md`, …) that must never be committed.
- `git restore -- linux macos windows` drops pub-get's line-ending churn.
- Anything else untracked or unrelated: leave it out of the commit and mention it.

## 2. Verify

Run the `verify` skill (`python -I ~/.claude/harness/verify.py --ui auto`, in the background):
- When `lib/` UI changed, a UI flow must pass, and you must look at its screenshots. If no flow reaches the changed screen, add one to `tool/ui/flows/`.
- Commit any `.g.dart` files that codegen regenerated.
- Never `flutter analyze` locally; CI does it.

Don't go on with a red verify. Fix the problem, or tell the user why it's red.

## 3. Commit

Match the history (`git log --format=%s -n 15`):
- **Subject:** imperative, plain English, says what the user gets, no prefix ("Open a stop's page from the read-only plan").
- **Body:** wrapped prose for the why, when it isn't obvious. End with the attribution trailer from the system reminder.
- **Scope:** one logical change per commit. Stage paths explicitly; no `git add -A` in a dirty tree.

## 4. Push and open the PR

```bash
git push -u origin HEAD
gh pr create --base master --title "<subject-style title>" --body-file <scratchpad>/pr.md
```

PR body style (see recent merged PRs, e.g. `gh pr view 148`):
- **Opening:** one paragraph on what changes and why. Name decisions and who made them ("Decided with bullyee on …").
- **`## What changes`:** bold-labelled bullets per area. Use a table when mapping old → new.
- **Notes:** call out overlaps with other open PRs ("this and #146 both change `day_planner.dart`").
- **`## Test plan`:** a checklist of what was run, with counts (`flutter test` (425), sub-bullets for the new cases, the UI flows and their screenshots). Mark only what actually ran as `[x]`.
- **Ending:** the PR attribution line from the system reminder.

Stacked on another open PR: use `--base <that branch>` and say so at the top of the body.

## 5. CI

```bash
gh pr checks --watch --interval 30      # run_in_background; you get notified when it ends
```

Jobs: `analyze + codegen` (stale `.g.dart` or analyzer warnings) and `flutter test` (unit tests plus Firestore rules on the emulator). On a failure, read the failing log (gh needs the run id when not interactive): `gh run view "$(gh run list --branch "$(git branch --show-current)" -L1 --json databaseId -q '.[0].databaseId')" --log-failed | tail -80`. Then fix, commit, push, and watch again. Don't stop at red.

## 6. Review

Start an independent reviewer (Agent tool, general-purpose). Give it the PR number and ask it to review `gh pr diff <n>` for correctness: logic errors, unhandled states, sync and rules implications, missing tests. Give it the code, not your opinion of the code.
- Fix the findings that hold up, push, and note them in a PR comment.
- Don't approve your own PR. `gh pr review --approve` is for the human reviewer.

## 7. Report

- PR link
- CI state
- what verify and the flows covered (and screenshots looked at)
- review findings fixed or disputed
- what's still open

If the work finishes an item in `docs/roadmap.md` (local, in the main checkout), say which; the user ticks it when it merges (see `land`).
