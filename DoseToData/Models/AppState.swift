import Foundation
import SwiftUI

@Observable
final class AppState {
    var onboardingStep: Int = 0
    var hasCompletedOnboarding: Bool = false
}
