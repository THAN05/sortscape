import Foundation
#if canImport(FirebaseCore) && canImport(FirebaseAnalytics) && canImport(FirebaseCrashlytics)
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

/// No Firebase app/network initialization until an explicit choice and a valid environment file.
@MainActor final class FirebaseAnalyticsService: AnalyticsService {
    private var configured = false
    private var analyticsEnabled = false, crashesEnabled = false
    private var options: FirebaseOptions? {
        guard ProcessInfo.processInfo.environment["SORTSCAPE_DISABLE_TELEMETRY"] != "1",
              NSClassFromString("XCTestCase") == nil, NSClassFromString("XCTest.XCTestCase") == nil,
              let environment = Bundle.main.object(forInfoDictionaryKey: "SortScapeTelemetryEnvironment") as? String,
              ["Development", "Production"].contains(environment),
              let path = Bundle.main.path(forResource: "GoogleService-Info-\(environment)", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path), options.bundleID == Bundle.main.bundleIdentifier,
              options.googleAppID.range(of: "^1:[0-9]+:ios:[a-fA-F0-9]+$", options: .regularExpression) != nil,
              let project = options.projectID, project.range(of: "^[a-z][a-z0-9-]{4,29}$", options: .regularExpression) != nil else { return nil }
        return options
    }
    var available: Bool { configured || options != nil }
    func setCollection(analytics: Bool, crashes: Bool) {
        analyticsEnabled = analytics; crashesEnabled = crashes
        if !configured, analytics || crashes, let options {
            FirebaseApp.configure(options: options); configured = true
        }
        guard configured else { return }
        Analytics.setConsent([.analyticsStorage: analytics ? .granted : .denied, .adStorage: .denied, .adUserData: .denied, .adPersonalization: .denied])
        Analytics.setAnalyticsCollectionEnabled(analytics)
        if !analytics { Analytics.resetAnalyticsData() }
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(crashes)
        if !crashes { Crashlytics.crashlytics().deleteUnsentReports() }
    }
    func log(_ event: AnalyticsEvent) {
        guard configured, analyticsEnabled, event.valid else { return }
        let parameters: [String: Any] = event.parameters.mapValues {
            switch $0 { case .text(let value): value as Any
            case .integer(let value): value as Any
            case .number(let value): value as Any }
        }
        Analytics.logEvent(event.name.rawValue, parameters: parameters)
    }
    func record(_ code: DiagnosticCode) {
        guard configured, crashesEnabled else { return }
        let crash = Crashlytics.crashlytics()
        crash.setCustomValue(code.rawValue, forKey: "diagnostic_code")
        crash.record(error: NSError(domain: "SortScape.Diagnostic", code: code.rawValue))
    }
}

#else
/// Offline validation build only: never pretends to deliver reports.
@MainActor final class FirebaseAnalyticsService: AnalyticsService {
    var available: Bool { false }
    func setCollection(analytics: Bool, crashes: Bool) {}
    func log(_ event: AnalyticsEvent) {}
    func record(_ code: DiagnosticCode) {}
}
#endif
