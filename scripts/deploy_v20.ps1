# Deploy Firestore rules + optional followerCount backfill + beta AAB (v20).
param(
  [switch]$SkipBackfill,
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Push-Location $root
try {
  Write-Host "=== 1/3 Firestore rules ==="
  firebase deploy --only firestore:rules
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  if (-not $SkipBackfill) {
    Write-Host ""
    Write-Host "=== 2/3 Follower count backfill ==="
    node scripts/backfill_follower_counts.js
    if ($LASTEXITCODE -ne 0) {
      Write-Warning @"
Backfill nije uspio (najcesce nedostaju ADC credentials).
Jednom pokreni: gcloud auth application-default login
Zatim: node scripts/backfill_follower_counts.js
Prati/unfollow u appu i dalje azurira brojace.
"@
    }
  } else {
    Write-Host "=== 2/3 Backfill preskocen ==="
  }

  if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "=== 3/3 Beta AAB build ==="
    & (Join-Path $PSScriptRoot "build_beta.ps1")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  } else {
    Write-Host "=== 3/3 Build preskocen ==="
  }

  Write-Host ""
  Write-Host "Gotovo."
} finally {
  Pop-Location
}
