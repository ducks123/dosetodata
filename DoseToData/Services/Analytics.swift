import Foundation
import PostHog

/// Product analytics for the acquisition funnel and retention.
///
/// ## Hard rules — do not relax these
///
/// 1. **No health content, ever.** Event names and numeric counts only.
///    Never a medication name, dose, mood score, side effect, note, date of
///    a check-in, or anything a user typed. If you are unsure whether a
///    value qualifies, it does — leave it out.
/// 2. **Anonymous.** We never call `identify()`, never attach an email, and
///    never set person properties. PostHog sees a random per-install ID and
///    nothing that ties it to a human.
/// 3. **No autocapture, no session replay.** Both are disabled below.
///    Session replay in particular would record medication names and mood
///    scores straight off the screen.
///
/// These rules are what let the app declare Product Interaction data as
/// "not linked to identity" and "not used for tracking" in
/// `PrivacyInfo.xcprivacy`, and keep `NSPrivacyTracking = false`.
enum Analytics {

    /// PostHog project API key (a publishable client key, not a secret —
    /// same class of value as the RevenueCat SDK key).
    ///
    /// Paste the key from PostHog → Project Settings → Project API Key.
    /// Until it is set, every call below is a no-op, so the app builds and
    /// runs normally with analytics simply switched off.
    static let apiKey = ""

    /// PostHog Cloud region host. Use "https://eu.i.posthog.com" for the EU.
    static let host = "https://us.i.posthog.com"

    private static var isEnabled = false

    // MARK: - Setup

    static func configure() {
        guard !apiKey.isEmpty, !isEnabled else { return }

        let config = PostHogConfig(apiKey: apiKey, host: host)
        // Explicit events only — nothing captured by accident.
        config.captureScreenViews = false
        config.captureApplicationLifecycleEvents = false
        config.sessionReplay = false
        // No IDFA / IDFV collection.
        config.optOut = false

        PostHogSDK.shared.setup(config)
        isEnabled = true
    }

    /// Single choke point for every event. Keeping one function makes the
    /// "no health content" rule auditable in one place.
    private static func capture(_ event: String, _ properties: [String: Any]? = nil) {
        guard isEnabled else { return }
        PostHogSDK.shared.capture(event, properties: properties)
    }

    // MARK: - Retention
    //
    // PostHog derives retention cohorts from any recurring event, so this one
    // event is what powers the Day 1 / Day 7 numbers.

    static func appOpened() {
        capture("app_opened")
    }

    // MARK: - Onboarding funnel

    /// `step` is a stable slug: "goals", "disclaimer", "medications".
    static func onboardingStepViewed(_ step: String) {
        capture("onboarding_step_viewed", ["step": step])
    }

    /// Count only — never which medications.
    static func onboardingMedsCompleted(medicationCount: Int) {
        capture("onboarding_meds_completed", ["medication_count": medicationCount])
    }

    /// Guided-tour progress, 1...5. See `UserPreferences.onboardingTourStage`.
    static func tourStageReached(_ stage: Int) {
        capture("tour_stage_reached", ["stage": stage])
    }

    static func tourCompleted() {
        capture("tour_completed")
    }

    // MARK: - Activation

    /// Fired when a check-in is saved. No answers, scores, or dates.
    static func checkInSaved(isFirstEver: Bool) {
        capture("checkin_saved", ["first_ever": isFirstEver])
    }

    /// `enabled` false means the user chose "Not now" on the reminder primer.
    static func reminderPrimerAnswered(enabled: Bool) {
        capture("reminder_primer_answered", ["enabled": enabled])
    }

    // MARK: - Monetization
    //
    // RevenueCat remains the source of truth for revenue. These events exist
    // so the paywall step appears in the same funnel as everything else.

    /// `context` is "onboarding" or "in_app".
    static func paywallShown(context: String) {
        capture("paywall_shown", ["context": context])
    }

    /// `plan` is "annual" or "monthly"; `isTrial` marks a free-trial start.
    static func purchaseCompleted(plan: String, isTrial: Bool) {
        capture("purchase_completed", ["plan": plan, "is_trial": isTrial])
    }
}
