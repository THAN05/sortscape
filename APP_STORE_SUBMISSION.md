# App Store submission preparation

No account changes, upload, submission, or publishing authorized by this document.
Use the verified free, ads-off scope until monetization is independently approved.

1. **Account owner:** confirm program membership, agreements, roles and ownership
   of explicit bundle ID `com.sortscape.puzzleworlds`. Create/select its iOS record,
   enter name, primary language, internal SKU, and appropriate category. Confirm
   storefront availability and pricing; recommended first release is free.
2. **Signing:** select the intended team and obtain distribution provisioning or
   Xcode-managed signing. Check accepted Xcode/SDK versions before distribution.
   Set the approved public privacy URL with `SORTSCAPE_PRIVACY_POLICY_URL` and
   verify Settings → Analytics and diagnostics → Privacy policy on the candidate.
   Confirm the app’s version/build is unused in the account.
3. **Product page:** use APP_STORE_METADATA.md, owner-approved support/privacy
   URLs, and selected real screenshots. Validate screenshot dimensions against
   the [current screenshot requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).
   iPad is retained, so the required 13-inch screenshot slot applies.
4. **Disclosures:** complete age rating, App Privacy, encryption/export compliance,
   content rights, accessibility claims, review contact and applicable territory
   requirements. Produce Organizer’s privacy report for the signed candidate
   and reconcile manifests with SDK configuration and observed network behavior.
5. **Purchases:** leave IAP off and omit all local QA products from this version.
   For a future monetized build, arrange Paid Apps agreements/tax/banking, configure
   consumable coins/hints and non-consumable Remove Ads, bundle and theme, match
   identifiers exactly, verify localized price and type, test in sandbox, and
   submit products per Apple's first-IAP review workflow. Placeholder identifiers
   from the local fixture are not App Store Connect evidence.
6. **Build:** archive the main Release scheme, sign with the owner’s team, validate
   in Organizer and retain app/dSYM UUIDs. Run on-device smoke checks and
   resolve packaging blockers. When separately authorized, upload through
   Organizer → Distribute App → App Store Connect. Wait for processing and verify
   the exact build. TestFlight internal/external assignment is a separate action;
   after approval and assignment, run the physical-device beta plan.
7. **Review:** after beta exit criteria and explicit approval, select the processed build, attach
   metadata and reviewer notes, select manual release, add for review and submit.
   Review approval does not itself authorize publishing.

## Reviewer notes draft — ads-off and purchase-off candidate

SortScape is an offline color-sorting puzzle game. No login is required. Tap
“Begin your escape,” then tap a vessel and a compatible destination. Free Undo,
Restart, and Hint are available during play. Clear worlds to earn coins and
stars; use “My island” to restore features as plans unlock. To see recovery,
make a legal move, close the app, and reopen the same world.

This build does not serve ads or offer in-app purchases. The local test storefront
is not exposed. Reporting is optional and off by default; without a
Firebase project configuration it is unavailable. All worlds and restoration
can be completed without payment or optional data collection. No review login
or external hardware is needed.

## Privacy and commerce assessment

- Apple guideline 5.1.1 requires a reachable policy in metadata and in the app.
  The policy should describe collection, purposes, recipients, retention/deletion,
  withdrawal and contact. Document local saves, purchase history if enabled, and
  the optional reporting configuration actually shipped. Do not invent retention
  periods or use a generic SDK policy in place of the owner's policy.
- The candidate does not request ATT or use a configured tracking workflow.
  Apple requires authorization for tracking or IDFA access, including relevant
  SDK behavior. UMP is a separate consent mechanism and is not ATT authorization.
  Do not enable a tracking feature without a separate review and appropriate consent.
- Source audit: Debug UMP refreshes consent, presents required forms, exposes
  privacy options where required, checks `canRequestAds` before load/presentation
  and discards loaded ads on withdrawal. Mock tests verify gates; no real regional
  UMP message or ad creative is verified. No production ad units are configured.
- Google Mobile Ads 13.12.0 may collect device/advertising data, approximate
  location from IP, interaction, performance and diagnostics when used. Local
  publisher/consent flags are not proof of no collection. Inspect the actual
  release SDK report and verify behavior before claiming a privacy label.
- Firebase Analytics Core and Crashlytics are linked. There is no production
  plist supplied. If enabled later, review app-instance identifiers, gameplay
  events, diagnostics, breadcrumbs when applicable, and processor retention.
  Separate analytics/crash opt-ins and revoke flows do not establish console
  delivery or legal compliance. No production reporting was verified.
- Local StoreKit tests cover verified fulfillment, idempotent consumables,
  non-consumable restore, refund handling and Remove Ads policy. The local
  storefront displays StoreKit prices and describes consumable restore limits.
  Production listings, entitlements and native purchase dialogs require account QA.
- Complete the age-rating questionnaire using actual content. No Kids Category
  claim is proposed. Before any ads launch, review creative ratings, suitability,
  regional consent/underage handling and Apple's advertising restrictions.

Official sources reviewed: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/),
[Apple privacy and ATT](https://developer.apple.com/app-store/user-privacy-and-data-use/),
[App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/),
[Google SDK disclosures](https://developers.google.com/admob/ios/privacy/data-disclosure),
[UMP](https://developers.google.com/admob/ios/privacy),
[Firebase disclosures](https://firebase.google.com/docs/ios/app-store-data-collection),
[upload workflow](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/).
