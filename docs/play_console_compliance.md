# My Farmer — Google Play Console (compliance checklist)

Reference for policy emails and release review. Update when Play policies change.

**App:** `com.myfarmer.network` · **targetSdk:** see `android/app/build.gradle.kts`

---

## 1. Privacy policy (mandatory)

| Where | Value |
|--------|--------|
| **Policy → App content → Privacy policy** | `https://myfarmernetwork-cmyk.github.io/my_farmer/` |
| **Build** | `PRIVACY_POLICY_URL` in `secrets.local.json` (enforced by `scripts/build_release.ps1`) |
| **In app** | Profil → Datenschutz + „Online-Version öffnen“ |

Web: DE / EN / HR. In-app: 9 sections + link to full web text.

---

## 2. Permissions declared in APK

| Permission | Used for | Play declaration |
|------------|----------|------------------|
| `INTERNET` | Firebase, maps, APIs | Standard |
| `CAMERA` | Plant scanner, product photos | Photos/videos — user-initiated |
| `ACCESS_FINE_LOCATION` | Marketplace radius, Google Maps, farm location, weather region | **Location — approximate/precise, foreground** |
| `ACCESS_COARSE_LOCATION` | Fallback / same features | Same form |
| `POST_NOTIFICATIONS` | Order/chat alerts | Notifications |

**Not used (no action):** Local Network, Manage Contacts, SMS, Call Log, MANAGE_EXTERNAL_STORAGE, background location, Accessibility tool.

---

## 3. Location — copy for Play Console (EN)

Use in **App content → Data safety** and **Location permission declaration** if asked:

> My Farmer uses location while the app is in use to show nearby marketplace listings and distances, display maps (vets, farm), set optional farm coordinates, and fetch weather for the user’s region. We do not collect location in the background. Coarse location is insufficient for map pin placement and consistent distance sorting; fine location is requested only when the user uses these features.

**DE (Kurzfassung):**

> Standort nur bei Nutzung der App: Umkreis auf dem Marktplatz, Entfernungen, Karten (Tierarzt, Hof), optionale Hofkoordinaten, Wetter für die Region. Kein Standort im Hintergrund.

**Future (targetSdk 37+, policy Jan 27, 2027):** one-time location via system location control where applicable; audit `geolocator` / Flutter when raising `targetSdk`.

Code: marketplace/weather use `LocationAccuracy.low` in `DeliveryService`; maps/parcels/vet use `medium` where needed.

---

## 4. Camera

> Camera access when the user takes a photo for the AI plant scanner or uploads product/listing images. Images are sent to our backend / Plant.id as described in the privacy policy.

---

## 5. Subscriptions (Google Play Billing + RevenueCat)

- Premium is a **digital feature** sold only through Google Play.
- Marketplace **product payments** are **peer-to-peer** (not processed by My Farmer).
- If you add **eligibility discounts** (e.g. student plans): disclose eligibility, verification, and price after eligibility ends (Play policy update).

---

## 6. Trader / business (EU)

From **November 2026**, declare **trader** status in Play Console if you sell to EU consumers (Gewerbe — My Farmer, contact in app/email).

Impressum / contact: business email signature (not stored in APK).

---

## 7. Japan payments

Only if you **distribute paid apps/IAP to Japan**: complete authorization by **December 1, 2026** or payouts may be held. Skip if Japan is not a target country.

---

## 8. Release build on PC

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_release.ps1
```

Requires: `REVENUECAT_ANDROID_KEY`, `PRIVACY_POLICY_URL`, NIRS URLs, no simulation flags.

---

## 9. After policy email (general)

Most bulk Play emails do **not** require immediate app changes. Review only sections that match permissions/features you use. My Farmer typically needs attention on: **location**, **privacy URL**, **trader**, **subscriptions wording** — not on Local Network / Contacts / SMS.
