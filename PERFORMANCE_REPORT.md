# Phase 8 performance and release QA

Measured 2026-11-03 with Xcode 27.1 / Swift 6.4, iOS 27 simulators on the local Mac.
These are development simulator observations, not physical iPhone benchmarks or a
commercial release sign-off. Firebase retrieval is blocked by GitHub connection
resets/SSL timeouts; all new app measurements use the explicit Firebase-unavailable
offline project. No live ad creative, Firebase console upload, retention statistic,
or physical-device battery figure is claimed.

## Changes with a concrete allocation benefit

- PuzzleScene used to remove/recreate every container, symbol and piece even for a
  selection change. It now updates outline strokes in place for identical board and
  size. A test verifies node identity across 200 selection updates and redraw after
  resizing; animation invalidates the cache so Undo/Restart remain correct.
- Piece gradients already had four cached textures; that cache is preserved. No new
  remote textures or synchronous asset downloads were added.
- IslandScene skips identical visual state, including availability, restoration,
  selection, theme, size and Reduce Motion. Ownership changes still construct/animate.
- All GameFeedback instances share three warmed audio buffers on a serial queue;
  SwiftUI reconstruction no longer creates/prepares another audio buffer set.
- Diagnostic frame sampling is opt-in, bounded at 3,600 samples and never uploaded.
  Hint solver work remains detached/cancellable, with injectable bounded search effort.

## Recorded workloads

| Workload | Observation | Scope |
| --- | --- | --- |
| 200 selection-only renders, world 100 | ~0.011 s average | XCTClockMetric, 5 samples, Debug hosted tests |
| 200 selections forcing full reconstruction | ~0.049 s average | Same process/board; deliberately forced redraw reference, not an archived old binary |
| Actual SKView rendering, 120 selection updates + invalid feedback | 123 valid frame samples; mean interval 16.915 ms, p95 16.667 ms | Compact simulator, bounded 2-second workload; concurrent simulator activity; not GPU frame time |
| Launch | 3.390 s mean; 3.402 / 3.408 / 3.361 s samples | XCTApplicationLaunchMetric; process relaunch/foreground launch, not first-install/dyld-only startup |
| Time Profiler | 10.708 s idle home trace, no rows in >250ms potential-hangs table | Separate iPhone 18 Pro simulator, isolated save, ads/store startup/telemetry disabled |

The reference is a microbenchmark for node reconstruction, not a percent improvement
in whole-game FPS. XCTMemoryMetric process peaks were approximately 69–70 MB during
one run; the second workload inherits prior allocations, so these are not clean
before/after memory footprints and do not prove lower peak memory or absence of
leaks. Launch tests run under UI automation with SDK startup disabled and cannot
predict configured Firebase startup cost. Preserve raw xcresult attachments/logs
before comparing future releases; don't establish hard performance budgets from
these few simulator samples.

Evidence: /private/tmp/sortscape-phase8-compact-corrected.log,
/private/tmp/sortscape-phase8-verified-full.log, and their DerivedDataPhase8Offline
xcresults. Frame JSON is attached to testRenderedSceneFrameCadence. The short
Time Profiler trace lives at /private/tmp/sortscape-phase8-home.trace; it is an idle
home smoke capture, not a representative gameplay/battery profile.

## Crash reporting development procedure (not yet run against Firebase)

1. Restore GitHub access; resolve/build the main SortScape project with Firebase
   13.1.0, not the offline project. Supply the ignored Development plist with correct
   bundle ID. Opt in to crash diagnostics. Analytics may remain off.
2. In DEBUG Settings, Send development diagnostic records only a fixed diagnostic
   enum code. Relaunch and verify a symbolicated nonfatal in the Development console.
3. For a real crash test, use a disposable UUID SORTSCAPE_TEST_SAVE and launch with
   SORTSCAPE_CRASH_TEST=1, Development configuration, debugger disconnected. Settings
   exposes a clearly destructive isolated development crash button only when all
   these gates and crash opt-in hold. Relaunch after pressing it; verify the report
   in the Development console. This code/control does not exist in Release.
4. Upload archived dSYMs explicitly through Tools/UploadCrashlyticsSymbols.sh using
   official SDK upload-symbols, that environment plist, and the archive's dSYMs.
   Verify function/line symbolication, revoke consent, repeat offline/foreground
   transitions, confirm no new app-supplied diagnostics while off and unsent deletion.
5. Do not intentionally crash production or claim verification from the mock tests.

## Physical-device release gates

Profile signed Release on the oldest supported iPhone and a current Dynamic Island
model: Time Profiler, Animation Hitches/Game Performance, Allocations/Leaks, Metal
GPU, and power/thermal tools. Exercise 20+ minutes of moves/undo/restart/hints, world
100, full island, audio/haptics, reward ad dismissal/interruptions, StoreKit sandbox,
background/foreground and memory pressure. Record p50/p95 frame times, allocations,
steady/peak memory, thermal state and energy under consistent brightness/network/
battery conditions. Test real VoiceOver, Dynamic Type, Reduce Motion, silent audio,
UMP regions and signed Firebase crash delivery. No battery, GPU, leak or device FPS
claim can currently be made. Existing background and Reduce Motion UI tests remain
part of every suite; offline puzzles and rewards never depend on reporting success.

## SDK/deployment blockers

The official Firebase Git repository could not be cloned (connection reset and SSL
connection timeout); a release archive/source endpoint probe also timed out. The
main Firebase-dependent build therefore cannot be verified here. The published
13.1.0 manifest/product names were reviewed; the moving main branch's 13.2.0 version
was not a released tag and was replaced before final configuration. No Firebase
SDK typechecking, DebugView, Crashlytics delivery/symbolication or real configuration
validation is claimed. No account files were supplied. See Configuration/Firebase-README.md and RETENTION_DASHBOARD.md for setup. Prior StoreKit/AdMob account/device
and server-reconciliation release gates remain in Documentation/STOREKIT.md and
Documentation/ADMOB.md. No products, live ads, dashboards or app were published.

## Final automated verification

- Existing pre-change baseline: 81/81 iOS tests, plus 38/38 swift test.
- Independent release CampaignTool validation: 100/100 boards solved and replayed.
- Final sequential offline-project suite: **96/96 passed, zero failures** — 38 core,
  44 hosted app, 14 UI. Bundle: DerivedDataPhase8Offline/Logs/Test/
  Test-SortScape-2026.11.03_15-38-13--0600.xcresult.
- Final Debug/test and Release simulator builds passed for the explicit offline
  variant. Release Info confirms ads NO, purchases false, Firebase analytics/crash
  collection false, Production environment. Binary check excludes both DEBUG crash
  probe and diagnostic button. Main Firebase-enabled build is blocked as above.
- Privacy compact screenshot reviewed: Documentation/Phase8-QA/privacy-compact.png.
  Individual passing tests: Documentation/Phase8-QA/tests-passed.json.

Earlier UI runs exposed crowded settings and a guide sheet hosted on a lazy section;
both were fixed by a dedicated privacy page and stable Settings sheet host. UI
scrolling/switch targeting was corrected and all flows passed in the final suite.
An overlapping StoreKit test run was interrupted after a pending-approval stall;
the final sequential run passed that test in 0.095 s. These superseded failures are
not hidden as passing runs; they are resolved by the final clean suite. Simulator
telephony/audio and Xcode metadata warnings remain non-failing environmental logs.

Final app was installed and normally launched on the primary iPhone simulator.
The existing v1 player file stayed byte-identical after launch; its home screen
was visually reviewed (Documentation/Phase8-QA/home-preserved-profile.png).
