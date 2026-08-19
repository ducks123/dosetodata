import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(UserPreferences.self) private var prefs

    var body: some View {
        Group {
            // The guided tour (tourStage > 0) runs inside the real app; the
            // question steps only show before the tour has started.
            if (prefs.hasCompletedOnboarding && prefs.disclaimerAccepted) || prefs.onboardingTourStage > 0 {
                MainTabView()
            } else {
                OnboardingContainerView()
            }
        }
        .preferredColorScheme(.light)
    }
}
