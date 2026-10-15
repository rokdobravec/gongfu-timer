import StoreKit
import SwiftUI

/// The one-time "Pro" unlock (history, stats, inventory), via StoreKit 2.
/// The price itself (€4.99) is set in App Store Connect, or in
/// Configuration.storekit for local testing.
@MainActor
final class ProStore: ObservableObject {
    static let productID = "com.example.GongfuTimer.pro"

    @Published private(set) var isPro: Bool {
        didSet { UserDefaults.standard.set(isPro, forKey: Self.cacheKey) }
    }
    @Published private(set) var product: Product?
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?

    private static let cacheKey = "isPro.v1"
    private var updates: Task<Void, Never>?

    init() {
        // Cached so Pro users don't see the paywall flash while StoreKit loads.
        isPro = UserDefaults.standard.bool(forKey: Self.cacheKey)
        updates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { await load() }
    }

    func load() async {
        if product == nil {
            product = try? await Product.products(for: [Self.productID]).first
        }
        await refreshEntitlement()
    }

    func purchase() async {
        if product == nil { await load() }
        guard let product else {
            errorMessage = "The App Store isn't available right now. Please try again later."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
            case .pending:
                errorMessage = "Your purchase is waiting for approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
        if !isPro {
            errorMessage = "No previous purchase was found for this Apple Account."
        }
    }

    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result else {
            errorMessage = "The purchase couldn't be verified."
            return
        }
        await transaction.finish()
        await refreshEntitlement()
    }

    private func refreshEntitlement() async {
        var owned = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.productID, t.revocationDate == nil {
                owned = true
            }
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-unlockPro") { owned = true }
        #endif
        isPro = owned
    }
}
