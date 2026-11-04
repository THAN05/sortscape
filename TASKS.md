# Phase 1

- [x] Inspect Mac/Xcode/Swift/simulators
- [x] Create Swift 6 XcodeGen app, core framework, and XCTest target
- [x] SwiftUI home and level navigation
- [x] SpriteKit board with four-piece containers and touch selection
- [x] Legal single-piece moves, undo, restart, completion, next-world navigation
- [x] Five levels and automated solvability/rules tests
- [x] Complete build/test verification and record results

# Later phases

- Production bundle identity/signing (persistence and progression completed in Phase 2)
- Animation, sound, haptics, art, and app icon implemented in Phase 3; final release asset review remains
- VoiceOver actions and Dynamic Type implemented in Phase 3; physical-device usability QA remains
- StoreKit 2, Google Mobile Ads, Firebase adapters and privacy/consent requirements
- UI automation expanded in Phase 3; physical-device performance testing remains

# Verification — November 3, 2026

Environment: Apple Silicon arm64, macOS 26.6.2, Xcode 27.1 (27A9275), Swift 6.4. Installed XcodeGen 2.46.0 through Homebrew. Project uses Swift 6 language mode and iOS 17 deployment target.

- XcodeGen generation: passed.
- xcodebuild test, SortScape scheme, iPhone 18 Pro / iOS 27.0: **TEST SUCCEEDED**, 5 XCTest cases, 0 failures. App and framework compiled successfully with simulator signing disabled.
- swift test: passed, 5 XCTest cases, 0 failures. Solvability search found legal solutions for all five levels.
- Compiler errors: none. Xcode emitted benign AppIntents metadata extraction warnings because no AppIntents dependency is present, plus simulator OS build metadata diagnostics.
- Physical-device testing and full UI interaction QA remain outstanding. A development team is needed for device signing; simulator builds have no signing blocker.
- StoreKit, ads, and analytics deliberately deferred to later phases.
- Dedicated SortScape QA iPhone 18 Pro simulator: app installed and launched successfully; rendered home screen visually verified with all five level links. Full touch walkthrough remains manual QA.

# Phase 2 — Complete Puzzle Engine and Level System

- [x] Inspect and preserve Phase 1 engine, controls, and original five boards
- [x] Pure Swift four-piece rule engine, history, restart, win detection, and move counter
- [x] JSON LevelManager with strict external-data validation and visible loading errors
- [x] Fifteen beginner levels bundled for both Xcode and SwiftPM
- [x] Iterative bounded solver returning replayable solutions; all 15 verified solvable
- [x] First-completion reward (25 coins), best move counts, sequential level unlocks
- [x] Versioned atomic local progress persistence, corrupt-save preservation, error reporting
- [x] Integrate saved progression, locked levels, rewards, and next-level flow with SwiftUI/SpriteKit
- [x] Core XCTest and end-to-end simulator progression test
- [x] Build and run on dedicated SortScape QA iPhone 18 Pro / iOS 27.0

## Phase 2 verification — November 3, 2026

`swift test`: **10 unit tests passed, zero failures**.
`xcodebuild test`: **TEST SUCCEEDED**, **10 unit tests and 1 UI test passed, zero failures**. Xcode 27.1 / Swift 6 mode; dedicated simulator ID `0C686083-E6B5-4DC7-B627-D4E88CEF65B3`. App and JSON framework resources compile and load successfully. No compiler errors; benign AppIntents metadata and Xcode simulator build/debugger metadata diagnostics remain.

Exact passing unit tests:

1. `PuzzleRulesTests.testMovesOneTopPieceToEmptyOrMatchingContainer`
2. `PuzzleRulesTests.testIllegalMovesDoNotMutateState`
3. `PuzzleRulesTests.testOnlyFullUniformContainersCountAsSolved`
4. `PuzzleRulesTests.testUndoAndRestartRestoreExactStateAndMoveCount`
5. `PuzzleRulesTests.testAllFifteenBundledLevelsHaveLegalSolutions`
6. `LevelProgressTests.testCatalogRejectsMalformedAndInvalidLevels`
7. `LevelProgressTests.testSolverReportsSolvedUnsolvableAndBudgetExhaustion`
8. `LevelProgressTests.testCompletionUnlocksNextLevelAndRewardsOnlyOnce`
9. `LevelProgressTests.testProgressRejectsLockedAndMismatchedSessions`
10. `LevelProgressTests.testProgressPersistsAndCorruptionIsReported`

Passing UI test: `ProgressionUITests.testSolveRewardUnlockAndRelaunchPersistence`. Uses real SpriteKit taps, checks undo/restart resets, solves level 1 in three moves, verifies reward and next-level navigation, relaunches, then verifies saved balance, unlocked level 2, and locked level 3. UUID-isolated test save preserves regular player progress.

No Phase 2 implementation/build blockers. Remaining QA: physical devices, iPad/small-phone layouts, VoiceOver container actions, playtesting difficulty, and broader UI coverage beyond the first level. Solver paths are not optimality guarantees. In-progress board persistence, corrupt-save recovery UI, cloud sync, and spending coins are future scope. StoreKit 2, ads, Firebase, final artwork, signing, and App Store release work remain deferred.

# Phase 3 — iPhone presentation and experience

- [x] Re-inspect Phase 2 code, architecture, level data, and automated tests; baseline 10 core + 1 UI tests passed before presentation work
- [x] Original sunlit garden visual identity, code-drawn landscape, app icon, rounded cream/teal menus
- [x] Gradient jewel pieces with shadows, color-independent diamond/circle/flower/star symbols, highlighted glass vessels
- [x] Curved piece transfer animations, invalid stroke/shake, completed-vessel pulse, confetti and results badge animation
- [x] Main-actor move transaction locks rapid taps, undo/restart, and back navigation until settled
- [x] Portrait, safe-area-aware scroll layouts with accessibility-size adaptations
- [x] Level/title, moves, coins; Undo, Restart, Hint, and Pause controls
- [x] Home, level selection, game, pause/settings, completion, replay, and next-world navigation
- [x] Background/inactive events settle committed moves, cancel hints, pause audio/scene, and require resume
- [x] Async bounded cancellable hints with stale-result protection and no coin charge
- [x] Original local move/invalid/completion WAV sounds and subtle haptics
- [x] Persistent sound/haptics/Reduce Motion preferences; always honor system Reduce Motion
- [x] Individual 44pt+ accessible vessel buttons, spoken contents, selection, hints, and announcement feedback
- [x] Add hosted presentation-model tests and broaden UI tests; retain screenshot attachments
- [x] Review home/game/completion screenshots and fix accessibility-size artwork/header/counter wrapping
- [x] Finish final compact-device and accessibility screenshot verification; record final results

## Phase 3 test coverage

The 10 named Phase 2 core tests above remain. Six new hosted tests:

1. `GameModelTests.testRapidTapsAndCommandsCannotCorruptAnimatingMove`
2. `GameModelTests.testPauseSettlesAnimationAndResumePreservesBoard`
3. `GameModelTests.testInvalidMoveLeavesHistoryAndSelectionIntact`
4. `GameModelTests.testReducedMotionAndCompletionUndoRestart`
5. `GameModelTests.testHintSelectsLegalSourceWithoutMovingPieces`
6. `GameModelTests.testPausedHintCannotApplyStaleResult`

