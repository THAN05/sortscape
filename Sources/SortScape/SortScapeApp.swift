import SwiftUI
import PuzzleCore

enum GameRoute: Hashable { case levels, island, store, game(Int) }
@MainActor
final class GameRouter: ObservableObject {
    @Published var path: [GameRoute] = []
    func next(_ id: Int) {
        if case .game = path.last {
            path[path.count - 1] = .game(id)
        } else {
            path.append(.game(id))
        }
    }
    func home() { path.removeAll() }
}

@main
struct SortScapeApp: App {
    @StateObject private var progress = ProgressModel()
    @StateObject private var settings = AppSettings.shared
    @StateObject private var router = GameRouter()
    @StateObject private var store = StoreModel()
    @StateObject private var ads = AdCoordinator.application()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                HomeView()
                    .navigationDestination(for: GameRoute.self) { route in
                        switch route {
                        case .levels: LevelSelectionView()
                        case .island: IslandView()
                        case .store: StoreView()
                        case .game(let id):
                            if let level = progress.manager?.levels.first(where: { $0.id == id }), progress.progress.isUnlocked(id) { GameView(level: level).id(id) }
                            else { ContentUnavailableView("World unavailable", systemImage: "lock") }
                        }
                    }
            }.environmentObject(progress).environmentObject(settings).environmentObject(router).environmentObject(store).environmentObject(ads)
                .task { if ProcessInfo.processInfo.environment["SORTSCAPE_DISABLE_STORE_START"] != "1", NSClassFromString("XCTestCase") == nil, NSClassFromString("XCTest.XCTestCase") == nil { await store.start(progress: progress) } }
                .task {
                    #if DEBUG
                    let testing = ProcessInfo.processInfo.environment["SORTSCAPE_TEST_ADS"] != nil && UUID(uuidString: ProcessInfo.processInfo.environment["SORTSCAPE_TEST_SAVE"] ?? "") != nil
                    #else
                    let testing = false
                    #endif
                    let configured = (Bundle.main.object(forInfoDictionaryKey: "SortScapeAdsEnabled") as? String) == "YES"
                    if ProcessInfo.processInfo.environment["SORTSCAPE_DISABLE_ADS"] == "1" && !testing { return }
                    await ads.start(progress: progress, enabled: testing || (configured && ProcessInfo.processInfo.environment["SORTSCAPE_DISABLE_ADS"] != "1"))
                }
                .task { Telemetry.shared.foreground(true) }
                .onChange(of: scenePhase) { _, phase in
                    // Transient inactive (system sheet) is not a session boundary.
                    if phase != .inactive { Telemetry.shared.foreground(phase == .active) }
                    ads.foreground(phase == .active)
                    if phase == .active { Task { await store.refreshEntitlements() } }
                }
                .tint(ScapeTheme.teal).preferredColorScheme(.light)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var progress: ProgressModel
    @State private var settingsOpen = false
    @Environment(\.dynamicTypeSize) private var typeSize
    private var continueLevel: Level? {
        progress.manager?.levels.first(where: { !progress.progress.isCompleted($0.id) && progress.progress.isUnlocked($0.id) }) ?? progress.manager?.levels.last
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Label("SORTSCAPE", systemImage: "sparkle").font(.system(size: 12, weight: .heavy, design: .rounded)).tracking(3)
                    Spacer()
                    Button { settingsOpen = true } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 20)).frame(width: 48, height: 48).background(.white, in: Circle()) }
                        .accessibilityLabel("Settings")
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("A little order.\nA world of calm.").font(.system(size: 39, weight: .bold, design: .rounded)).tracking(-1).minimumScaleFactor(0.8)
                    Text("Colorful puzzles. A moment for you.").font(.subheadline).foregroundStyle(ScapeTheme.teal)
                }
                Image("IslandCover").resizable().scaledToFit()
                    .frame(height: 270).frame(maxWidth: .infinity)
                    .background(Color(red: 1, green: 0.93, blue: 0.79))
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .accessibilityHidden(true)
                CurrencyBalanceView(coins: progress.progress.coins, stars: progress.progress.starBalance)
                Text("\(progress.progress.bestMoves.count)/\(progress.manager?.levels.count ?? 0) worlds restored").font(.caption).foregroundStyle(ScapeTheme.teal)
                if let level = continueLevel {
                    NavigationLink(value: GameRoute.game(level.id)) {
                        HStack { Text(progress.progress.bestMoves.isEmpty ? "Begin your escape" : "Continue your journey"); Image(systemName: "arrow.right") }
                    }.buttonStyle(ScapeButtonStyle()).accessibilityIdentifier("play")
                }
                NavigationLink(value: GameRoute.levels) { Text("Explore worlds") }.buttonStyle(ScapeButtonStyle(secondary: true)).accessibilityIdentifier("explore")
                NavigationLink(value: GameRoute.island) {
                    HStack { Label("My island", systemImage: "leaf.fill"); Spacer(); Text("\(progress.progress.island.completionPercentage)%") }
                }.buttonStyle(ScapeButtonStyle(secondary: true)).accessibilityIdentifier("island")
                #if DEBUG && targetEnvironment(simulator)
                NavigationLink(value: GameRoute.store) { Label("Visit the store", systemImage: "bag") }.buttonStyle(ScapeButtonStyle(secondary: true)).accessibilityIdentifier("store")
                #endif
                if let error = progress.error { Text(error).font(.footnote).foregroundStyle(.red) }
                Text("NO TIMER. JUST YOU & A LITTLE POSSIBILITY.").font(.caption2.weight(.medium)).tracking(1).frame(maxWidth: .infinity).multilineTextAlignment(.center).foregroundStyle(ScapeTheme.teal)
            }.padding(24).frame(maxWidth: 560)
        }.frame(maxWidth: .infinity).background(ScapeTheme.cream).foregroundStyle(ScapeTheme.ink)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $settingsOpen) { SettingsView(isPause: false) }
    }
}

