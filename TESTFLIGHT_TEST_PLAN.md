# SortScape: Puzzle Worlds — 10-day beta plan

Start only after a signed candidate passes RELEASE_CHECKLIST.md and the owner
explicitly authorizes distribution. Current archives are local QA artifacts.
Use an internal group first. Start the clock after the build is processed and
available to testers; no test dates or invitations have been scheduled.

| Days | Focus | Pass evidence |
| --- | --- | --- |
| 1–2 | Fresh install, sorting guide, first clear, next world, locked worlds | Small and large iPhones; record version/build and OS; all actions reachable |
| 3–4 | Beginner through Expert, Undo, Restart, free Hint, fast taps | Representative worlds 1/21/41/66/86/100; no move corruption or blocked free progression |
| 5 | Offline and interruption | Enable Airplane Mode with Wi-Fi off; move, terminate during animation, reopen same world, Undo; verify wallet/rewards after a solved-board relaunch |
| 6 | Progression and island | Verify coins/stars, unlock gating, spend confirmation, milestones, relaunch; replay earns no duplicate first-clear rewards |
| 7 | Accessibility and lifecycle | Portrait, notch/home indicator, largest Dynamic Type, VoiceOver order/labels, Reduce Motion, background/foreground, memory pressure, silent audio |
| 8 | Monetization QA | StoreKit sandbox or Xcode configuration only; cancel, pending/approved, failed and interrupted delivery, restart, restore, refund; official test ad units only |
| 9 | Privacy and performance | UMP available/denied/revoked/offline; no ad blocks Next; independent analytics/crash opt-ins; compare cold launch/frame/thermal data on device |
| 10 | Retest and decision | Reproduce/fix all blockers; verify clean install and upgrade on final build; owner decides whether to advance |

Include a compact iPhone, a Dynamic Island iPhone, and the oldest supported iOS
available on physical hardware. Cover iPad separately if retained in device
families; verify landscape and window resizing as well as portrait. The current design uses a light appearance; verify system appearance
changes do not produce broken contrast. Separate test-ad runs from the normal
ads-off candidate. In test-ad QA, check reward only after the earned callback,
no duplicate grant on replay, failure/cancel costs nothing, first session has no
forced interstitial, caps hold, and Remove Ads prevents forced interstitials.
Do not turn on production ads for testing.

For StoreKit, use the simulator Local Store scheme for repeatable local tests.
Run sandbox tests only after the account has matching approved QA product setup
and a deliberately configured test build; the current Release store is disabled.
With private Firebase configuration, verify consent and development diagnostic
delivery separately; no intentional crash in Release. No accounts or real charges
are required to play through the campaign.

## Bug report template

    Title:
    Severity (P0/P1/P2/P3):
    Version/build, device, OS:
    Fresh install or upgrade; approximate progress:
    World/tier, moves, hints, relevant wallet before/after:
    Network state, accessibility settings, consent choices:
    Steps to reproduce:
    Expected:
    Actual:
    Frequency (e.g. 2/5):
    Workaround:
    Screenshot or timestamp / crash report ID if available:

Remove account identifiers, receipts, and personal information from attachments.
For performance, record the device, build, workload, thermal state and measurement
method; distinguish a subjective stutter from measured frame timing.

- **P0 — block:** crash on launch, progression/save loss, incorrect money/reward,
  consent bypass, production ad exposure, or release artifact/signing invalid.
- **P1 — block:** repeatable puzzle/navigation lock, broken restore/Remove Ads,
  inaccessible core action, or severe sustained performance issue.
- **P2 — triage:** recoverable issue with a clear workaround; owner accepts or fixes.
- **P3 — nonblocking:** cosmetic copy/layout polish without accessibility impact.

## Exit criteria

- [ ] Final signed build and exact tester cohort identified; explicit approval recorded.
- [ ] All campaign solutions and full XCTest suite pass on candidate code.
- [ ] Physical-device, offline, upgrade, privacy and accessibility evidence attached.
- [ ] Zero open P0/P1 issues; P2 exceptions recorded with owner and workaround.
- [ ] Account metadata, privacy/support links and disclosure checks complete.
- [ ] Store/ads/telemetry behavior matches approved configuration; no production ad testing.
