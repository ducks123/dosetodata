import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @Environment(UserPreferences.self) private var prefs
    @Environment(SubscriptionService.self) private var sub
    @Environment(\.modelContext) private var modelContext

    @State private var step: Int = 0

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()

            switch step {
            case 0:
                TrackingGoalsStepView(onContinue: advance, onSkip: advance)
                    .transition(.opacity)
            case 1:
                MedicationsOnboardingStepView(onContinue: advance, onSkip: advance)
                    .transition(.opacity)
            case 2:
                PrivacyDisclaimerStepView(onAccept: advance)
                    .transition(.opacity)
            default:
                PaywallView(isDismissible: false, onComplete: finish)
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
