# Architecture

The Phase 2/3 sections below describe the foundation. The Phase 4 section specifies the current campaign, solver, progression format, and migration.

# Phase 2 foundation

## PuzzleCore

A Swift 6 value-model framework with no SpriteKit, SwiftUI, UIKit, service, or main-actor dependency. The same source and JSON resources build through XcodeGen and Swift Package Manager.

- `PuzzleState`: bottom-to-top arrays with capacity four, bounds checking, single-top-piece transfer to empty or matching tops, and full-uniform-container win detection. Its trusted initializer enforces capacity with a precondition; external JSON is validated before construction.
- `PuzzleSession`: initial board plus successful-move snapshots. Undo restores the exact previous state and decrements the current path's move count; invalid moves do not enter history. Restart clears history. Completion does not remove undo/restart functionality.
- `LevelManager`: decodes bundled `Resources/beginner.json`. Rejects malformed JSON, unknown colors, invalid/duplicate/out-of-order IDs, empty names, oversized containers, unbalanced color totals, missing empty tubes, and pre-solved boards. IDs are consecutive starting at 1. There are 15 beginner levels, including the original five boards. Xcode embeds JSON in the PuzzleCore framework; SwiftPM uses Bundle.module. Bundle failures surface as UI errors rather than crashing or silently loading a fallback.
- `PuzzleSolver`: bounded, iterative depth-first graph search with visited-state detection and parent links. Returns a legal replayable path, unsolvable, or search-limit-reached. It skips dismantling full monochrome tubes and equivalent empty destinations. It does not promise an optimal solution. Search runs in tests/content validation and on a cancellable background worker for Phase 3 hints, never in the gameplay render loop. All 15 bundled levels are validated by replaying the returned moves through the engine.
- `PlayerProgress`: completed-level best move counts, sequential unlock checks, and first-completion rewards of 25 coins. Coins derive from completed levels, so repeated completion, undo, restart, and relaunch cannot farm rewards. A completion requires an unlocked level, matching initial board, solved session, and a positive move count. Replay can improve a best score.
- `ProgressStore`: Foundation-based persistence adapter using a versioned Codable envelope and atomic file replacement. Missing save means new player; corrupt/unsupported saves throw and remain untouched. Completed levels, best counts, coins, and unlocks persist; a partially played board does not.

## iOS application

`ProgressModel` is the shared main-actor ObservableObject injected into the navigation tree. It loads the catalog and progress, reports failures, and publishes progress only after persistence succeeds. Saves live in Application Support/SortScape/progress.json. Read failure disables saving to preserve the existing file. A write failure leaves published progress unchanged and lets completion be retried via undo/replay or restart.

`HomeView` displays balance, completed count, and continue/explore actions; `LevelSelectionView` displays 15 level links with locked/completed indicators. Level 1 starts unlocked. `GameView` owns a main-actor `GameModel` and persistent `PuzzleScene`. GameModel translates taps into engine operations, publishes the move count/message, and sends state to the scene. SwiftUI observes settled completion, commits progress, displays rewards in a results sheet, and exposes next-world navigation after unlock. The callback from scene to model is weak.

`PuzzleScene` retains only presentation state, adaptive geometry, numbered color pieces, selection outlines, and touch hit testing. It never decides move legality or awards progress. Menus, messages, undo/restart, and navigation remain SwiftUI.

## Verification and future boundaries

Core XCTest covers rules, history, JSON validation, solvability, rewards, unlocks, and persistence. An iOS UI test exercises actual SpriteKit taps, undo/restart, completion, unlock, and relaunch persistence. Debug builds accept a UUID test-save namespace so UI tests never overwrite normal player progress; Release ignores that environment variable.

Future purchases, ads, and analytics belong in separate adapters outside PuzzleCore. Cloud sync, in-progress saves, save-recovery UI, economy spending, optimal hints, and physical-device performance QA remain future work. Animation, audio, artwork, and accessible vessel actions are implemented in Phase 3 below. No third-party SDKs are required.

