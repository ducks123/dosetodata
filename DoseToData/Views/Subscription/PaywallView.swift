import SwiftUI
import RevenueCat

// MARK: - PaywallView

struct PaywallView: View {
    @Environment(SubscriptionService.self) private var sub
    @Environment(\.dismiss) private var dismiss

    /// When true, shows an "X" close button (e.g. when presented from within the app).
    var isDismissible: Bool = true
    /// Called instead of dismiss() after a successful purchase, or when the user
    /// skips during onboarding. Used when PaywallView is embedded in the onboarding flow.
    var onComplete: (() -> Void)? = nil

    @State private var selectedPlan: Plan = .annual
    @State private var showError = false

    enum Plan { case monthly, annual }

    // MARK: - Prices (shown while real prices load)

    private var monthlyPackage: Package? {
        sub.offerings?.current?.availablePackages
            .first { $0.storeProduct.productIdentifier == SubscriptionService.monthlyProductID }
    }

    private var annualPackage: Package? {
        sub.offerings?.current?.availablePackages
            .first { $0.storeProduct.productIdentifier == SubscriptionService.annualProductID }
    }

    private var monthlyPriceString: String {
        monthlyPackage?.storeProduct.localizedPriceString ?? "$4.99"
    }

    private var annualPriceString: String {
        annualPackage?.storeProduct.localizedPriceString ?? "$39.99"
    }

    /// Monthly cost when billed annually (for the "save X%" badge).
    private var annualPerMonthString: String {
        guard let pkg = annualPackage else { return "$3.33" }
        let price = pkg.storeProduct.price
        let perMonth = price / 12
        let formatted = pkg.storeProduct.priceFormatter?.string(from: perMonth as NSDecimalNumber) ?? "$3.33"
        return formatted
    }

    private var savingsPercent: Int {
        guard let monthly = monthlyPackage, let annual = annualPackage else { return 33 }
        let monthlyCost = monthly.storeProduct.price * 12
        let annualCost  = annual.storeProduct.price
        guard monthlyCost > 0 else { return 33 }
        let savings = ((monthlyCost - annualCost) / monthlyCost * 100) as NSDecimalNumber
        return Int(truncating: savings)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── Header ──────────────────────────────────────────────
                header
                    .padding(.top, isDismissible ? 20 : 60)

                // ── Features ────────────────────────────────────────────
                featureList
                    .padding(.top, 32)

                // ── Plan picker ─────────────────────────────────────────
                planPicker
                    .padding(.top, 28)

                // ── CTA ─────────────────────────────────────────────────
                ctaButton
                    .padding(.top, 20)
                    .padding(.horizontal, 24)

                // ── Trial note ──────────────────────────────────────────
                Group {
                    if case .trial(let days) = sub.status {
                        Text("\(days) day\(days == 1 ? "" : "s") left in your free trial. Then \(selectedPlan == .monthly ? monthlyPriceString + "/mo" : annualPriceString + "/yr"). Cancel any time.")
                    } else {
                        Text("7 days free, then \(selectedPlan == .monthly ? monthlyPriceString + "/mo" : annualPriceString + "/yr"). Cancel before trial ends and you won't be charged.")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 32)

                // ── Restore ─────────────────────────────────────────────
                Button("Restore purchases") {
                    Task { try? await sub.restorePurchases() }
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.top, 14)

                // ── Onboarding skip ──────────────────────────────────────
                if !isDismissible, onComplete != nil {
                    Button("Maybe later") {
                        onComplete?()
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Palette.textSecondary.opacity(0.6))
                    .padding(.top, 8)
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
        .overlay(alignment: .topTrailing) {
            if isDismissible {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                .padding(.top, 16)
                .padding(.trailing, 20)
            }
        }
        .overlay {
            if sub.isLoading {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.4)
                        .tint(.white)
                }
            }
        }
        .alert("Something went wrong", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sub.errorMessage ?? "Please try again.")
        }
        .onChange(of: sub.errorMessage) { _, msg in
            if msg != nil { showError = true }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .task { await sub.refresh() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.49, green: 0.30, blue: 0.94), Theme.Palette.primary],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

