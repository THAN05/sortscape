# Post-launch measurement specification

No live observations exist. Build separate dashboards for App Store Connect,
consenting production telemetry, and sandbox/QA. Do not combine their populations
or count synthetic fixtures as users, sales, impressions or retention.

| Measure | Operational definition | Evidence |
| --- | --- | --- |
| DAU | Distinct eligible app instances with a foreground engagement event on a UTC day | Consented Analytics production cohort; track consent coverage |
| D1 / D7 / D30 | First-observed-install cohort members active exactly 1 / 7 / 30 UTC days later divided by the original cohort | Firebase first_open proxy; exclude immature cohorts, report sample size and late-arrival window |
| Tutorial completion | Tutorial finish events / guide starts; report opt-in sample and early exits separately | Explicit guide events; guide reading does not prove mastery |
| Level completion | Solves / starts by world, tier and build; report retries and hints separately | Attempt events, not unique player conversion |
| Abandonment | Explicit navigation exits on unfinished attempts; separately estimate unresolved starts after a documented inactivity window | Distinguish restart, process death and still-active attempts; avoid counting every missing completion as a failure |
| Ads | Actual impressions by placement and network; paid impression revenue by currency and precision; rewarded earned / started | AdMob reporting is authoritative for earnings; client callbacks are diagnostics; no estimates for missing paid values |
| IAP | Distinct paying users / eligible active users in the same reporting population and window; separate product sales, refunds and net proceeds | App Store Connect reports; verified local deliveries measure fulfillment only, not revenue |
| Crash-free sessions | Eligible observed sessions without a fatal crash / eligible sessions | Crashlytics dashboard with configured session coverage; compare by app version and device |
| ARPDAU | Recognized ad and IAP revenue on the same UTC day divided by DAU from a compatible population | Normalize currency, reconcile refunds and distinguish gross sales from proceeds. If denominators cannot be aligned, report components and mark combined ARPDAU unavailable |

Record timestamps, reporting timezone, release version, supported OS, attribution
window and consent coverage. Set minimum cohort sizes before segmenting; do not
send transaction IDs, names or emails. D30 for a day-1 cohort is only measurable
after its return day closes and exports settle. A 30-day plan cannot promise a
fully mature D30 chart. Firebase and ad/in-app revenue dashboards are currently
unconfigured or disabled; mark missing instrumentation unavailable rather than
publishing zeros that imply verification. Review event schema in ANALYTICS_EVENTS.md.

Use App Store impressions → product page views → downloads to assess acquisition.
Track purchasing and ad offer conversion independently of store conversion.
No paid revenue appears in an ads-off, purchases-off launch scope by design;
verify actual financial sources before drawing comparisons. Monitor interrupted
attempt recovery, restore/refund tickets and unexpected currency changes as guardrails.
