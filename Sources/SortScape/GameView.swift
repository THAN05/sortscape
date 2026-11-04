import SwiftUI
import SpriteKit
import PuzzleCore

private enum GameSheet: String, Identifiable { case pause, completion; var id: String { rawValue } }

struct GameView: View {
    @EnvironmentObject private var ads: AdCoordinator
    @EnvironmentObject private var progress: ProgressModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var router: GameRouter
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @StateObject private var model: GameModel
    @State private var sheet: GameSheet?
    @State private var advancing = false
    @State private var reward = RewardReceipt()
    @State private var completionPresented = false
    let level: Level
    init(level: Level) { self.level = level; _model = StateObject(wrappedValue: GameModel(level: level, checkpoint: .application(level: level))) }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())) {
                        Label("\(model.session.moveCount) moves", systemImage: "arrow.left.arrow.right").accessibilityIdentifier("moves")
                        if !typeSize.isAccessibilitySize { Spacer() }
                        Label("\(progress.progress.coins) coins", systemImage: "sun.max.fill").accessibilityIdentifier("coins")
                    }.frame(maxWidth: .infinity, alignment: .leading).font(.system(.subheadline, design: .rounded).weight(.semibold))
                    board.frame(height: max(typeSize.isAccessibilitySize ? 340 : 240, geometry.size.height - boardReservedHeight))
                    Text(model.message).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(ScapeTheme.teal)
                        .frame(maxWidth: .infinity, minHeight: 42).accessibilityIdentifier("game-message")
                    (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))) {
                        control("Undo", icon: "arrow.uturn.backward", disabled: !model.session.canUndo || model.busy || model.findingHint) { model.undo() }
                        control("Restart", icon: "arrow.clockwise", disabled: model.busy || model.findingHint) { model.restart() }
                        control(hintUsed ? "Hint used" : "Hint", icon: "lightbulb", disabled: hintUsed || !model.acceptsInput, identifier: "hint") {
                            model.hint(record: { progress.useHint(in: level.id) })
                        }
                    }
                    if !hintUsed && progress.progress.availableHints > 0 {
                        Button("Use move assist (\(progress.progress.availableHints) tokens)") {
                            model.hint(applyMove: { progress.useHint(in: level.id, spendingToken: true) })
                        }.frame(minHeight: 44).disabled(!model.acceptsInput).accessibilityIdentifier("use-hint-token")
                    }
                    if ads.enabled && !model.completionReady {
                        (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))) {
                            if !hintUsed {
                                RewardAdButton(title: "Free Hint") { watchRewardAd(.hint, placement: "hint") }
                                    .disabled(ads.busy || !model.acceptsInput).accessibilityIdentifier("ad-hint")
                            }
                            RewardAdButton(title: "Free 2-Move Rewind") { watchRewardAd(.undo, placement: "undo") }
                                .disabled(ads.busy || !model.acceptsInput).accessibilityIdentifier("ad-undo")
                        }
                        Text(ads.message).font(.caption).foregroundStyle(ScapeTheme.teal)
                    }
                    if ads.hasPendingReward {
                        Button("Retry saving earned ad reward") { ads.retryPendingRewards() }.frame(minHeight: 44)
                    }
                    if progress.progress.adRewards.undos > 0 {
                        Button("Rewind two moves (\(progress.progress.adRewards.undos) tokens)") {
                            model.rewind { progress.consumeAdUndo() }
                        }.frame(minHeight: 44).disabled(!model.acceptsInput || model.session.moveCount < 2).accessibilityIdentifier("use-rewind-token")
                    }
                    if model.completionReady {
                        Button("View your restored world") { sheet = .completion }.buttonStyle(ScapeButtonStyle())
                    }
                    if let error = model.checkpointError { Text(error).font(.footnote).foregroundStyle(.red) }
                    if let error = progress.error { Text(error).foregroundStyle(.red).font(.footnote) }
                }.padding(.horizontal, 20).padding(.vertical, 12).frame(maxWidth: 560)
            }.frame(maxWidth: .infinity)
        }.background(ScapeTheme.cream).foregroundStyle(ScapeTheme.ink)
            .navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("WORLD \(String(format: "%02d", level.id)) · \(level.tier.title.uppercased())")
                            .font(.caption2.weight(.heavy))
                            .tracking(1)
                            .foregroundStyle(ScapeTheme.teal)
                        Text(level.name)
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundStyle(ScapeTheme.ink)
                    }
                    .lineLimit(1)
                    .frame(width: 200, alignment: .leading)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.pause(); sheet = .pause } label: {
                        Image(systemName: "pause.fill")
                    }
                    .accessibilityLabel("Pause")
                    .accessibilityIdentifier("pause")
                }
            }
            .navigationBarBackButtonHidden(model.busy)
            .onAppear { updateMotion(); model.resume(); ads.location = model.completionReady ? .completed(level.id) : .playing }
            .onDisappear { model.leave(); ads.location = .menu }
            .onChange(of: systemReduceMotion) { _, _ in updateMotion() }
            .onChange(of: settings.reduceMotion) { _, _ in updateMotion() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { model.pause(); if sheet == nil && !ads.busy { sheet = .pause } }
            }
            .onChange(of: model.completionReady, initial: true) { _, ready in
                if ready {
                    ads.location = .completed(level.id)
                    reward = progress.complete(level: level, session: model.session)
                    if reward.rating > 0 { model.clearCompletedCheckpoint() }
                    ads.levelCompleted()
                    Task { await ads.preload() }
                    if !model.paused { completionPresented = true; sheet = .completion }
                } else { completionPresented = false; ads.location = .playing }
            }
            .sheet(item: $sheet, onDismiss: {
                guard !advancing else { return }
                model.resume()
                if model.completionReady && !completionPresented {
                    completionPresented = true
                    Task { @MainActor in sheet = .completion }
                }
            }) { content in
                switch content {
                case .pause:
                    SettingsView(isPause: true, onRestart: { model.restart() }, onHome: { router.home() })
                case .completion:
                    CompletionView(level: level, moves: model.session.moveCount, reward: reward,
                                   canAdvance: nextLevel != nil, saveError: progress.error,
                                   advancing: advancing, next: advance,
                                   replay: { model.restart(); sheet = nil }, home: { sheet = nil; router.home() })
                }
            }
    }

    private func advance() {
        guard !advancing, let nextLevel else { return }
        advancing = true
        if ads.canShowInterstitial(after: level.id) {
            // Keep the completion sheet as the presenter until the ad closes.
            Task {
                await ads.betweenLevels(completedLevel: level.id)
                guard router.path.last == .game(level.id) else { return }
                openNextWorld(nextLevel.id)
                await ads.preload()
            }
        } else {
            openNextWorld(nextLevel.id)
        }
    }

    private func openNextWorld(_ id: Int) {
        router.next(id)
        sheet = nil
    }

    private func watchRewardAd(_ reward: AdReward, placement: String) {
        guard model.acceptsInput, !ads.busy else { return }
        Telemetry.shared.emit(AnalyticsEvent(name: .rewardedOffered, parameters: ["placement": .text(placement), "level_id": .integer(level.id)]))
        model.pause()
        Task {
            await ads.reward(reward)
            if ads.isActive { model.resume() } else { sheet = .pause }
            await ads.preload()
        }
    }

    private var nextLevel: Level? {
        guard let next = progress.manager?.next(after: level.id), progress.progress.isUnlocked(next.id) else { return nil }
        return next
    }
    private func updateMotion() { model.reduceMotion = systemReduceMotion || settings.reduceMotion }
    private var boardReservedHeight: CGFloat {
        if typeSize.isAccessibilitySize { return 330 }
        var height: CGFloat = 250
        if ads.enabled && !model.completionReady { height += 110 }
        if !hintUsed && progress.progress.availableHints > 0 { height += 60 }
        if progress.progress.adRewards.undos > 0 { height += 60 }
        if ads.hasPendingReward { height += 60 }
        return height
    }

    private var hintUsed: Bool { progress.progress.hasUsedHint(in: level.id) }
    private func control(_ title: String, icon: String, disabled: Bool, identifier: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) { Image(systemName: icon).font(.system(size: 20)); Text(title).font(.caption.weight(.semibold)) }
                .frame(maxWidth: .infinity, minHeight: 68).background(.white, in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain).disabled(disabled).opacity(disabled ? 0.4 : 1).accessibilityLabel(title).accessibilityIdentifier(identifier ?? title.lowercased())
    }
    private var board: some View {
        GeometryReader { geometry in
            ZStack {
                SpriteView(scene: model.scene).accessibilityHidden(true)
                // Shared geometry provides real 44pt+ touch targets and individual VoiceOver actions.
                ForEach(Array(model.session.state.containers.indices), id: \.self) { index in
                    let rect = BoardLayout.tubes(size: geometry.size, count: model.session.state.containers.count)[index]
                    Button { model.select(index) } label: { Color.clear.contentShape(Rectangle()) }
                        .buttonStyle(.plain)
                        .frame(width: max(44, rect.width + 16), height: max(44, rect.height + 20))
                        .position(x: rect.midX, y: geometry.size.height - rect.midY)
                        .accessibilityLabel(model.containerLabel(index))
                        .accessibilityHint(model.selected == nil ? "Select the top piece" : "Move selected piece here")
                        .accessibilityAddTraits(model.selected == index ? .isSelected : [])
                        .accessibilityIdentifier("vessel-\(index)")
                        .disabled(!model.acceptsInput)
                }
            }.accessibilityElement(children: .contain).accessibilityIdentifier("puzzle-board")
                .clipShape(RoundedRectangle(cornerRadius: 30))
                .overlay(RoundedRectangle(cornerRadius: 30).stroke(.white.opacity(0.5), lineWidth: 1))
                .shadow(color: ScapeTheme.teal.opacity(0.16), radius: 14, y: 8)
        }
    }
}

