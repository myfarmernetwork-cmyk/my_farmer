# My Farmer — release checklist (Play Store)

Pročitaj prije svakog novog AAB builda. Sprečava ponavljanje problema iz buildova 64–69.

## Prije builda na PC-u

- [ ] `pubspec.yaml` i `lib/config/app_version.dart` imaju **isti** broj (npr. `1.0.0+70`)
- [ ] **Povećaj `versionCode`** (+1) — Play ne prihvaća isti broj dva puta
- [ ] `flutter analyze` na kritičnim datotekama (startup, seller, auth)
- [ ] Build samo preko: `powershell -ExecutionPolicy Bypass -File .\scripts\build_release.ps1`

## Play Console — politika i sadržaj (2026–2027)

Detaljno: **`docs/play_console_compliance.md`**

- [ ] **Policy → App content → Privacy policy**  
      URL: `https://myfarmernetwork-cmyk.github.io/my_farmer/`
- [ ] **Data safety** usklađen s appom (lokacija, kamera, email, Firebase, RevenueCat)
- [ ] **Location (ACCESS_FINE_LOCATION)** — deklaracija: tržnica u radijusu, karta, koordinate hofa, vrijeme (nema background GPS)
- [ ] **Camera** — AI skener biljaka, slike proizvoda (korisnik pokreće)
- [ ] **Trader status** (EU) — u Console od **studeni 2026** (Gewerbe / Siniša Depčinski, Gerabronn)
- [ ] **Japan** — samo ako prodaješ u Japan; autorizacija do **1. 12. 2026**
- [ ] **Subscriptions** — jasan opis Premium u Play listing / paywall (nema „student plan“ bez eligibility teksta)
- [ ] **API 37+ / 2027** — kad podigneš `targetSdk` 37: location button za jednokratne zahtjeve; deklaracija fine location obavezna do **27. 1. 2027**

My Farmer **nema**: Local Network, Manage Contacts, SMS/Call Log, MANAGE_EXTERNAL_STORAGE, Accessibility tool.

## Play Console / potpis

- [ ] Upload keystore: `android/upload-keystore.jks` + `android/key.properties` (gitignored)
- [ ] SHA-256 upload ključa registriran u **Android-Entwicklerbestätigung** (status **Bestätigt**)
- [ ] AAB potpis provjera: `keytool -list -v -keystore android/upload-keystore.jks -alias upload`
- [ ] Nakon uploada: **Start rollout** (ne ostavljati Draft)

## Test uređaji — što NE raditi

- [ ] **NE** `flutter run` / Debug na telefonu/tabletu koji testira Play verziju (USB kabl)
  - Debug prepisuje Play app → nema Play linka → update ne radi
- [ ] **NE** ručni APK na uređaje s Play instalacijom
- [ ] Test telefoni: samo **Closed test link** → instalacija s Google Playa
- [ ] Ako update ne prolazi: **deinstaliraj** → instaliraj iznova s test linka (ne forsirati update)

## Poznati bugovi koje smo fixali (ne vraćati)

### Startup treptanje (+67/+69)
- `FirestoreCacheService`: **ne** zvati `terminate()` na cold startu
- `AuthGate`: stabilni `ValueKey` po `user.uid` na shell widgetima
- `MainNavigationScreen`: **ne** prekrivati UI spinnerom kad provideri reloadaju u pozadini
- `LocationRequiredGate`: session cache `_sessionGrantedUid` — GPS provjera jednom po sesiji

### UI / boje (+71)
- Tržište: `MarketplaceProductCard` — puna slika, smeđi glass overlay, prodavač ostaje
- Akcent smeđa: `lib/theme/agro_accent_colors.dart` (ne narandžasta za košaricu/potvrdu)
- Donji tabovi se **ne diraju**
- Firestore stream **u `initState`**, ne unutar `build()`
- `StreamBuilder`: spinner samo kad `waiting && !snapshot.hasData`
- Razlog: `navigationBadgesProvider` rebuilda ekran → novi stream = spinner petlja

### Play upload blokiran
- Novi upload ključ mora biti u Console prije objave AAB-a

## Nakon rollouta (15–60 min)

- [ ] Play Store → My Farmer → verzija (**Info o aplikaciji** → build broj)
- [ ] **Detalji u trgovini Google Play** postoji (potvrda Play instalacije)
- [ ] App start stabilan (bez treptanja)
- [ ] Tab **Moji proizvodi** stabilan (lista + vremenski banner)
- [ ] Tablet i telefon na **istom** Google tester računu

## Brza provjera verzije na uređaju

Play Store → My Farmer → App info → verzija mora odgovarati zadnjem objavljenom buildu (npr. 70).
