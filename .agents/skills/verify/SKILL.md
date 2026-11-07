---
name: verify
description: Fast, token-efficient test and security rules verification runner for trip_planner. Runs compact unit tests and live Firestore emulator security rules tests with summarized output. Use whenever verifying changes before submitting PRs.
---

# Fast Test & Security Verification for trip_planner

Use this skill to run the complete verification suite without polluting the agent's context window with thousands of passing test lines.

## How to Run

Execute the verification script via `run_command`:

```powershell
powershell -ExecutionPolicy Bypass -File tool\verify.ps1
```

### Options

* **Unit Tests Only** (skip emulator):
  ```powershell
  powershell -ExecutionPolicy Bypass -File tool\verify.ps1 -UnitOnly
  ```
* **Firestore Security Rules Only** (skip unit tests):
  ```powershell
  powershell -ExecutionPolicy Bypass -File tool\verify.ps1 -RulesOnly
  ```

## Why This Saves Tokens

1. **Compact Output**: Uses `flutter test --reporter=compact` and filters out redundant verbose stdout, outputting only 2-3 lines when all tests pass.
2. **Aggregated Results**: Summarizes Firestore emulator test output to a single confirmation line (`ALL X/X FIRESTORE RULES TESTS PASSED`).
3. **Error Isolation**: On failure, dumps only the relevant error stack trace (last 30 lines) so the agent can quickly diagnose and fix issues without overflowing context limits.
