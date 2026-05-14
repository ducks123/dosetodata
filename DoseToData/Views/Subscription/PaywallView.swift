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

    @State private var selectedPlan: Plan = .trialAnnual
    @State private var showError = false
    @State private var showSilentRestoreAlert = false

    enum Plan: Equatable {
        case annual
        case monthly
        case trialAnnual
        case trialMonthly

        var isTrial: Bool {
            self == .trialAnnual || self == .trialMonthly
        }

        var isAnnual: Bool {
            self == .annual || self == .trialAnnual
        }
    }

    // MARK: - Packages

    private var monthlyPackage: Package? {
        sub.offerings?.current?.availablePackages
            .first { $0.storeProduct.productIdentifier == SubscriptionService.monthlyProductID }
    }

    private var annualPackage: Package? {
        sub.offerings?.current?.availablePackages
            .first { $0.storeProduct.productIdentifier == SubscriptionService.annualProductID }
    }

    private var selectedPackage: Package? {
        switch selectedPlan {
        case .annual, .trialAnnual:   return annualPackage
        case .monthly, .trialMonthly: return monthlyPackage
        }
    }

    // MARK: - Price strings

    private var packagesLoaded: Bool {
        monthlyPackage != nil || annualPackage != nil
    }

    private var monthlyPriceString: String {
        monthlyPackage?.storeProduct.localizedPriceString ?? "—"
    }

    private var annualPriceString: String {
        annualPackage?.storeProduct.localizedPriceString ?? "—"
    }

    private var annualPerMonthString: String {
        guard let pkg = annualPackage else { return "—" }
        let price = pkg.storeProduct.price
        let perMonth = price / 12
        return pkg.storeProduct.priceFormatter?.string(from: perMonth as NSDecimalNumber) ?? "—"
    }

    private var savingsPercent: Int {
        guard let monthly = monthlyPackage, let annual = annualPackage else { return 0 }
        let monthlyCost = monthly.storeProduct.price * 12
        let annualCost  = annual.storeProduct.price
        guard monthlyCost > 0 else { return 0 }
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

                // ── Retry link when offerings fail to load ───────────────
                if !packagesLoaded && !sub.isRefreshing {
                    Button {
                        Task { await sub.refresh() }
                    } label: {
                        Label("Could not load prices — tap to retry", systemImage: "arrow.clockwise")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.Palette.negative)
                    }
                    .padding(.top, 12)
                }

                // ── Billed-amount summary ───────────────────────────────
                // Apple Guideline 3.1.2(c): the billed total must be clearly
                // and conspicuously displayed in the purchase flow. Putting it
                // directly above the CTA in a slightly heavier weight so it
                // can't be missed.
                billedAmountSummary
                    .padding(.top, 18)
                    .padding(.horizontal, 24)

                // ── CTA ─────────────────────────────────────────────────
                ctaButton
                    .padding(.top, 8)
                    .padding(.horizontal, 24)

                // ── Cancel-anytime fine print ───────────────────────────
                trialNote
                    .padding(.top, 8)
                    .padding(.horizontal, 32)

                // ── Apple-required subscription disclosure ───────────────
                legalDisclosure
                    .padding(.top, 8)
                    .padding(.horizontal, 24)

                // ── Restore ─────────────────────────────────────────────
                Button("Restore purchases") {
                    Task { try? await sub.restorePurchases() }
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.top, 8)

                // ── Legal links ──────────────────────────────────────────
                HStack(spacing: 4) {
                    Link("Privacy Policy", destination: LegalLinks.privacyPolicy)
                    Text("·")
                    Link("Terms of Use", destination: LegalLinks.termsOfService)
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.top, 8)

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
        .overlay(alignment: .topTrailing) {
            if isDismissible {
                Button { dismiss() } label: {
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
                    ProgressView().scaleEffect(1.4).tint(.white)
                }
            }
        }
        .alert("Something went wrong", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sub.errorMessage ?? "Please try again.")
        }
        .alert("You're already subscribed", isPresented: $showSilentRestoreAlert) {
            Button("Enter app") { finish() }
            Button("Stay here", role: .cancel) {}
        } message: {
            Text("This Apple ID already has an active DoseToData subscription, so no new charge was made. Tap Enter app to continue.")
        }
        .onChange(of: sub.errorMessage) { _, msg in
            if msg != nil { showError = true }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .task {
            sub.errorMessage = nil  // clear any stale error before presenting
            await sub.refresh()
        }
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
        ("Unlimited daily check-ins",       "checkmark.circle.fill"),
        ("Track medications & adherence",   "pill.fill"),
        ("Insights & trend charts",         "chart.xyaxis.line"),
        ("Run custom tracking tests",       "flask.fill"),
        ("Medication timeline & reminders", "bell.fill"),
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

            // ── Annual ──────────────────────────────────────────────────
            // App Store Guideline 3.1.2(c): the BILLED amount must be the
            // most prominent pricing element. We show $39.99/yr large and
            // the calculated $3.33/mo equivalent small and subordinate.
            planRow(
                plan: .annual,
                title: "Annual",
                billed: "\(annualPriceString)/year",
                secondary: "Just \(annualPerMonthString)/mo equivalent",
                badge: savingsPercent > 0 ? "SAVE \(savingsPercent)%" : nil
            )

            // ── Monthly ─────────────────────────────────────────────────
            planRow(
                plan: .monthly,
                title: "Monthly",
                billed: "\(monthlyPriceString)/month",
                secondary: nil,
                badge: nil
            )

            // ── Free trial ──────────────────────────────────────────────
            trialRow
        }
    }

    /// A tappable row for Annual or Monthly direct plans.
    /// `billed` is the total billed amount and is the largest text; `secondary`
    /// (e.g. "$3.33/mo equivalent") is rendered small and muted underneath.
    private func planRow(plan: Plan, title: String, billed: String, secondary: String?, badge: String?) -> some View {
        let isSelected = selectedPlan == plan
        return Button { selectedPlan = plan } label: {
            HStack(spacing: 14) {
                radioCircle(selected: isSelected)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text(billed)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    if let secondary {
                        Text(secondary)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
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
                    .stroke(isSelected ? Theme.Palette.primary : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    /// The "7-Day Free Trial" row, which expands to show Annual/Monthly sub-options when selected.
    /// Sub-options lead with the BILLED amount (e.g., $39.99/year, $4.99/month)
    /// per App Store Guideline 3.1.2(c) — the trial framing is subordinate to
    /// the price the user will actually be charged after the trial.
    private var trialRow: some View {
        let isTrialSelected = selectedPlan.isTrial
        return VStack(spacing: 0) {
            Button { selectedPlan = .trialAnnual } label: {
                HStack(spacing: 14) {
                    radioCircle(selected: isTrialSelected)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Try it first")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.Palette.textSecondary)
                        Text("Free for 7 days")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("Then your selected plan price below")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "gift.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.Palette.primary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            // Sub-options — only visible when trial is selected
            if isTrialSelected {
                Divider().padding(.horizontal, 16)

                HStack(spacing: 0) {
                    trialSubOption(
                        plan: .trialAnnual,
                        label: "Then",
                        billed: "\(annualPriceString)/yr",
                        secondary: "\(annualPerMonthString)/mo equivalent",
                        badge: savingsPercent > 0 ? "SAVE \(savingsPercent)%" : nil
                    )
                    Divider().frame(height: 72)
                    trialSubOption(
                        plan: .trialMonthly,
                        label: "Then",
                        billed: "\(monthlyPriceString)/mo",
                        secondary: nil,
                        badge: nil
                    )
                }
                .padding(.vertical, 6)
            }
        }
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isTrialSelected ? Theme.Palette.primary : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .animation(.easeInOut(duration: 0.18), value: isTrialSelected)
    }

    private func trialSubOption(plan: Plan, label: String, billed: String, secondary: String?, badge: String?) -> some View {
        let isSelected = selectedPlan == plan
        return Button { selectedPlan = plan } label: {
            VStack(spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isSelected ? Theme.Palette.primary : Color.clear)
                        .overlay(Circle().stroke(isSelected ? Theme.Palette.primary : Theme.Palette.divider, lineWidth: 1.5))
                        .frame(width: 14, height: 14)
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Text(billed)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let secondary {
                    Text(secondary)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Palette.success)
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
    }

    private func radioCircle(selected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(selected ? Theme.Palette.primary : Theme.Palette.divider, lineWidth: 2)
                .frame(width: 22, height: 22)
            if selected {
                Circle()
                    .fill(Theme.Palette.primary)
                    .frame(width: 12, height: 12)
            }
        }
    }

    // MARK: - Billed-amount summary
    //
    // Apple Guideline 3.1.2(c) compliance: this is the load-bearing line
    // that states the total billed amount in a clear, prominent way. Any
    // free-trial / introductory framing lives in `trialNote` below, in a
    // smaller, subordinate position relative to this.

    private var billedAmountSummary: some View {
        let text: String
        switch selectedPlan {
        case .annual:
            text = "You will be billed \(annualPriceString) per year."
        case .monthly:
            text = "You will be billed \(monthlyPriceString) per month."
        case .trialAnnual:
            text = "After your 7-day free trial: \(annualPriceString) per year."
        case .trialMonthly:
            text = "After your 7-day free trial: \(monthlyPriceString) per month."
        }
        return Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.Palette.textPrimary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Trial / cancel-anytime fine print
    //
    // Intentionally smaller and lighter than `billedAmountSummary` above so
    // the billed amount stays the most prominent pricing element.

    private var trialNote: some View {
        Group {
            if case .trial(let days) = sub.status {
                Text("\(days) day\(days == 1 ? "" : "s") left in your free trial. Cancel any time.")
            } else if selectedPlan.isTrial {
                Text("Cancel before the trial ends and you won't be charged.")
            } else {
                Text("Cancel any time in iOS Settings.")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.Palette.textSecondary)
        .multilineTextAlignment(.center)
    }

    // MARK: - Legal disclosure (Apple Guideline 3.1.2)

    private var legalDisclosure: some View {
        Text("""
Payment will be charged to your Apple ID account at confirmation of purchase. \
Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. \
Your account will be charged for renewal within 24 hours prior to the end of the current period. \
You can manage and cancel your subscriptions in your App Store account settings. \
Any unused portion of a free trial will be forfeited upon purchase of a subscription.
""")
        .font(.system(size: 11))
        .foregroundStyle(Theme.Palette.textSecondary.opacity(0.8))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            guard let pkg = selectedPackage else { return }
            Task {
                do {
                    let outcome = try await sub.purchase(package: pkg)
                    switch outcome {
                    case .newPurchase:
                        // Real, fresh transaction — advance into the app.
                        finish()
                    case .silentRestore:
                        // Apple silently completed because this Apple ID
                        // already owns the product. Don't slip into the app;
                        // make the user explicitly acknowledge.
                        showSilentRestoreAlert = true
                    case .userCancelled:
                        // User dismissed Apple's payment sheet. Stay on the
                        // paywall. No alert, no advance.
                        break
                    }
                } catch {
                    // If the user cancelled the Apple payment sheet, stay on the
                    // paywall silently — no alert, no dismiss.
                    let nsError = error as NSError
                    let isCancelled = nsError.code == 1        // RevenueCat purchaseCancelled
                        || nsError.code == 2                   // SKError.paymentCancelled
                        || nsError.code == 9                   // SKError.overlayTimeout
                        || nsError.localizedDescription.lowercased().contains("cancel")
                    guard !isCancelled else { return }
                    sub.errorMessage = error.localizedDescription
                }
            }
        } label: {
            Group {
                if sub.isLoading || sub.isRefreshing {
                    HStack(spacing: 10) {
                        ProgressView().tint(.white).scaleEffect(0.85)
                        Text("Loading…").font(.system(size: 16, weight: .bold))
                    }
                } else {
                    Text(ctaLabel)
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: packagesLoaded
                        ? [Theme.Palette.primary, Color(red: 0.35, green: 0.20, blue: 0.80)]
                        : [Color.gray, Color.gray.opacity(0.8)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Theme.Palette.primary.opacity(packagesLoaded ? 0.35 : 0), radius: 8, y: 4)
        }
        .disabled(sub.isLoading || sub.isRefreshing || !packagesLoaded)
    }

    private var ctaLabel: String {
        guard packagesLoaded else { return "Loading prices…" }
        switch selectedPlan {
        case .trialAnnual, .trialMonthly: return "Start 7-Day Free Trial"
        case .annual:                      return "Subscribe Annually"
        case .monthly:                     return "Subscribe Monthly"
        }
    }

    private func finish() {
        if let onComplete { onComplete() } else { dismiss() }
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
            let totalDays = SubscriptionService.trialDays
            let dayNumber = max(1, totalDays - days + 1)
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(days == 1 ? "Last day of your free trial" : "Day \(dayNumber) of \(totalDays) — free trial")
                            .font(.system(size: 13, weight: .semibold))
                        Text(days == 1 ? "Upgrade today to keep access" : "\(days) days remaining")
                            .font(.system(size: 11))
                            .opacity(0.8)
                    }
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