# Phase 3 presentation and interaction

The Phase 2 engine, JSON catalog, persistence format, first-completion rewards, and all 15 boards remain intact. Baseline unit and simulator UI tests are run before presentation changes.

## Visual identity and screens

`Theme.swift` owns the cream/teal/coral palette, rounded button style, and original sunlit landscape drawn with SwiftUI shapes. `Tools/GenerateIcon.swift` produces the opaque 1024px AppIcon from original drawing commands. No remote art, fonts, purchases, advertising, or analytics dependencies are added. Original synthesized PCM sound assets live in the application Resources directory.

`GameRouter` owns a typed NavigationStack path: home → level selection → game. Advancing replaces the last game route, so progressing through worlds does not accumulate gameplay screens. Home has a primary continue action and a separate world-selection screen. Game sheets provide pause/settings and results with next/replay/home actions. The game checks unlocks again when resolving a route.

`GameView` shows world/title, current moves, coins, accessible vessels, status, Undo, Restart, Hint, and Pause. Safe-area-aware SwiftUI layout and a scroll fallback keep controls reachable on compact phones and at accessibility text sizes. Standard semantic text styles respond to Dynamic Type; artwork and board pieces scale independently. iPhone orientation stays portrait.

## Animation transaction boundary

`GameModel` remains the single main-actor owner of a PuzzleSession. A legal move commits atomically, then input and undo/restart are locked during a 450ms presentation transaction. `PuzzleScene` animates the removed top piece along a curved path for 420ms. The model then renders the committed state, pulses newly completed vessels, and emits completion exactly at the settled state. Reduce Motion skips movement, shake, confetti, and spring animations; selected/invalid/completed strokes and text still communicate the result.

Rapid taps, multi-touch callbacks, and invalid indices are guarded in the model as well as disabled in SwiftUI. The navigation back button is hidden during a move. Background/inactive events cancel the timer, settle a committed move, cancel hints, pause the scene/audio, and present a resume sheet. Returning to the app preserves the live board. Navigating away cancels pending work; in-progress boards still do not persist across process termination.

`BoardLayout` is shared by SpriteKit drawing and the SwiftUI vessel buttons. Each vessel has a minimum 44pt touch target, an explicit spoken bottom-to-top color/symbol list and piece count, selected status, and action hint. Decorative artwork and the duplicated SpriteKit accessibility surface are hidden from VoiceOver. Pieces use diamond/circle/flower/star symbols in addition to color. Invalid moves and hints also post VoiceOver announcements.

## Hints, feedback, and preferences

Hints run the existing solver on a detached worker with a 50,000-state budget. A snapshot and generation token prevent stale results from applying after pause, navigation, or changes. Parent cancellation propagates to the worker; the core solver checks cancellation between visited states. A hint highlights its source and announces the suggested source/destination without moving a piece or charging coins. Unsolvable states and budget exhaustion have separate messages; paths are not guaranteed shortest.

`GameFeedback` preloads local move/invalid/completion WAV effects and uses soft impact or notification haptics. The ambient AVAudioSession respects Silent Mode and other audio; configuration, decoding, preparation, and playback are confined to a serial background queue. Audio stops on pause/leave. `AppSettings` persists independent sound, haptic, and reduced-motion switches in UserDefaults. Effective reduced motion is the logical OR of the in-app preference and the system accessibility setting. Debug UI tests namespace preferences and progress by UUID.

## QA boundaries

Core tests cover unchanged rules and all level solutions. Hosted `SortScapeTests` cover animation input locks, invalid selection, pause settling, reduced-motion completion/undo/restart, hints, and stale hint cancellation. UI tests cover navigation, actual accessible vessel taps, completion rewards and relaunch persistence, settings, app background/resume, and accessibility-size layout. Screenshots are retained as XCTest attachments and exported for review.

