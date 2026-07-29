# Generira android/upload-keystore.jks (alias: upload).
# Pokreni iz korijena projekta: .\android\create_upload_keystore.ps1
# Lozinke unosi interaktivno — iste stavi u android/key.properties.

$ErrorActionPreference = "Stop"
$androidDir = $PSScriptRoot
$keystorePath = Join-Path $androidDir "upload-keystore.jks"

if (Test-Path $keystorePath) {
    Write-Host "Keystore vec postoji: $keystorePath"
    exit 1
}

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $keytool) {
    $candidate = Join-Path $env:JAVA_HOME "bin\keytool.exe"
    if (Test-Path $candidate) { $keytool = $candidate } else { throw "keytool nije pronaden. Instaliraj JDK." }
} else {
    $keytool = $keytool.Source
}

Write-Host "Unesi lozinku za keystore (storePassword) — koristi istu u key.properties:"
& $keytool -genkeypair -v `
    -keystore $keystorePath `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -alias upload `
    -dname "CN=My Farmer, OU=Mobile, O=My Farmer Network, L=Sarajevo, ST=Federacija BiH, C=BA"

Write-Host ""
Write-Host "Gotovo. Ažuriraj android/key.properties s istim lozinkama."
