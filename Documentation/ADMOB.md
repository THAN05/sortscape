# AdMob development and release notes

## Current configuration

Official Swift packages are pinned to Google Mobile Ads 13.12.0 and UMP 3.1.0. Google recommends Swift Package Manager, GADApplicationIdentifier, and SKAdNetworkItems in the app's Info.plist. The project supplies Google's sample app through Configuration/Ads.xcconfig and declares Google's SKAdNetwork ID. No production identifiers or account credentials are present.

- App: ca-app-pub-3940256099942544~1458002511
- Rewarded: ca-app-pub-3940256099942544/1712485313
- Interstitial: ca-app-pub-3940256099942544/4411468910

These are Google's official dedicated iOS test identifiers. The adapter validates application ID syntax and cannot display a live unit; its ad unit IDs are fixed to Google's test units. ADS_ENABLED=NO is the shipping default. To exercise Google test ads, run Debug and open Settings > Enable Google test ads. This invokes UMP, then initializes/loads only if consent allows it. A sample app without configured UMP messages may fail consent validation; this keeps ads off and does not block gameplay. Production enablement is outside this phase.

Configuration/Ads.local.xcconfig is ignored and is the intended private deployment override. Do not commit real IDs. A privately configured publisher app ID can supply UMP messages while retaining official test units. A later approved release must deliberately add privately configured live unit IDs, configure the actual account's messages, audit buyers/SKAdNetwork entries, and verify all policies. Nothing is published here.

## Player experience

Each voluntary placement labels the reward alongside Watch ad. Tapping the offer opts in and starts the ad if available.

- +1 automatic-move hint token; existing free hints remain.
- +25 bonus coins once per completed world; repeats cannot farm coins.
- +1 two-move rewind token; existing unlimited normal Undo remains.

Only the SDK earned callback authorizes a reward; dismissal, impression, clicks, loading, or failed presentation do not. Rewards and UUID claim markers commit atomically in v5 player saves. Save failures leave the wallet unchanged and show a retry path. Callback IDs survive restart, but an earned callback lost before a successful disk write cannot be recovered reliably without server-side verification. No currency is ever charged for an ad. Client-side records are not anti-tamper protection; SSV and an authenticated server are future options.

Forced interstitials are eligible on Next after levels 10, 20, and each subsequent tenth level with a next world. The final level has no Next transition. A ready ad presents over the completion sheet. If the ad is unavailable or ineligible, Next opens the next world immediately. First process session: none. Later sessions require 4 completed worlds and 3 minutes in the session, plus 3 minutes since any full-screen ad. Global limits: 2 forced per session, 3 per UTC day, 8 combined full-screen ads per UTC day. Rewarded ads have a 30-second cooldown. Failed/unavailable ads skip immediately; no loading screen gates the next puzzle. Remove Ads and Starter Bundle suppress all forced ads. Optional reward ads remain opt-in, as disclosed in the store.

## Privacy and SDK data

UMP is refreshed when enabled on each process session, then required forms are presented. canRequestAds gates initialization and every load/show. Errors or unknown status disable ads. Settings provides required privacy options and persistent device opt-out; revoking permission clears cached ads and invalidates in-flight loads. Disabling blocks new ad loads/presentations, but an initialized Google SDK may report previous activity. Data already transmitted cannot be recalled.

The app does not ask for ATT or request IDFA. It requests non-personalized/restricted-data ads, disables publisher first-party ID and coarse-location collection, and has no mediation adapters. ATT permission would be required before introducing cross-app/site tracking; an ATT prompt alone would not replace UMP or regional consent. Do not configure an IDFA explanation message or add tracking in an account without implementing and reviewing the corresponding permission flow. There is no app-added tracking usage string because this phase does not request tracking.

Google's SDK can still receive IP-derived location, advertising/interaction data, diagnostics, device information, and other data documented by Google. Non-personalized is not data-free. Its packaged privacy manifests describe its collection/API use; the application's manifest covers its own local settings/counters. App Store privacy labels must include SDK behavior, not merely our empty list of app-uploaded data. Review the exact pinned SDK and configured account before shipping; the current account/region/age settings are not a substitute for that review.

The intended age audience, Kids Category/COPPA, under-age treatment, EEA/UK/Swiss messages, and applicable US privacy messages must be configured by the product owner before enabling a real account. This phase does not assert that the game is child-directed or guess users' ages. No consent choice is forced to access puzzles or rewards already earned. Do not promise a globally compliant commercial configuration without account and device validation.

Own analytics remain on-device and contain aggregate counters, currency totals, and coarse UTC return days only. No user/device/account/ad-request IDs, personal event properties, raw SDK errors, or external analytics uploads are added. Local diagnostics distinguish exposed/ad-free completion days and return days; they do not establish a causal retention effect or provide fleet-wide reporting. Consented aggregate telemetry and a cohort/experiment plan are future release decisions; Firebase is not introduced.

## Test strategy and physical-device QA

MockAdService and MockAdConsentService exercise success, no-fill/offline, interrupted/no-earned dismissal, duplicate callbacks, pending save rollback, concurrency, ownership, privacy denial/withdrawal, and local caps. UUID-isolated UI profiles use mocks and never request a live ad. Release ignores test-save/mock overrides. Pure Swift tests validate all 100 boards plus reward journals, migration, and frequency rules.

Still required on physical devices with a configured TEST account/message setup:

- EEA/UK/CH required form, consent expiry, rejection, privacy reopening, US opt-out, offline consent failures.
- Official Google test creatives: real load/display/dismiss/earned ordering, interruptions/background/external browser, expired cache and no fill.
- VoiceOver/dynamic text, landscape ad creative return to portrait, audio ducking/haptics, memory/performance and StoreKit Remove Ads purchase/refund while an ad loads.
- Paid-event delivery is account/creative-dependent; test ads need not report revenue. Validate production revenue accuracy only in a later approved release.
- Review App Store privacy nutrition labels, privacy/support policy URL, SDK signatures/manifests, Kids/age classification, real account setup, and full SKAdNetwork buyer list. No live test, product submission, or publication is authorized here.

## Official references reviewed November 3, 2026

- [Google SDK setup / SPM](https://developers.google.com/admob/ios/quick-start)
- [Rewarded API and official test ID](https://developers.google.com/admob/ios/rewarded)
- [Interstitial API and official test ID](https://developers.google.com/admob/ios/interstitial)
- [UMP consent and privacy options](https://developers.google.com/admob/ios/privacy)
- [Publisher privacy settings](https://developers.google.com/admob/ios/privacy/strategies)
- [SDK data disclosures](https://developers.google.com/admob/ios/privacy/data-disclosure)
- [Apple privacy and ATT requirements](https://developer.apple.com/app-store/user-privacy-and-data-use/)

## Current runtime evidence

The actual SDK/UMP sample-path smoke reached both rewarded and interstitial test loads. Both loads failed; no creative/impression/reward/revenue was delivered. A later refresh did not complete another load during observation, and no exact network/server cause was established. Normal menu remained interactive. Automated success/reward assertions use mocks; successful real creative presentation is explicitly still unverified. See Phase7-QA/sdk-smoke.json.
