# Retention and player experience reporting

This is the reporting specification, not measured retention. No player dataset or
Firebase console connection is available. Create separate Development/Production
GA4 properties, enable BigQuery export in the console and apply least-privilege IAM,
retention limits and deletion policies. Register event-scoped custom dimensions
level_id, difficulty, placement, item, reason and ad_format; custom metrics move_count,
completion_time, hints_used, restarts, stars_earned and levels_completed as needed.
Keep cardinality low; don't register transaction/ticket/session identifiers.

## Cohorts

Use UTC calendar dates consistently. Cohort D is users whose first_open first occurs
on D. Day N retention = distinct cohort users active exactly on D+N / all distinct
cohort users on D, only when that day has elapsed. Report D1, D7 and D30 with cohort
sizes and confidence intervals; don't confuse rolling or cumulative retention with
exact-day retention. first_open is a first-observed-install proxy: reinstall, denied
consent, late opt-in and resetAnalyticsData can alter this identity/cohort. Reporting
covers consenting observed players and cannot establish all-install retention.
Never backfill denied-consent activity or identify players across reinstalls.

DAU = distinct consenting app-instance users with observed foreground/engagement
activity that UTC day, using GA4 active-user definitions consistently. Never equate
a local ad counter with fleet DAU. Don't send a second daily_active_user event.
Use exported user_pseudo_id only inside controlled analytics reporting, not app logs.

## Dashboard pages

1. Acquisition/retention: first-open cohorts, D1/D7/D30 and DAU; filters app version,
   OS, device category, country (SDK aggregate), acquisition source and consent coverage.
2. Sessions: GA4 built-in sessions and engagement duration; separately show custom
   session_end duration and levels_completed/foreground interval. Inactive system
   sheets aren't session endings; backgrounds are. Termination can omit session_end;
   show coverage and don't compare these intervals as identical to GA4 sessions.
3. Tutorial: starts → finishes of explicit two-page sorting guide. No claim that
   reading both pages proves mastery; segment subsequent first-level completion.
4. Difficulty: level_start, level_complete, level_restart, level_fail(reason), moves,
   active completion-time median/p90, hint use, star distribution. Completion/start
   is attempt-based, not unique-user conversion; segment by first vs repeat visits
   using exported ordered events when required. Identify high restart/abandonment
   relative to adjacent boards and sufficient sample size. OS termination may omit
   level_fail/session_end; also examine unmatched starts after a defined inactivity
   window, exclude still-active/right-censored attempts, and report that inference
   separately from explicit navigation failures. Then inspect solver
   solution length/effort in Documentation/level-validation.json. Don't alter published
   seeded boards automatically. AssistancePolicy bounds hint search effort and is
   injectable; rewards and star thresholds remain immutable campaign data.
5. Monetization/retention: offered → started → earned reward funnels by placement;
   actual paid ad revenue by currency (do not sum unlike currencies); interstitial
   impressions, purchase completion and currency sinks. Separate local StoreKit/test
   ads from real revenue datasets (use Development property). Compare next-day return
   and next-level starts by ad exposure, controlling for progress and session number;
   observational correlation does not prove causation. No ad-placement changes were
   justified by nonexistent retention data. Current caps remain first-session-free,
   4 clears, 180s spacing, 2 interstitial/session and 3/day.

## Example BigQuery exact-day cohort skeleton

Replace project/dataset and restrict date partitions in a scheduled query. Mature
cohorts only; deduplicate each user/date. GA4 event_date uses property timezone, so
this skeleton explicitly derives UTC dates from event_timestamp instead.

```sql
WITH observed AS (
  SELECT user_pseudo_id AS u, event_name,
    DATE(TIMESTAMP_MICROS(event_timestamp), 'UTC') AS day
  FROM `PROJECT.analytics_PROPERTY.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20261101' AND '20261231'
    AND user_pseudo_id IS NOT NULL
), installs AS (
  SELECT u, MIN(day) AS cohort FROM observed
  WHERE event_name = 'first_open' GROUP BY u
), active AS (
  SELECT DISTINCT u, day FROM observed
  WHERE event_name IN ('session_start', 'user_engagement', 'level_start')
)
SELECT cohort, n AS retention_day, COUNT(DISTINCT i.u) AS cohort_size,
  COUNT(DISTINCT IF(a.u IS NOT NULL, i.u, NULL)) AS returned,
  SAFE_DIVIDE(COUNT(DISTINCT IF(a.u IS NOT NULL, i.u, NULL)),
              COUNT(DISTINCT i.u)) AS retention
FROM installs i CROSS JOIN UNNEST([1, 7, 30]) n
LEFT JOIN active a ON a.u = i.u AND a.day = DATE_ADD(i.cohort, INTERVAL n DAY)
WHERE DATE_ADD(cohort, INTERVAL n DAY) < CURRENT_DATE('UTC')
GROUP BY cohort, retention_day;
```

For production, include complete historical first_open coverage (not just a short
window that would misclassify old installs), late-arriving export updates, consent
coverage and privacy thresholds. No dashboards have been deployed or populated.
