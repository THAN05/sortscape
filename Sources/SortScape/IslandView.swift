import SwiftUI
import SpriteKit
import PuzzleCore

struct CurrencyBalanceView: View {
    let coins: Int
    let stars: Int
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 20))) {
            Label("\(coins) coins", systemImage: "sun.max.fill").accessibilityIdentifier("wallet-coins")
            if !typeSize.isAccessibilitySize { Spacer() }
            Label("\(stars) stars", systemImage: "star.fill").accessibilityIdentifier("wallet-stars")
        }.font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(ScapeTheme.teal).accessibilityElement(children: .contain)
    }
}

struct IslandView: View {
    @EnvironmentObject private var progress: ProgressModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var board = IslandBoardModel()
    @State private var dialogOpen = false
    @State private var feedback: String?
    @State private var constructionMessage = "Tap a plot or choose a restoration plan."
    private let effects = GameFeedback()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CurrencyBalanceView(coins: progress.progress.coins, stars: progress.progress.starBalance)
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Your little island").font(.system(.largeTitle, design: .rounded).bold())
                            Text("A place you bring to life, one puzzle at a time.").font(.subheadline).foregroundStyle(ScapeTheme.teal)
                        }
                    }
                    SpriteView(scene: board.scene).frame(height: 330).clipShape(RoundedRectangle(cornerRadius: 30))
                        .shadow(color: ScapeTheme.teal.opacity(0.12), radius: 12, y: 6)
                        .accessibilityHidden(true)
                    HStack {
                        Text("\(progress.progress.island.completionPercentage)% restored").font(.headline).accessibilityIdentifier("island-percentage")
                        Spacer()
                        Text("\(progress.progress.island.restored.count)/10 plans").font(.subheadline)
                    }
                    ProgressView(value: Double(progress.progress.island.restored.count), total: 10).tint(ScapeTheme.teal)
                        .accessibilityLabel("Island completion")
                    if let objective = progress.progress.nextRestorationObjective {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("NEXT LITTLE POSSIBILITY").font(.caption.weight(.heavy)).tracking(1)
                            Text(objective.name).font(.system(.title3, design: .rounded).bold())
                            Text(requirements(objective)).font(.subheadline)
                        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white, in: RoundedRectangle(cornerRadius: 22)).accessibilityIdentifier("next-objective")
                    } else {
                        Label("Island complete. A beautiful place to be.", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(ScapeTheme.teal)
                    }
                    Text(constructionMessage).font(.subheadline).foregroundStyle(ScapeTheme.teal).accessibilityIdentifier("construction-message")
                    if progress.progress.purchases.ownsTheme {
                        Toggle("Moonlit Lagoon theme", isOn: Binding(get: { progress.progress.purchases.premiumThemeSelected }, set: { progress.selectPremiumTheme($0) }))
                            .accessibilityIdentifier("premium-theme")
                    }
                    Text("Restoration plans").font(.system(.title2, design: .rounded).bold())
                    ForEach(RestorationItem.all) { item in
                        plan(item).id(item.id)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Restore your island at your own pace.").font(.headline)
                        Text("Coins pay for construction. Stars unlock plans and are not consumed. Clear more worlds or improve your stars for extra rewards.").font(.footnote)
                        Text("Lifetime: \(progress.progress.economy.lifetimeCoinsEarned) coins earned · \(progress.progress.economy.lifetimeCoinsSpent) spent").font(.caption)
                        Text("Island milestones: +20 coins at 2 plans, +40 at 5, +75 at 10.").font(.caption)
                    }.foregroundStyle(ScapeTheme.teal).padding(.vertical)
                    if let error = progress.error { Text(error).foregroundStyle(.red).font(.footnote) }
                }.padding(20).frame(maxWidth: 560)
            }.frame(maxWidth: .infinity).background(ScapeTheme.cream).foregroundStyle(ScapeTheme.ink)
                .navigationTitle("Island restoration").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
                .onAppear { updateScene() }
                .onChange(of: progress.progress) { _, _ in updateScene() }
                .onChange(of: board.selected) { _, id in
                    updateScene()
                    if let id {
                        if systemReduceMotion || settings.reduceMotion { proxy.scrollTo(id, anchor: .center) }
                        else { withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(id, anchor: .center) } }
                    }
                }
                .onChange(of: systemReduceMotion) { _, _ in updateScene() }
                .onChange(of: settings.reduceMotion) { _, _ in updateScene() }
                .onChange(of: scenePhase) { _, phase in board.scene.isPaused = phase != .active; if phase != .active { effects.stop() } }
                .onDisappear { effects.stop() }
                .alert("A little more to go", isPresented: $dialogOpen) {
                    Button("Got it", role: .cancel) {}
                } message: { Text(feedback ?? "") }


        }
    }
    private func plan(_ item: RestorationItem) -> some View {
        let status = progress.progress.restorationStatus(item)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Group {
                    if let name = IslandRewardArt.name(for: item.id), let artwork = UIImage(named: name) {
                        Image(uiImage: artwork).resizable().scaledToFit().padding(3)
                    } else {
                        Image(systemName: item.icon).font(.system(size: 25)).foregroundStyle(ScapeTheme.teal)
                    }
                }.frame(width: 48, height: 48).background(ScapeTheme.teal.opacity(0.09), in: RoundedRectangle(cornerRadius: 15)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name).font(.system(.headline, design: .rounded))
                    Text(item.detail).font(.subheadline).foregroundStyle(ScapeTheme.teal)
                }
                Spacer(minLength: 0)
            }
            Text(requirements(item)).font(.caption).foregroundStyle(ScapeTheme.teal)
            if status == .restored {
                Label("Restored", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(ScapeTheme.teal)
                    .frame(minHeight: 44).accessibilityIdentifier("restored-\(item.id.rawValue)")
            } else {
                Button {
                    board.selected = item.id
                    switch status {
                    case .available: build(item)
                    case .insufficientCoins: notify("You need \(item.cost - progress.progress.coins) more coins for \(item.name). Keep sorting—every new world earns at least 25 coins.")
                    case .locked: notify(requirements(item))
                    case .restored: break
                    }
                } label: {
                    Label(status == .locked ? "Locked plan" : (status == .insufficientCoins ? "Need \(item.cost - progress.progress.coins) more coins" : "Restore · \(item.cost) coins"), systemImage: status == .locked ? "lock.fill" : "hammer.fill")
                }.buttonStyle(ScapeButtonStyle(secondary: status != .available))
                    .accessibilityIdentifier("restore-\(item.id.rawValue)")
                    .accessibilityLabel("\(item.name), \(status == .locked ? "locked" : "restore for \(item.cost) coins")")
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(board.selected == item.id ? ScapeTheme.coral : .clear, lineWidth: 2))
    }
    private func requirements(_ item: RestorationItem) -> String {
        var result = "\(item.cost) coins · Clear \(item.requiredLevels) worlds · Earn \(item.requiredStars) stars"
        if let prior = item.prerequisite, let name = RestorationItem.all.first(where: { $0.id == prior })?.name { result += " · Restore \(name) first" }
        return result
    }
    private func updateScene() {
        board.scene.reduceMotion = systemReduceMotion || settings.reduceMotion
        board.scene.update(progress: progress.progress, selected: board.selected)
    }
    private func build(_ item: RestorationItem) {
        switch progress.restore(item.id) {
        case .restored(let bonus):
            constructionMessage = "\(item.name) restored!" + (bonus > 0 ? " Milestone: +\(bonus) coins." : "")
            effects.play(.complete)
            UIAccessibility.post(notification: .announcement, argument: constructionMessage)
        case .alreadyRestored: constructionMessage = "\(item.name) is already part of your island."
        case .insufficientCoins(let needed): buildFailure("You need \(needed) more coins. No coins were spent.")
        case .locked: buildFailure("This plan still has requirements to meet. No coins were spent.")
        case .invalidTransaction: buildFailure(progress.error ?? "Restoration could not be completed. No coins were spent.")
        }
    }
    private func notify(_ text: String) { feedback = text; dialogOpen = true; effects.play(.invalid) }
    private func buildFailure(_ text: String) {
        constructionMessage = text; effects.play(.invalid)
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}
