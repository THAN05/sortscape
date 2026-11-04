# SortScape Phase 9 QA — 2026-11-03

Audited sources, XcodeGen settings, campaign data, and tests with Xcode 27.1
(27A9275), Swift 6.4 in Swift 6 language mode. The supported deployment target
is iOS 17.0. The main app now resolves Firebase 13.1.0; its SDK-backed code
compiled for simulator and device. No private Firebase configuration was supplied.

## Audit and fixes

| Phase | Verified in source / tests | Limits |
| --- | --- | --- |
| 1–2 | Native SwiftUI/SpriteKit app; pure Swift rule engine, legal move validation, undo/restart and JSON campaign; 38 core tests | No assumption about physical-device behavior |
| 3 | Board animation input lock, safe-area layouts, settings, accessible vessel labels, Reduce Motion and background handling | Light appearance is intentional; physical VoiceOver and haptics still required |
| 4 | 100 IDs, solver replay, seed reproducibility, five tiers, unlock and best-star rules | Solver proof is not a playability survey |
| 5 | Durable wallet, idempotent progression, ten restoration items, migration/corruption tests | Cloud save and device migration not implemented |
| 6 | Verified local StoreKit fulfillment, pending/cancel/restore/revocation and duplicate-grant tests | Real sandbox account/products and native cancellation on device unverified |
| 7 | Consent gates and interstitial caps, Remove Ads, earned-callback dedup, no-ad progression | Real Google test creative and regional UMP presentation unverified |
| 8 | Firebase SDK linked and built; typed telemetry, opt-in choices and Crashlytics adapter | No project plist/console delivery, live cohorts or daily-challenge gameplay |
| 9 | In-progress board/Undo recovery, version/build metadata, generic-device archive | No signed or distributed build |

Critical gap fixed: unfinished worlds formerly restarted after process death.
Checkpoints now record legal moves atomically before animation, reconstruct the
Undo stack on reopen, and clear after a durable completion reward. A malformed
journal is rejected without changing the wallet. First recovery tests found that
FileHandle reports missing files with Cocoa code 4 on this simulator; handling
both missing-file codes fixed the clean-start and cleared-checkpoint paths.

## Verified artifacts and measurements

- `swift test`: 38 passed. Release CampaignTool: **100/100 solved and replayed**.
- Firebase-linked Debug build-for-testing: succeeded. Compact QA: iPhone SE
  (3rd generation), iOS 27.0. Separate iPhone 18 Pro/iOS 27 launch visually
  checked on an isolated save: Documentation/Phase9-QA/pro-smoke.png.
- Main `Release` generic iOS archive: **succeeded unsigned**, arm64/iPhoneOS,
  SDK 27.1, deployment 17.0. Artifact:
  `DerivedDataPhase9/SortScape.xcarchive`. A separate earlier offline QA archive
  also succeeded; use the main archive as current packaging evidence.
- Archive inspection: `com.sortscape.puzzleworlds`, SortScape, 1.0.0 (1),
  portrait, iPhone/iPad, compiled AppIcon (source 1024×1024, opaque), app and
  PuzzleCore dSYMs (app UUID matches the binary), 19 privacy manifests. StoreKit fixtures, Firebase plists,
  debug crash probe and provisioning profile are absent. Ads/purchases and
  default analytics/crash collection are disabled.
- Initial main archive failed on missing SDK binaries in a cache shared with
  the offline project. SwiftPM restored the cached artifacts and the retry passed;
  dedicated main package resolution also succeeded. Use separate cache paths.
- Signing-enabled QA archive failed because no development team is selected.
  Read-only inventory found one Apple Development identity, no Apple
  Distribution identity and no locally decoded provisioning profile matching
  SortScape. No account or provisioning changes were made.
- Debug simulator XCTest launch: **3.983 s** mean (three samples). World 100
  SKView diagnostic: **123** intervals, mean **16.871 ms**, p95 **16.667 ms**.
  200 selection renders averaged **0.011 s** versus **0.049 s** for a forced
  rebuild reference. Hosted peak memory was about **70–71 MB** during those
  workloads. These measure simulator workloads with reporting unavailable;
  they do not establish device FPS, disk-write latency, leaks, or energy impact.
