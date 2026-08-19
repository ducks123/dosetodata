import SwiftUI
import SwiftData

/// Drives the question steps of onboarding:
///
///   0. Goals       — what to track (tailors the daily check-in)
///   1. Disclaimer  — privacy promise + medical disclaimers
///   2. Medications — add current meds (skippable)
///
/// After the medications step the user lands in the real app for a guided
/// tour (first check-in on Today → Schedule → Insights → paywall → reminder),
/// driven by `prefs.onboardingTourStage` and rendered by MainTabView.
struct OnboardingContainerView: View {
    @Environment(UserPreferences.self) private var prefs

    @State private var step: Int = 0

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()

            switch step {
            case 0:
                TrackingGoalsStepView(onContinue: advance, onSkip: advance)
                    .transition(.opacity)
            case 1:
                PrivacyDisclaimerStepView(onAccept: {
                    prefs.disclaimerAccepted = true
                    advance()
                })
                .transition(.opacity)
            default:
                MedicationsOnboardingStepView(onContinue: {
                    // Hand off to the in-app guided tour; RootView switches
                    // to MainTabView once the stage is non-zero.
                    prefs.onboardingTourStage = 1
                })
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    private func advance() {
        step += 1
    }
}

#Preview {
    OnboardingContainerView()
        .environment(UserPreferences())
        .modelContainer(for: Medication.self, inMemory: true)
}
