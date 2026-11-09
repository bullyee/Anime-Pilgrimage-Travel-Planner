param(
  [switch]$All,
  [switch]$WithEmulator,
  [switch]$RulesOnly,
  [switch]$UnitOnly
)

# Prerequisites:
# 1. Flutter SDK
# 2. (For Firestore emulator rules tests):
#    - Firebase CLI (`firebase`)
#    - Python 3 (`python`)
#    - JDK 21 / JBR (Java 21 from Android Studio `jbr` or standalone JDK 21)

$ErrorActionPreference = "Continue"
Write-Host "=== TRIP PLANNER FAST VERIFIER ===" -ForegroundColor Cyan

$runUnit = $true
$runRules = $false

if ($RulesOnly) {
  $runUnit = $false
  $runRules = $true
} elseif ($All -or $WithEmulator) {
  $runUnit = $true
  $runRules = $true
} elseif ($UnitOnly) {
  $runUnit = $true
  $runRules = $false
} else {
  # Default is UnitOnly to avoid triggering the Windows Firewall prompt on java.exe
  $runUnit = $true
  $runRules = $false
}

# 1. Flutter Unit Tests
if ($runUnit) {
  Write-Host "[1/2] Running Flutter Unit Tests..." -ForegroundColor Yellow
  $testOutput = flutter test --reporter=failures-only 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Flutter unit tests failed!" -ForegroundColor Red
    $testOutput | Select-Object -Last 30
    exit 1
  }
  $passLine = ($testOutput | Where-Object { $_ -match "All tests passed" } | Select-Object -Last 1)
  if (-not $passLine) {
    $passLine = ($testOutput | Select-Object -Last 2) -join "`n"
  }
  Write-Host "[PASS] Flutter tests: $passLine" -ForegroundColor Green
}

# 2. Firestore Emulator Rules Tests
if ($runRules) {
  Write-Host "[2/2] Running Firestore Rules Tests on Emulator..." -ForegroundColor Yellow

  # Locate Java 21 / JBR
  if (-not $env:JAVA_HOME -or -not (Test-Path "$env:JAVA_HOME\bin\java.exe")) {
    $candidatePaths = @(
      "$env:ProgramFiles\Android\Android Studio\jbr",
      "$env:ProgramFiles\Android\Android Studio1\jbr",
      "$env:LOCALAPPDATA\Programs\Android Studio\jbr",
      "$env:ProgramFiles\Java\jdk-21"
    )
    if (Test-Path "$env:ProgramFiles\Android") {
      $asDirs = Get-ChildItem "$env:ProgramFiles\Android" -Directory -Filter "Android Studio*" -ErrorAction SilentlyContinue
      foreach ($d in $asDirs) {
        $jbr = Join-Path $d.FullName "jbr"
        if ($candidatePaths -notcontains $jbr) {
          $candidatePaths += $jbr
        }
      }
    }

    $found = $null
    foreach ($path in $candidatePaths) {
      if (Test-Path "$path\bin\java.exe") {
        $found = $path
        break
      }
    }
    if ($found) {
      $env:JAVA_HOME = $found
    } else {
      Write-Host "[FAIL] Java 21 / JBR not found. Please set JAVA_HOME to a JDK 21 / JBR directory containing bin\java.exe." -ForegroundColor Red
      exit 1
    }
  }

  $env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

  $rulesOutput = firebase emulators:exec --project trip-planner-2775c --only firestore "python test/rules_v2_emulator_test.py" 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Firestore rules tests failed!" -ForegroundColor Red
    $rulesOutput | Select-Object -Last 30
    exit 1
  }

  $passLine = $rulesOutput | Where-Object { $_ -match "ALL \d+/\d+ FIRESTORE RULES TESTS PASSED" } | Select-Object -First 1
  if (-not $passLine) {
    Write-Host "[FAIL] Firestore rules tests did not report a valid pass line!" -ForegroundColor Red
    $rulesOutput | Select-Object -Last 30
    exit 1
  }
  Write-Host "[PASS] $passLine" -ForegroundColor Green
} else {
  Write-Host "(Skipped Firestore rules emulator tests to avoid firewall prompts. Pass -WithEmulator or -RulesOnly to run them.)" -ForegroundColor Gray
}

Write-Host "=== ALL CHECKS PASSED ===" -ForegroundColor Green