Release validation still requires physical-device listening/haptics, VoiceOver user testing, interruption/performance profiling, device-matrix testing, localization, and signing/App Store setup. Simulator checks cannot establish tactile quality. Production monetization remains deferred.


# Phase 4 — seeded 100-level campaign

## Content pipeline and schema

`LevelGeneration.swift` adds an explicitly specified SplitMix64/Fisher–Yates candidate generator. A recipe stores version, UInt64 seed, color count (2–4), and empty-container count (1–2). Version 1 shuffles four copies of each color into full four-piece tubes plus empties. Candidate generation is distinct from accepting a playable level: CampaignTool rejects solved starts, cosmetic duplicates, unsolvable candidates, and search-budget failures before writing anything. Version 0 deterministically resolves an immutable seed index in the archived 15-board catalog, allowing four retained layouts to remain reproducible.

`CampaignTool` is an SPM executable, excluded from the iOS app target. It evaluates a fixed pool schedule, deduplicates boards under BOTH color renaming and tube permutations, solves candidates, scores them, and selects 100 boards in ascending measured difficulty. First Light and Tidal Pools remain worlds 1/2 with unchanged boards. Four archive layouts are selected in total; the other 96 are new seeded boards. The entire JSON output reproduces byte-for-byte. The archive is not an additional playable campaign.

`campaign.json` has a versioned envelope and exactly 100 LevelDefinitions, each with ID, name, tier, bottom-to-top containers, generation recipe, and difficulty metrics. `Documentation/campaign.schema.json` documents its structural contract. LevelManager enforces exact keys/types, consecutive unique IDs, capacities, four pieces per color, empty space, non-solved starts, tier boundaries, seed reproduction, deduplication, and a nondecreasing bounded score curve. It does not solve 100 puzzles on the UI thread at startup. Malformed or oversized metadata is rejected before arithmetic.

`CampaignValidator` independently solves every accepted board, verifies recorded effort and length, and replays all moves through PuzzleState before accepting the report. `Documentation/level-validation.json` records all 100 IDs/seeds/tiers/solution lengths/efforts/scores. `Documentation/LEVEL_AUTHORING.md` contains commands, thresholds, invariants, and publishing guidance.

## Solver and difficulty

PuzzleSolver now uses deterministic A* with a binary heap and a tube-permutation transposition table. Its admissible lower bound counts pieces outside the longest uniform bottom prefix for each color. Already completed tubes and pointless uniform-stack relocations are pruned. Parent links retain actual tube indices, so returned paths replay on the rendered board even though visited keys ignore tube order. Cancellation is checked between expansions, and bounded search returns unsolvable or budget-exhausted distinctly. Independent BFS tests check reference optimality on small boards; production hints remain budgeted rather than promising a response for every arbitrary state.

Effort is expanded-state count, independent of device speed. Complexity is twice the adjacent-color-boundary count, plus four times the color count, plus six for a one-empty-tube board. Difficulty score is three times solution length plus complexity plus floor(log2(effort + 1)). Campaign scores are nondecreasing, and the loader rejects adjacent increases above 12. The current campaign's largest increase is 5. Tiers are Beginner 1–20, Easy 21–40, Medium 41–65, Hard 66–85, Expert 86–100. Scores are engineering estimates awaiting human playtest calibration, not evidence of universally enjoyable or expert-level difficulty.

No mechanics are added. All 100 worlds retain four-piece capacity, one-piece transfer, matching-top/empty destinations, and the same four colors/symbols. Each tier's selection header explains a planning strategy as space/complexity increases.

## Stars and save migration

PlayerProgress v2 persists best move counts, best stars, an explicit unlocked-level set, and rewarded-level IDs. Completion validates the session's initial and solved states, improves best moves/stars monotonically, unlocks only the next world, and grants 25 coins once. Three stars require reference length + max(1, length/5) moves or fewer; two require length + max(3, length/2) or fewer; any other valid finish receives one. Undo counts the current successful path, and hints are free. Replaying a completed world is always available and cannot duplicate coins.

