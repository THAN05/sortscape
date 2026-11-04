# SortScape: Puzzle Worlds

Commercial iOS-first sorting puzzle. Swift 6, iOS 17+, SwiftUI menus, SpriteKit board.

- `Sources/PuzzleCore` is a pure Swift value-model module. Never import UI, advertising, analytics, or purchase frameworks there.
- `Sources/SortScape` owns presentation and main-actor interaction. PuzzleScene renders state and forwards taps; it does not decide legality.
- Containers store bottom-to-top pieces, maximum four. Each move transfers one top piece to an empty container or matching top color.
- Update ARCHITECTURE.md and TASKS.md when behavior or scope changes.
- `project.yml` is the source of truth: run `xcodegen generate` after configuration changes. Keep the generated project available to open directly.
- Test rules using `swift test`. Validate iOS using `xcodebuild -project SortScape.xcodeproj -scheme SortScape -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test CODE_SIGNING_ALLOWED=NO` (choose an available device).
- The 100-level campaign lives in `Sources/PuzzleCore/Resources/campaign.json`. IDs are consecutive 1–100. `beginner.json` is an immutable legacy archive used for seed version 0 and v1 save migration.
- Run `swift run -c release CampaignTool generate` for deterministic authoring, and `swift run -c release CampaignTool validate` for independent all-level replay/metrics validation. See Documentation/LEVEL_AUTHORING.md and campaign.schema.json.
- Never replace a published board/benchmark without a migration. v2 progress stores stars, explicit unlocks, first-reward IDs, mapped best scores, archived v1 scores, and banked historical coins. Preserve v1 backups and corrupt saves.
- Keep progression rewards idempotent, never silently overwrite corrupt saves, and isolate UI-test saves from player saves.
- Phase 3: `GameModel` owns the main-actor animation input lock; never mutate session from PuzzleScene. Share geometry through BoardLayout for hit testing and VoiceOver targets.
- Respect both system and in-app Reduce Motion. Cancel/settle animations and hints on pause/background/navigation. Preserve UUID-isolated progress/preferences in UI tests.
- Tests now include PuzzleCoreTests, hosted SortScapeTests, and SortScapeUITests in the SortScape scheme. Screenshots attach to UI test results.
- Original artwork is code-drawn in Theme.swift and Tools/GenerateIcon.swift; sounds are bundled local WAVs.
- No production credentials or third-party SDKs in Phase 4. StoreKit 2, Google Mobile Ads, and Firebase are future integrations requiring product/privacy decisions.
- Phase 5 saves are v3. EconomyManager owns separate coin/star ledgers; never mutate balances in UI or award from animation callbacks. Stable transaction IDs prevent duplicate first clears, efficiency tiers, and milestones.
- ProgressModel injects PlayerSaveService and publishes only after a successful whole-profile write. Preserve v1/v2 migration backups and claim markers; never reset corrupt/future saves.
- IslandScene draws/selects sites only. PlayerProgress validates prerequisites, balance, and restoration transactions. Stars gate the current island but are not spent. Confirmation is a SwiftUI alert; recheck rules at commit.

- Phase 6: saves are v4, including PurchaseState. StoreKitPurchaseManager verifies transactions, atomically fulfills via ProgressModel, then finishes; never grant from raw/unverified payloads, UI, or collection animations.
- Keep release SortScapeStoreEnabled disabled until approved App Store Connect setup. Both simulator run schemes use local StoreKit configuration; never use real transactions during development. Storefront prices come only from Product.displayPrice.
- StoreKitTest requires SORTSCAPE_DISABLE_STORE_START=1 in test-host environment. Inject isolated profiles; UI tests may enable their own UUID-isolated store. Never let the app startup listener consume a test manager's transaction into regular progress.
- Preserve fulfilled/revoked transaction IDs and starterClaimed on refund. Reconcile non-consumable access, retain delivered currency without negative balances, and keep free hints and all free progression. See Documentation/STOREKIT.md for local-record/server limitations.
- Phase 7 saves are v5. AdRewardState UUID markers and earned credits/coins must commit together through ProgressModel. Never reward on impression/dismissal or spend player currency for failed ads. Preserve free hints and normal unlimited Undo.
- GoogleMobileAds 13.12.0 and UMP 3.1.0 are pinned SPM app-only dependencies. Only official test ad UNIT IDs are permitted; shipping ADS_ENABLED stays NO. A private app ID may supply UMP messages without enabling live units. Production IDs belong in ignored private configuration, never source. See Documentation/ADMOB.md.
- AdCoordinator exclusively owns full-screen presentation, consent gates and global frequency policy. Interstitials run only on completed-board Next transitions, never active gameplay or session one, and never with Remove Ads/Starter.
- UMP permission must precede SDK init/load and be rechecked before show. Do not add unnecessary ATT prompts or claim that non-personalized ads collect no data. The app's ad counters are local-only; Google SDK data has separate disclosures.

- Phase 8: app-only Telemetry/AnalyticsService and opt-in FirebaseAnalyticsService. Firebase Analytics Core + Crashlytics are pinned to verified release 13.1.0. Do not manually emit reserved first_open/session_start, personal data, purchase IDs, fake revenue or events for features that do not exist.
- Collection defaults OFF independently for analytics/crashes. Missing environment configuration fails closed. Private Firebase files live in ignored Resources/Firebase; post-build copies only the selected environment. Debug=Development, Release=Production. Never commit service-account credentials. Telemetry never controls game/save success.
- Currency and purchase events originate only after ProgressModel's successful whole-profile write; compare durable journals for idempotency. Remote analytics is best effort, not authoritative finance. Preserve v5 saves; analytics preferences are separate from economy.
- Main project.yml contains real Firebase dependencies. When network retrieval is blocked, Tools/GenerateOfflineProject.py creates explicit SortScapeOffline.xcodeproj for app/tests with reporting unavailable. A passing offline build does NOT validate Firebase SDK compilation, uploads or Crashlytics symbolication; never label it a complete production integration.
- Keep pause/sound/haptic/motion controls ahead of reporting sections. Present the sorting guide from stable SettingsView, not a lazily instantiated Form section. UI tests must tap actual switch thumbs and assert the resulting value before relaunch.
- PERFORMANCE_REPORT.md records measured simulator conditions/limitations; never substitute simulator timings for physical-device FPS, memory or battery evidence. Keep frame diagnostic sampling opt-in and bounded.

- Phase 9: save in-progress attempts separately from v5 economy. Persist only legal
  move journals, replay against the exact published board, isolate UI-test files,
  and keep a solved checkpoint until the idempotent reward write succeeds.
- Keep main and offline SwiftPM cache paths distinct; resolving the offline graph
  can remove Firebase artifacts from a shared cache. Main Firebase compile/archive
  now works locally; no private Firebase config or upload/delivery is verified.
- Maintain explicit Release version/build and safe feature defaults. An unsigned
  device archive is local QA evidence only. Never upload, distribute, invite
  testers, or submit without the owner's explicit approval.

- Phase 10 uses an ads-off, purchases-off launch candidate. Keep Release separate
  from Debug private overrides; do not expose the QA storefront/consent flows or
  package placeholder products. In-app privacy policy needs an owner-approved
  HTTPS SORTSCAPE_PRIVACY_POLICY_URL. Use CheckLaunchArchive.py for local checks;
  it does not replace Apple validation. Capture only real UI; home/store QA
  captures are not product-page assets. No upload or release without explicit approval.