Three UI tests:

1. `ProgressionUITests.testSolveRewardUnlockAndRelaunchPersistence` — separate world navigation, moves, undo/restart, solve, first-completion coins, next world, and local progress after relaunch.
2. `ProgressionUITests.testPauseSettingsHintsAndBackgroundResume` — hint feedback, sound/haptic/motion switches, invalid feedback, home/background activation, resume, and undo.
3. `ProgressionUITests.testLargeTextAndAccessibleVessels` — largest accessibility text category, spoken piece descriptions, minimum vessel targets, scrolling, move and undo, retained screenshots.

## Remaining release work

- Physical-device audio/haptic tuning and VoiceOver usability sessions (simulators cannot establish tactile quality)
- Full device/OS matrix, interruptions, memory/performance profiling, and localization
- Difficulty playtesting; solver hints remain valid rather than optimal
- In-progress board persistence across process termination and corrupt-save recovery UI remain future scope
- Development signing, App Store configuration, commercial release review
- No production ads, purchases, analytics, or third-party SDKs added


## Phase 3 final verification — November 3, 2026

- Phase 2 baseline: `swift test` 10/10; simulator 10 unit + 1 UI tests passed before work.
- Final pure Swift tests: **10/10 passed**, zero failures, including replaying solutions for all 15 levels.
- Full iPhone 18 Pro / iOS 27.0 run: **19/19 passed** (10 core + 6 hosted model + 3 UI), `TEST SUCCEEDED`.
- Full compact iPhone SE (3rd generation) simulator / iOS 27.0 run: **19/19 passed**, `TEST SUCCEEDED`. Includes final serial-queue audio implementation; the audio main-thread warnings are gone.
- After screenshot-discovered accessibility layout fixes: largest-text UI test rerun on both devices, both passed. Decorative art no longer scales beyond its pieces; counters/controls stack at accessibility sizes.
- After tightening compact default board height: complete progression/navigation/relaunch UI test rerun on the compact device, passed. Screenshot confirms standard controls fit above the bottom edge. No puzzle/model code changed in this final layout adjustment.
- Screenshots visually inspected for home, gameplay, pause/settings, completion, compact layout, and largest Dynamic Type. Selected final evidence is retained in `Documentation/Phase3-QA/`.
- Final app installed and launched normally on SortScape QA; existing regular player progress is preserved. No production ads or purchases.
- Xcode emits benign missing-AppIntents and simulator build metadata diagnostics. Some runs report failure collecting additional simulator diagnostics despite **TEST SUCCEEDED**. The Simulator GUI app bundle is absent at the expected Xcode path, so opening its window fails; `simctl` app launch, screenshot capture, and XCTest execution all succeed.

Result bundles:

- `DerivedData/Logs/Test/Test-SortScape-2026.11.03_12-06-54--0600.xcresult` — full large-phone suite
- `DerivedDataCompact/Logs/Test/Test-SortScape-2026.11.03_12-08-59--0600.xcresult` — full compact-phone suite
- `DerivedData/Logs/Test/Test-SortScape-2026.11.03_12-10-17--0600.xcresult` — corrected large-text layout
- `DerivedDataCompact/Logs/Test/Test-SortScape-2026.11.03_12-11-38--0600.xcresult` — corrected compact large-text layout
- `DerivedDataCompact/Logs/Test/Test-SortScape-2026.11.03_12-12-27--0600.xcresult` — final compact control fit and progression

# Phase 4 — 100-level campaign and progression

- [x] Inspect Phases 1–3, docs, and tests; baseline build and all 19 XCTest tests passed before changes
- [x] Pure Swift deterministic SplitMix64/Fisher–Yates candidate generation with stored versioned recipes
- [x] Solver verification before acceptance; reject solved, duplicate, invalid, or unsolvable candidates
- [x] A* solver with reproducible effort metrics, heap, tube symmetry, cancellation, and explicit budget results
- [x] 100 JSON levels with IDs 1–100, names, tiers, seeds, recipes, solution lengths, effort, complexity, scores
- [x] Duplicate detection ignores color renaming and tube permutation
- [x] Required tier counts: Beginner 20, Easy 20, Medium 25, Hard 20, Expert 15
- [x] Smooth measured score curve, tier strategy guidance, no new mechanics
- [x] Tier-filtered level selection with available/locked/completed indicators, best moves, stars, and replay
- [x] Save stars and explicit unlocks; improve records monotonically; first-completion rewards remain idempotent
- [x] Migrate v1 scores by matching board identity; preserve all old scores/coins and back up before first v2 write
- [x] Strict JSON schema checks, independent all-level solver replay and metrics report
- [x] Core tests: generation, uniqueness, reproducibility, curve, BFS cross-check, invalid data, all-100 progression, stars, migration, persistence
- [x] Hosted model checks: animated representative worlds 1, 21, 41, 66, 86, 100; completion/undo/restart
- [x] Finish full iPhone UI suite, representative tier screenshots, and final launch; record results

## Campaign generation and validation

565 candidates evaluated (15 archived recipes + 550 version-1 seeds): 378 unique solvable candidates accepted into the pool. Rejected 187: 88 duplicates, 2 already solved, 97 unsolvable, 0 search-budget failures. Selected and independently validated **100/100** campaign levels: **96 new seeded layouts + 4 retained archived layouts**. Every level reproduces from its versioned recipe/seed. Full campaign regeneration matched SHA-256 `be9116a7b0fd044c4ab9ff54fcbe819605ad31e965ba90b714e8abdf004b6046` byte-for-byte.

| Tier | Worlds | Count | Score range | Solution length range |
| --- | --- | --- | --- | --- |
| Beginner | 1–20 | 20 | 29–55 | 3–10 |
| Easy | 21–40 | 20 | 56–64 | 9–11 |
| Medium | 41–65 | 25 | 64–79 | 10–14 |
| Hard | 66–85 | 20 | 79–88 | 13–15 |
| Expert | 86–100 | 15 | 88–112 | 15–21 |

Largest adjacent score increase: **5** (validator limit 12). These are solver/complexity estimates; difficulty and enjoyment still need human playtesting. All levels use the original rules and four-color symbol palette.

`Documentation/level-validation.json` records each level's solution length, effort and score. `Documentation/campaign.schema.json` defines structure; `CampaignValidator` and LevelManager enforce cross-record/game-rule constraints. Commands and migration guarantees are in `Documentation/LEVEL_AUTHORING.md`.


## Phase 4 verification — November 3, 2026

