# Postavlja NIRS/Sentinel Hub tajne na Firebase Functions (iz secrets.local.json).
# Pokreni jednom prije: firebase login && firebase use my-farmer-552a3
# Zatim deploy: firebase deploy --only functions:fetchNirsNdvi

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$secretsPath = Join-Path $root "secrets.local.json"

if (-not (Test-Path $secretsPath)) {
  Write-Error "Nedostaje secrets.local.json"
}

$secrets = Get-Content $secretsPath -Raw | ConvertFrom-Json

$nirsApiKey = [string]$secrets.NIRS_API_KEY
if ($nirsApiKey.Trim().Length -eq 0) {
  $nirsApiKey = [string]$secrets.SENTINEL2_API_KEY
}

$clientId = [string]$secrets.SENTINEL_HUB_CLIENT_ID
if ($clientId.Trim().Length -eq 0) {
  $clientId = [string]$secrets.SENTINEL2_API_KEY
}

$clientSecret = [string]$secrets.SENTINEL_HUB_CLIENT_SECRET
if ($clientSecret.Trim().Length -eq 0) {
  $clientSecret = [string]$secrets.SENTINEL2_API_SECRET
}

if ($nirsApiKey.Trim().Length -eq 0 -or $clientId.Trim().Length -eq 0 -or $clientSecret.Trim().Length -eq 0) {
  Write-Error "Popuni NIRS_API_KEY, SENTINEL_HUB_CLIENT_ID i SENTINEL_HUB_CLIENT_SECRET u secrets.local.json"
}

Push-Location (Join-Path $root "functions")
try {
  Write-Host "Postavljam Firebase secrets za fetchNirsNdvi..."
  $nirsApiKey | firebase functions:secrets:set NIRS_API_KEY
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  $clientId | firebase functions:secrets:set SENTINEL_HUB_CLIENT_ID
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  $clientSecret | firebase functions:secrets:set SENTINEL_HUB_CLIENT_SECRET
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Write-Host "OK. Sada pokreni: firebase deploy --only functions:fetchNirsNdvi"
} finally {
  Pop-Location
}
