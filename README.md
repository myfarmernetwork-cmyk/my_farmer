# My Farmer

Flutter marketplace app for farmers, buyers, veterinarians, and agribusiness.

**Package:** `com.myfarmer.network`  
**Firebase:** `my-farmer-552a3`

## Privacy policy (GitHub Pages)

Hosted HTML (EN + DE): `docs/index.html`

After publishing on GitHub Pages, set in `secrets.local.json`:

```json
"PRIVACY_POLICY_URL": "https://YOUR_USERNAME.github.io/my_farmer/"
```

Use the same URL in **Play Console → App content → Privacy policy**.

## Quick start (development)

```powershell
# 1. Secrets
Copy-Item secrets.local.json.example secrets.local.json
# Edit secrets.local.json — at minimum REVENUECAT_ANDROID_KEY for subscriptions

# 2. Run on device
.\scripts\run_dev.ps1 -d YOUR_DEVICE_ID
```

## Play Store — Closed beta

1. **Privacy policy URL** — host `assets/translations` privacy text on a public page (Notion, GitHub Pages, your site). Set `PRIVACY_POLICY_URL` in `secrets.local.json`.
2. **Play Console** — create app, complete Data safety + Content rating + Target audience.
3. **Build AAB:**
   ```powershell
   .\scripts\build_beta.ps1
   ```
   Output: `build\app\outputs\bundle\release\app-release.aab`
4. Upload to **Testing → Closed testing** and add tester emails.
5. Beta build uses `BETA_FREE_PREMIUM=true` — testers get Premium without Play billing.

## Play Store — Production release

1. Create subscriptions in Play Console (IDs must match `lib/config/revenuecat_config.dart`):
   - `premium_buyer_monthly`, `premium_hobby_monthly`, `premium_pro_monthly`
   - `license_vet_monthly`, `license_pharmacy_monthly`, `scan_topup_pack`
2. Link Play ↔ RevenueCat, configure entitlement `premium`.
3. Deploy Firebase backend:
   ```powershell
   .\scripts\deploy_all_secrets.ps1
   firebase.cmd deploy --only functions,firestore:rules,firestore:indexes
   ```
4. **Build production AAB** (no free premium):
   ```powershell
   .\scripts\build_release.ps1
   ```
5. Store listing: icon (512×512), feature graphic (1024×500), 2+ screenshots, short/long description.
6. Lawyer review of marketplace terms + privacy policy before wide EU launch.

## Legal & account features (in-app)

| Feature | Location |
|---------|----------|
| Marketplace terms | Profile → Uvjeti tržnice |
| Privacy policy | Profile → Politika privatnosti |
| Account deletion | Profile → Obriši račun |
| Registration consent | Checkbox on sign-up |
| Roles & subscriptions PDF | Profile |
| Beta tester guide PDF | Profile |

## Signing

Upload keystore: `android/upload-keystore.jks` + `android/key.properties` (gitignored).  
Create keystore: `.\android\create_upload_keystore.ps1`

## Version

Set in `pubspec.yaml`: `version: 1.0.0+2` (name+build number). Android uses Flutter values from `local.properties` at build time.

## Marketplace payments

Peer-to-peer only (cash, direct PayPal, bank transfer). Platform does not process buyer→seller money. Premium subscriptions use Google Play via RevenueCat.

## Troubleshooting

**PowerShell blocks `firebase`:** use `firebase.cmd` instead of `firebase`.

**Gradle / build fails:** run `flutter clean` then rebuild.

**Account deletion:** requires deployed Cloud Functions `requestAccountDeletion` and `purgeScheduledAccountDeletions`.