- `swift test`: **20 core tests passed, zero failures**.
- Independent `CampaignTool validate`: **100/100 validated**, all returned solutions replayed; all recorded metrics matched.
- Full iPhone 18 Pro / iOS 27.0 `xcodebuild test`: **TEST SUCCEEDED — 31 tests passed, zero failures** (20 core + 7 hosted gameplay-model + 4 UI tests).
- Hosted representative tests cover worlds 1, 21, 41, 66, 86, and 100, including a real animated move, settled completion, undo/restart, and compact board geometry.
- UI representative checks cover all five tiers, visible earned stars, replay access, legal hinted movement, undo, and home navigation. Existing completion/unlock/relaunch, pause/settings/background, and largest-text tests pass.
- Two initial UI harness assumptions were corrected: Hint already selects its source, and offscreen Form rows may require scrolling before they exist in the accessibility tree. Neither required changing puzzle rules. The final full suite passed after these corrections.
- Visual review found clipped bottom-row vessel numbers on six-tube boards and cropping in the short selection-art card. Presentation fixes were applied; compact model/UI regression verification is recorded below after completion.
- The normal app launches via simctl with the new campaign and existing progress. As in Phase 3, the Simulator GUI bundle is unavailable in the shell environment; process launch, screenshots, and automated interaction work.
- Xcode still emits benign missing-AppIntents and simulator build/debugger metadata diagnostics; no compilation errors remain.

Full-suite result: `DerivedData/Logs/Test/Test-SortScape-2026.11.03_12-32-45--0600.xcresult`.

New core tests (in addition to preserved rules/history/persistence tests):

1. `CampaignTests.testAllHundredLevelsValidateAndReproduceExactly`
2. `CampaignTests.testTierCountsAndDifficultyCurveHaveNoSpikes`
3. `CampaignTests.testCanonicalIdentityRejectsCosmeticPermutations`
4. `CampaignTests.testGeneratorRejectsUnsupportedRecipesAndHugeLegacySeed`
5. `CampaignTests.testStrictSchemaAndTamperedCampaignAreRejected`
6. `CampaignTests.testAStarMatchesIndependentBreadthFirstSearchOnSmallBoards`
7. `CampaignProgressTests.testFullCampaignUnlocksAndAwardsEachLevelExactlyOnce`
8. `CampaignProgressTests.testReplayImprovesStarsAndBestMovesWithoutDuplicateReward`
9. `CampaignProgressTests.testVersionOneMigrationPreservesCoinsScoresAndBackup`
10. `CampaignProgressTests.testStarsAndUnlocksPersistAcrossFreshStoreInstances`

Additional model test: `GameModelTests.testRepresentativeTierBoardsAnimateCompleteUndoAndRestart`.
Additional UI test: `ProgressionUITests.testRepresentativeDifficultyTiersAndStarReplay`.

Remaining: human enjoyment/difficulty calibration, physical-device performance/audio/haptics/VoiceOver QA, full OS/device matrix, and release signing. No ads, purchases, or analytics were introduced. In-progress board restoration across process termination remains outside this phase; completed progression persists.


Final presentation regression: compact iPhone SE / iOS 27.0 targeted run **TEST SUCCEEDED — 8/8 passed** (7 hosted model tests + the five-tier UI test). The model test now also checks that vessel-number frames remain inside the scene. Final screenshots confirm complete bottom-row numbers and uncropped selection jewels. Evidence from all five tiers and a normal launch is in `Documentation/Phase4-QA/`.

Targeted result: `DerivedDataCompact/Logs/Test/Test-SortScape-2026.11.03_12-37-28--0600.xcresult`.
The normally launched campaign displays 100 worlds and preserves the existing 75-coin / 3-completed-world save in this environment. No regular player save was reset or used as an automated fixture.

Phase 4 implementation and automated validation are complete. No build or failing-test blockers remain; playtest calibration and physical-device release QA remain as listed above.

# Phase 5 — economy, rewards, and island restoration

- [x] Re-run Phase 1–4 baseline: 20 core tests, 31 simulator tests, and independent validation of all 100 campaign levels passed
- [x] Pure Swift separate coin/star ledger, lifetime totals, nonnegative balances, stable idempotent transaction IDs
- [x] First-clear rewards, rating-improvement efficiency bonuses, earned stars, and one-time level/island milestones
- [x] Version 3 Codable persistence; preserve v1/v2 balances, backups, historical claim markers, and corrupt/future files
- [x] Injectable save service; failed writes publish neither wallet changes nor restoration ownership
- [x] Original interactive isometric SpriteKit island with all 10 requested decorations and construction animation
- [x] Level/star/prerequisite gates, 31,550-coin total construction cost, next objective, completion percentage
- [x] Home/island navigation, wallet displays, restoration cards, direct spending and insufficient-funds feedback
- [x] Compact completion receipt with automatic reward saving. Replay cannot farm bonuses.
- [x] Reduce Motion, accessible list controls, safe-area scrolling, background pause
- [x] Unit and simulator UI coverage for economy, migrations, restoration, restart persistence, and save failures

The campaign earns 29,990 to 30,990 coins before island milestones. All decorations cost 31,550. The first nine builds award 60 milestone coins, leaving 500 to 1,500 coins to earn from level ad bonuses on a fresh save. The last build awards another 75 coins. Release builds currently disable ads, so full restoration on campaign and ad earnings requires an ad-enabled build.

Remaining release work: human economy/difficulty playtesting, physical-device sound/haptic/VoiceOver usability and performance QA, localization, signing and App Store preparation. In-progress puzzle persistence and corrupt-save recovery UI remain future scope. Production ads, purchases, and analytics remain deferred.

## Phase 5 final verification — November 3, 2026

- `swift test`: **30 tests passed, zero failures**.
- `xcodebuild test`: **TEST SUCCEEDED**, **47 tests passed, zero failures** (30 PuzzleCore, 10 hosted model, 7 UI), iPhone SE (3rd generation) / iOS 27.0.
- Independent campaign validator: **100/100 valid**; final tests also independently solve/replay and reproduce all 100 boards.
- All 10 decorations built through confirmed UI actions; after relaunch, 100% ownership, 3,395 coins and 300 stars persisted. Cancel and insufficient funds leave balances unchanged.
- Reviewed compact-phone island and completion screenshots in Documentation/Phase5-QA. Final tested app installed and launched normally on the iPhone 18 Pro QA simulator; regular player save preserved.
- Fixed a simulator confirmation-popover Cancel/accessibility issue by using an explicit two-button alert. No compiler errors or failing tests remain. Xcode simulator metadata/AppIntents diagnostics remain benign.
- Result: `DerivedDataCompact/Logs/Test/Test-SortScape-2026.11.03_13-00-39--0600.xcresult`. Full log: `/private/tmp/sortscape-phase5-final-ios.log`; core log: `/private/tmp/sortscape-phase5-core-final.log`; validator log: `/private/tmp/sortscape-phase5-validation.log`.

Exact passing tests:

