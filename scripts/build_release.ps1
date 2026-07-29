# Play Store release build — učitava tajne iz secrets.local.json (ne ide u git).
# 1. Kopiraj secrets.local.json.example -> secrets.local.json
# 2. Popuni ključeve
# 3. .\scripts\build_release.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$secretsPath = Join-Path $root "secrets.local.json"

# Ključevi samo za Firebase Functions — nikad u APK (--dart-define).
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
  Write-Error "Nedostaje secrets.local.json — kopiraj secrets.local.json.example i popuni ključeve."
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
    Write-Warning "REVENUECAT_SIMULATION=true — ignorirano za release build."
    continue
  }
  if ($name -eq "BETA_FREE_PREMIUM" -and $value.Trim().ToLower() -eq "true") {
    Write-Warning "BETA_FREE_PREMIUM=true — ignorirano za produkcijski release build."
    continue
  }
  if ($name -eq "PAYMENT_SIMULATION" -and $value.Trim().ToLower() -eq "true") {
    Write-Warning "PAYMENT_SIMULATION=true — ignorirano za release build."
    continue
  }
  if ($name -eq "NIRS_USE_LIVE_API" -and $value.Trim().ToLower() -eq "false") {
    Write-Warning "NIRS_USE_LIVE_API=false — ignorirano za release build (forsira se true)."
    continue
  }

  if ($value.Trim().Length -gt 0) {
    $defines += "--dart-define=${name}=$value"
  }
}

$rcKey = [string]$secrets.REVENUECAT_ANDROID_KEY
if ($rcKey.Trim().Length -eq 0) {
  Write-Error "REVENUECAT_ANDROID_KEY je obavezan u secrets.local.json."
}

$nirsUrl = [string]$secrets.SENTINEL2_API_BASE_URL
$nirsKey = [string]$secrets.SENTINEL2_API_KEY
if ($nirsUrl.Trim().Length -eq 0 -or $nirsKey.Trim().Length -eq 0) {
  Write-Error "SENTINEL2_API_BASE_URL i SENTINEL2_API_KEY su obavezni za live NIRS u release buildu."
}
if ($nirsUrl -match "sentinel-hub\.com/?$") {
  Write-Error "SENTINEL2_API_BASE_URL mora biti Firebase funkcija fetchNirsNdvi, ne sentinel-hub.com."
}

$defines += "--dart-define=REVENUECAT_SIMULATION=false"
$defines += "--dart-define=PAYMENT_SIMULATION=false"
$defines += "--dart-define=NIRS_USE_LIVE_API=true"
$defines += "--dart-define=PLANT_SCANNER_USE_CLOUD=true"

Push-Location $root
try {
  Write-Host "Building appbundle (release, live RevenueCat + NIRS + Plant.id cloud)..."
  $cmd = @("flutter", "build", "appbundle", "--release") + $defines
  & $cmd[0] $cmd[1..($cmd.Length - 1)]
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Write-Host "OK: build\app\outputs\bundle\release\app-release.aab"
} finally {
  Pop-Location
}