ProgressStore reads versions 1/2 and writes version 2 atomically. v1 best scores map to new IDs only when the old/new layouts are canonically equivalent. Those worlds retain scores, stars, replay access, and already-rewarded status. Historical scores not selected in the new campaign remain in legacyBestMoves; historical rewards not attributable to a mapped new world remain in legacyCoins. This preserves the entire earned balance without pretending an old score was earned on a different board. The old unlocked range remains open, mapped completed boards stay replayable, and further completions unlock their next world. Before the first v2 overwrite, the exact v1 file is copied to a .v1.backup sibling. Corrupt and future-version saves remain untouched and surface an error.

## Presentation and tests

The existing SpriteKit scene/animation transaction requires no rule changes: every generated board has 3–6 tubes and at most four colors. Level selection filters by five difficulty ranges, shows completed/available/locked state, best moves and accessible star ratings, and supports replay. Game headers show tier/world; results show stars and the three-star target. Home totals derive from the 100-level manager. Scene controls, audio, reduced motion, VoiceOver vessel descriptions, input locks, pause/resume, and next-world replacement navigation are preserved.

Core tests cover full generation/validation/reproduction, schema tampering, duplicate identity, all-100 progression, star improvements, reward idempotency, migration/backups, persistence, and the original rules. Hosted tests solve/animate representative worlds 1/21/41/66/86/100 with undo/restart. UI tests browse all five tiers, verify visible stars and replay access, request a hint, perform its move, undo, and return home; the existing completion, relaunch, large-text, and background tests remain. Debug-only completed-campaign fixtures require a UUID-isolated test namespace and complete boards through the real engine; Release ignores them.

# Phase 5 — economy and island restoration

`EconomyManager` is a pure Swift Codable ledger with separate coin/star balances and lifetime earned/spent totals. Stable transaction IDs make awards and purchases idempotent; conflicting IDs, invalid amounts, and insufficient funds cannot mutate balances. PlayerProgress coordinates the ledger, best scores, unlocks, and IslandProgress as one value transaction.

A first clear grants 25 coins. Reaching two and three stars grants 5 additional coins per newly reached tier, once each; improving a previous rating grants only the difference. Stars are awarded only for improvements to the best rating. Existing reference-length star thresholds remain unchanged. Level milestones at 5/10/20/40/65/85/100 award 25/50/75/100/125/150/200 coins once. RewardReceipt distinguishes first-clear, efficiency, milestone coins, rating, and newly earned stars. Completion saves rewards before presenting them; Collect animates an already committed receipt and never awards again.

`IslandRestoration.swift` defines ten catalog entries, prerequisites, level/star requirements, costs, and placement coordinates. Pathways, trees, flower garden, cottage, bridge, picnic area, fountain, windmill, dock, and lighthouse cost 31,550 coins together. Restoration milestones at 2/5/10 items grant 20/40/75 coins. Stars gate construction but are not consumed. One-star clears satisfy the level and star gates. A perfect campaign pays 30,990 coins, including restoration funding at 8, 25, 40, 60, 80, and 100 clears. The first two island milestones add 60 coins, leaving 500 coins for twenty distinct 25-coin ad bonuses before the final build. The final 75-coin milestone is awarded after that build. Existing saves claim eligible restoration funding once by ledger ID. The next objective and completion percentage derive from persisted ownership.

`PlayerSaveService` is a Sendable injectable boundary. ProgressModel saves a proposed copy before publishing it, so a failed write changes neither wallet nor ownership. ProgressStore writes version 3 atomically and reads versions 1–3. Version 2 migration imports the exact old wallet and earned stars and creates claim markers for historical clears, rating tiers, and milestones, preventing retroactive replay bonuses. Version 1 retains the existing published-board mapping before the economy import. Exact v1/v2 backups precede migration. Corrupt, incomplete-v3, and future saves are preserved and reported, never silently reset. Historical lifetime totals begin with the imported balance because old saves did not record spending.

