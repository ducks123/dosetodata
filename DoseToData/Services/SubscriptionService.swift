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
    var isRefreshing = false
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
        isRefreshing = true
        defer { isRefreshing = false }

        // 10-second timeout on customerInfo so we never hang indefinitely.
        do {
            let customerInfo = try await withTimeout(seconds: 10) {
                try await Purchases.shared.customerInfo()
            }
            apply(customerInfo: customerInfo)
        } catch {
            if status == .loading {
                // RevenueCat unreachable — fall back to local trial / grandfather status.
                applyLocalStatus()
            }
        }
        // 10-second timeout on offerings — non-fatal, paywall uses fallback prices.
        do {
            offerings = try await withTimeout(seconds: 10) {
                try await Purchases.shared.offerings()
            }
        } catch {
            // Non-fatal — paywall will show fallback prices.
        }
    }

    // MARK: - Timeout helper

    private func withTimeout<T: Sendable>(
        seconds: Double,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw CancellationError()
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
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

    // MARK: - Local trial

    /// Stores the date when the local trial expires (new users only).
    private static let trialExpiryKey = "com.stewartsherpa.dosetodata.trialExpiry"
    /// UserDefaults key written by UserPreferences when onboarding completes.
    private static let onboardingCompletedKey = "dosetodata.onboarding.completed"
    /// Persisted flag so grandfathered status survives across launches.
    private static let grandfatheredKey = "com.stewartsherpa.dosetodata.grandfathered"

    /// Returns the number of trial days remaining, or `nil` if the user is permanently grandfathered.
    ///
    /// - Existing users (had the app before this build): grandfathered → returns `nil` → maps to `.active`.
    /// - New users: 7-day trial → returns days remaining → 0 maps to `.expired`.
    static func localTrialDaysLeft() -> Int? {
        let defaults = UserDefaults.standard

        // Already marked grandfathered on a previous launch — fast path.
        if defaults.bool(forKey: grandfatheredKey) { return nil }

        if let expiry = defaults.object(forKey: trialExpiryKey) as? Date {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
            return max(0, days)
        } else {
            // First time this code runs on this device.
            let isExistingUser = defaults.bool(forKey: onboardingCompletedKey)
            if isExistingUser {
                // Had the app before — grandfather them in permanently.
                defaults.set(true, forKey: grandfatheredKey)
                return nil
            } else {
                // Brand-new user — start the 7-day trial clock.
                let expiry = Calendar.current.date(byAdding: .day, value: trialDays, to: Date())!
                defaults.set(expiry, forKey: trialExpiryKey)
                return trialDays
            }
        }
    }

    // MARK: - Private helpers

    /// Applies status based solely on the local trial / grandfather state.
    private func applyLocalStatus() {
        if let daysLeft = Self.localTrialDaysLeft() {
            status = daysLeft > 0 ? .trial(daysLeft: daysLeft) : .expired
        } else {
            status = .active // permanently grandfathered existing user
        }
    }

    private func apply(customerInfo: CustomerInfo) {
        guard let entitlement = customerInfo.entitlements[Self.entitlementID],
              entitlement.isActive else {
            // No active RevenueCat entitlement — fall back to local trial / grandfather status.
            applyLocalStatus()
            return
        }

        // RevenueCat reports an App Store introductory free trial as `.intro`,
        // not `.trial`. Treat both as "in trial" so the banner + days-left UI
        // works for users in either kind of introductory period.
        let isInTrialPeriod = entitlement.periodType == .trial
            || entitlement.periodType == .intro
        if isInTrialPeriod {
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
