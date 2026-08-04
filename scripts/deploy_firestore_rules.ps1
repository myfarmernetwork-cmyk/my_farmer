# Deploy Firestore security rules (followers, followerCount, etc.)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Push-Location $root
try {
  Write-Host "Deploying firestore.rules to Firebase..."
  firebase deploy --only firestore:rules
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Write-Host "OK: Firestore rules deployed."
} finally {
  Pop-Location
}