`IslandScene` owns only original code-drawn isometric presentation and site hit testing. IslandBoardModel bridges site selection to an accessible SwiftUI restoration list. IslandView displays balances, requirements, direct spending, insufficient-funds feedback, objectives, and lifetime totals. Construction rechecks requirements in PlayerProgress. Newly owned decorations animate into place; Reduce Motion uses static placement. Backgrounding pauses scene/audio. VoiceOver uses equivalent labeled list controls instead of decorative SpriteKit nodes. Home and completion routes both reach the island.

Tests cover ledger arithmetic/idempotency, rating improvements, restoration gates/affordability/milestones, v2 migration, v3 reload, corrupt saves, and injected write failures. UI tests exercise direct spending, insufficient funds, all ten builds, and process-restart persistence using UUID-isolated saves. Production ads, purchases, and analytics remain absent.

# Phase 6 — StoreKit 2

`StoreKitPurchaseManager` is an actor in the application module. `StoreCatalog` maps five stable StoreItem fulfillment keys to configurable App Store IDs in Resources/StoreProducts.json. Product.products(for:) supplies names, descriptions, and displayPrice; storefront prices are never embedded in SwiftUI. The local SortScape.storekit configuration contains test-only USD prices and is bundled only in test targets, excluded from the shipping application. No purchase SDK or StoreKit import enters PuzzleCore.

The actor starts a Transaction.updates listener at launch, recovers Transaction.unfinished, and reconciles Transaction.currentEntitlements at startup and foreground. purchase() returns explicit success/pending/cancelled/failure states. Only verified, known-catalog transactions of the expected product type and single-unit quantity cross into ProgressModel. Unknown/unverified/unsupported transactions remain unfinished. After an atomic profile save succeeds, finish() is called; a crash before finishing simply redelivers an idempotent transaction. Restore Purchases explicitly invokes AppStore.sync(), retries unfinished delivery, and reconciles non-consumables. Failed delivery or ownership writes are reported as restore failures.

`PurchaseState` is a pure Swift fulfillment journal in PlayerProgress v4. Keys include StoreKit environment and transaction ID, preventing Xcode, sandbox, and production IDs from colliding. Coin credits use the existing validated EconomyManager; hints have granted/used counters and cannot become negative. Starter Bundle grants 1,500 coins and 20 hints once per local profile plus ad-removal access. A persistent starterClaimed marker survives refund and repurchase. Other consumables grant once per transaction. Remove Ads and premium-theme ownership are live entitlements, reconciled from verified Apple data. Refund tombstones prevent stale cached transaction results from re-enabling revoked access. Already delivered currency is retained on refund rather than taking balances negative. Reconciliation uses a revision check to avoid overwriting updates with an interleaved snapshot.

ProgressModel is the single main-actor save owner for both gameplay and purchases, preventing stale independent writers from losing progression. Both fulfillment marker and reward are saved in the same atomic file before publication; a failure leaves both unchanged and the Apple transaction unfinished. V4 requires a purchase journal. Published v3 saves migrate without losing wallet, stars, island, or scores, with an exact .v3.backup before overwrite. V1/v2 migrations and backups remain supported.

StoreModel bridges the actor to SwiftUI and observes asynchronous delivery feedback. StoreView provides localized prices, wallet and hint inventory, ownership, retry/restore, purchase disclosures, Apple terms/refund links, and accessible scrollable controls. Home links to the store. Paid hint tokens optionally apply one solver-validated move; they are charged only after a valid result and before synchronous board mutation. Existing free hints remain unchanged. Moonlit Lagoon is a selectable cosmetic island palette with moon/stars; revocation disables it. No ad framework is present; Remove Ads is an entitlement contract for a future ad adapter.

The default release Info.plist keeps SortScapeStoreEnabled false. Developer simulator builds accept only Xcode-environment transactions. Both shared debug run schemes select the local StoreKit configuration. Device/release enablement requires explicit product/account setup and review. XCTest disables the app startup store listener so StoreKitTest sessions use only their injected temporary profiles, never a real player's save. UI tests use UUID profiles. See Documentation/STOREKIT.md for setup, validation, and the device-only persistence security boundary.

