# SortScape release checklist

## Local candidate

- Bundle ID: `com.sortscape.puzzleworlds`; display name: SortScape.
- Marketing version/build: **1.0.0 (2)** in XcodeGen. Verify build-number uniqueness
  in App Store Connect before upload and increment for each subsequent upload.
- Release targets iOS 17+, portrait on iPhone, all four orientations on iPad.
  Validate iPad layouts and supply the required 13-inch screenshots.
- The AppIcon catalog uses original 1024px art. Verify generated icons, required
  screenshots, safe areas and complete storefront metadata on the final candidate.
- Keep Release ads **NO**, purchases **false**, and Analytics/Crashlytics collection
  **false** until the appropriate reviewed configurations are ready. The adapter
  supports only official Google test ad units; no production ad placement is enabled.
- No local StoreKit fixtures, debug probes, credentials, or development Firebase
  plist in Release. Keep dSYMs with every archive. Production Firebase config is
  private and optional; SDK compilation does not establish collection or delivery.

## Apple Developer / App Store Connect actions

- [ ] Confirm the intended team owns the explicit bundle ID and create/select the
  App Store Connect iOS record. Verify roles and current agreements.
- [ ] Select the team in Xcode Signing & Capabilities or set `DEVELOPMENT_TEAM` in
  private build settings. Provision App Store distribution credentials/profile
  (or configure Xcode-managed signing). This Mac has a development identity but
  no local distribution identity or matching provisioning profile was found.
- [ ] Supply public privacy policy and support URLs, review contact details, beta
  feedback email, description, keywords, category, screenshots, and review notes.
- [ ] Complete the age-rating questionnaire, export compliance, privacy disclosures,
  accessibility disclosures as applicable, and any market-specific requirements.
  Review SDK manifests and actual enabled data collection; do not infer “no data”
  from consent defaults or treat the manifest as the App Store privacy questionnaire.
- [ ] If enabling IAP later, set up agreements/tax/banking and replace placeholder
  products with configured products. Verify sandbox metadata and flows before
  enabling Release purchasing. Use a separate QA configuration for test ads.
- [ ] Supply private Firebase environment files if reporting is part of the beta;
  verify actual consent and symbolicated diagnostic delivery. If deliberately
  shipping with reporting unavailable, document that product decision explicitly.

## Archive and upload, only after approval

1. Open `SortScape.xcodeproj` (the main project), select scheme SortScape and
   **Any iOS Device**, and confirm Archive uses Release. Resolve Swift packages.
   Do not share a `-clonedSourcePackagesDirPath` with the offline project; resolving
   the smaller package graph can remove binary artifacts the main build needs.
2. Configure the intended signing team/profile, check versions and settings, 
   confirm Apple accepts the installed Xcode/SDK for the intended upload, then
   choose **Product → Archive**. Equivalent local archive command, with signing
   already configured:

   ```sh
   xcodebuild -project SortScape.xcodeproj -scheme SortScape \
     -configuration Release -destination 'generic/platform=iOS' \
     -archivePath DerivedDataPhase10/SortScape-Signed.xcarchive archive
   ```

3. Inspect the archive and dSYMs. In Organizer, use **Validate App** where available
   and resolve signing/entitlement/metadata errors. Keep the tested archive.
4. After explicit upload approval, select the signed archive in Organizer →
   **Distribute App** → **App Store Connect**, choose the upload workflow and the
   intended distribution scope, review the signing/version choices, and upload.
   Wait for processing and verify the exact version/build in TestFlight.
5. Separately authorize tester distribution. Configure test information and
   compliance answers, assign the build to an internal group, then request Beta
   App Review if required for external testing. App Store submission is separate.

Official Apple references: [Xcode TestFlight workflow](https://help.apple.com/xcode/mac/current/en.lproj/dev2539d985f.html),
[upload and processing](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/),
[privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/),
and [age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/).

No upload, tester invitation, registration, or submission was performed.

## Phase 10 submission gates

- [x] Validate 100/100 campaign solutions and prepare initial metadata and launch plan.
- [x] Build the Firebase-linked local unsigned device archive:
  `DerivedDataPhase10/SortScape-Launch.xcarchive`. Inspect Release artifact flags.
- [x] Separate Release from development overrides; strip the placeholder catalog
  and compile out test ad unit loads. The linked SDK keeps an inert sample app ID.
- [ ] Owner supplies the approved public policy URL via
  `SORTSCAPE_PRIVACY_POLICY_URL`, confirms the in-app link, and supplies support URL.
- [ ] Owner selects the team and provisions a signed archive, completes account
  metadata, disclosures and app review notes. No distribution identity was found.
- [ ] Validate the signed candidate, complete physical-device beta and review
  evidence. No TestFlight distribution evidence exists.
- [ ] Confirm screenshots and final free scope. Production IAP/AdMob are separate
  launches requiring approved identifiers, device QA and disclosure updates.
- [ ] Decide whether reporting is unavailable at launch or provide production
  Firebase config and verify opted-in event delivery and crash symbolication.
- [ ] Obtain explicit permission before any upload, distribution or submission.

See APP_STORE_SUBMISSION.md for the privacy/SDK review and reviewer notes,
APP_STORE_METADATA.md for store copy and Documentation/AppStoreScreenshots
for captures. The unsigned archive is not a submission-ready artifact.

Verified local evidence: 100/100 campaign solutions, 100 distinct passing
XCTest cases across the documented split runs, and native large-iPhone/iPad
capture sets. Run `Tools/CheckLaunchArchive.py` on the local archive; add
`--submission-preflight` to check team/signing metadata and in-app policy URL
before Organizer validation. The current preflight fails those two checks.