            Text("DoseToData Premium")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.Palette.textPrimary)

            Text("Track your health, understand your data.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Feature list

    private let features: [(String, String)] = [
        ("Unlimited daily check-ins",      "checkmark.circle.fill"),
        ("Track medications & adherence",  "pill.fill"),
        ("Insights & trend charts",        "chart.xyaxis.line"),
        ("Run custom tracking tests",      "flask.fill"),
        ("iCloud backup & sync",           "icloud.fill"),
    ]

    private var featureList: some View {
        VStack(spacing: 10) {
            ForEach(features, id: \.0) { title, icon in
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Palette.primary)
                        .frame(width: 24)
                    Text(title)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Plan picker

    private var planPicker: some View {
        VStack(spacing: 10) {
            planRow(
                plan: .annual,
                title: "Annual",
                subtitle: "\(annualPerMonthString)/mo — billed \(annualPriceString)/yr",
                badge: "SAVE \(savingsPercent)%"
            )
            planRow(
                plan: .monthly,
                title: "Monthly",
                subtitle: "\(monthlyPriceString)/month",
                badge: nil
            )
        }
    }

    private func planRow(plan: Plan, title: String, subtitle: String, badge: String?) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            selectedPlan = plan
        } label: {
            HStack(spacing: 14) {
                // Radio circle
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.Palette.primary : Theme.Palette.divider, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Theme.Palette.primary)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }

                Spacer()

                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Palette.success)
                        .clipShape(Capsule())
                }
            }
            .padding(16)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? Theme.Palette.primary : Color.clear,
                        lineWidth: 2
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            let pkg = selectedPlan == .monthly ? monthlyPackage : annualPackage
            guard let pkg else { return }
            Task {
                do {
                    try await sub.purchase(package: pkg)
                    if let onComplete { onComplete() } else { dismiss() }
                } catch {
                    sub.errorMessage = error.localizedDescription
                }
            }
        } label: {
            Text(selectedPlan == .annual ? "Start 7-Day Free Trial" : "Try Free for 7 Days")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Theme.Palette.primary, Color(red: 0.35, green: 0.20, blue: 0.80)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Theme.Palette.primary.opacity(0.35), radius: 8, y: 4)
        }
    }
}

// MARK: - LockedFeatureButton

/// Wraps any button label. Shows it normally when user can write; shows a
/// lock overlay and presents the paywall when they can't.
struct LockedFeatureButton<Label: View>: View {
    @Environment(SubscriptionService.self) private var sub
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var showPaywall = false

    var body: some View {
        Button {
            if sub.status.canWrite {
                action()
            } else {
                showPaywall = true
            }
        } label: {
            label()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(sub)
        }
    }
}

// MARK: - TrialBanner

/// A small amber banner shown inside the Today / Schedule tabs while on trial.
struct TrialBanner: View {
    @Environment(SubscriptionService.self) private var sub
    @State private var showPaywall = false

    var body: some View {
        if case .trial(let days) = sub.status {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                    Text(days == 1 ? "Last day of free trial" : "\(days) days left in free trial")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("Upgrade →")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color(red: 0.55, green: 0.38, blue: 0.0))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.Palette.pastelYellow)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environment(sub)
            }
        }
    }
}

// MARK: - ExpiredBanner

/// Full-bleed banner shown when the trial has expired.
struct ExpiredBanner: View {
    @Environment(SubscriptionService.self) private var sub
    @State private var showPaywall = false

    var body: some View {
        if sub.status == .expired {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                    Text("Your free trial has ended — upgrade to keep logging")
                        .font(.system(size: 13, weight: .semibold))
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.Palette.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .sheet(isPresented: $showPaywall) {
                PaywallView(isDismissible: true)
                    .environment(sub)
            }
        }
    }
}
