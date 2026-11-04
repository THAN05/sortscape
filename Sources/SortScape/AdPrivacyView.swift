import SwiftUI

struct AdPrivacyView: View {
    @EnvironmentObject private var ads: AdCoordinator
    var body: some View {
        Section {
            Text(ads.message).accessibilityIdentifier("ad-message")
            if ads.loading { ProgressView("Checking privacy or loading test ads…") }
            if ads.enabled {
                Button("Disable ads on this device") { ads.disable() }.disabled(ads.busy).accessibilityIdentifier("disable-ads")
                if !ads.consentAllowed {
                    Button("Retry privacy check") { Task { await ads.enableTestAds() } }.disabled(ads.busy || ads.loading)
                }
                Button("Retry loading ads") { Task { await ads.preload() } }.disabled(ads.busy || ads.loading)
            }
            #if DEBUG
            if !ads.enabled {
                Button("Enable Google test ads") { Task { await ads.enableTestAds() } }
                    .disabled(ads.busy || ads.loading).accessibilityIdentifier("enable-test-ads")
            }
            #endif
            if ads.privacyOptionsRequired {
                Button("Manage ad privacy choices") { Task { await ads.privacyOptions() } }
                    .disabled(ads.busy || ads.loading).accessibilityIdentifier("ad-privacy-options")
            }
            if ads.hasPendingReward { Button("Retry saving earned ad reward") { ads.retryPendingRewards() } }
            Text("No tracking permission is requested. Ads use non-personalized, restricted-data requests after Google's consent check. Google may still receive IP address, device and ad interaction data. Disabling ads stops new ad loads and presentations. Google may still report prior ad activity; data already sent cannot be recalled.").font(.footnote)
            Link("Google advertising privacy", destination: URL(string: "https://policies.google.com/technologies/ads")!)
            Text("Ad statistics stay on this device. We keep aggregate impressions, rewards, revenue estimates, and days returned to evaluate the experience. No personal identifiers or analytics uploads are added.").font(.footnote)
            Text("Local sessions: \(ads.analytics.snapshot.counters["session_start", default: 0]) · rewarded impressions: \(ads.analytics.snapshot.counters["rewarded_impression", default: 0]) · forced impressions: \(ads.analytics.snapshot.counters["interstitial_impression", default: 0])").font(.caption)
        } header: { Text("Advertising & privacy") }
    }
}