struct LevelSelectionView: View {
    @EnvironmentObject private var progress: ProgressModel
    @State private var selectedTier = DifficultyTier.beginner
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("The garden path").font(.system(.largeTitle, design: .rounded).bold())
                Text("100 small escapes. One colorful journey.").foregroundStyle(ScapeTheme.teal)
                WorldArtwork().frame(height: 150).clipShape(RoundedRectangle(cornerRadius: 24))
                HStack {
                    Text("\(selectedTier.title) · \(selectedTier.range.lowerBound)–\(selectedTier.range.upperBound)").font(.system(.title3, design: .rounded).bold())
                    Spacer()
                    Label("\(progress.progress.totalStars)/300", systemImage: "star.fill").font(.caption.bold()).foregroundStyle(ScapeTheme.teal)
                }
                Text(selectedTier.guidance).font(.subheadline).foregroundStyle(ScapeTheme.teal)
                ForEach((progress.manager?.levels ?? []).filter { $0.tier == selectedTier }) { level in
                    NavigationLink(value: GameRoute.game(level.id)) {
                        HStack(spacing: 16) {
                            Text(String(format: "%02d", level.id)).font(.system(.title2, design: .rounded).bold()).minimumScaleFactor(0.6).frame(width: 52, height: 52)
                                .background(ScapeTheme.teal.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))
                            VStack(alignment: .leading, spacing: 7) {
                                Text(level.name).font(.system(.headline, design: .rounded))
                                Text(progress.progress.bestMoves[level.id].map { "Best: \($0) moves" } ?? (progress.progress.isUnlocked(level.id) ? "Ready to restore" : "Complete world \(level.id - 1) to unlock"))
                                    .font(.caption).foregroundStyle(ScapeTheme.teal)
                                StarRating(stars: progress.progress.stars[level.id, default: 0])
                            }
                            Spacer(minLength: 4)
                            Image(systemName: progress.progress.isCompleted(level.id) ? "checkmark.seal.fill" : (progress.progress.isUnlocked(level.id) ? "arrow.right" : "lock.fill"))
                        }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 23))
                    }.buttonStyle(.plain).disabled(!progress.progress.isUnlocked(level.id))
                        .accessibilityIdentifier("level-\(level.id)")
                }
            }.padding(20).frame(maxWidth: 560)
        }.frame(maxWidth: .infinity).background(ScapeTheme.cream).foregroundStyle(ScapeTheme.ink)
            .navigationTitle("Puzzle worlds").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(DifficultyTier.allCases, id: \.self) { tier in
                            Button("\(tier.title) · \(tier.range.lowerBound)–\(tier.range.upperBound)") { selectedTier = tier }
                                .accessibilityIdentifier("tier-\(tier.rawValue)")
                        }
                    } label: { Label("Difficulty", systemImage: "line.3.horizontal.decrease") }
                    .accessibilityIdentifier("tier-picker")
                }
            }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var guideOpen = false
    let isPause: Bool
    var onRestart: (() -> Void)?
    var onHome: (() -> Void)?
    var body: some View {
        NavigationStack {
            Form {
                if isPause {
                    Section {
                        Button("Resume puzzle") { dismiss() }.accessibilityIdentifier("resume")
                        Button("Restart puzzle") { onRestart?(); dismiss() }
                        Button("Back to home") { onHome?(); dismiss() }
                    }
                }
                Section {
                    Toggle("Sound effects", systemImage: "speaker.wave.2", isOn: $settings.sound).accessibilityIdentifier("sound-setting")
                    Toggle("Haptic feedback", systemImage: "hand.tap", isOn: $settings.haptics).accessibilityIdentifier("haptic-setting")
                    Toggle("Reduce motion", systemImage: "figure.stand", isOn: $settings.reduceMotion).accessibilityIdentifier("motion-setting")
                } header: { Text("Make yourself comfortable") } footer: { Text("System Reduce Motion is always respected. Sound effects also respect Silent Mode.") }
                Section {
                    NavigationLink("Analytics and diagnostics") { TelemetryPreferencesView() }
                        .accessibilityIdentifier("analytics-settings")
                } header: { Text("Privacy") }
                Section {
                    Button("Learn to sort") { guideOpen = true }
                    Text("Tap a vessel, then a matching top color or an empty vessel. Restore each vessel with four matching pieces.")
                    Text("◆ Coral diamond   ● Blue circle\n✿ Mint flower   ✦ Gold star")
                } header: { Text("A gentle guide") }
                #if DEBUG
                AdPrivacyView()
                #endif

            }.navigationTitle(isPause ? "Take a breath" : "Your preferences")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.tint(ScapeTheme.teal)
            .sheet(isPresented: $guideOpen) { SortingGuide() }
    }
}
