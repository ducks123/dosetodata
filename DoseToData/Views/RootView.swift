import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(UserPreferences.self) private var prefs

    var body: some View {
        Group {
            if prefs.hasCompletedOnboarding && prefs.disclaimerAccepted {
                MainTabView()
            } else {
                OnboardingContainerView()
            }
        }
        .preferredColorScheme(.light)
    }
}
