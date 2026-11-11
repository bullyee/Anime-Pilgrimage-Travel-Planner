---
name: land
description: Merge approved trip_planner PRs the user names, then retarget and rebase PRs stacked on them, refresh local master and update the local roadmap. Use when the user says merge/land #N (or several PR numbers). Never merges a PR the user didn't name.
---

# Land PRs

Merging to `master` publishes; it's the user's call. Act only on the PR numbers the user named in this conversation, in the order they gave. Stop and ask if a step fails or something looks off.

## 1. Check each PR

```bash
gh pr view <n> --json number,title,state,isDraft,baseRefName,headRefName,mergeable,reviewDecision,statusCheckRollup
```

Merge only when all of these hold:
- the PR is open and not a draft,
- `mergeable` is `MERGEABLE`,
- every check is SUCCESS, SKIPPED or NEUTRAL,
- `reviewDecision` is APPROVED.

If the review isn't APPROVED, ask the user whether to merge anyway; it's their repo. Report anything else that fails and stop.

**Before merging, note the PRs stacked on it.** Deleting the head branch makes GitHub retarget them to `master` on its own, so afterwards they can no longer be found by base:

```bash
gh pr list --state open --base <its head branch> --json number,headRefName
git rev-parse origin/<its head branch>     # the old base: the stacked branches' commits start after it
```

## 2. Merge

```bash
gh pr merge <n> --merge --delete-branch
```

The repo uses merge commits ("Merge pull request #148 from …"), so never squash or rebase-merge. `--delete-branch` also tries to delete the local branch; that fails harmlessly when another worktree has it checked out.

## 3. Stacked PRs

For each PR noted in step 1: GitHub has already moved its base to `master` (check with `gh pr view <m> --json baseRefName`; if not, `gh pr edit <m> --base master`). Its branch still carries the merged PR's commits, so rebase it in its own worktree (create one with `git worktree add` if needed), using the old base SHA from step 1:

```bash
git fetch origin
git rebase --onto origin/master <old base sha> <branch>
git push --force-with-lease
```

Never use a plain `--force`.

- If the rebase conflicts, resolve it only when the resolution is clear.
- Otherwise, `git rebase --abort` and tell the user.

After pushing, run `gh pr checks <m> --watch` (in the background).

## 4. Local state

`git fetch origin --prune`. Don't check out or pull in the main checkout (the first line of `git worktree list`): it has local-only docs and may hold someone's uncommitted work. Report how far behind its `master` is, and offer `git -C <main> merge --ff-only origin/master` when its tree is clean apart from the untracked docs.

## 5. Roadmap

`docs/roadmap.md` (untracked, main checkout) is the plan. For each merged PR, find its line by PR number or by topic:
- Tick it (`- [x]`) and add the PR and date in the file's style ("(#148, 2026-11-11)").
- If unsure which line, show the candidates and ask.

`docs/mvp-plan.md` is the finished MVP plan; leave it alone.

## 6. Report

- what merged (with merge commit),
- what was retargeted or rebased, with CI state,
- roadmap lines ticked,
- anything left: deploys needed, such as `firestore.rules`, which deploys from `master` only and only when the user says so.