# Phase 7 — advertising and privacy

The app target pins the official GoogleMobileAds 13.12.0 and GoogleUserMessagingPlatform 3.1.0 Swift packages. PuzzleCore remains independent of advertising frameworks. Configuration/Ads.xcconfig supplies the Google sample application ID through GADApplicationIdentifier and keeps ADS_ENABLED=NO. Ignored Ads.local.xcconfig can hold private deployment configuration; production app/ad unit IDs are never committed or enabled. The development adapter validates the configured application ID and contains only Google's official rewarded/interstitial test units. A private publisher app ID can supply UMP message configuration without enabling live ad units. Package.resolved pins revisions; no mediation adapters or Firebase are added.

AdService is a main-actor presentation/loading boundary. GoogleAdMobService caches expiring RewardedAd/InterstitialAd objects, applies non-personalized/restricted-data requests, disables publisher first-party ID and coarse-location collection, and configures general ad content. FullScreenContentDelegate reports impression, presentation, dismissal, failures, and paid events. Rewards come only from the SDK's earned-reward callback. A retained full-screen ad and continuation span presentation; concurrent presentation is disallowed. GoogleConsentService updates UMP at session startup when ads are enabled, displays required forms, checks canRequestAds, and exposes required privacy options. Consent failure fails closed, even if an old cached permission exists. SDK initialization and all ad loads follow permission; GADDelayAppMeasurementInit delays measurement startup. No ATT request, IDFA usage, or unnecessary tracking usage string is added by the app. Vendor data collection and account messaging still require release review; non-personalized does not mean no data is collected.

AdCoordinator owns consent/policy gates, global presentation lock, ready state, optional reward tickets, and transitions. Ads are off by default. Debug settings explicitly enable Google test ads; a UUID-gated mock factory supplies deterministic UI tests without network/live ads. Disabling ads persists across launches and discards caches; UMP privacy options remain accessible when required. Generation checks discard loads completed after privacy changes. Privacy is rechecked before every load/presentation. Backgrounding prevents new presentation and preserves earned rewards, while gameplay settles/pauses through existing GameModel controls.

AdFrequencyManager is pure Swift, persisted independently across launches. A session is one app process. Interstitials require a Next transition after a level numbered in multiples of ten, session 2+, four distinct completed worlds, 180 seconds since session start, 180 seconds since any full-screen ad, and 180 seconds since the last interstitial. Caps are two interstitials per session, three per UTC day, and eight total full-screen ads per UTC day. Rewarded ads also have a 30-second presentation cooldown. Counts advance on actual SDK presentation, not on failed load/show attempts. Clock rollback cannot shorten cooldowns. Remove Ads or Starter Bundle prohibits forced interstitials; optional, clearly described reward ads remain user-initiated. No ad load is awaited on the Next action: unavailable ads skip immediately. Next replaces the current game route immediately when no ad is ready or eligible. A ready interstitial presents over the completion sheet. The app replaces the game route and closes the sheet as soon as presentation ends. Reward buttons show the reward and a play icon, with a Watch ad label that starts the ad on tap.

PlayerProgress v5 adds an AdRewardState journal of UUID reward tickets. Hint and rewind credits and +25 bonus coins are saved atomically with the ticket through ProgressModel, so duplicate callbacks or replays after process restart cannot duplicate fulfillment. Bonus coins are once per completed world, including replays. Hint tokens integrate with availableHints and consume earned ad credits before paid inventory. Rewind tokens apply two legal historical undo steps; free single-step Undo and free hints remain unchanged. No currency is deducted for ads. Pending earned callbacks with write failures remain retryable in the running coordinator; a process/device failure before durable delivery cannot be guaranteed by client-only SDK callbacks. AdMob SSV plus a server ledger is needed for stronger recovery/fraud guarantees. V1–V4 saves migrate with backups; v5 requires both purchase and ad journals.

