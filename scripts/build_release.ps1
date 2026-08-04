# Play Store release build - loads secrets from secrets.local.json (not in git).
# 1. Copy secrets.local.json.example -> secrets.local.json
# 2. Fill in keys
# 3. .\scripts\build_release.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$secretsPath = Join-Path $root "secrets.local.json"

# Keys for Firebase Functions only - never in APK (--dart-define).
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
  Write-Error "Missing secrets.local.json - copy secrets.local.json.example and fill keys."
}

$secrets = Get-Content $secretsPath -Raw | ConvertFrom-Json
$defines = @()

foreach ($prop in $secrets.PSObject.Properties) {
  $name = $prop.Name
  $value = [string]$prop.Value

  if ($serverOnlyKeys -contains $name) {
    continue
  }

  if ($name -eq "REVENUECAT_SIMULATION" -and $value.Trim().ToLower() -eq "true") {
    Write-Warning "REVENUECAT_SIMULATION=true ignored for release build."
    continue
  }
  if ($name -eq "BETA_FREE_PREMIUM" -and $value.Trim().ToLower() -eq "true") {
    Write-Warning "BETA_FREE_PREMIUM=true ignored for production release build."
    continue
  }
  if ($name -eq "PAYMENT_SIMULATION" -and $value.Trim().ToLower() -eq "true") {
    Write-Warning "PAYMENT_SIMULATION=true ignored for release build."
    continue
  }
  if ($name -eq "NIRS_USE_LIVE_API" -and $value.Trim().ToLower() -eq "false") {
    Write-Warning "NIRS_USE_LIVE_API=false ignored for release build (forced true)."
    continue
  }

  if ($value.Trim().Length -gt 0) {
    $defines += "--dart-define=${name}=$value"
  }
}

$rcKey = [string]$secrets.REVENUECAT_ANDROID_KEY
if ($rcKey.Trim().Length -eq 0) {
  Write-Error "REVENUECAT_ANDROID_KEY is required in secrets.local.json."
}

$nirsUrl = [string]$secrets.SENTINEL2_API_BASE_URL
$nirsKey = [string]$secrets.SENTINEL2_API_KEY
if ($nirsUrl.Trim().Length -eq 0 -or $nirsKey.Trim().Length -eq 0) {
  Write-Error "SENTINEL2_API_BASE_URL and SENTINEL2_API_KEY are required for live NIRS."
}
if ($nirsUrl -match "sentinel-hub\.com/?$") {
  Write-Error "SENTINEL2_API_BASE_URL must be Firebase fetchNirsNdvi, not sentinel-hub.com."
}

$defines += "--dart-define=REVENUECAT_SIMULATION=false"
$defines += "--dart-define=PAYMENT_SIMULATION=false"
$defines += "--dart-define=NIRS_USE_LIVE_API=true"
$defines += "--dart-define=PLANT_SCANNER_USE_CLOUD=true"

Push-Location $root
try {
  Write-Host "Building appbundle release..."
  $cmd = @("flutter", "build", "appbundle", "--release") + $defines
  & $cmd[0] $cmd[1..($cmd.Length - 1)]
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Write-Host "OK: build\app\outputs\bundle\release\app-release.aab"
} finally {
  Pop-Location
}