struct CompletionView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @EnvironmentObject private var settings: AppSettings
    @State private var appeared = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @EnvironmentObject private var ads: AdCoordinator
    @EnvironmentObject private var progress: ProgressModel
    @EnvironmentObject private var router: GameRouter
    let level: Level
    let moves: Int
    let reward: RewardReceipt
    let canAdvance: Bool
    let saveError: String?
    let advancing: Bool
    let next: () -> Void
    let replay: () -> Void
    let home: () -> Void
    var body: some View {
        ViewThatFits(in: .vertical) {
            completionContent.fixedSize(horizontal: false, vertical: true)
            ScrollView { completionContent }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ScapeTheme.cream)
        .presentationDragIndicator(.visible)
        .disabled(advancing)
        .interactiveDismissDisabled(ads.busy || advancing)
        .onAppear {
            if systemReduceMotion || settings.reduceMotion { appeared = true }
            else { withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { appeared = true } }
        }
    }

    private var completionContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 38))
                .foregroundStyle(.white, ScapeTheme.teal)
                .frame(width: 52, height: 52)
                .background(ScapeTheme.teal.opacity(0.12), in: Circle())
                .scaleEffect(appeared ? 1 : 0.8)
                .accessibilityHidden(true)
            Text("World restored!").font(.system(.title, design: .rounded).bold())
            Text("\(level.tier.title) · \(level.name)").font(.subheadline).foregroundStyle(ScapeTheme.teal)
            StarRating(stars: level.stars(for: moves)).font(.title).accessibilityIdentifier("completion-stars")
            Text("3 stars: \(level.metrics.map { $0.solutionLength + max(1, $0.solutionLength / 5) } ?? moves) moves or fewer. Replay to improve your best.")
                .font(.caption).foregroundStyle(ScapeTheme.teal).multilineTextAlignment(.center)
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 16))) {
                Label("\(moves) moves", systemImage: "arrow.left.arrow.right")
                Label(reward.coinsEarned > 0 ? "+\(reward.coinsEarned) coins" : "Rewards already earned", systemImage: "sun.max.fill")
            }.font(.system(.subheadline, design: .rounded).bold())
            VStack(spacing: 4) {
                HStack { Text("First clear"); Spacer(); Text("+\(reward.baseCoins) coins") }
                HStack { Text("Efficiency bonus"); Spacer(); Text("+\(reward.efficiencyCoins) coins") }
                if reward.milestoneCoins > 0 {
                    HStack { Text("Milestone bonus"); Spacer(); Text("+\(reward.milestoneCoins) coins") }
                }
                HStack { Text("New stars"); Spacer(); Text("+\(reward.starsEarned) stars") }
            }.font(.subheadline).padding(10).background(.white, in: RoundedRectangle(cornerRadius: 22))
            ProgressView(value: Double(progress.progress.bestMoves.count), total: 100).tint(ScapeTheme.teal).accessibilityLabel("Campaign progress")
            Text("\(progress.progress.bestMoves.count)/100 worlds restored").font(.caption).foregroundStyle(ScapeTheme.teal)
            if let saveError {
                Text(saveError).foregroundStyle(.red).font(.footnote)
            } else if reward.coinsEarned > 0 || reward.starsEarned > 0 {
                Label("Rewards saved automatically", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(ScapeTheme.teal)
            }
            if ads.enabled {
                if !progress.progress.adRewards.hasBonus(for: level.id) {
                    RewardAdButton(title: "Free 25 Coin Bonus") {
                        Telemetry.shared.emit(AnalyticsEvent(name: .rewardedOffered, parameters: ["placement": .text("level_bonus"), "level_id": .integer(level.id)]))
                        Task {
                            await ads.reward(.levelCoins(level.id))
                            await ads.preload()
                        }
                    }
                        .disabled(ads.busy).accessibilityIdentifier("ad-bonus-coins")
                } else {
                    Label("Ad bonus collected · 25 coins", systemImage: "checkmark.seal.fill")
                        .font(.headline).foregroundStyle(ScapeTheme.teal).accessibilityIdentifier("ad-bonus-saved")
                }
                Text(ads.message).font(.caption).foregroundStyle(ScapeTheme.teal)
            }
            if ads.hasPendingReward { Button("Retry saving earned reward") { ads.retryPendingRewards() } }
            if canAdvance { Button("Next world →", action: next).buttonStyle(ScapeButtonStyle()).accessibilityIdentifier("next-world").disabled(ads.busy) }
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))) {
                completionAction("Play again", icon: "arrow.clockwise", action: replay)
                    .accessibilityIdentifier("replay")
                completionAction("Visit my island", icon: "leaf.fill") {
                    home()
                    router.path.append(.island)
                }.accessibilityIdentifier("completion-island")
                completionAction("Back to home", icon: "house.fill", action: home)
            }
            .disabled(ads.busy)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .foregroundStyle(ScapeTheme.ink)
    }

    private func completionAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.subheadline).accessibilityHidden(true)
                Text(title).font(.caption.weight(.semibold))
            }
            .foregroundStyle(ScapeTheme.ink)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}



private struct RewardAdButton: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(ScapeTheme.teal, in: Circle())
                    .accessibilityHidden(true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        Text(title).font(.subheadline.weight(.semibold))
                        Text("Watch ad").font(.caption)
                    }.fixedSize()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.subheadline.weight(.semibold))
                        Text("Watch ad").font(.caption)
                    }
                }
            }
            .foregroundStyle(ScapeTheme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minHeight: 44)
            .background(ScapeTheme.teal.opacity(0.09), in: Capsule())
            .overlay { Capsule().strokeBorder(ScapeTheme.teal.opacity(0.22)) }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityLabel("\(title), watch ad")
    }
}