- Separate Google sample-app smoke launched an isolated debug profile.
  At inspection it recorded session start only, with no verified ad load,
  impression, earned reward or revenue. Mock SDK tests are separate evidence.

## Still to verify

Signed archive and Organizer validation; matching App Store Connect record,
distribution signing and compliance/metadata; private Firebase config and
actual delivery; sandbox purchase/account and real test-creative/UMP behavior;
Airplane Mode with Wi-Fi off; physical VoiceOver, safe-area rotation behavior,
haptics, memory pressure, thermal/battery and sustained frame timing. iPad and
iOS 17 physical coverage remain open. Automated no-ad tests simulate network/
service unavailability; they do not prove radios were disabled. No TestFlight
upload, tester distribution, real purchase, or live ad was performed.

Logs: `/private/tmp/sortscape-phase9-core-final.log`,
`/private/tmp/sortscape-phase9-levels.log`,
`/private/tmp/sortscape-phase9-main-build-tests.log`,
`/private/tmp/sortscape-phase9-final-archive.log`,
`/private/tmp/sortscape-phase9-signing.log`.

## Final XCTest results

- Compact iPhone SE full Firebase-linked suite: **99/100 cases passed** — all
  38 core and 15 UI cases, and 46/47 hosted cases. Two assertions in the same
  interrupted-delivery test expected the coin balance immediately; it was zero
  when checked. No other cases failed.
- Adjusted that regression to wait for the asynchronous StoreKit update, then
  verify repeat recovery does not duplicate the grant. No production purchase
  logic changed. Sequential iPhone 18 Pro follow-up: **9/9 passed** — all seven
  StoreKit cases, large text/accessibility and unfinished board/Undo relaunch.
- **100 distinct cases passed across the full run and follow-up.** This is not
  a claim that the first full invocation was clean. Local StoreKit only; native
  device sandbox/account validation is outstanding.
- Individual passing cases and both result paths:
  `Documentation/Phase9-QA/tests-passed.json`. Logs:
  `/private/tmp/sortscape-phase9-final-tests.log` and
  `/private/tmp/sortscape-phase9-followup.log`.

## Phase 10 release audit — 2026-11-03

Rechecked the code, Phase 9 result evidence and archive settings. No TestFlight
processing, distribution, tester feedback or device-beta evidence exists.
The Phase 9 green follow-up was a simulator run, not a TestFlight test.

- Phases 1–4: native shell, pure Swift rules, seeded campaign, solver, animation,
  accessible board and unlocks are implemented. Fresh `swift test` 38/38;
  independent Release CampaignTool validation replayed 100/100 solutions.
- Phase 5: economy/restoration ledgers, reward deduplication and old save
  migration remain in place. Real iPad UI completed all ten island plans with
  earned coins and verified persistence. Free gameplay has no purchase/ad gate.
- Phases 6–7: StoreKit and consent/ad policy implementations remain in Debug and
  core tests; local/sandbox evidence is distinct from production. No configured
  App Store Connect products, live ad units, or regional UMP/test-creative
  success verified. Launch candidate disables monetization.
- Phase 8: Firebase Analytics Core and Crashlytics compile/link. No production
  plist or console delivery verified. No daily challenges or live metrics.
- Phase 9: attempt recovery and Release archive were verified locally. Signing,
  physical beta and account/setup actions are still open.
- Phase 10: Release isolation, production-mode guard, test product stripping,
  debug ad/UMP gating, hidden QA storefront, iPad orientation metadata,
  configurable privacy link, metadata and screenshot capture automation added.

### Archive and preflight

Main project, Release, generic iOS, Xcode 27.1/SDK 27.1, arm64, iOS 17 minimum,
`com.sortscape.puzzleworlds` **1.0.0 (2)**. Local unsigned archive:
`DerivedDataPhase10/SortScape-Launch.xcarchive`. Archive succeeded.
App icon source is 1024 × 1024 with no alpha; compiled AppIcon and dSYMs are
present. No missing base icon was identified in this local inspection; final
Organizer/App Store validation is outstanding. Alternate appearance artwork
is optional polish, not assumed required.

