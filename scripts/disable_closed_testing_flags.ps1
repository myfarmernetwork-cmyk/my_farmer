# Gasenje test premiuma prije Production objave.
# Pokretanje (ako imas gcloud ADC): node scripts/disable_closed_testing_flags.js
# Inace: Firebase Console -> Firestore -> config -> app (ručno, vidi ispis ispod).

Write-Host ""
Write-Host "=== KORAK 1: Gasenje test premiuma (Firestore config/app) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Firebase Console: https://console.firebase.google.com/project/my-farmer-552a3/firestore"
Write-Host "Kolekcija: config  |  Dokument: app"
Write-Host ""
Write-Host "Postavi na FALSE (ili obrisi polja):" -ForegroundColor Yellow
Write-Host "  closedTestingFreeWeatherAlerts = false"
Write-Host "  closedTestingFreeChat          = false"
Write-Host "  closedTestingFreeVetIntake     = false"
Write-Host "  closedTestingFreePremium       = false   (ako postoji)"
Write-Host ""
Write-Host "Spremi dokument. Testeri gube besplatan premium odmah (bez novog AAB-a)."
Write-Host ""
