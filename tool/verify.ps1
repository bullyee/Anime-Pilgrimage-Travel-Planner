param(
  [switch]$Fast,
  [switch]$RulesOnly,
  [switch]$UnitOnly
)

$ErrorActionPreference = "Continue"
Write-Host "=== TRIP PLANNER FAST VERIFIER ===" -ForegroundColor Cyan

# 1. Flutter Unit Tests
if (-not $RulesOnly) {
  Write-Host "[1/2] Running Flutter Tests..." -ForegroundColor Yellow
  $testOutput = flutter test --reporter=compact 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Flutter tests failed!" -ForegroundColor Red
    $testOutput | Select-Object -Last 30
    exit 1
  }
  $lastLine = ($testOutput | Select-Object -Last 2) -join "`n"
  Write-Host "[PASS] Flutter tests passed:`n$lastLine" -ForegroundColor Green
}

# 2. Firestore Emulator Rules Tests
if (-not $UnitOnly) {
  Write-Host "[2/2] Running Firestore Rules Tests on Emulator..." -ForegroundColor Yellow
  $env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
  $env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
  $rulesOutput = firebase emulators:exec --only firestore "python test/rules_v2_emulator_test.py" 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Firestore rules tests failed!" -ForegroundColor Red
    $rulesOutput | Select-Object -Last 30
    exit 1
  }
  $passLine = $rulesOutput | Where-Object { $_ -match "ALL \d+/\d+ FIRESTORE RULES TESTS PASSED" }
  Write-Host "[PASS] $passLine" -ForegroundColor Green
}

Write-Host "=== ALL CHECKS PASSED ===" -ForegroundColor Green
