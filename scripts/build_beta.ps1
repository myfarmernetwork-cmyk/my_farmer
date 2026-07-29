# Closed testing (Play Store beta) - release AAB s besplatnim Premiumom za testere.
# 1. Kopiraj secrets.local.json.example -> secrets.local.json
# 2. Postavi REVENUECAT_ANDROID_KEY i PRIVACY_POLICY_URL
# 3. powershell -ExecutionPolicy Bypass -File .\scripts\build_beta.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$secretsPath = Join-Path $root "secrets.local.json"

$serverOnlyKeys = @(
  "SENTINEL_HUB_CLIENT_ID",
  "SENTINEL_HUB_CLIENT_SECRET",
  "SENTINEL2_API_SECRET",
  "NIRS_API_KEY",
  "PLANT_ID_API_KEY",
  "STRIPE_SECRET_KEY",
  "PAYPAL_CLIENT_SECRET",
  "PAYPAL_ENV"
)

if (-not (Test-Path $secretsPath)) {
  Write-Error "Nedostaje secrets.local.json - kopiraj secrets.local.json.example i postavi REVENUECAT_ANDROID_KEY."
}

$secrets = Get-Content $secretsPath -Raw | ConvertFrom-Json
$defines = @()

foreach ($prop in $secrets.PSObject.Properties) {
  $name = $prop.Name
  $value = [string]$prop.Value

  if ($serverOnlyKeys -contains $name) {
    continue
  }

  # Beta build forsira ove flagove — ne ucitava iz secrets.
  if ($name -in @(
      "REVENUECAT_SIMULATION",
      "BETA_FREE_PREMIUM",
      "PAYMENT_SIMULATION",
      "NIRS_USE_LIVE_API",
      "PLANT_SCANNER_USE_CLOUD"
    )) {
    continue
  }

  if ($value.Trim().Length -gt 0) {
    $defines += "--dart-define=${name}=$value"
  }
}

$rcKey = [string]$secrets.REVENUECAT_ANDROID_KEY
if ($rcKey.Trim().Length -eq 0) {
  Write-Error "REVENUECAT_ANDROID_KEY je obavezan u secrets.local.json (npr. goog_xxx)."
}

$defines += "--dart-define=REVENUECAT_ANDROID_KEY=$rcKey"
$defines += "--dart-define=REVENUECAT_SIMULATION=false"
$defines += "--dart-define=BETA_FREE_PREMIUM=true"
$defines += "--dart-define=PAYMENT_SIMULATION=false"
$defines += "--dart-define=NIRS_USE_LIVE_API=true"
$defines += "--dart-define=PLANT_SCANNER_USE_CLOUD=true"

$privacyUrl = [string]$secrets.PRIVACY_POLICY_URL
if ($privacyUrl.Trim().Length -eq 0) {
  Write-Warning "PRIVACY_POLICY_URL nije postavljen — link Politika privatnosti u appu nece raditi u ovom buildu."
}

Push-Location $root
try {
  Write-Host "Building appbundle (closed beta)..."
  flutter build appbundle --release @defines
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Write-Host ""
  Write-Host "OK: build\app\outputs\bundle\release\app-release.aab"
  Write-Host "Upload u Play Console, Testing, Closed testing"
} finally {
  Pop-Location
}
