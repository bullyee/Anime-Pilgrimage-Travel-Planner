---
name: verify
description: Verify trip_planner changes before calling them done or opening a PR — runs the unit tests the change touches, build_runner when a generated file's source changed, the Firestore rules tests when the rules changed, and for UI changes builds the APK and runs the scripted emulator flows in tool/ui/flows with screenshots. Use after code changes, before committing or submitting PRs.
---

# Verify trip_planner changes

The full procedure is shared with other coding agents and lives in
`.claude/skills/verify/SKILL.md`. Read that file and follow it step by step.
Where it names a Claude Code tool, use your own equivalent.