GameView and CompletionView label the reward and the Watch ad action before presentation. GameModel pauses for rewarded content; no SDK decides moves or rewinds. History and input locks validate token spending before board mutation. Bonus, token, failure, and consent feedback remain accessible text; navigation is guarded while an ad is onscreen. All ordinary progression, puzzles, purchases, and island restoration remain independent of ad availability.

AdAnalytics records on-device aggregate loads, shows, impressions, SDK-confirmed completions, unique rewards, failures, paid-event currency/micros, UTC return days, and completion counts on exposed/ad-free days. No IDs, ad request metadata, raw errors, precise event timestamps, or personal information enter these counters; no analytics endpoint receives them. These are local retention diagnostics, not a claim of measured population retention lift. A future consented aggregate export/cohort design is required to evaluate real commercial impact. The app privacy manifest covers its UserDefaults access and local-only data; Google's separate packaged manifests/disclosures cover its SDK data. See Documentation/ADMOB.md for privacy/account/device QA and current evidence.

## Phase 8 — consent-aware telemetry and measured rendering

`AnalyticsService` is a main-actor app boundary with Firebase and recording mock
implementations; PuzzleCore still imports no vendor/UI SDK. Typed events and values
validate Firebase names/types without accepting arbitrary payloads. `Telemetry`
owns independent persisted opt-ins, foreground interval summaries, per-ticket
one-shot events (bounded at 10k), and once-per-process diagnostic codes. Firebase
owns automatic first_open/session_start/DAU; see ANALYTICS_EVENTS.md for exact
semantics and RETENTION_DASHBOARD.md for reporting definitions/consent bias.

FirebaseAnalyticsService lazily configures only after consent plus a valid matching
bundle/environment file. App Info defaults analytics/crash collection false, screen
auto-reporting false, IDFV false, and ads-related consent false. Analytics Core omits
identity support. Opt-out disables collection, resets analytics data and deletes
unsent crash reports; crash-only opt-in does not enable analytics. No user ID is set.
Vendor installation identifiers still exist when opted in. App privacy manifest
now declares optional gameplay/purchase/diagnostic analytics; vendor manifests and
App Store privacy disclosures must be reviewed with actual deployment settings.

`LevelTelemetry` is injected into GameModel with a monotonic clock. Attempts track
active time, real hints/undo/restart and success/abandonment, excluding pauses and
background. Completed attempts are single-shot, replay starts a new attempt.
`ProgressModel.commit` compares successfully written ledger/restoration/purchase
journals and emits only new facts; no event from failed save/duplicate fulfillment.
A crash in the save→log interval can omit a report; telemetry is deliberately not
part of the economic transaction. AdCoordinator accepts telemetry injection;
real SDK show/impression/earned/paid callbacks feed sanitized events and ticket
dedup. Paid revenue is never synthesized. Optional guide pages emit tutorial
start/finish through a stable Settings presentation host. Daily challenge names
exist in the contract but no daily challenge implementation is claimed.

`AssistancePolicy` injects bounded 1k–100k solver effort without replacing published
boards/rewards. PuzzleScene preserves all piece nodes on selection-only updates,
changing outline strokes in place; board/geometry changes still rebuild and move
animations explicitly invalidate the render cache. Four existing textures stay
cached. IslandScene skips identical visual projections including restoration
availability, theme, selection, motion and size. Audio buffers are warmed once per
process instead of each reconstructed SwiftUI view. Optional frame interval
sampling is bounded to 3,600 local samples and disabled in normal play.