- `PuzzleCoreTests.CampaignProgressTests.testFullCampaignUnlocksAndAwardsEachLevelExactlyOnce`
- `PuzzleCoreTests.CampaignProgressTests.testReplayImprovesStarsAndBestMovesWithoutDuplicateReward`
- `PuzzleCoreTests.CampaignProgressTests.testStarsAndUnlocksPersistAcrossFreshStoreInstances`
- `PuzzleCoreTests.CampaignProgressTests.testVersionOneMigrationPreservesCoinsScoresAndBackup`
- `PuzzleCoreTests.CampaignTests.testAllHundredLevelsValidateAndReproduceExactly`
- `PuzzleCoreTests.CampaignTests.testAStarMatchesIndependentBreadthFirstSearchOnSmallBoards`
- `PuzzleCoreTests.CampaignTests.testCanonicalIdentityRejectsCosmeticPermutations`
- `PuzzleCoreTests.CampaignTests.testGeneratorRejectsUnsupportedRecipesAndHugeLegacySeed`
- `PuzzleCoreTests.CampaignTests.testStrictSchemaAndTamperedCampaignAreRejected`
- `PuzzleCoreTests.CampaignTests.testTierCountsAndDifficultyCurveHaveNoSpikes`
- `PuzzleCoreTests.EconomyTests.testAllRestorationsAndMilestonesAreReachableWithoutPurchases`
- `PuzzleCoreTests.EconomyTests.testCorruptV3AndFutureSavesAreRejectedWithoutOverwrite`
- `PuzzleCoreTests.EconomyTests.testCurrencyAwardsSpendingAndLifetimeTotalsAreSeparate`
- `PuzzleCoreTests.EconomyTests.testInsufficientInvalidAndOverflowAmountsNeverMutateLedger`
- `PuzzleCoreTests.EconomyTests.testInsufficientRestorationFundsNeverSpendOrPlaceDecoration`
- `PuzzleCoreTests.EconomyTests.testReceiptTracksCoinsStarsBonusesAndNoReplayFarm`
- `PuzzleCoreTests.EconomyTests.testRestorationRequirementsInsufficientCoinsAndDuplicateBuild`
- `PuzzleCoreTests.EconomyTests.testTransactionsAreIdempotentAndConflictsCannotChangeBalances`
- `PuzzleCoreTests.EconomyTests.testV2MigrationPreservesBalancesAndPreventsRetroactiveBonuses`
- `PuzzleCoreTests.EconomyTests.testV3SaveRestartsRetainSpentBalancesIslandAndMilestoneIDs`
- `PuzzleCoreTests.LevelProgressTests.testCatalogRejectsMalformedAndInvalidLevels`
- `PuzzleCoreTests.LevelProgressTests.testCompletionUnlocksNextLevelAndRewardsOnlyOnce`
- `PuzzleCoreTests.LevelProgressTests.testProgressPersistsAndCorruptionIsReported`
- `PuzzleCoreTests.LevelProgressTests.testProgressRejectsLockedAndMismatchedSessions`
- `PuzzleCoreTests.LevelProgressTests.testSolverReportsSolvedUnsolvableAndBudgetExhaustion`
- `PuzzleCoreTests.PuzzleRulesTests.testAllHundredBundledLevelsHaveLegalSolutions`
- `PuzzleCoreTests.PuzzleRulesTests.testIllegalMovesDoNotMutateState`
- `PuzzleCoreTests.PuzzleRulesTests.testMovesOneTopPieceToEmptyOrMatchingContainer`
- `PuzzleCoreTests.PuzzleRulesTests.testOnlyFullUniformContainersCountAsSolved`
- `PuzzleCoreTests.PuzzleRulesTests.testUndoAndRestartRestoreExactStateAndMoveCount`
- `SortScapeTests.GameModelTests.testHintSelectsLegalSourceWithoutMovingPieces`
- `SortScapeTests.GameModelTests.testInvalidMoveLeavesHistoryAndSelectionIntact`
- `SortScapeTests.GameModelTests.testPausedHintCannotApplyStaleResult`
- `SortScapeTests.GameModelTests.testPauseSettlesAnimationAndResumePreservesBoard`
- `SortScapeTests.GameModelTests.testRapidTapsAndCommandsCannotCorruptAnimatingMove`
- `SortScapeTests.GameModelTests.testReducedMotionAndCompletionUndoRestart`
- `SortScapeTests.GameModelTests.testRepresentativeTierBoardsAnimateCompleteUndoAndRestart`
- `SortScapeTests.ProgressModelTests.testFailedConstructionSaveRollsBackBothWalletAndIsland`
- `SortScapeTests.ProgressModelTests.testFailedRewardSaveDoesNotPublishAndCanRetryExactlyOnce`
- `SortScapeTests.ProgressModelTests.testFreshInjectedModelRetainsWalletStarsAndRestoration`
- `SortScapeUITests.ProgressionUITests.testAllTenDecorationsCanBeBuiltWithEarnedCoins`
- `SortScapeUITests.ProgressionUITests.testInsufficientIslandFundsCannotChangeBalance`
- `SortScapeUITests.ProgressionUITests.testIslandConfirmationSpendingAndRestartPersistence`
- `SortScapeUITests.ProgressionUITests.testLargeTextAndAccessibleVessels`
- `SortScapeUITests.ProgressionUITests.testPauseSettingsHintsAndBackgroundResume`
- `SortScapeUITests.ProgressionUITests.testRepresentativeDifficultyTiersAndStarReplay`
- `SortScapeUITests.ProgressionUITests.testSolveRewardUnlockAndRelaunchPersistence`

# Phase 6 — StoreKit 2 purchases

- [x] Inspect Phase 1–5 sources, save migrations, architecture, economy and island tests
- [x] Baseline: 30 pure Swift tests and full 47-test compact simulator suite passed, zero failures
- [x] Five configurable placeholder product IDs and local StoreKit configuration with requested reference prices
- [x] Localized names/descriptions/prices from Product metadata; no displayed storefront prices hardcoded in Swift
- [x] StoreKitPurchaseManager actor, verified fulfillment, Transaction.updates listener, unfinished recovery and current-entitlement reconciliation
- [x] Atomic v4 fulfillment journal and coin/hint delivery; environment-scoped transaction IDs; finish only after durable save
- [x] Pending, cancellation, verification failure, unknown catalog/type, interrupted save, duplicate delivery, restore and refund handling
- [x] V1–V3 compatibility/backups; v4 requires purchase journal; existing wallet, stars, island, scores and unlocks preserved
- [x] Coin packs, hint inventory/automatic move assists, Starter Bundle one-time rewards, ad-removal and cosmetic ownership
- [x] Existing free hints and all non-paying progression preserved; no ad SDK added
- [x] Store UI, balance/inventory, ownership, feedback, restore/retry, Apple terms/refund links and local-save disclosures
- [x] Selectable Moonlit Lagoon island cosmetic, automatically disabled on entitlement removal
- [x] Pure Swift purchase/migration tests, injected write-failure tests, StoreKitTest integration and end-to-end store UI tests
- [x] Document App Store Connect/account setup, final IDs/types, fulfillment/refund policy and device-only security limits in Documentation/STOREKIT.md
- [x] Keep shipping purchases disabled; no real transactions, product submission, or publication

Native purchase-confirmation cancellation UI could not be automated in the headless simulator (no Cancel control exposed). That exploratory test was removed from the automated suite; actual PurchaseResult.userCancelled handling and simulated cancellation-error no-grant behavior are tested. Xcode 27.1 wraps the simulated cancellation error as StoreKitError.unknown. Native system-sheet cancellation remains physical-device/sandbox QA. The initial sign-in prompt was stopped without credentials; startup StoreKitTest isolation now prevents listener interference with regular progress.

Release blockers: final product IDs and Apple team/App Store Connect agreements/products/localizations, approved store enablement, sandbox/TestFlight/physical-device testing, privacy/support URLs and final product review. Local Codable records cannot establish account-wide exactly-once consumable or bundle rewards across deletion/rollback/reinstall/devices; add authenticated server fulfillment if that guarantee is required. No such server/account configuration was performed.

