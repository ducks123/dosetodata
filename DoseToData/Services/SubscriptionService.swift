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

    /// Persisted last-known write-access answer. Lets the brief `.loading`
    /// window at cold start avoid failing open for expired users (H1) without
    /// flashing a paywall at paying users.
    private static let lastKnownCanWriteKey = "com.stewartsherpa.dosetodata.lastKnownCanWrite"

    /// Effective write access for the current state. During `.loading` we
    /// fall back to the last resolved answer (cached) instead of unconditionally
    /// allowing writes; everything else defers to `status.canWrite`. Call sites
    /// should use this, not `status.canWrite`, so the cold-start window is
    /// handled consistently.
    var canWrite: Bool {
        Self.effectiveCanWrite(
            status: status,
            lastKnownCanWrite: UserDefaults.standard.object(forKey: Self.lastKnownCanWriteKey) as? Bool
        )
    }

    /// Pure decision used by `canWrite` (extracted for testability). During
    /// `.loading`, returns `lastKnownCanWrite` if we have one, else `true`
    /// (fresh install mid-onboarding must not be blocked). Otherwise the
    /// status's own `canWrite`.
    static func effectiveCanWrite(status: SubscriptionStatus, lastKnownCanWrite: Bool?) -> Bool {
        if case .loading = status {
            return lastKnownCanWrite ?? true
        }
        return status.canWrite
    }

    // MARK: - Constants

    static let apiKey = "appl_HgzNcfwmgesUTjULAJRtoOoELMg"
    static let entitlementID = "premium"
    static let monthlyProductID = "com.stewartsherpa.dosetodata.monthly"
    static let annualProductID  = "com.stewartsherpa.dosetodata.annual"
    static let trialDays = 14

    // MARK: - Observed state

    var status: SubscriptionStatus = .loading {
        didSet {
            // Cache the resolved write-access decision so the transient
            // `.loading` window at cold start can fall back to the last real
            // answer (see `canWrite`). Skip `.loading` itself — we only want
            // to remember resolved states.
            if case .loading = status { return }
            UserDefaults.standard.set(status.canWrite, forKey: Self.lastKnownCanWriteKey)
        }
    }
    var offerings: Offerings? = nil
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String? = nil
    /// For trials this is when the free trial ends (and the user is first
    /// charged). For paid subscriptions this is the next renewal date. Nil
    /// for grandfathered / local-fallback users with no real RC entitlement.
    var expirationDate: Date? = nil
    /// Whether auto-renewal is currently on. False after the user has
    /// cancelled (still active until expiration, but won't renew).
    var willRenew: Bool = false

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

    /// The outcome of a `purchase(package:)` call.
    enum PurchaseOutcome {
        /// A brand-new transaction was created — the user actually subscribed.
        case newPurchase
        /// The user's Apple ID already owned this product, so StoreKit
        /// silently completed without a real purchase. The entitlement is now
        /// active but no money/trial was started right now.
        case silentRestore
        /// The user dismissed Apple's purchase sheet without confirming.
        /// RevenueCat v5 reports this via `result.userCancelled` rather than
        /// throwing, so we MUST surface it explicitly — otherwise callers
        /// treat a cancellation as a successful purchase and bypass the
        /// paywall.
        case userCancelled
    }

    @MainActor
    func purchase(package: Package) async throws -> PurchaseOutcome {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Snapshot the latest purchase date BEFORE attempting to buy, so we
        // can tell whether this call actually created a new transaction.
        let beforeInfo = try? await Purchases.shared.customerInfo()
        let beforeDate = beforeInfo?.entitlements[Self.entitlementID]?.latestPurchaseDate

        let result = try await Purchases.shared.purchase(package: package)

        // RC 5.x: cancellation returns userCancelled=true instead of throwing.
        // Catching this BEFORE apply() is the load-bearing check that
        // prevents a cancelled purchase from being treated as success.
        if result.userCancelled {
            return .userCancelled
        }

        apply(customerInfo: result.customerInfo)

        let afterDate = result.customerInfo.entitlements[Self.entitlementID]?.latestPurchaseDate
        // If the latestPurchaseDate didn't change, no fresh transaction
        // happened — StoreKit just acknowledged the existing entitlement.
        if let afterDate, beforeDate == afterDate {
            return .silentRestore
        }
        // Also catch the case where the entitlement was active before AND
        // after but the date moved within the last few seconds (rare, but
        // possible during fast sandbox resubscribe). Anything older than 30s
        // is a restore.
        if let afterDate, Date().timeIntervalSince(afterDate) > 30 {
            return .silentRestore
        }
        return .newPurchase
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

    /// Whole trial days remaining until `expiry`, computed from the exact
    /// timestamp so the final partial day isn't lost. Returns 0 only once
    /// `now` has reached/passed `expiry`; while any time remains it returns at
    /// least 1. (Previously the caller floored `.day` components, so a trial
    /// with under 24h left reported 0 and expired up to a day early — M6.)
    static func trialDaysRemaining(expiry: Date, now: Date) -> Int {
        guard now < expiry else { return 0 }
        let seconds = expiry.timeIntervalSince(now)
        return max(1, Int(ceil(seconds / 86_400)))
    }

    /// Returns the number of trial days remaining, or `nil` if the user is permanently grandfathered.
    ///
    /// - Existing users (had the app before this build): grandfathered → returns `nil` → maps to `.active`.
    /// - New users: local fallback trial → days remaining → 0 maps to `.expired`.
    static func localTrialDaysLeft() -> Int? {
        let defaults = UserDefaults.standard

        // Already marked grandfathered on a previous launch — fast path.
        if defaults.bool(forKey: grandfatheredKey) { return nil }

        if let expiry = defaults.object(forKey: trialExpiryKey) as? Date {
            // Gate on the exact expiry timestamp, not a floored day count.
            return trialDaysRemaining(expiry: expiry, now: Date())
        } else {
            // First time this code runs on this device.
            let isExistingUser = defaults.bool(forKey: onboardingCompletedKey)
            if isExistingUser {
                // Had the app before — grandfather them in permanently.
                defaults.set(true, forKey: grandfatheredKey)
                return nil
            } else {
                // Brand-new user — start the local fallback trial clock.
                let expiry = Calendar.current.date(byAdding: .day, value: trialDays, to: Date())!
                defaults.set(expiry, forKey: trialExpiryKey)
                return trialDays
            }
        }
    }

    // MARK: - Private helpers

    /// Applies status based solely on the local trial / grandfather state.
    private func applyLocalStatus() {
        // No RC entitlement, so no real expiration / renewal data.
        willRenew = false
        if let daysLeft = Self.localTrialDaysLeft() {
            status = daysLeft > 0 ? .trial(daysLeft: daysLeft) : .expired
            // Reflect the local trial's expiry so Settings can still show a date.
            expirationDate = UserDefaults.standard.object(forKey: Self.trialExpiryKey) as? Date
        } else {
            status = .active // permanently grandfathered existing user
            expirationDate = nil
        }
    }

    private func apply(customerInfo: CustomerInfo) {
        guard let entitlement = customerInfo.entitlements[Self.entitlementID],
              entitlement.isActive else {
            // No active RevenueCat entitlement — fall back to local trial / grandfather status.
            applyLocalStatus()
            return
        }

        expirationDate = entitlement.expirationDate
        willRenew = entitlement.willRenew

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
