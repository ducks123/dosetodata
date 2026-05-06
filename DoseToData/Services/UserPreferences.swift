import Foundation
import SwiftUI

enum TrackingGoal: String, CaseIterable, Identifiable, Codable {
    case mood
    case medications
    case sideEffects
    case sleep
    case energy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mood: return "Mood"
        case .medications: return "Medications"
        case .sideEffects: return "Side effects"
        case .sleep: return "Sleep"
        case .energy: return "Energy"
        }
    }

    var icon: String {
        switch self {
        case .mood: return "heart.fill"
        case .medications: return "pill.fill"
        case .sideEffects: return "exclamationmark.triangle.fill"
        case .sleep: return "moon.fill"
        case .energy: return "bolt.fill"
        }
    }
}

@Observable
final class UserPreferences {
    private enum Keys {
        static let hasCompletedOnboarding = "dosetodata.onboarding.completed"
        static let trackingGoals = "dosetodata.onboarding.trackingGoals"
        static let disclaimerAccepted = "dosetodata.disclaimer.accepted"
        static let displayName = "dosetodata.user.displayName"
        static let dailyCheckInReminderEnabled = "dosetodata.reminders.dailyCheckIn.enabled"
        static let dailyCheckInReminderTime = "dosetodata.reminders.dailyCheckIn.time"
        static let checkInReminderTimes = "dosetodata.reminders.checkIn.times"
    }

    /// Default time for the end-of-day check-in reminder.
    static let defaultDailyCheckInTime = "20:00"
    /// Default reminder times: 5 PM only.
    static let defaultCheckInReminderTimes: [String] = ["17:00"]

    private let defaults: UserDefaults

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    var disclaimerAccepted: Bool {
        didSet { defaults.set(disclaimerAccepted, forKey: Keys.disclaimerAccepted) }
    }

    var trackingGoals: Set<TrackingGoal> {
        didSet {
            let raw = trackingGoals.map { $0.rawValue }
            defaults.set(raw, forKey: Keys.trackingGoals)
        }
    }

    var displayName: String {
        didSet { defaults.set(displayName, forKey: Keys.displayName) }
    }

    /// Whether the user wants a daily push to do their check-in.
    var dailyCheckInReminderEnabled: Bool {
        didSet { defaults.set(dailyCheckInReminderEnabled, forKey: Keys.dailyCheckInReminderEnabled) }
    }

    /// Stored as "HH:mm" (24-hour). Use `dailyCheckInReminderComponents` to read.
    var dailyCheckInReminderTime: String {
        didSet { defaults.set(dailyCheckInReminderTime, forKey: Keys.dailyCheckInReminderTime) }
    }

    /// Parsed hour/minute from `dailyCheckInReminderTime`, falling back to 8pm if malformed.
    var dailyCheckInReminderComponents: (hour: Int, minute: Int) {
        let parts = dailyCheckInReminderTime.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]),
              (0...23).contains(h),
              (0...59).contains(m)
        else { return (20, 0) }
        return (h, m)
    }

    /// Array of "HH:mm" times the user wants check-in reminders.
    /// Empty = no reminders. Default is 5 PM.
    var checkInReminderTimes: [String] {
        didSet { defaults.set(checkInReminderTimes, forKey: Keys.checkInReminderTimes) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.disclaimerAccepted = defaults.bool(forKey: Keys.disclaimerAccepted)
        self.displayName = defaults.string(forKey: Keys.displayName) ?? ""
        let rawGoals = defaults.array(forKey: Keys.trackingGoals) as? [String] ?? []
        self.trackingGoals = Set(rawGoals.compactMap(TrackingGoal.init(rawValue:)))
        // Legacy single-reminder fields (kept for Settings time-picker compat)
        if defaults.object(forKey: Keys.dailyCheckInReminderEnabled) == nil {
            self.dailyCheckInReminderEnabled = true
            defaults.set(true, forKey: Keys.dailyCheckInReminderEnabled)
        } else {
            self.dailyCheckInReminderEnabled = defaults.bool(forKey: Keys.dailyCheckInReminderEnabled)
        }
        self.dailyCheckInReminderTime = defaults.string(forKey: Keys.dailyCheckInReminderTime)
            ?? Self.defaultDailyCheckInTime
        // Multi-reminder times — default 5 PM for new installs
        self.checkInReminderTimes = (defaults.array(forKey: Keys.checkInReminderTimes) as? [String])
            ?? Self.defaultCheckInReminderTimes
    }
}
