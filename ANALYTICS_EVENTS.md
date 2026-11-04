# Analytics event contract

Phase 8, 2026-11-03. Closed Swift event enum, typed string/integer/finite double
parameters, max 25 parameters, names <=40 characters and values <=100 UTF-8 bytes.
No player-supplied text, names, email, save contents, receipt identifiers, ticket IDs,
error descriptions, precise location or advertising identifiers are sent by app code.
Firebase still uses installation/app-instance identifiers: optional reporting is not
anonymous. Analytics Core is selected, IDFV disabled, all ads consent denied.
Analytics and crash reporting require independent Settings opt-in. Events while off
or unconfigured are dropped, not buffered for later consent or retroactively sent. Active attempt counters reset at consent changes so earlier
uncounted time/hints are not backfilled after opt-in.

| Event | Trigger / parameters |
| --- | --- |
| first_open | Firebase automatic only; first observed activation, not manually logged |
| session_start | Firebase automatic only, with Firebase's own session semantics |
| session_end | Background foreground-interval closure: duration seconds, levels_completed |
| tutorial_start / tutorial_complete | Settings → Learn to sort opens / player finishes both guide pages; closing early never completes |
| level_start | First active appearance per attempt |
| level_complete | Committed solved state after animation settles, once per attempt; stars_earned is performance rating, not new currency |
| level_fail | Unfinished attempt left or restarted; reason navigation/restart; no false failure for invalid tap or background |
| level_restart | Actual restart; previous attempt metrics; followed by new level_start |
| hint_used | Solver produces usable free suggestion, or token is successfully spent on a legal assist |
| undo_used | Actual normal Undo or two-move rewind, never disabled/no-history taps |
| island_decoration_unlocked | Successfully saved restoration: decoration enum |
| daily_challenge_started / daily_challenge_completed | Reserved typed hooks only. No daily challenge feature exists; never emitted speculatively |
| rewarded_ad_offered | Visible optional reward confirmation requested: placement, level_id |
| rewarded_ad_started | SDK full-screen show callback, once per ticket |
| rewarded_ad_completed | SDK earned callback, once per ticket, independent of later save retry |
| interstitial_ad_shown | SDK impression callback, once per ticket |
| ad_load / ad_loaded / ad_failed / ad_dismissed | SDK lifecycle: ad_format; no raw SDK errors |
| ad_revenue_paid | SDK paid callback only: ad_platform=admob, ad_format, value in currency units, ISO currency; ticket dedup; never estimated |
| purchase_started | User's accepted store action: logical item enum |
| purchase_completed | Newly verified durable fulfillment record only: item; no restore/reconcile/revoked/duplicate callback |
| purchase_failed | Purchase request returns failure: item, reason=store_error; cancellation and pending are not failures |
| virtual_currency_earned / virtual_currency_spent | Newly saved ledger entries only, separate coins/stars, absolute value, source=gameplay/purchase/rewarded_ad; migration excluded |

Level events carry level_id (Int), difficulty (tier raw string), move_count (Int),
completion_time (Double seconds active in attempt), hints_used (Int), restarts (Int).
level_start begins at zero; time excludes pause/background. level_restart describes
the old attempt; new attempts preserve visit restart count. Stars never sent as
money. Level completion is gameplay success even if reward saving fails; currency
analytics is emitted only after a successful write.

Purchase/reward/economy duplication is prevented by comparison of durable before/
after journal state, including after app restart. No transaction IDs leave the device.
There is deliberately no analytics transaction queue in the economic save: a process
crash immediately after save but before logging can lose an analytics event. Exactly
once remote analytics requires server reconciliation; client analytics must never
change reward fulfillment or claim financially authoritative accounting.

Firebase may also generate automatic in_app_purchase, ad_impression and engagement
events. Use the custom purchase_completed / ad_revenue_paid streams for these app
reports OR the automatic streams, never sum both. Do not manually log reserved
first_open, session_start or in_app_purchase. Screen auto-reporting is disabled.

Official setup and reference reviewed:
- https://firebase.google.com/docs/ios/setup
- https://firebase.google.com/docs/analytics/ios/configure-data-collection
- https://firebase.google.com/docs/analytics/ios/events
- https://firebase.google.com/docs/crashlytics/ios/get-started
- https://raw.githubusercontent.com/firebase/firebase-ios-sdk/13.1.0/Package.swift

Use Development Firebase DebugView (-FIRDebugEnabled in a local scheme) to verify
real uploads once configuration and SDK access exist. Never enable debug collection
in production. No Firebase traffic or console data has been verified in this session.
