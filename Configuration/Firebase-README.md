Firebase SDK 13.1.0 (Analytics Core + Crashlytics), app target only.

Download separate iOS app configuration files from your Development and Production
Firebase projects, bundle ID com.sortscape.puzzleworlds. Put them at:
Sources/SortScape/Resources/Firebase/GoogleService-Info-Development.plist
Sources/SortScape/Resources/Firebase/GoogleService-Info-Production.plist
This directory is ignored. Run xcodegen generate after adding a file. Bundle only
the intended environment file for distribution; do not distribute development
configuration in production. Debug selects Development; Release selects Production through Ads.xcconfig.
Optional overrides belong in ignored Configuration/Telemetry.local.xcconfig.
Firebase client config is not an authorization secret, but keep deployment-specific
files private. Never embed service-account keys. Configure console data retention,
sharing, access control, App Store privacy answers and a public privacy policy.
Collection defaults off and requires independent user analytics/crash choices.
App must not be marketed as anonymous: Firebase uses installation/app-instance IDs.

For release symbol upload, run the official Crashlytics upload-symbols command in CI
with that environment's plist and the archived dSYM bundle. Do not upload during
local unconfigured builds. See PERFORMANCE_REPORT.md for development verification.
