---
name: verify
description: Fast, token-efficient test and security rules verification runner for trip_planner. Runs compact unit tests and optional live Firestore emulator security rules tests with summarized output. Use whenever verifying changes before submitting PRs.
---

# Fast Test & Security Verification for trip_planner

Use this skill to run the verification suite cleanly without polluting the agent's context window with thousands of passing test lines.

## Prerequisites

1. **Flutter SDK**: on `PATH` for unit tests.
2. **For Firestore security rules tests** (`-WithEmulator` / `-RulesOnly`):
   - **Firebase CLI**: `firebase` on `PATH`.
   - **Python 3**: `python` on `PATH` with `requests` installed.
   - **JDK 21 / JBR**: Java 21, found automatically in Android Studio `jbr` or via `JAVA_HOME`.

## How to Run

Execute the verification script via your shell:

```powershell
powershell -ExecutionPolicy Bypass -File tool\verify.ps1
```

By default, this runs Flutter unit tests using `--reporter=failures-only` (summarized to a single line on success). Emulator rules tests are skipped by default to avoid triggering Windows Firewall prompts for `java.exe`.

### Options

* **Run with Firestore Security Rules Emulator**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File tool\verify.ps1 -WithEmulator
  ```
* **Firestore Security Rules Only** (skip unit tests):
  ```powershell
  powershell -ExecutionPolicy Bypass -File tool\verify.ps1 -RulesOnly
  ```
* **Unit Tests Only** (explicit):
  ```powershell
  powershell -ExecutionPolicy Bypass -File tool\verify.ps1 -UnitOnly
  ```

## Why This Saves Tokens

1. **Compact Output**: Uses `flutter test --reporter=failures-only` and emits only failing tests, or a single pass line when all tests pass.
2. **Aggregated Results**: Summarizes Firestore emulator test output to a single confirmation line (`ALL X/X FIRESTORE RULES TESTS PASSED`).
3. **Safe Environment Detection**: Automatically searches for JBR across Android Studio installations if `JAVA_HOME` is unset, and specifies `--project trip-planner-2775c`.
4. **Error Isolation**: On failure, dumps only the relevant error stack trace (last 30 lines) so the agent can quickly diagnose and fix issues without overflowing context limits.
