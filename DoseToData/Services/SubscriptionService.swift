import Foundation
import RevenueCat

// MARK: - Subscription status

enum SubscriptionStatus: Equatable {
    /// Still checking with RevenueCat.
    case loading
    /// Within the 14-day free trial.
    case trial(daysLeft: Int)
    /// Active paid subscriber.
    case active
    /// Trial expired, no active subscription — read-only mode.
    case expired

    var canWrite: Bool {
        switch self {
        case .loading, .trial, .active: return true
        case .expired: return false
        }
    }

    var isTrial: Bool {
        if case .trial = self { return true }
        return false
    }

    var daysLeftInTrial: Int? {
        if case .trial(let days) = self { return days }
        return nil
    }
}

// MARK: - SubscriptionService

@Observable
final class SubscriptionService {

    // MARK: - Constants

    static let apiKey = "appl_HgzNcfwmgesUTjULAJRtoOoELMg"
    static let entitlementID = "premium"
    static let monthlyProductID = "com.stewartsherpa.dosetodata.monthly"
    static let annualProductID  = "com.stewartsherpa.dosetodata.annual"
    static let trialDays = 7

    // MARK: - Observed state

    var status: SubscriptionStatus = .loading
    var offerings: Offerings? = nil
    var isLoading = false
    var errorMessage: String? = nil

    // MARK: - Configure

    @discardableResult
    static func configure() -> Bool {
        guard apiKey.hasPrefix("appl_") else { return false }
        Purchases.configure(withAPIKey: apiKey)
        Purchases.logLevel = .error
        return true
    }

    // MARK: - Fetch current status

    @MainActor
    func refresh() async {
        guard Self.configure() else {
            status = .expired
            return
        }
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            apply(customerInfo: customerInfo)
        } catch {
            if status == .loading { status = .expired }
        }
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            // Non-fatal — paywall will show fallback prices.
        }
    }

    // MARK: - Purchase

    @MainActor
    func purchase(package: Package) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let result = try await Purchases.shared.purchase(package: package)
        apply(customerInfo: result.customerInfo)
    }

    // MARK: - Restore

    @MainActor
    func restorePurchases() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let customerInfo = try await Purchases.shared.restorePurchases()
        apply(customerInfo: customerInfo)
    }

    // MARK: - Private helpers

    private func apply(customerInfo: CustomerInfo) {
        guard let entitlement = customerInfo.entitlements[Self.entitlementID],
              entitlement.isActive else {
            status = .expired
            return
        }

        if entitlement.periodType == .trial {
            // Compute days left from the entitlement's expiration date.
            if let expDate = entitlement.expirationDate {
                let days = Calendar.current.dateComponents(
                    [.day], from: Date(), to: expDate
                ).day ?? 0
                status = .trial(daysLeft: max(1, days))
            } else {
                status = .trial(daysLeft: Self.trialDays)
            }
        } else {
            status = .active
        }
    }
}
