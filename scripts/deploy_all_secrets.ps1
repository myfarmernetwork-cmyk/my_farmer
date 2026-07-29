# Postavlja sve Firebase Functions tajne iz secrets.local.json (jedan deploy).
# Prije: firebase login && firebase use my-farmer-552a3
# Poslije: firebase deploy --only functions

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$secretsPath = Join-Path $root "secrets.local.json"

if (-not (Test-Path $secretsPath)) {
  Write-Error "Nedostaje secrets.local.json"
}

$secrets = Get-Content $secretsPath -Raw | ConvertFrom-Json

function Set-FirebaseSecret {
  param([string]$Name, [string]$Value)
  if ($Value.Trim().Length -eq 0) {
    Write-Warning "Preskačem $Name (prazno u secrets.local.json)"
    return
  }
  Write-Host "Postavljam $Name..."
  $Value | firebase functions:secrets:set $Name
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$nirsApiKey = [string]$secrets.NIRS_API_KEY
if ($nirsApiKey.Trim().Length -eq 0) { $nirsApiKey = [string]$secrets.SENTINEL2_API_KEY }

$clientId = [string]$secrets.SENTINEL_HUB_CLIENT_ID
if ($clientId.Trim().Length -eq 0) { $clientId = [string]$secrets.SENTINEL2_API_KEY }

$clientSecret = [string]$secrets.SENTINEL_HUB_CLIENT_SECRET
if ($clientSecret.Trim().Length -eq 0) { $clientSecret = [string]$secrets.SENTINEL2_API_SECRET }

$plantIdKey = [string]$secrets.PLANT_ID_API_KEY

Push-Location (Join-Path $root "functions")
try {
  Write-Host "=== Firebase Functions secrets ==="

  Set-FirebaseSecret -Name "NIRS_API_KEY" -Value $nirsApiKey
  Set-FirebaseSecret -Name "SENTINEL_HUB_CLIENT_ID" -Value $clientId
  Set-FirebaseSecret -Name "SENTINEL_HUB_CLIENT_SECRET" -Value $clientSecret
  Set-FirebaseSecret -Name "PLANT_ID_API_KEY" -Value $plantIdKey
  Set-FirebaseSecret -Name "STRIPE_SECRET_KEY" -Value ([string]$secrets.STRIPE_SECRET_KEY)
  Set-FirebaseSecret -Name "PAYPAL_CLIENT_ID" -Value ([string]$secrets.PAYPAL_CLIENT_ID)
  Set-FirebaseSecret -Name "PAYPAL_CLIENT_SECRET" -Value ([string]$secrets.PAYPAL_CLIENT_SECRET)
  Set-FirebaseSecret -Name "PAYPAL_ENV" -Value ([string]$secrets.PAYPAL_ENV)

  Write-Host ""
  Write-Host "OK. Sljedeći korak:"
  Write-Host "  firebase deploy --only functions"
} finally {
  Pop-Location
}