Main XcodeGen configuration links official Firebase 13.1.0 Analytics Core and
Crashlytics. Debug/Release select Development/Production; only that ignored private
plist is copied. dSYMs are generated; Tools/UploadCrashlyticsSymbols.sh is a deliberate
CI archive upload step, never a hidden upload during unconfigured local builds.
Configuration/Firebase-README.md documents account/configuration requirements.
GitHub connection resets currently prevent SDK retrieval/typechecking here. Explicit
SortScapeOffline.xcodeproj (derived by Tools/GenerateOfflineProject.py) keeps app QA
runnable without Firebase and exposes reporting as unavailable. Its passing tests
must not be represented as successful Firebase SDK/upload validation.

## Phase 9 — in-progress world recovery and release packaging

PuzzleSession keeps the legal move journal alongside its Undo snapshots.
PuzzleCheckpointStore atomically writes a versioned journal per world under
Application Support/SortScape/Attempts. On load it matches the published starting
board and replays each move through the engine, rejecting incompatible, oversized,
invalid, or post-solve journals. Reads do not replace corrupt files. A new move or
Restart can replace/discard an unusable checkpoint. Debug test namespaces use a
separate directory and cannot modify the normal player's checkpoints.

Checkpoint writes happen before SpriteKit's animation lock, so a process death
mid-animation can recover the committed move. Undo and Restart also persist.
Re-entering the same world restores its board, move count and Undo history, with
no old selection, pending hint or animation. A solved checkpoint is kept until
ProgressModel successfully commits the reward; reloading before that point goes
through the existing idempotent reward path. The v5 wallet and purchase journals
are unchanged. A checkpoint does not contain or award any money or entitlement.
Writes are best effort: storage failure surfaces a message and does not block play.

Release metadata is explicit (1.0.0 / 1, com.sortscape.puzzleworlds). The main
project now resolves and compiles Firebase, including its device Release archive.
This supersedes Phase 8's package-download blocker, not the unverified console
and private-config steps. The unsigned archive is a local candidate, not a signed
TestFlight artifact. Keep offline and main SwiftPM workspace caches separate.
See QA_REPORT.md and RELEASE_CHECKLIST.md for verified evidence and account gates.

## Phase 10 — release isolation

Release uses its own xcconfig; it does not inherit private Debug ad/telemetry
overrides. The archive script requires Production telemetry selection and ads
off in Release, strips the local StoreKit catalog, and copies only the selected
private Firebase environment. The production StoreModel does not start a local
StoreKit manager or expose the QA storefront. Debug ad enablement, UMP form
entry points and Google test ad unit loads are compiled
out of Release. AdMob's sample app identifier is inert SDK metadata, not a
production ad configuration. This candidate does not monetize.

Settings shows a privacy link only when the build provides a valid HTTPS
SORTSCAPE_PRIVACY_POLICY_URL. No policy URL or production Firebase credentials
were supplied. iPhone remains portrait; iPad declares all four orientations
for its device family. Physical landscape QA remains an acceptance gate.

Tools/CaptureStoreScreenshots.py runs the existing isolated UI flows and exports
unaltered PNGs and provenance. Local StoreKit images are QA-only. The main
unsigned generic-iOS archive uses 1.0.0 (2); signed distribution and real-device
review are separate steps requiring owner action.

## Island artwork

The home screen uses the bundled `IslandCover` illustration. The active app
icon is Glass Puzzles. `IslandRewardArt` maps each restoration ID to one
bundled illustration shared by the SpriteKit scene and SwiftUI reward cards.
The scene sizes props to their plots while preserving each image's aspect
ratio. Locked and available plots continue to use the existing markers.
The editable source atlas is in `Documentation/IslandArtwork/RewardAtlas.png`.
To regenerate its eight image sets, run
`swift Tools/ImportIslandAtlas.swift Documentation/IslandArtwork/RewardAtlas.png Sources/SortScape/Assets.xcassets`.

Each level allows one successful hint per player save. A free suggestion and
a token-assisted move share the same limit. The progress save records the
level and any token debit together. Restart, Undo, and replay preserve the
limit. Older saves start with an empty set of used hints.

The final five island items unlock at 25, 40, 60, 80, and 100 clears.
Earlier purchases keep their original ledger entries.