## Phase 6 final verification — November 3, 2026

- Baseline Phases 1–5: **30/30 core** and **47/47 simulator tests** passed before StoreKit integration. No critical gameplay/economy/island regressions found.
- Final `swift test`: **34/34 passed**, zero failures. Includes all 100 seeded boards independently solved/replayed/reproduced and v1/v2/v3 migration coverage.
- Full compact iPhone SE (3rd generation) / iOS 27.0: **61/61 passed** (34 core, 19 hosted including 7 StoreKitTest, 8 UI), **TEST SUCCEEDED**.
- Full iPhone 18 Pro / iOS 27.0: **61/61 passed**, **TEST SUCCEEDED**.
- After final Info.plist/test-resource packaging and asynchronous refund-test stabilization: **54/54 passed** (34 core, 19 hosted, 1 store UI), zero failures. The other 7 gameplay UI tests passed in both full runs; no gameplay/presentation code changed after those runs.
- Clean Release build and final packaged Release build: **BUILD SUCCEEDED**. Inspected release Info.plist: SortScapeStoreEnabled is Boolean false. No .storekit fixtures or StoreKitTest frameworks in the shipping app.
- Final debug game installed and launched normally on iPhone 18 Pro QA. Existing regular player data retained; all purchases during QA used local Xcode transactions and isolated profiles. No credentials entered, real payments made, product submissions, or publication.
- Store screenshots reviewed on compact and large phones, retained in Documentation/Phase6-QA. Local purchase, token use, undo, and relaunch persistence passed.
- No remaining compiler errors or failing automated tests. Benign Xcode AppIntents/simulator metadata diagnostics remain; StoreKitTest's imported legacy-header and deliberately isolated no-listener test warnings do not occur in the app's launch listener flow. Native cancellation-sheet QA remains as noted above.

Result bundles:

- `DerivedDataCompact/Logs/Test/Test-SortScape-2026.11.03_13-24-04--0600.xcresult` — full 61 compact tests
- `DerivedData/Logs/Test/Run-SortScape-2026.11.03_13-26-46--0600.xcresult` — full 61 large-phone tests
- `DerivedDataCompact/Logs/Test/Test-SortScape-2026.11.03_13-32-24--0600.xcresult` — final 54 packaging/regression tests

Logs: `/private/tmp/sortscape-phase6-core-final.log`, `/private/tmp/sortscape-phase6-primary-final.log`, `/private/tmp/sortscape-phase6-packaged-final.log`, `/private/tmp/sortscape-phase6-packaged-release.log`.

Exact passing tests in the full suite:

- `PuzzleCoreTests.CampaignProgressTests.testFullCampaignUnlocksAndAwardsEachLevelExactlyOnce`
- `PuzzleCoreTests.CampaignProgressTests.testReplayImprovesStarsAndBestMovesWithoutDuplicateReward`
- `PuzzleCoreTests.CampaignProgressTests.testStarsAndUnlocksPersistAcrossFreshStoreInstances`
- `PuzzleCoreTests.CampaignProgressTests.testVersionOneMigrationPreservesCoinsScoresAndBackup`
- `PuzzleCoreTests.CampaignTests.testAllHundredLevelsValidateAndReproduceExactly`
- `PuzzleCoreTests.CampaignTests.testAStarMatchesIndependentBreadthFirstSearchOnSmallBoards`
- `PuzzleCoreTests.CampaignTests.testCanonicalIdentityRejectsCosmeticPermutations`
- `PuzzleCoreTests.CampaignTests.testGeneratorRejectsUnsupportedRecipesAndHugeLegacySeed`
- `PuzzleCoreTests.CampaignTests.testStrictSchemaAndTamperedCampaignAreRejected`
- `PuzzleCoreTests.CampaignTests.testTierCountsAndDifficultyCurveHaveNoSpikes`
- `PuzzleCoreTests.EconomyTests.testAllRestorationsAndMilestonesAreReachableWithoutPurchases`
- `PuzzleCoreTests.EconomyTests.testCorruptV3AndFutureSavesAreRejectedWithoutOverwrite`
- `PuzzleCoreTests.EconomyTests.testCurrencyAwardsSpendingAndLifetimeTotalsAreSeparate`
- `PuzzleCoreTests.EconomyTests.testInsufficientInvalidAndOverflowAmountsNeverMutateLedger`
- `PuzzleCoreTests.EconomyTests.testInsufficientRestorationFundsNeverSpendOrPlaceDecoration`
- `PuzzleCoreTests.EconomyTests.testReceiptTracksCoinsStarsBonusesAndNoReplayFarm`
- `PuzzleCoreTests.EconomyTests.testRestorationRequirementsInsufficientCoinsAndDuplicateBuild`
- `PuzzleCoreTests.EconomyTests.testTransactionsAreIdempotentAndConflictsCannotChangeBalances`
- `PuzzleCoreTests.EconomyTests.testV2MigrationPreservesBalancesAndPreventsRetroactiveBonuses`
- `PuzzleCoreTests.EconomyTests.testV3SaveRestartsRetainSpentBalancesIslandAndMilestoneIDs`
- `PuzzleCoreTests.LevelProgressTests.testCatalogRejectsMalformedAndInvalidLevels`
- `PuzzleCoreTests.LevelProgressTests.testCompletionUnlocksNextLevelAndRewardsOnlyOnce`
- `PuzzleCoreTests.LevelProgressTests.testProgressPersistsAndCorruptionIsReported`
- `PuzzleCoreTests.LevelProgressTests.testProgressRejectsLockedAndMismatchedSessions`
- `PuzzleCoreTests.LevelProgressTests.testSolverReportsSolvedUnsolvableAndBudgetExhaustion`
- `PuzzleCoreTests.PurchaseProgressTests.testConsumablesAreAtomicIdempotentAndPersistAfterRestart`
- `PuzzleCoreTests.PurchaseProgressTests.testReconciliationRemovesRevokedThemeAndHintsNeverGoNegative`
- `PuzzleCoreTests.PurchaseProgressTests.testStarterRewardsNeverRepeatOnRestoreRefundOrRepurchase`
- `PuzzleCoreTests.PurchaseProgressTests.testVersionThreeMigrationPreservesWalletAndRequiresV4Journal`
- `PuzzleCoreTests.PuzzleRulesTests.testAllHundredBundledLevelsHaveLegalSolutions`
- `PuzzleCoreTests.PuzzleRulesTests.testIllegalMovesDoNotMutateState`
- `PuzzleCoreTests.PuzzleRulesTests.testMovesOneTopPieceToEmptyOrMatchingContainer`
- `PuzzleCoreTests.PuzzleRulesTests.testOnlyFullUniformContainersCountAsSolved`
- `PuzzleCoreTests.PuzzleRulesTests.testUndoAndRestartRestoreExactStateAndMoveCount`
- `SortScapeTests.GameModelTests.testHintSelectsLegalSourceWithoutMovingPieces`
- `SortScapeTests.GameModelTests.testInvalidMoveLeavesHistoryAndSelectionIntact`
- `SortScapeTests.GameModelTests.testPaidAssistChargesOnlyForAValidCurrentMove`
- `SortScapeTests.GameModelTests.testPausedHintCannotApplyStaleResult`
- `SortScapeTests.GameModelTests.testPauseSettlesAnimationAndResumePreservesBoard`
- `SortScapeTests.GameModelTests.testRapidTapsAndCommandsCannotCorruptAnimatingMove`
- `SortScapeTests.GameModelTests.testReducedMotionAndCompletionUndoRestart`
- `SortScapeTests.GameModelTests.testRepresentativeTierBoardsAnimateCompleteUndoAndRestart`
- `SortScapeTests.ProgressModelTests.testFailedConstructionSaveRollsBackBothWalletAndIsland`
- `SortScapeTests.ProgressModelTests.testFailedRewardSaveDoesNotPublishAndCanRetryExactlyOnce`
- `SortScapeTests.ProgressModelTests.testFreshInjectedModelRetainsWalletStarsAndRestoration`
- `SortScapeTests.ProgressModelTests.testPurchaseAndHintSaveFailuresNeverPublishPartialFulfillment`
- `SortScapeTests.StoreKitPurchaseTests.testInterruptedDeliveryRetriesAfterFailedSaveAndRestart`
- `SortScapeTests.StoreKitPurchaseTests.testPendingApprovalDeliversViaUpdatesOnlyAfterApproval`
- `SortScapeTests.StoreKitPurchaseTests.testRealStoreKitProductsAndSuccessfulConsumablesPersistExactlyOnce`
- `SortScapeTests.StoreKitPurchaseTests.testRefundRevokesThemeAndRemoveAdsWithoutNegativeBalances`
- `SortScapeTests.StoreKitPurchaseTests.testRestoreReconcilesNonConsumablesAndStarterRewardsDoNotRepeat`
- `SortScapeTests.StoreKitPurchaseTests.testUnverifiedTransactionNeverGrantsOrFinishes`
- `SortScapeTests.StoreKitPurchaseTests.testUserCancellationAndFailureGrantNothing`
- `SortScapeUITests.ProgressionUITests.testAllTenDecorationsCanBeBuiltWithEarnedCoins`
- `SortScapeUITests.ProgressionUITests.testInsufficientIslandFundsCannotChangeBalance`
- `SortScapeUITests.ProgressionUITests.testIslandConfirmationSpendingAndRestartPersistence`
- `SortScapeUITests.ProgressionUITests.testLargeTextAndAccessibleVessels`
- `SortScapeUITests.ProgressionUITests.testPauseSettingsHintsAndBackgroundResume`
- `SortScapeUITests.ProgressionUITests.testRepresentativeDifficultyTiersAndStarReplay`
- `SortScapeUITests.ProgressionUITests.testSolveRewardUnlockAndRelaunchPersistence`
- `SortScapeUITests.StoreUITests.testLocalStorePurchasesAndHintInventorySurviveRelaunch`