`python3 Tools/CheckLaunchArchive.py DerivedDataPhase10/SortScape-Launch.xcarchive`
passed. Adding `--submission-preflight` correctly fails for missing team/signing
and missing approved HTTPS policy URL. The Mac has one development identity,
zero local distribution identities. A compatible team/profile was not supplied.
App default analytics/crash reporting is off. No private Firebase production
plist is present. Google sample application ID remains inert SDK metadata;
the app binary lacks the two test ad unit identifiers. No local StoreKit
catalog or fixture and no debug crash probe are packaged. A manifest is not
proof of compliance; see APP_STORE_SUBMISSION.md.

### Simulator runs and captures

Two initial full attempts were interrupted after blocking in the local StoreKit
daemon (large iPhone pending approval, compact interrupted delivery). The second
attempt had 65 passing cases before the stall. These interrupted runs are not
clean passes. A separate full non-StoreKit run excludes seven hosted StoreKit
integration cases and one store UI case; core purchase ledger tests remain.
Phase 9 purchase evidence is historical, not a Phase 10 result.

The 13-inch iPad capture run passed 2/2 real UI flows (complete a world, unlock
and relaunch; restore ten plans and relaunch). Captures are in
`Documentation/AppStoreScreenshots/ipad-13-inch`. Compact reference captures,
including the local StoreKit screen, are from Phase 9 and clearly labeled.
No captures were fabricated, upscaled or submitted. iPad landscape,
physical accessibility, Airplane Mode and device performance remain open.

Fresh Phase 10 results: compact non-StoreKit run **91/92** (all 38 core and
40 hosted cases passed; 13/14 UI). The privacy UI test failed in an unnecessary
scroll/snapshot query on the dedicated screen. The test now waits for navigation
and taps visible switches without dragging that page. Compact privacy follow-up
**1/1 passed**, including relaunch persistence. No consent implementation change
was required to fix this test. Separate iPhone 18 Pro local StoreKit **8/8 passed**
(seven hosted plus store UI). **100 distinct cases passed across the three runs**;
there was no single clean 100-case invocation. The large-iPhone and iPad runs
each passed **2/2** capture flows in addition. Main app source Release-only
gates were also verified in the final device archive.

Unedited current screenshot sets: iPhone 18 Pro Max 1320 × 2868; iPad Pro
13-inch 2064 × 2752; compact QA and separate local StoreKit QA. Only gameplay,
completion and island captures from the target sizes are listing candidates.
Home and Store captures are marked QA-only. Visual review covered the iPad
gameplay/island and large-iPhone completion frames. Final signed-build and
App Store Connect checks are outstanding. No TestFlight or live production
service verification is implied.

Per-test names and result bundles: `Documentation/Phase10-QA/tests-passed.json`.
Logs: `/private/tmp/sortscape-phase10-{core,levels,launch,nonpurchase,storekit,privacy,large-retry,ipad}.log`.

## Pre-submission re-verification — 2026-11-03 (evening)

- `swift test`: **38/38 passed**. Release `CampaignTool validate`: **100/100** levels
  solved and replayed; `Documentation/level-validation.json` unchanged.
- Full SortScape scheme on iPhone 18 Pro / iOS 27 simulator, single invocation
  including local StoreKit and UI tests: **TEST SUCCEEDED, 100/100 passed, 0 failed**.
  This is the first single clean 100-case run on record.
- Fresh unsigned Release generic-iOS archive: succeeded, 1.0.0 (2).
  `CheckLaunchArchive.py` passed; `--submission-preflight` still fails on the
  missing approved HTTPS privacy-policy URL and missing team/signing identity.
  Mac has one Apple Development identity, no Apple Distribution identity.
- Source check: QA storefront, ad SDK start and UMP flows are compiled out of
  Release (`#if DEBUG`). No upload, signing change or account action performed.
