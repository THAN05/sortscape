import SwiftUI

struct TelemetrySettingsSection: View {
    @ObservedObject private var telemetry = Telemetry.shared
    var body: some View {
        Section {
            Toggle("Share gameplay analytics", isOn: Binding(get: { telemetry.analyticsEnabled }, set: { telemetry.preferences(analytics: $0, crashes: telemetry.crashesEnabled) }))
                .accessibilityIdentifier("analytics-setting")
            Toggle("Share crash diagnostics", isOn: Binding(get: { telemetry.crashesEnabled }, set: { telemetry.preferences(analytics: telemetry.analyticsEnabled, crashes: $0) }))
                .accessibilityIdentifier("crash-setting")
            #if DEBUG
            if telemetry.available && telemetry.crashesEnabled {
                Button("Send development diagnostic") { telemetry.diagnose(.developmentProbe) }
                if ProcessInfo.processInfo.environment["SORTSCAPE_CRASH_TEST"] == "1",
                   UUID(uuidString: ProcessInfo.processInfo.environment["SORTSCAPE_TEST_SAVE"] ?? "") != nil {
                    Button("Crash isolated development test", role: .destructive) { fatalError("SortScape development crash probe") }
                }
            }
            #endif
        } header: { Text("Help improve SortScape") }
        footer: { Text(telemetry.available ? "Optional Firebase reports include puzzle actions and app diagnostics. No name, email, advertising identifier, or save contents are sent by SortScape. You can turn sharing off at any time." : "Reporting is unavailable in this build. Your choices are saved; gameplay works offline. Reporting requires a configured Firebase project. No gameplay reports are being sent.") }
    }
}

struct SortingGuide: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var visit = UUID()
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: step == 0 ? "hand.tap" : "checkmark.circle").font(.system(size: 64)).foregroundStyle(ScapeTheme.teal).accessibilityHidden(true)
                Text(step == 0 ? "Pick a piece" : "Find its place").font(.largeTitle.bold())
                Text(step == 0 ? "Tap a vessel to select its top piece. Shapes identify colors too." : "Tap an empty vessel or a matching top color. Fill each vessel with four matching pieces. Undo, Restart, and free Hint are always available.").multilineTextAlignment(.center)
                Button(step == 0 ? "Next" : "Ready to sort") {
                    if step == 0 { step = 1 }
                    else {
                        Telemetry.shared.emit(AnalyticsEvent(name: .tutorialComplete), once: "tutorial.complete.\(visit)")
                        dismiss()
                    }
                }.buttonStyle(ScapeButtonStyle()).frame(minHeight: 44)
            }.padding(24).navigationTitle("Sorting guide")
                .toolbar { Button("Close") { dismiss() } }
                .onAppear { Telemetry.shared.emit(AnalyticsEvent(name: .tutorialStart), once: "tutorial.start.\(visit)") }
        }
    }
}

struct TelemetryPreferencesView: View {
    var body: some View {
        Form {
            TelemetrySettingsSection()
            if let text = Bundle.main.object(forInfoDictionaryKey: "SortScapePrivacyPolicyURL") as? String,
               let url = URL(string: text), url.scheme == "https", url.host != nil {
                Link("Privacy policy", destination: url)
            }
        }
            .navigationTitle("Analytics & diagnostics")
            .navigationBarTitleDisplayMode(.inline)
    }
}