# Phase 7 — Google AdMob and player-safe advertising

- [x] Inspect Phase 1–6 architecture/tests; baseline 34 core and full 61 simulator tests passed
- [x] Review current official Google SDK/UMP, test IDs, privacy/data disclosures and Apple ATT guidance
- [x] Pin GoogleMobileAds 13.12.0 and GoogleUserMessagingPlatform 3.1.0 through SPM; retain Package.resolved
- [x] Build-configured application ID, sample configuration, ignored private override, shipping ads OFF, test-unit-only adapter
- [x] AdService, GoogleAdMobService, MockAdService and centralized AdCoordinator; prevent overlapping presentations
- [x] Optional hint token, +25 once-per-world bonus, two-move rewind token; clear opt-in confirmation and earned-only rewards
- [x] Atomic v5 UUID ad reward journal, duplicate callbacks/replay prevention, save rollback/retry, v1–v4 migration/backups
- [x] Preserve free hints, unlimited free normal Undo, all campaign/island progression and StoreKit fulfillment
- [x] Interstitials only on solved-board Next transitions; first-session exclusion, four-level threshold, three-minute cooldown and global caps
- [x] Remove Ads/Starter suppress forced ads; unavailable ads never gate next-level progression
- [x] UMP consent/required forms and privacy options; consent errors fail closed, generation guards prevent late grants of SDK permission
- [x] Persistent device opt-out, no unnecessary ATT prompt, non-personalized/restricted requests, no first-party publisher ID/coarse collection
- [x] Own privacy manifest, SDK-data disclosures and actionable Settings privacy controls
- [x] Local aggregate load/show/impression/completion/reward/revenue/return-day metrics; no personal properties or analytics uploads
- [x] Pure Swift and hosted tests for rewards, frequency, consent, concurrency, offline gameplay, ownership and persistence
- [x] Simulator UI tests for optional rewards, cancellation, duplicate callback handling, bonus replay prevention, next-level and failure/denial paths
- [x] Documentation/ADMOB.md records configuration, security/consent limits, telemetry scope and physical-device test requirements

No production ad units are present or enabled; no publishing occurred. Network-served Google test creatives, account-configured UMP forms, paid-event availability, regional/age policy and physical-device behavior require the release QA listed in Documentation/ADMOB.md. Automated presentations use deterministic mocks, not an actual watched Google creative. Local return-day diagnostics instrument retention; no population impact or real revenue has been measured. A server/SSV is needed for recovery of callbacks lost before durable local save and stronger anti-fraud guarantees.

## Phase 7 final verification — November 3, 2026

- Baseline: 34 pure Swift and full 61 simulator tests passed before ad integration.
- Final `swift test`: **38/38 passed**, zero failures; all 100 levels remain valid/reproducible/solvable.
- Full iPhone 18 Pro / iOS 27 run after fixing pause controls: **80/80 passed**, **TEST SUCCEEDED** (38 core + 30 hosted + 12 UI).
- Final compact iPhone SE / iOS 27 run after consent-cancellation and save-retry refinements: **71/71 passed**, **TEST SUCCEEDED** (38 core + 31 hosted + 2 affected UI). Together the full/focused runs exercised **81 unique passing tests**. The focused run includes the one additional coordinator save-retry test added after the full run.
- Previous compact failure was an offscreen Resume button after adding privacy settings. Fixed by moving essential pause actions to the top; pause/background/resume passed in both corrected runs. No known automated failures remain.
- Final Release build: **BUILD SUCCEEDED**. Inspected sample GADApplicationIdentifier, delayed measurement=true, advertising flag=NO, purchase flag=false, no ATT usage string, app/Google/UMP privacy manifests present, and no StoreKit test configuration in the release app.
- Real SDK smoke used only the sample app and official test units in an isolated debug profile. Initial UMP permission allowed SDK loads; rewarded and interstitial loads both failed. No ad impression, earned callback, or live creative occurred. Subsequent refresh did not produce another load during observation. No exact network/server cause was established. Successful actual creative delivery, regional messages and paid events remain account/device QA; mock success is not presented as actual Google delivery.
- Mock/SDK integration build, successful/failed/cancelled rewarded flows, duplicate callbacks, retained pending reward retry, forced-ad policy/ownership, privacy errors/withdrawal/late response, concurrency, offline rules, StoreKit, island, 100-level campaign, navigation and persistence are covered.
- Compact bonus/pause screenshots inspected and retained in Documentation/Phase7-QA. Final normal launch preserves regular player progress. No production ad IDs, live ads or publishing.

