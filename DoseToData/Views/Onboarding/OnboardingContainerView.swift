import SwiftUI
import SwiftData

/// Drives the onboarding sequence:
///
///   0. Goals            — what to track (tailors the daily check-in)
///   1. Disclaimer       — privacy promise + medical disclaimers
///   2. Medications      — add current meds (skippable)
///   3. First check-in   — the real DailyCheckInSheet (skippable → paywall)
///   4. Day-1 chart      — confetti + first data point (only after a check-in)
///   5. Paywall          — hard gate; trial-first framing in this mode
///   6. Reminder primer  — schedule the daily nudge, then enter the app
struct OnboardingContainerView: View {
    @Environment(UserPreferences.self) private var prefs
    @Environment(SubscriptionService.self) private var sub
    @Environment(\.modelContext) private var modelContext

    @State private var step: Int = 0
    @State private var didLogFirstCheckIn = false

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()

            switch step {
            case 0:
                TrackingGoalsStepView(onContinue: advance, onSkip: advance)
                    .transition(.opacity)
            case 1:
                PrivacyDisclaimerStepView(onAccept: advance)
                    .transition(.opacity)
            case 2:
                MedicationsOnboardingStepView(onContinue: advance)
                    .transition(.opacity)
            case 3:
                OnboardingCheckInStepView(
                    onSaved: {
                        didLogFirstCheckIn = true
                        advance()
                    },
                    onSkip: {
                        // No check-in → nothing to celebrate; skip the
                        // Day-1 chart and go straight to the paywall.
                        step = 5
                    }
                )
                .transition(.opacity)
            case 4:
                Day1ChartStepView(onContinue: advance)
                    .transition(.opacity)
            case 5:
                PaywallView(
                    isDismissible: false,
                    dayOneLogged: didLogFirstCheckIn,
                    onComplete: advance
                )
                .transition(.opacity)
            default:
                ReminderPrimerStepView(onDone: finish)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    private func advance() {
        step += 1
    }

    private func finish() {
        prefs.disclaimerAccepted = true
        prefs.hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingContainerView()
        .environment(UserPreferences())
        .modelContainer(for: Medication.self, inMemory: true)
}
