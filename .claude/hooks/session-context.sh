#!/usr/bin/env bash
# SessionStart hook: print where the work stands so a new or resumed session
# doesn't have to ask. Stdout becomes context for Claude. Read-only: it never
# fetches, switches branches or writes anything. Every section is best-effort;
# a missing tool or no network just drops that section.

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

echo "## Session context (from .claude/hooks/session-context.sh)"

branch=$(git branch --show-current 2>/dev/null)
echo "- Branch: ${branch:-detached at $(git rev-parse --short HEAD)}"

if git rev-parse --verify -q origin/master >/dev/null; then
  read -r behind ahead < <(git rev-list --left-right --count origin/master...HEAD 2>/dev/null)
  echo "- vs origin/master (last fetch): ${ahead:-?} ahead, ${behind:-?} behind"
fi

# Uncommitted work, minus the pub-get churn the run-app skill says to drop.
changes=$(git status --porcelain 2>/dev/null | grep -vE ' (linux|macos|windows)/' )
churn=$(git status --porcelain -- linux macos windows 2>/dev/null | wc -l)
if [ -n "$changes" ]; then
  echo "- Uncommitted ($(printf '%s\n' "$changes" | wc -l) files):"
  printf '%s\n' "$changes" | head -12 | sed 's/^/    /'
fi
[ "$churn" -gt 0 ] && echo "- $churn files under linux/macos/windows changed (usually pub-get line endings; \`git restore -- linux macos windows\`)"

if command -v gh >/dev/null 2>&1; then
  # The current branch's PR, with its checks and review state.
  if [ -n "$branch" ] && [ "$branch" != master ]; then
    pr=$(timeout 8 gh pr view --json number,title,state,isDraft,reviewDecision,mergeable,statusCheckRollup \
      -q '"#\(.number) \(.title) [\(.state)\(if .isDraft then ", draft" else "" end)] review=\(.reviewDecision // "none") mergeable=\(.mergeable) checks=\([.statusCheckRollup[]? | (.conclusion // .status)] | group_by(.) | map("\(.[0])×\(length)") | join(","))"' 2>/dev/null)
    echo "- This branch's PR: ${pr:-none}"
  fi
  # Open, non-draft PRs (the ones waiting on review, CI or a merge).
  prs=$(timeout 8 gh pr list --state open --limit 15 --json number,title,isDraft,headRefName,reviewDecision,statusCheckRollup \
    -q '.[] | select(.isDraft|not) | "#\(.number) \(.title) (\(.headRefName)) review=\(.reviewDecision // "none") checks=\([.statusCheckRollup[]? | (.conclusion // .status)] | if length==0 then "none" elif all(.=="SUCCESS" or .=="SKIPPED" or .=="NEUTRAL") then "green" elif any(.=="FAILURE" or .=="CANCELLED" or .=="TIMED_OUT") then "RED" else "running" end)"' 2>/dev/null)
  drafts=$(timeout 8 gh pr list --state open --draft --limit 50 --json number -q 'length' 2>/dev/null)
  if [ -n "$prs" ]; then
    echo "- Open PRs (not draft):"
    printf '%s\n' "$prs" | sed 's/^/    /'
  fi
  [ -n "$drafts" ] && [ "$drafts" != 0 ] && echo "- Draft PRs: $drafts (\`gh pr list --draft\`)"
fi

# Unfinished plan items. docs/roadmap.md is kept local (untracked) in the main
# checkout and ordered by version, so the first open items are the current ones.
# (docs/mvp-plan.md is the finished MVP plan; it isn't read.)
for f in docs/roadmap.md TODO.md; do
  [ -f "$f" ] || continue
  open=$(grep -cE '^\s*[-*] \[ \]' "$f")
  [ "$open" -gt 0 ] || continue
  echo "- $f: $open open items; first few:"
  grep -E '^\s*[-*] \[ \]' "$f" | head -6 | sed -E 's/^\s*[-*] \[ \] /    - /' | cut -c1-140
done

exit 0
