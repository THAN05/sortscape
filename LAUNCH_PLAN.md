# Launch and first 30 days

Recommended scope: free full campaign and restoration, no ads or purchases.
Optional production reporting is a separate approved configuration. Do not announce
a launch date until the signed candidate, privacy/support pages, device beta and
account setup pass RELEASE_CHECKLIST.md.

| Window | Actions and decision |
| --- | --- |
| Before release | Finish signing, configure the policy link, validate the signed candidate, run the 10-day beta, resolve P0/P1 issues, approve metadata and actual screenshots. Review data flows and console settings. Verify no live monetization in the candidate. |
| Day 0 | After explicit approval, release manually from App Store Connect. Verify availability, correct build, store assets and support links on intended storefronts. Install through the store and smoke-test offline play, recovery, and progression. |
| Days 1–3 | Check crashes, app launch issues, loss of progress, accessibility and support reports daily. Escalate any broken save, consent or core progression immediately. Confirm event coverage before using dashboards. |
| Days 4–7 | Review early cohort D1, tutorial exits, world-level hint/restart/exit counts and store conversion. Read device/build context before changing difficulty. |
| Days 8–14 | Review mature D7 and support trends. Compare cohorts and sample sizes; prioritize one well-supported onboarding, readability or pacing improvement. Rerun affected tests and beta checks before updating. |
| Days 15–21 | Compare pre/post changes with matching cohorts, OS and consent coverage. If monetization is approved separately, test its sandbox and consent paths first; roll out narrowly with retention/crash/progression guardrails and a tested kill switch. |
| Days 22–30 | Decide next update from stability, support and mature retention. Plan D30 review after return windows close. Publish no statistics based on incomplete cohorts or test data. |

Owner approves release and any paid/ads rollout. Engineering owns artifact,
crash and progression checks; support owns issue triage and feedback summaries.
Pause rollout for save loss, incorrect charges/rewards, privacy failure, repeatable
crash or blocked progression. Disable affected server-controlled features only
where a verified switch exists; the current monetization-off build has no live
feature switches. For a first release, do not assume staged rollout or rollback
is available; prepare a corrective build or discuss storefront availability with
the owner. For eligible updates, review Apple's current phased-release options.
Definitions and source limitations: POST_LAUNCH_METRICS.md.
