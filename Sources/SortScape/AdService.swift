import UIKit
import PuzzleCore

enum AdFormat: String, Codable, Sendable { case rewarded, interstitial }
enum AdEvent: Sendable {
    case load(AdFormat), loaded(AdFormat), show(AdFormat), impression(AdFormat), dismissed(AdFormat), failed(AdFormat)
    case earned, revenue(AdFormat, Double, String)
}
@MainActor
protocol AdService: AnyObject {
    var event: ((AdEvent) -> Void)? { get set }
    var rewardedReady: Bool { get }
    var interstitialReady: Bool { get }
    func initialize() async
    func loadRewarded() async
    func loadInterstitial() async
    func presentRewarded(earned: @escaping @MainActor () -> Void) async -> Bool
    func presentInterstitial() async -> Bool
    func discardLoadedAds()
}
@MainActor
protocol AdConsentService: AnyObject {
    var canRequestAds: Bool { get }
    var privacyOptionsRequired: Bool { get }
    func update() async throws
    func privacyOptions() async throws
    func cancel()
}

/// Deterministic service: never initializes Google, accesses the network, or shows live ads.
@MainActor
final class MockAdService: AdService {
    var event: ((AdEvent) -> Void)?
    var rewardedReady = false, interstitialReady = false
    var loadSucceeds = true, presentationSucceeds = true, earnsReward = true, duplicateCallbacks = false
    var holdPresentation = false
    private var completion: CheckedContinuation<Bool, Never>?
    private(set) var initializeCount = 0
    private(set) var presentations = 0
    func initialize() async { initializeCount += 1 }
    func loadRewarded() async { event?(.load(.rewarded)); rewardedReady = loadSucceeds; event?(loadSucceeds ? .loaded(.rewarded) : .failed(.rewarded)) }
    func loadInterstitial() async { event?(.load(.interstitial)); interstitialReady = loadSucceeds; event?(loadSucceeds ? .loaded(.interstitial) : .failed(.interstitial)) }
    func presentRewarded(earned: @escaping @MainActor () -> Void) async -> Bool {
        guard rewardedReady, presentationSucceeds else { event?(.failed(.rewarded)); return false }
        rewardedReady = false; presentations += 1; event?(.show(.rewarded)); event?(.impression(.rewarded))
        if earnsReward { event?(.earned); earned(); if duplicateCallbacks { earned() } }
        if holdPresentation { return await withCheckedContinuation { completion = $0 } }
        event?(.dismissed(.rewarded)); return true
    }
    func presentInterstitial() async -> Bool {
        guard interstitialReady, presentationSucceeds else { event?(.failed(.interstitial)); return false }
        interstitialReady = false; presentations += 1; event?(.show(.interstitial)); event?(.impression(.interstitial))
        event?(.dismissed(.interstitial)); return true
    }
    func dismiss() { event?(.dismissed(.rewarded)); completion?.resume(returning: true); completion = nil }
    func discardLoadedAds() { rewardedReady = false; interstitialReady = false }
}
@MainActor
final class MockAdConsentService: AdConsentService {
    var canRequestAds = true, privacyOptionsRequired = true, fails = false
    var holdUpdate = false
    private var updateContinuation: CheckedContinuation<Void, Never>?
    func update() async throws {
        if holdUpdate { await withCheckedContinuation { updateContinuation = $0 } }
        if fails { throw URLError(.notConnectedToInternet) }
    }
    private(set) var cancellationCount = 0
    func cancel() { cancellationCount += 1 }
    func completeUpdate() { updateContinuation?.resume(); updateContinuation = nil }
    func privacyOptions() async throws { try await update() }
}
