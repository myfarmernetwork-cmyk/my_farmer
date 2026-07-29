# Lokalni dev run - ucitava tajne iz secrets.local.json.
# Primjer: .\scripts\run_dev.ps1 -d ZY22KN47QJ

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
  Write-Error "Nedostaje secrets.local.json - kopiraj secrets.local.json.example i popuni kljuceve."
}

$secrets = Get-Content $secretsPath -Raw | ConvertFrom-Json
$defines = @()

foreach ($prop in $secrets.PSObject.Properties) {
  $name = $prop.Name
  $value = [string]$prop.Value
  if ($serverOnlyKeys -contains $name) {
    continue
  }
  if ($value.Trim().Length -gt 0) {
    $defines += "--dart-define=${name}=$value"
  }
}

Push-Location $root
try {
  Write-Host "flutter run (dev)..."
  if ($args.Count -gt 0) {
    & flutter run @defines @args
  } else {
    & flutter run @defines
  }
} finally {
  Pop-Location
}