Result bundles:

- `DerivedDataAdsFinal/Logs/Test/Test-SortScape-2026.11.03_13-58-42--0600.xcresult` — full 80-test corrected run
- `DerivedDataAds/Logs/Test/Test-SortScape-2026.11.03_14-04-33--0600.xcresult` — final 71-test compact run

Logs: `/private/tmp/sortscape-phase7-core-final.log`, `/private/tmp/sortscape-phase7-final-corrected.log`, `/private/tmp/sortscape-phase7-final-targeted.log`, `/private/tmp/sortscape-phase7-packaged-release.log`. Debug-only SDK load diagnostics report domain/code, not request IDs or raw SDK payloads; they are not sent to analytics. Benign simulator telephony/audio/AppIntents metadata diagnostics remain.

Passing ad-specific tests:

- `PuzzleCoreTests.AdvertisingTests.testBonusRequiresCompletedLevelAndNeverRepeatsOnReplay`
- `PuzzleCoreTests.AdvertisingTests.testFrequencyAndRewardsSurviveRestartAndV4Migration`
- `PuzzleCoreTests.AdvertisingTests.testInterstitialFirstSessionTimingPlacementOwnershipAndGlobalCaps`
- `PuzzleCoreTests.AdvertisingTests.testRewardCallbacksAreIdempotentAndConflictSafe`
- `SortScapeTests.AdCoordinatorTests.testConcurrentPresentationAndBackgroundCannotGrantAdditionalRewards`
- `SortScapeTests.AdCoordinatorTests.testConsentDeniedErrorWithdrawnAndDisabledNeverInitializeOrLoad`
- `SortScapeTests.AdCoordinatorTests.testEarnedRewardDuplicateCallbacksAndRestartNeverDuplicateTokens`
- `SortScapeTests.AdCoordinatorTests.testInterstitialOnlyCompletedTransitionAfterFirstSessionAndNeverForRemoveAds`
- `SortScapeTests.AdCoordinatorTests.testLinkedSDKUsesSampleAppAndDelayedMeasurementWithoutATTPrompt`
- `SortScapeTests.AdCoordinatorTests.testLoadFailureDismissalAndPresentationFailureGrantNothing`
- `SortScapeTests.AdCoordinatorTests.testLocalAnalyticsContainNoIDsAndValidateRevenue`
- `SortScapeTests.AdCoordinatorTests.testOfflineGameRemainsPlayableWithNoAdServiceAvailability`
- `SortScapeTests.AdCoordinatorTests.testOptOutWhileConsentIsInFlightNeverInitializesSDK`
- `SortScapeTests.GameModelTests.testRewardedRewindPreservesNormalUndoAndNeverSpendsOnInvalidState`
- `SortScapeTests.ProgressModelTests.testCoordinatorRetainsEarnedRewardUntilSaveRetrySucceeds`
- `SortScapeTests.ProgressModelTests.testEarnedAdRewardSaveFailureRetriesWithoutDuplicateDelivery`
- `SortScapeUITests.AdvertisingUITests.testOptionalRewindTokenWorksWithoutChangingFreeUndo`
- `SortScapeUITests.AdvertisingUITests.testRewardHintConsentDescriptionCancelDuplicateAndRelaunch`
- `SortScapeUITests.AdvertisingUITests.testRewardedBonusOnceAndNextLevelNavigation`
- `SortScapeUITests.AdvertisingUITests.testUnavailableAndPrivacyDeniedAdsNeverBlockOfflineGameplay`

## Phase 8 — implemented app layer; Firebase deployment verification blocked

- [x] Inspect phases 1–7, source architecture/save rules and tests before editing.
  Pre-change iOS baseline 81/81 and pure Swift 38/38 passed. Independent Release
  CampaignTool validation solved/replayed **100/100** unchanged campaign boards.
- [x] Add typed AnalyticsService/FirebaseAnalyticsService/MockAnalyticsService,
  telemetry coordinator, independent analytics/crash preferences, schema checks,
  consent-change counter reset, environment-specific private configuration and
  Firebase Analytics Core + Crashlytics 13.1.0 SPM declarations. Review official docs.
- [x] Real gameplay attempt timing, starts/completion/abandonment/restarts, actual
  hints/undo, saved restoration/currency, verified new purchase fulfillment and
  actual SDK ad lifecycle/earned/paid callbacks. Do not manually duplicate Firebase
  first_open/session_start, restored purchase conversions, rewards or fake revenue.
- [x] Add explicit two-page sorting guide and real tutorial start/completion hooks.
- [x] Dedicated compact-safe analytics/diagnostics page, separate guide presentation,
  persisted opt-ins, no pre-consent event queue, no raw identifiers/player text.
- [x] Nonfatal fixed diagnostic codes after opt-in, DEBUG-only gated development
  probe/crash procedure, explicit archive dSYM upload helper; no production crash probe.
- [x] Preserve piece nodes on selection changes, skip identical island projections,
  reuse warmed audio buffers, retain cached textures and accessibility/Reduce Motion.
- [x] Bounded injectable hint search policy; preserve published boards/star thresholds.
- [x] Measure simulator launch, selection/rendering, frame intervals and memory;
  capture Time Profiler smoke trace. See PERFORMANCE_REPORT.md for actual scope.
- [x] Document retention/cohort/dashboard definitions, consent bias, abandonment
  inference, session coverage and actual-revenue reporting. No invented statistics.
- [x] Add explicit reproducible offline Xcode project for blocked SDK-download QA.
- [x] Run final sequential complete suite: **96/96 passed, zero failures** on iPhone
  SE3 / iOS 27 simulator: **38 PuzzleCore + 44 hosted app + 14 UI**. Pending StoreKit
  approval, restore/refund and existing ad/accessibility/progression tests all pass.
- [x] Debug/test and final Release simulator builds passed for SortScapeOffline.
  App launched through XCTest on compact and Pro simulators; compact privacy
  screenshot reviewed. Release flags: ads NO, purchases false, Firebase analytics
  and Crashlytics collection false; Production environment. DEBUG probe strings
  absent from Release binary. Existing player save was never reset by UI tests.
- [x] Update AGENTS.md, ARCHITECTURE.md, ANALYTICS_EVENTS.md, PERFORMANCE_REPORT.md,
  RETENTION_DASHBOARD.md, Firebase configuration instructions and README.

Final clean result bundle:
`DerivedDataPhase8Offline/Logs/Test/Test-SortScape-2026.11.03_15-38-13--0600.xcresult`

Logs: `/private/tmp/sortscape-phase8-final96.log`,
`/private/tmp/sortscape-phase8-shipping-check.log`,
`/private/tmp/sortscape-phase8-campaign.log`,
`/private/tmp/sortscape-phase8-build.log` (blocked main Firebase build).
All 96 individual test names are recorded in `Documentation/Phase8-QA/tests-passed.json`.
New passing TelemetryTests cover schema/reserved events, privacy independence and
persistence, mid-attempt opt-in with no backfill, attempt timing/restart/dedup,
session timing, failed-save/purchase/currency idempotency across restart, restored
entitlement conversion suppression, unavailable backend, earned callback/no fabricated
revenue, piece-node reuse/resize, reference vs selection performance and actual SKView
frame cadence. New UI tests cover privacy/guide/relaunch and measured launch time.

