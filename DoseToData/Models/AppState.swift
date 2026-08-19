import Foundation
import SwiftUI

@Observable
final class AppState {
    var onboardingStep: Int = 0
    var hasCompletedOnboarding: Bool = false
    var pendingInsightsTestID: UUID? = nil
    var shouldNavigateToInsights: Bool = false
    var pendingTodayDate: Date? = nil
    var confettiTrigger: UUID? = nil
    /// Set to a random encouraging message after a successful today check-in.
    /// Cleared when TodayView renders it (so it only shows once per submission).
    var postCheckInMessage: String? = nil
}

// MARK: - Streak helpers

extension AppState {
    /// Calculates the current consecutive-day check-in streak from a sorted list
    /// of check-in dates (oldest first). Returns 0 if the user hasn't checked in
    /// today or yesterday (streak is considered broken).
    static func currentStreak(from checkIns: [Date], calendar: Calendar = .current) -> Int {
        let days = Set(checkIns.map { calendar.startOfDay(for: $0) })
            .sorted(by: >)   // newest first
        guard !days.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Streak only counts if the user checked in today or yesterday
        guard days[0] == today || days[0] == yesterday else { return 0 }

        var streak = 0
        var cursor = days[0]
        for day in days {
            if day == cursor {
                streak += 1
                cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
            } else {
                break
            }
        }
        return streak
    }

    static let milestoneDays: Set<Int> = [7, 30, 60, 100]

    static let encouragingMessages: [String] = [
        "Great job prioritizing your health today! 💪",
        "Another day logged. You're building something valuable.",
        "Small steps, big picture. Keep it up!",
        "Your future self will thank you for this.",
        "Consistency is the real superpower. Nice work.",
        "You showed up today. That matters more than you know.",
        "Data is only as good as the person collecting it, and you're doing great.",
    ]
}
