---
name: verify
description: Verify trip_planner changes before calling them done or opening a PR — runs the unit tests the change touches, build_runner when a generated file's source changed, the Firestore rules tests when the rules changed, and for UI changes builds the APK and runs the scripted emulator flows in tool/ui/flows with screenshots. Use after code changes, before committing or submitting PRs.
---

# Verify trip_planner changes

## On the dev PC (Claude Code): the verify loop

This repo uses the maintainer's general harness: `~/.claude/harness/verify.py`, driven by the global `verify-loop` skill. `.claude/verify.json` configures it for this repo:
- the Firestore rules check runs when `firestore.rules` or `test/rules_*` changes,
- UI flows run from `tool/ui/flows`,
- the emulator is `Pixel_Test`, booted automatically when needed,
- `--reinstall` is used because the emulator's `/data` is nearly full.

```bash
python -I ~/.claude/harness/verify.py --plan       # what runs and why
python -I ~/.claude/harness/verify.py --ui auto    # run it (background: the APK build takes minutes)
```

How it maps changes to tests:
- `lib/features/<f>/…/x.dart` → `test/…/x_test.dart` if it exists, else any `x_test.dart`, else all of `test/features/<f>/`.
- `pubspec.*` or an unmapped file (e.g. `lib/shared/`, the router) → the full suite.
- A changed file with `part '*.g.dart'` → `build_runner` first. Commit any `.g.dart` it reports as regenerated; CI fails on stale generated code.

Rules for this repo:
- **Never run `flutter analyze` here**; it freezes the PC. CI's `analyze + codegen` job runs it on every PR.
- UI flows run on the `Pixel_Test` emulator only. The user's phone (Pixel 10a) is never wiped: no `clean` flows, `--reinstall` or `--allow-phone-clean` on it.
- When a change adds or alters a screen, add or extend a flow in `tool/ui/flows/`. The step format is in `~/.claude/harness/uiflow.py`; see `create_trip.json` for an example. Then look at the screenshots before calling the UI done.
- After a build or test run, `git restore -- linux macos windows` (pub-get line-ending churn).

## Without the harness: tool/verify.ps1

Other agents, or a machine without `~/.claude/harness`, use the compact PowerShell runner:

```powershell
powershell -ExecutionPolicy Bypass -File tool\verify.ps1               # unit tests, failures only
powershell -ExecutionPolicy Bypass -File tool\verify.ps1 -WithEmulator # + Firestore rules on the emulator
powershell -ExecutionPolicy Bypass -File tool\verify.ps1 -RulesOnly    # rules only
```

The rules tests need:
- the Firebase CLI,
- Python 3 with `requests`,
- Java 21. The script finds Android Studio's `jbr` when `JAVA_HOME` is unset.

Emulator rules tests are opt-in because `java.exe` can trigger a Windows Firewall prompt.

Output stays compact: `--reporter=failures-only`, one line per passing suite, and on failure only the last 30 lines.