Earlier runs found compact settings crowding and an unstable guide presentation;
fixed with a dedicated privacy page/stable sheet host. Accessibility test scrolling
and switch-thumb targeting were corrected. The final clean suite supersedes those
failures. One overlapping StoreKit run was interrupted after a test-daemon stall;
its pending-approval test passed in the final sequential run. No current failing
app tests remain. Simulator audio/telephony/Xcode metadata warnings are non-fatal.

Remaining release gates (do not mark Phase 8 commercial release-ready):

- [ ] Restore GitHub package download access, resolve Firebase and its transitive
  packages, build/test the MAIN Firebase-linked project. Git clones failed with
  connection resets/SSL timeouts; no Firebase adapter SDK typechecking is claimed.
- [ ] Supply matching Development/Production Firebase project files; verify console
  DebugView, actual consent/offline behavior, Crashlytics crash/nonfatal delivery and
  archive symbolication. No Firebase account/configuration was provided.
- [ ] Deploy/configure the documented GA4/BigQuery dashboards, retention/deletion/IAM
  settings and privacy disclosures/policy. No retention/player dataset exists here.
- [ ] Daily challenge tracking is a typed contract only because there is no daily
  challenge gameplay feature. Do not emit fake events or claim that feature exists.
- [ ] Physical-device Release CPU/GPU/frame-time/memory/leak/thermal/battery, VoiceOver,
  haptic and real SDK privacy/ad/sandbox purchase QA; prior StoreKit/AdMob account,
  server-reconciliation and support/privacy deployment gates still apply.

No live ads, real purchases, product submissions, dashboard deployment or publishing
were enabled. Normal free/offline gameplay and v5 economic save format are preserved.

Final normal primary-simulator launch succeeded (no test-save override). Existing v1
player file remained byte-for-byte unchanged after launch; home screenshot confirms
the preserved profile in Documentation/Phase8-QA/home-preserved-profile.png.

## Phase 9 — local beta candidate; distribution prerequisites remain

- [x] Audit Phases 1–8 source and tests. Independently solve/replay all 100 worlds.
- [x] Recover unfinished worlds and Undo history across termination using separate,
  atomically written and validated checkpoints. Preserve existing economic saves.
- [x] Add regression tests for interrupted animation, solved checkpoint retention,
  corrupt journal rejection, and actual app termination/relaunch/Undo.
- [x] Set version/build 1.0.0 (1) and verify app identity, icons, safe Release flags,
  iPhoneOS architecture and matching dSYMs.
- [x] Resolve Firebase 13.1.0, compile the SDK-linked simulator build, and archive the
  SDK-linked app for generic iOS in Release. Phase 8's package blocker is resolved.
- [x] Prepare local unsigned archive: `DerivedDataPhase9/SortScape.xcarchive`.
- [x] Prepare QA_REPORT.md, RELEASE_CHECKLIST.md, TESTFLIGHT_TEST_PLAN.md, and
  architecture notes. See QA_REPORT.md for full suite and sequential rerun results.
- [ ] Select the intended Apple Developer team and configure distribution signing
  and provisioning for this bundle ID. No matching profile/distribution identity
  was found; the signing-enabled attempt failed. Validate the signed archive.
- [ ] Confirm App Store Connect record, public privacy/support URLs, beta contact,
  age rating, export compliance, accessibility and privacy disclosures.
- [ ] Verify configured Firebase console/Crashlytics delivery with private project
  files if reporting is part of beta. Daily challenge remains unimplemented.
- [ ] Complete physical-device, offline radio, memory/thermal, iPad, sandbox purchase,
  regional UMP and real Google test-creative QA. Production advertising stays off.
- [ ] Any upload, distribution, tester invitations or submission requires separate
  explicit owner approval. None performed in this phase.

Phase 9 verification: 38/38 pure Swift, 100/100 solved boards, 99/100 full iOS
cases plus 9/9 sequential follow-up; all 100 distinct cases passed across runs.
The one initial asynchronous StoreKit test failure passed after the bounded-wait
fix. Both simulator sizes passed the new termination/Undo recovery flow.

## Phase 10 — local launch preparation; not submission-ready

- [x] Audit source and Phase 9 evidence. No TestFlight beta evidence exists.
- [x] Fresh 38/38 pure Swift tests and 100/100 independent solution replays.
- [x] Main Firebase-linked Release device archive succeeded unsigned, 1.0.0 (2):
  `DerivedDataPhase10/SortScape-Launch.xcarchive`. App/dSYM UUIDs match.
- [x] Separate Release from Debug overrides. Compile out test ad requests/UMP
  entry points, remove placeholder IAP catalog, hide QA storefront, set iPad
  orientations, add configurable in-app policy link, and verify local packaging.
- [x] All 100 distinct XCTest cases passed across split runs: 91/92 compact
  non-StoreKit, 8/8 local StoreKit on iPhone 18 Pro, and 1/1 corrected privacy
  UI follow-up. Record initial StoreKit stalls and the fixed UI automation failure
  in QA_REPORT.md; do not describe this as one clean invocation.
- [x] Real screenshot automation and native large iPhone/iPad captures (2/2 flows
  on each), compact QA and local StoreKit QA. No fabricated images.
- [x] Prepare current-limit metadata, reviewer notes, submission checklist,
  SDK/privacy review, 30-day plan, and metric definitions. No live metrics exist.
- [ ] Owner: approved policy/support URLs, signing team and provisioning,
  App Store Connect record, metadata and disclosures. Local submission preflight
  fails for missing signature/team and policy link.
- [ ] Signed-build validation and physical beta/accessibility, radio-off,
  landscape and thermal QA. No TestFlight upload/distribution yet.
- [ ] Decide whether to launch reporting-off or supply Production Firebase
  configuration and verify delivery. Monetization is separately gated: no
  production App Store products or AdMob units have been verified.
- [ ] Obtain separate explicit approval before upload, review submission or release.

See APP_STORE_METADATA.md, APP_STORE_SUBMISSION.md, RELEASE_CHECKLIST.md,
LAUNCH_PLAN.md and POST_LAUNCH_METRICS.md. Nothing uploaded or published.

- Island art refresh: softer shoreline and terrain; cottage and lighthouse
  illustrations and eight new reward illustrations used in the scene and
  restoration cards. The blue-circle and red-diamond island illustration
  appears on the home screen.
- Icon candidates are under Documentation/IconOptions; Glass Puzzles selected as the active AppIcon.

- Rewarded ad offers use full-width buttons with play icons and explicit
  Watch ad text. Next opens the next world immediately if no interstitial is
  ready or eligible. Ready interstitials present over the completion sheet.

- Limit hints to one per level, shared by free suggestions and token assists.

The final five island items unlock at 25, 40, 60, 80, and 100 clears.
Earlier purchases keep their original ledger entries.
