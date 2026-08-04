# Postavi Plant.id API kljuc na Firebase i redeploy identifyPlant funkcije.
# Prije: u secrets.local.json postavi valjan PLANT_ID_API_KEY s https://admin.kindwise.com
# Prije: firebase login && firebase use my-farmer-552a3

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$secretsPath = Join-Path $root "secrets.local.json"

if (-not (Test-Path $secretsPath)) {
  Write-Error "Nedostaje secrets.local.json"
}

$plantIdKey = [string](Get-Content $secretsPath -Raw | ConvertFrom-Json).PLANT_ID_API_KEY
if ($plantIdKey.Trim().Length -lt 20) {
  Write-Error "PLANT_ID_API_KEY u secrets.local.json je prazan ili prekratak. Dohvati kljuc s Plant.id / Kindwise admin panela."
}

Write-Host "Postavljam PLANT_ID_API_KEY na Firebase (my-farmer-552a3)..."
$plantIdKey | firebase.cmd functions:secrets:set PLANT_ID_API_KEY --project my-farmer-552a3
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Deploy identifyPlant funkcije..."
Push-Location (Join-Path $root "functions")
try {
  firebase.cmd deploy --only functions:identifyPlant --project my-farmer-552a3
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
  Pop-Location
}

Write-Host ""
Write-Host "OK. Skener bi trebao raditi u appu (Cloud Function + Plant.id kljuc)."
Write-Host "Test: AI skener -> fotografija -> Analiziraj. Nema potrebe za novim APK-om."
