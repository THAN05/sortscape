# SortScape: Puzzle Worlds

Phase 7 iOS sorting game with an optional StoreKit 2 store and interactive island restoration. Open `SortScape.xcodeproj`, select the SortScape scheme and an iOS 17+ simulator, then Run. The generated project is included; XcodeGen is only needed after editing `project.yml`.

## Commands

```sh
xcodegen generate
swift test
xcodebuild -project SortScape.xcodeproj -scheme SortScape -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath DerivedData test CODE_SIGNING_ALLOWED=NO
```

Explore worlds or continue from the home screen. Tap a nonempty container to select it, then tap an empty container or one with a matching top piece. Each move transfers one piece. Fill each occupied container with four matching pieces. Tap the selection again to cancel. Undo and Restart are available below the board. 100 seeded, verified worlds load from bundled JSON across five difficulty tiers. Level 1 starts unlocked; completion awards 25 coins once, efficiency and milestone bonuses, and unlocks the next world. Progress, best move counts, earned stars, and unlocks save locally. Existing Phase 1–5 saves migrate without losing coins, with a backup before upgrade.

See AGENTS.md for contributor guidance, ARCHITECTURE.md for module boundaries, and TASKS.md for verification and future work. Device installation requires an Apple development team in Signing & Capabilities. No third-party SDK setup is required.


Gameplay includes animated transfers, color-independent symbols, spoken vessel actions, hints, pause/settings, and a completion screen. Sound, haptics, and Reduce Motion are configurable; system Reduce Motion is always respected. Backgrounding pauses the current puzzle. The scheme runs core, presentation-model, and UI tests; UI screenshots are saved in the xcresult bundle.


For campaign generation, independent validation, schema, difficulty scoring, and save migration, see [level authoring](Documentation/LEVEL_AUTHORING.md). Run `swift run -c release CampaignTool validate` to independently replay all 100 solutions and refresh the report.

The store includes configurable coin/hint packs, ad-removal and cosmetic entitlements, and Starter Bundle. Select **SortScape Local Store** for simulator-only purchases. Shipping purchases remain disabled pending approval and Apple account setup. Prices use localized StoreKit metadata. See [StoreKit setup and security boundaries](Documentation/STOREKIT.md).

Advertising uses the official Google Mobile Ads/UMP Swift packages and **only Google test ad units**. Shipping ads default to off. Debug Settings offers an explicit test-ad/privacy flow; no forced ad can interrupt an active puzzle. Free hints and Undo remain available. See [AdMob integration and privacy QA](Documentation/ADMOB.md) for consent/account setup, caps, local-only analytics, and device tests still needed.


## Phase 8 telemetry builds

The main project links Firebase Analytics Core and Crashlytics 13.1.0. Supply private
environment files as described in Configuration/Firebase-README.md; reporting stays
off by default. Phase 9 resolved the packages and built the main unsigned iOS archive. Firebase console verification still requires private configuration.
For explicit offline QA, run `python3 Tools/GenerateOfflineProject.py`, then open
SortScapeOffline.xcodeproj (scheme SortScape). This builds the app without Firebase
and labels reporting unavailable; it does not validate the SDK-enabled release.
See ANALYTICS_EVENTS.md, RETENTION_DASHBOARD.md and PERFORMANCE_REPORT.md for event
semantics, privacy, measured results, and remaining release gates.
